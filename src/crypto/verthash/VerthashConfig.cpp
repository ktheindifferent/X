/* X Miner
 * Copyright (c) 2024 X Project
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

#include "crypto/verthash/VerthashConfig.h"
#include "3rdparty/rapidjson/document.h"
#include "base/io/json/Json.h"

namespace xmrig {

const char *VerthashConfig::kField       = "verthash";
const char *VerthashConfig::kDataFile    = "data-file";
const char *VerthashConfig::kGenDataFile = "gen-data-file";

bool VerthashConfig::read(const rapidjson::Value &value)
{
    if (value.IsObject()) {
        m_dataFile    = Json::getString(value, kDataFile);
        m_genDataFile = Json::getString(value, kGenDataFile);
        return true;
    }

    return false;
}

rapidjson::Value VerthashConfig::toJSON(rapidjson::Document &doc) const
{
    using namespace rapidjson;
    auto &allocator = doc.GetAllocator();

    Value obj(kObjectType);

    if (!m_dataFile.isEmpty()) {
        obj.AddMember(StringRef(kDataFile), m_dataFile.toJSON(), allocator);
    }

    if (!m_genDataFile.isEmpty()) {
        obj.AddMember(StringRef(kGenDataFile), m_genDataFile.toJSON(), allocator);
    }

    return obj;
}

} // namespace xmrig
