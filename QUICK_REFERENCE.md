# X Miner - Quick Reference Card

**Version:** 1.0.0 | **Date:** December 3, 2025

---

## 🚀 Quick Start

```bash
# Build
mkdir build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j$(nproc)

# Test
./x --bench=1M

# Mine (TARI)
./x -o pool-global.tari.snipanet.com:3333 -u YOUR_WALLET -a rx/0

# Mine (Monero)
./x -o pool.example.com:3333 -u YOUR_WALLET -a rx/0
```

---

## 📋 Common Commands

### Benchmarking
```bash
./x --bench=1M                    # Quick test (1M hashes)
./x --bench=10M --threads=16      # Full benchmark
./x --bench=rx/0                  # Specific algorithm
./x --bench=rx/0 --bench-submit   # Submit results
```

### Mining
```bash
./x -o POOL:PORT -u WALLET              # Basic mining
./x -c config.json                      # Use config file
./x --threads=8                         # Limit threads
./x --randomx-prefetch-mode=3           # Prefetch mode
./x --print-time=10                     # Hashrate every 10s
```

### Information
```bash
./x --help                        # Show all options
./x --version                     # Version info
./x --print-platforms             # List GPUs
```

---

## ⚙️ Configuration

### JSON Config (`config.json`)

```json
{
    "autosave": true,
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "hw-aes": null,
        "priority": null,
        "asm": true,
        "argon2-impl": null,
        "astrobwt-max-size": 550,
        "astrobwt-avx2": false,
        "argon2": [0, 1, 2, 3],
        "cn": [
            [1, 0],
            [1, 2],
            [1, 4],
            [1, 6]
        ],
        "cn-heavy": [
            [1, 0],
            [1, 2]
        ],
        "cn-lite": [
            [1, 0],
            [1, 1],
            [1, 2],
            [1, 3]
        ],
        "cn-pico": [
            [2, 0],
            [2, 1],
            [2, 2],
            [2, 3]
        ],
        "cn/0": false,
        "cn/1": false,
        "cn/2": [1, 0],
        "cn/ccx": false,
        "cn/double": false,
        "cn/fast": [1, 0],
        "cn/gpu": false,
        "cn/half": [1, 0],
        "cn/lite": false,
        "cn/lite/0": false,
        "cn/lite/1": false,
        "cn/pico": false,
        "cn/pico/tlo": false,
        "cn/r": false,
        "cn/rto": false,
        "cn/rwz": false,
        "cn/xao": false,
        "cn/zls": false,
        "ghostrider": [
            [8, 0],
            [8, 2]
        ],
        "rx": [0, 2, 4, 6],
        "rx/0": false,
        "rx/arq": false,
        "rx/graft": false,
        "rx/keva": false,
        "rx/sfx": false,
        "rx/wow": false,
        "rx/xla": false,
        "panthera": false,
        "randomx": {
            "mode": "auto",
            "1gb-pages": false,
            "rdmsr": true,
            "wrmsr": true,
            "cache_qos": false,
            "numa": true,
            "scratchpad_prefetch_mode": 4
        },
        "max-threads-hint": 100
    },
    "opencl": {
        "enabled": false,
        "cache": true,
        "loader": null,
        "platform": "AMD",
        "adl": true,
        "cn/0": false,
        "cn-lite/0": false,
        "rx/0": [
            {
                "index": 0,
                "intensity": 1024,
                "worksize": 8,
                "threads": 1,
                "unroll": 8,
                "affinity": -1
            }
        ]
    },
    "cuda": {
        "enabled": false,
        "loader": null,
        "nvml": true,
        "cn/0": false,
        "cn-lite/0": false,
        "rx/0": [
            {
                "index": 0,
                "threads": 32,
                "blocks": 60,
                "bfactor": 6,
                "bsleep": 25,
                "affinity": -1
            }
        ]
    },
    "donate-level": 1,
    "donate-over-proxy": 1,
    "log-file": null,
    "pools": [
        {
            "algo": null,
            "coin": null,
            "url": "pool.example.com:3333",
            "user": "YOUR_WALLET",
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
    "retries": 5,
    "retry-pause": 5,
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
    "dns": {
        "ipv6": false,
        "ttl": 30
    },
    "user-agent": null,
    "verbose": 0,
    "watch": true,
    "pause-on-battery": false,
    "pause-on-active": false
}
```

### Minimal Config (TARI)

```json
{
    "pools": [{
        "url": "pool-global.tari.snipanet.com:3333",
        "user": "YOUR_WALLET_ADDRESS",
        "pass": "x",
        "algo": "rx/0"
    }],
    "cpu": {
        "enabled": true,
        "huge-pages": true
    },
    "randomx": {
        "scratchpad_prefetch_mode": 3
    }
}
```

---

## 🎯 Algorithm Selection

| Algorithm | Coin | Command |
|-----------|------|---------|
| `rx/0` | Monero, TARI | `-a rx/0` |
| `rx/wow` | Wownero | `-a rx/wow` |
| `cn/r` | Monero (old) | `-a cn/r` |
| `cn/half` | Masari | `-a cn/half` |
| `cn-lite/1` | AEON | `-a cn-lite/1` |
| `kawpow` | Ravencoin | `-a kawpow` |
| `ghostrider` | Raptoreum | `-a ghostrider` |

---

## 🔧 Performance Tuning

### CPU Optimization

```bash
# Enable huge pages (Linux)
sudo sysctl -w vm.nr_hugepages=1280

# Set high priority
nice -n -20 ./x [options]

# Limit threads (test for sweet spot)
./x --threads=12  # Try different values

# Configure prefetch mode
./x --randomx-prefetch-mode=3  # Mode 3 for modern CPUs
```

### Thread Configuration

```json
{
    "cpu": {
        "rx": [0, 2, 4, 6, 8, 10, 12, 14],  # Even cores only
        "affinity": [0, 2, 4, 6, 8, 10, 12, 14]
    }
}
```

### Prefetch Modes

| Mode | Type | Best For |
|------|------|----------|
| 0 | Disabled | Baseline testing |
| 1 | PREFETCHT0 | Older CPUs (default) |
| 2 | PREFETCHNTA | Memory bandwidth limited |
| 3 | Forced Read | Zen4/Zen5, Ice Lake+ |

---

## 📊 Monitoring

### Hashrate
```bash
# Show every 10 seconds
./x --print-time=10

# Log to file
./x -l logfile.txt

# Verbose mode
./x -v  # or -vv for very verbose
```

### API Access
```bash
# Enable HTTP API
./x --http-enabled --http-host=127.0.0.1 --http-port=3000

# Check status
curl http://127.0.0.1:3000/1/summary

# Get hashrate
curl http://127.0.0.1:3000/1/backends
```

---

## 🐛 Troubleshooting

### Low Hashrate

```bash
# Check configuration
./x --dry-run -c config.json

# Verify huge pages
cat /proc/meminfo | grep Huge  # Linux
./x --bench=1M  # Should show huge pages %

# Test different thread counts
for i in 4 8 12 16; do
    echo "Testing $i threads"
    ./x --bench=1M --threads=$i
done
```

### Crashes

```bash
# Reduce threads
./x --threads=4

# Disable huge pages
./x --no-huge-pages

# Debug build
cmake .. -DCMAKE_BUILD_TYPE=Debug
gdb ./x
```

### Connection Issues

```bash
# Test pool connection
ping pool-address.com
telnet pool-address.com 3333

# Enable verbose logging
./x -v -v

# Try different pool
./x -o backup-pool.com:3333 -u WALLET
```

---

## 📈 Expected Performance

### RandomX (rx/0)

| CPU | Cores | Hashrate |
|-----|-------|----------|
| Intel i9-9880H | 16T | ~1,500 H/s |
| AMD Ryzen 9 5950X | 32T | ~18,000 H/s |
| AMD Ryzen 9 7950X | 32T | ~22,000 H/s |
| Intel i9-13900K | 32T | ~20,000 H/s |

### CryptoNight (cn/r)

| CPU | Cores | Hashrate |
|-----|-------|----------|
| Intel i9-9880H | 16T | ~3,000 H/s |
| AMD Ryzen 9 5950X | 32T | ~15,000 H/s |

---

## 🔐 Security

### Pool Security
- Always use TLS when available (`tls: true`)
- Verify pool SSL certificate
- Use unique passwords per pool

### System Security
- Run as non-root user when possible
- Limit network access
- Monitor system resources
- Keep software updated

---

## 💡 Tips & Tricks

### Maximize Hashrate
1. Enable huge pages
2. Use correct thread count (usually cores, not threads)
3. Set CPU affinity to physical cores only
4. Disable hyperthreading for better cache performance
5. Keep system cool
6. Close background applications

### Save Power
1. Reduce thread count
2. Lower CPU frequency
3. Use eco mode in BIOS
4. Enable pause-on-battery

### Reduce Heat
1. Lower thread count
2. Improve cooling
3. Undervolt CPU (if supported)
4. Set power limits

---

## 📞 Getting Help

### Resources
- **Documentation:** `docs/` directory
- **Examples:** `examples/` directory
- **Scripts:** `scripts/` directory
- **Issues:** GitHub Issues

### Common Files
- `CLAUDE.md` - Project overview
- `BUILD.md` - Build instructions
- `PERFORMANCE.md` - Performance guide
- `API.md` - API documentation
- `ALGORITHMS.md` - Algorithm details

### Support Channels
- GitHub Issues: Bug reports
- GitHub Discussions: Questions
- Pool Discord: Pool-specific help

---

## 📝 Changelog

### Version 1.0.0 (December 2025)
- ✅ Memory copy reduction optimization
- ✅ CPU-specific prefetch auto-detection
- ✅ AVX-512 infrastructure
- ✅ Comprehensive documentation
- ✅ Build system improvements

---

**Quick Reference Version:** 1.0
**Last Updated:** December 3, 2025
**Maintained by:** X Development Team
