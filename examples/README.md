# X Miner Configuration Examples

This directory contains example configuration files for popular cryptocurrencies.

## Usage

1. Copy the example configuration for your desired coin
2. Edit the configuration file:
   - Replace `YOUR_WALLET_ADDRESS` with your actual wallet address
   - Adjust pool URLs as needed
   - Configure hardware settings (CPU/GPU)
3. Run X with the configuration:
   ```bash
   ./x -c /path/to/config.json
   ```

## Available Examples

### TARI (XTM) - `tari-xtm.json`
- **Algorithm**: RandomX (rx/0)
- **Pool**: Kryptex
- **Hardware**: CPU
- **Description**: TARI is the default coin for X miner

Usage:
```bash
./x -c examples/tari-xtm.json
```

### Monero (XMR) - `monero-xmr.json`
- **Algorithm**: RandomX (rx/0)
- **Pools**: SupportXMR, 2Miners (failover)
- **Hardware**: CPU
- **Description**: The original RandomX cryptocurrency

Usage:
```bash
./x -c examples/monero-xmr.json
```

### Ravencoin (RVN) - `ravencoin-rvn.json`
- **Algorithm**: KawPow
- **Pools**: 2Miners, Flypool (failover)
- **Hardware**: GPU (CUDA/OpenCL)
- **Description**: GPU mining with KawPow algorithm

Usage:
```bash
./x -c examples/ravencoin-rvn.json
```

## Configuration Tips

### CPU Mining Optimization

For best CPU performance:
```json
{
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "hw-aes": null,
        "priority": 2,
        "asm": true,
        "max-threads-hint": 100
    },
    "randomx": {
        "mode": "auto",
        "1gb-pages": false,
        "numa": true
    }
}
```

### GPU Mining Setup

For GPU mining (AMD):
```json
{
    "cpu": {
        "enabled": false
    },
    "opencl": {
        "enabled": true,
        "platform": "AMD",
        "adl": true
    }
}
```

For GPU mining (NVIDIA):
```json
{
    "cpu": {
        "enabled": false
    },
    "cuda": {
        "enabled": true,
        "nvml": true
    }
}
```

### Multiple Pools (Failover)

Configure backup pools for reliability:
```json
{
    "pools": [
        {
            "url": "primary-pool.com:3333",
            "user": "YOUR_WALLET",
            "enabled": true
        },
        {
            "url": "backup-pool.com:3333",
            "user": "YOUR_WALLET",
            "enabled": true
        }
    ]
}
```

### HTTP API

Enable the HTTP API for monitoring:
```json
{
    "http": {
        "enabled": true,
        "host": "127.0.0.1",
        "port": 8080,
        "access-token": "your-secret-token",
        "restricted": false
    }
}
```

Then access: `http://127.0.0.1:8080/1/summary`

### Logging

Save logs to a file:
```json
{
    "log-file": "/var/log/x-miner.log",
    "verbose": 1
}
```

### Background Mode

Run as a background service:
```json
{
    "background": true,
    "syslog": true
}
```

## Creating Your Own Configuration

### Step 1: Choose Your Coin

Determine:
- Algorithm (rx/0, kawpow, cn/r, etc.)
- Pool URL and port
- Your wallet address

### Step 2: Configure Hardware

Choose mining backends:
- **CPU**: For RandomX, CryptoNight algorithms
- **OpenCL**: For AMD GPUs
- **CUDA**: For NVIDIA GPUs

### Step 3: Optimize Settings

- Enable huge pages for better performance
- Set appropriate thread count
- Configure memory settings
- Enable hardware-specific optimizations

### Step 4: Test

```bash
# Test configuration without mining
./x -c yourconfig.json --dry-run

# Test with benchmark
./x -c yourconfig.json --bench=1M

# Start mining
./x -c yourconfig.json
```

## Algorithm Reference

| Algorithm | Coins | Hardware | Memory |
|-----------|-------|----------|--------|
| rx/0 | Monero, TARI | CPU | 2 GB |
| kawpow | Ravencoin | GPU | - |
| cn/r | Monero (old) | CPU | 2 MB |
| ghostrider | Raptoreum | CPU | Variable |
| argon2/* | Various | CPU | 256 KB - 512 KB |

## Pool Selection

Consider these factors when choosing pools:
- **Hashrate**: Larger pools = more frequent payouts (but smaller)
- **Fees**: Typically 0-2%
- **Location**: Choose pools closer to you for lower latency
- **Minimum Payout**: Check minimum payout thresholds
- **Reliability**: Check pool uptime and reputation

## Security Notes

- Never share your private keys or wallet seed phrases
- Use strong access tokens for HTTP API
- Keep your miner software updated
- Monitor your miner for unexpected behavior
- Use TLS connections when available

## Need Help?

- See main [README.md](../README.md) for general usage
- Check [BUILD.md](../BUILD.md) for build instructions
- Review [doc/ALGORITHMS.md](../doc/ALGORITHMS.md) for algorithm details
- Visit [doc/CPU.md](../doc/CPU.md) for CPU optimization tips

## Contributing Examples

Have a configuration for a popular coin? Please contribute!

1. Create a configuration file: `coinname-symbol.json`
2. Test it thoroughly
3. Add documentation to this README
4. Submit a pull request

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.
