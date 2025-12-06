/* XMRig
 * Copyright (c) 2018-2021 SChernykh   <https://github.com/SChernykh>
 * Copyright (c) 2016-2021 XMRig       <https://github.com/xmrig>, <support@xmrig.com>
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


#ifndef XMRIG_CONFIG_DEFAULT_H
#define XMRIG_CONFIG_DEFAULT_H


namespace xmrig {


// This feature require CMake option: -DWITH_EMBEDDED_CONFIG=ON
#ifdef XMRIG_FEATURE_EMBEDDED_CONFIG
const static char *default_config =
R"===(
{
    "api": {
        "id": null,
        "worker-id": null
    },
    "http": {
        "enabled": false,
        "host": "127.0.0.1",
        "port": 0,
        "access-token": null,
        "restricted": true
    },
    "autosave": true,
    "background": false,
    "colors": true,
    "title": true,
    "randomx": {
        "init": -1,
        "init-avx2": -1,
        "mode": "auto",
        "1gb-pages": false,
        "rdmsr": true,
        "wrmsr": true,
        "cache_qos": false,
        "numa": true
    },
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "huge-pages-jit": false,
        "hw-aes": null,
        "priority": null,
        "memory-pool": false,
        "yield": true,
        "max-threads-hint": 100,
        "asm": true,
        "argon2-impl": null,
        "cn/0": false,
        "cn-lite/0": false
    },
    "opencl": {
        "enabled": false,
        "cache": true,
        "loader": null,
        "platform": "AMD",
        "adl": true,
        "cn/0": false,
        "cn-lite/0": false
    },
    "cuda": {
        "enabled": false,
        "loader": null,
        "nvml": true,
        "cn/0": false,
        "cn-lite/0": false
    },
    "donate-level": 100,
    "donate-over-proxy": 1,
    "log-file": null,
    "pools": [
        {
            "algo": "rx/0",
            "coin": "tari",
            "url": "pool-global.tari.snipanet.com:9000",
            "user": "127PHAz3ePq93yWJ1Gsz8VzznQFui5LYne5jbwtErzD5WsnqWAfPR37KwMyGAf5UjD2nXbYZiQPz7GMTEQRCTrGV3fH",
            "pass": "x",
            "rig-id": null,
            "nicehash": false,
            "keepalive": false,
            "enabled": true,
            "tls": true,
            "tls-fingerprint": null,
            "daemon": false,
            "socks5": null,
            "self-select": null,
            "submit-to-origin": false
        },
        {
            "algo": "rx/0",
            "coin": "tari",
            "url": "pool-global.tari.snipanet.com:3333",
            "user": "127PHAz3ePq93yWJ1Gsz8VzznQFui5LYne5jbwtErzD5WsnqWAfPR37KwMyGAf5UjD2nXbYZiQPz7GMTEQRCTrGV3fH",
            "pass": "x",
            "rig-id": null,
            "nicehash": false,
            "keepalive": false,
            "enabled": true,
            "tls": false,
            "tls-fingerprint": null,
            "daemon": false,
            "socks5": null,
            "self-select": null,
            "submit-to-origin": false
        },
        {
            "algo": "rx/0",
            "coin": "tari",
            "url": "xtm-rx.kryptex.network:7038",
            "user": "solo:127PHAz3ePq93yWJ1Gsz8VzznQFui5LYne5jbwtErzD5WsnqWAfPR37KwMyGAf5UjD2nXbYZiQPz7GMTEQRCTrGV3fH",
            "pass": "x",
            "rig-id": null,
            "nicehash": false,
            "keepalive": false,
            "enabled": true,
            "tls": false,
            "tls-fingerprint": null,
            "daemon": false,
            "socks5": null,
            "self-select": null,
            "submit-to-origin": false
        }
    ],
    "print-time": 60,
    "health-print-time": 60,
    "dmi": true,
    "retries": 0,
    "retry-pause": 1,
    "syslog": false,
    "tls": {
        "enabled": false,
        "protocols": null,
        "cert": null,
        "cert_key": null,
        "ciphers": null,
        "ciphersuites": null,
        "dhparam": null
    },
    "user-agent": null,
    "verbose": 0,
    "watch": true,
    "pause-on-battery": false,
    "pause-on-active": false
}
)===";
#endif


} // namespace xmrig


#endif /* XMRIG_CONFIG_DEFAULT_H */
