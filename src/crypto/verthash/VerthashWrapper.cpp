/* X Miner
 * Copyright (c) 2024 X Project
 * Copyright (c) 2018-2021 CryptoGraphics
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

#include "crypto/verthash/VerthashWrapper.h"

#include <cstring>

namespace xmrig {

Verthash::Verthash()
{
    memset(&m_info, 0, sizeof(m_info));
}

Verthash::~Verthash()
{
    release();
}

Verthash &Verthash::instance()
{
    static Verthash inst;
    return inst;
}

bool Verthash::init(const char *dataFilePath)
{
    std::lock_guard<std::mutex> lock(m_mutex);

    if (m_initialized && m_info.data != nullptr) {
        // Already initialized - check if same file
        if (m_info.fileName && strcmp(m_info.fileName, dataFilePath) == 0) {
            return true;  // Same file, nothing to do
        }
        // Different file, release old data first
        verthash_info_free(&m_info);
        memset(&m_info, 0, sizeof(m_info));
    }

    int result = verthash_info_init(&m_info, dataFilePath);
    if (result != 0) {
        memset(&m_info, 0, sizeof(m_info));
        m_initialized = false;
        return false;
    }

    m_initialized = true;
    return true;
}

void Verthash::release()
{
    std::lock_guard<std::mutex> lock(m_mutex);

    if (m_initialized) {
        verthash_info_free(&m_info);
        memset(&m_info, 0, sizeof(m_info));
        m_initialized = false;
    }
}

void Verthash::hash(const uint8_t *input, uint8_t *output) const
{
    if (!isValid()) {
        memset(output, 0, VH_HASH_OUT_SIZE);
        return;
    }

    verthash_hash(m_info.data, m_info.dataSize,
                  reinterpret_cast<const unsigned char(*)[VH_HEADER_SIZE]>(input),
                  reinterpret_cast<unsigned char(*)[VH_HASH_OUT_SIZE]>(output));
}

int Verthash::generateDataFile(const char *outputPath)
{
    return verthash_generate_data_file(outputPath);
}

} // namespace xmrig
