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

#ifndef XMRIG_VERTHASH_WRAPPER_H
#define XMRIG_VERTHASH_WRAPPER_H

#include "crypto/verthash/Verthash.h"

#include <mutex>
#include <string>

namespace xmrig {

/**
 * C++ wrapper class for the Verthash C API
 * Provides singleton-style access to Verthash data file
 */
class Verthash
{
public:
    static Verthash &instance();

    // Initialize with a data file path
    bool init(const char *dataFilePath);

    // Release resources
    void release();

    // Check if data is loaded and valid
    bool isValid() const { return m_info.data != nullptr && m_info.dataSize > 0; }

    // Getters for GPU upload
    const uint8_t *data() const { return m_info.data; }
    uint64_t dataSize() const { return m_info.dataSize; }
    uint32_t dataMask() const { return m_info.bitmask; }

    // Get the file path
    const char *filePath() const { return m_info.fileName; }

    // CPU hash function (wrapper around verthash_hash)
    void hash(const uint8_t *input, uint8_t *output) const;

    // Generate data file (one-time operation)
    static int generateDataFile(const char *outputPath);

private:
    Verthash();
    ~Verthash();

    // Non-copyable
    Verthash(const Verthash &) = delete;
    Verthash &operator=(const Verthash &) = delete;

    verthash_info_t m_info;
    mutable std::mutex m_mutex;
    bool m_initialized = false;
};

} // namespace xmrig

#endif // XMRIG_VERTHASH_WRAPPER_H
