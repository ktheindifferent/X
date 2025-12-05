/* X Miner
 * Copyright (c) 2024 X Project
 * Copyright (c) 2021 CryptoGraphics
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "backend/opencl/runners/OclVerthashRunner.h"
#include "backend/common/Tags.h"
#include "backend/opencl/OclLaunchData.h"
#include "backend/opencl/wrappers/OclError.h"
#include "backend/opencl/wrappers/OclLib.h"
#include "base/io/log/Log.h"
#include "base/io/log/Tags.h"
#include "base/net/stratum/Job.h"
#include "base/tools/Chrono.h"
#include "crypto/verthash/VerthashWrapper.h"

#include <stdexcept>
#include <cstring>

namespace xmrig {

constexpr size_t BLOB_SIZE = 80;  // Verthash header size

OclVerthashRunner::OclVerthashRunner(size_t index, const OclLaunchData &data) :
    OclBaseRunner(index, data)
{
    switch (data.thread.worksize()) {
    case 64:
    case 128:
    case 256:
    case 512:
        m_workGroupSize = data.thread.worksize();
        break;
    }

    if (data.device.vendorId() == OclVendor::OCL_VENDOR_NVIDIA) {
        m_options += " -DPLATFORM=OPENCL_PLATFORM_NVIDIA";
    }
    else if (data.device.vendorId() == OclVendor::OCL_VENDOR_AMD) {
        m_options += " -DPLATFORM=OPENCL_PLATFORM_AMD";
    }
}


OclVerthashRunner::~OclVerthashRunner()
{
    OclLib::release(m_verthashData);
    OclLib::release(m_sha3State);
    OclLib::release(m_sha3PrecomputeKernel);
    OclLib::release(m_verthashKernel);
    OclLib::release(m_controlQueue);
    OclLib::release(m_stop);
}


bool OclVerthashRunner::loadVerthashData()
{
    const Verthash &vh = Verthash::instance();

    if (!vh.isValid()) {
        LOG_ERR("%s " RED("Verthash data file not loaded"), Tags::opencl());
        return false;
    }

    if (m_verthashData && m_verthashDataSize == vh.dataSize()) {
        return true;  // Already loaded
    }

    // Release old buffer if exists
    if (m_verthashData) {
        OclLib::release(m_verthashData);
        m_verthashData = nullptr;
    }

    m_verthashDataSize = vh.dataSize();
    m_verthashBitmask = vh.dataMask();

    const uint64_t start_ms = Chrono::steadyMSecs();

    // Create GPU buffer for verthash data
    cl_int ret;
    m_verthashData = OclLib::createBuffer(m_ctx, CL_MEM_READ_ONLY, m_verthashDataSize, nullptr, &ret);
    if (ret != CL_SUCCESS) {
        LOG_ERR("%s " RED("Failed to allocate verthash data buffer: %s"),
                Tags::opencl(), OclError::toString(ret));
        return false;
    }

    // Upload verthash data to GPU
    ret = OclLib::enqueueWriteBuffer(m_queue, m_verthashData, CL_TRUE, 0,
                                      m_verthashDataSize, vh.data(), 0, nullptr, nullptr);
    if (ret != CL_SUCCESS) {
        LOG_ERR("%s " RED("Failed to upload verthash data: %s"),
                Tags::opencl(), OclError::toString(ret));
        OclLib::release(m_verthashData);
        m_verthashData = nullptr;
        return false;
    }

    LOG_INFO("%s " YELLOW("Verthash") " data uploaded to GPU " BLACK_BOLD("(%" PRIu64 "ms, %zu MB)"),
             Tags::opencl(), Chrono::steadyMSecs() - start_ms, m_verthashDataSize / (1024 * 1024));

    return true;
}


void OclVerthashRunner::run(uint32_t nonce, uint32_t /*nonce_offset*/, uint32_t *hashOutput)
{
    const size_t local_work_size = m_workGroupSize;
    const size_t global_work_offset = nonce;
    const size_t global_work_size = m_intensity - (m_intensity % m_workGroupSize);

    // Write header blob to input buffer
    enqueueWriteBuffer(m_input, CL_FALSE, 0, BLOB_SIZE, m_blob);

    // Clear output buffer
    const uint32_t zero = 0;
    enqueueWriteBuffer(m_output, CL_FALSE, 0, sizeof(uint32_t), &zero);

    // Set kernel arguments
    OclLib::setKernelArg(m_verthashKernel, 0, sizeof(cl_mem), &m_verthashData);
    OclLib::setKernelArg(m_verthashKernel, 1, sizeof(cl_mem), &m_input);
    OclLib::setKernelArg(m_verthashKernel, 2, sizeof(uint32_t), &m_verthashBitmask);
    OclLib::setKernelArg(m_verthashKernel, 3, sizeof(uint32_t), &nonce);
    OclLib::setKernelArg(m_verthashKernel, 4, sizeof(cl_mem), &m_output);

    // Execute verthash kernel
    cl_int ret = OclLib::enqueueNDRangeKernel(m_queue, m_verthashKernel, 1,
                                               &global_work_offset, &global_work_size,
                                               &local_work_size, 0, nullptr, nullptr);
    if (ret != CL_SUCCESS) {
        LOG_ERR("%s" RED(" error ") RED_BOLD("%s") RED(" when calling ") RED_BOLD("clEnqueueNDRangeKernel") RED(" for kernel ") RED_BOLD("verthash"),
                ocl_tag(), OclError::toString(ret));
        throw std::runtime_error(OclError::toString(ret));
    }

    // Read results
    uint32_t output[16] = {};
    enqueueReadBuffer(m_output, CL_TRUE, 0, sizeof(output), output);

    if (output[0] > 15) {
        output[0] = 15;
    }

    hashOutput[0xFF] = output[0];
    memcpy(hashOutput, output + 1, output[0] * sizeof(uint32_t));
}


void OclVerthashRunner::set(const Job &job, uint8_t *blob)
{
    m_blob = blob;

    // Load verthash data if not already loaded
    if (!m_verthashData) {
        if (!loadVerthashData()) {
            throw std::runtime_error("Failed to load verthash data");
        }
    }

    const uint64_t target = job.target();

    // Set target in kernel
    OclLib::setKernelArg(m_verthashKernel, 5, sizeof(uint64_t), &target);
}


void OclVerthashRunner::build()
{
    OclBaseRunner::build();

    // Create kernels
    cl_int ret;

    m_sha3PrecomputeKernel = OclLib::createKernel(m_program, "sha3_512_precompute", &ret);
    if (ret != CL_SUCCESS) {
        throw std::runtime_error(OclError::toString(ret));
    }

    m_verthashKernel = OclLib::createKernel(m_program, "verthash_search", &ret);
    if (ret != CL_SUCCESS) {
        throw std::runtime_error(OclError::toString(ret));
    }
}


void OclVerthashRunner::init()
{
    OclBaseRunner::init();

    m_controlQueue = OclLib::createCommandQueue(m_ctx, data().device.id());

    cl_int ret;
    m_stop = OclLib::createBuffer(m_ctx, CL_MEM_READ_ONLY, sizeof(uint32_t) * 2, nullptr, &ret);
    if (ret != CL_SUCCESS) {
        throw std::runtime_error(OclError::toString(ret));
    }

    // Create SHA3 state buffer
    m_sha3State = OclLib::createBuffer(m_ctx, CL_MEM_READ_WRITE, m_intensity * 200, nullptr, &ret);
    if (ret != CL_SUCCESS) {
        throw std::runtime_error(OclError::toString(ret));
    }
}

} // namespace xmrig
