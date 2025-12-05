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

#ifndef XMRIG_OCLVERTHASHRUNNER_H
#define XMRIG_OCLVERTHASHRUNNER_H

#include "backend/opencl/runners/OclBaseRunner.h"

#include <mutex>

namespace xmrig {

class OclVerthashRunner : public OclBaseRunner
{
public:
    XMRIG_DISABLE_COPY_MOVE_DEFAULT(OclVerthashRunner)

    OclVerthashRunner(size_t index, const OclLaunchData &data);
    ~OclVerthashRunner() override;

protected:
    void run(uint32_t nonce, uint32_t nonce_offset, uint32_t *hashOutput) override;
    void set(const Job &job, uint8_t *blob) override;
    void build() override;
    void init() override;
    uint32_t processedHashes() const override { return m_intensity; }

private:
    bool loadVerthashData();

    uint8_t *m_blob = nullptr;

    // Verthash data buffer on GPU
    cl_mem m_verthashData = nullptr;
    size_t m_verthashDataSize = 0;
    uint32_t m_verthashBitmask = 0;

    // Kernels
    cl_kernel m_sha3PrecomputeKernel = nullptr;
    cl_kernel m_verthashKernel = nullptr;

    // Work configuration
    size_t m_workGroupSize = 256;

    // Control queue for early job notification
    cl_command_queue m_controlQueue = nullptr;
    cl_mem m_stop = nullptr;

    // Precomputed SHA3 state buffer
    cl_mem m_sha3State = nullptr;
};

} /* namespace xmrig */

#endif // XMRIG_OCLVERTHASHRUNNER_H
