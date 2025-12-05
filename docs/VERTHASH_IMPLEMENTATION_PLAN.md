# Verthash Implementation Plan - Vertcoin (VERT) Support

**Status:** Planning Phase
**Priority:** Medium (Phase 4: Algorithm Expansion)
**Estimated Effort:** 3-5 weeks (2-3 developers)
**Complexity:** High

---

## Executive Summary

Adding Vertcoin support to X requires implementing the **Verthash** proof-of-work algorithm. Verthash is a memory-hard algorithm designed to be ASIC-resistant while remaining GPU-friendly. Vertcoin switched from Lyra2REv3 to Verthash in December 2020 to maintain decentralized mining.

**Key Challenges:**
- Complex algorithm with I/O-intensive operations
- Requires 1.2GB dataset (verthash.dat file)
- CPU and GPU implementations needed
- Dataset generation and validation
- Integration with existing X architecture

---

## Algorithm Overview

### Verthash Characteristics

**Algorithm Properties:**
- **Memory requirement:** 1.2GB dataset (verthash.dat)
- **Hash function:** Sha3-256 (Keccak)
- **Dataset:** Static (doesn't change with blockchain)
- **Memory-hard:** Designed to be memory-bound
- **GPU-friendly:** Better on GPUs than CPUs (unlike RandomX)

**Mining Process:**
1. Load/generate 1.2GB verthash.dat file
2. For each nonce:
   - Generate input hash using Sha3
   - Perform dataset lookups (memory-bound)
   - Final Sha3 hash
3. Check if result meets difficulty target

### Algorithm Specifications

**Dataset Generation:**
```
Size: 1,228,800,000 bytes (1.2GB)
Format: Binary file with Blake2b hashes
Generation: One-time process (takes ~20 minutes)
Verification: SHA-256 checksum
```

**Hash Function:**
```
Input: 80-byte block header
Output: 32-byte hash
Iterations: ~130-140 dataset lookups per hash
Memory access pattern: Pseudorandom
```

---

## Implementation Requirements

### 1. Core Algorithm Implementation

**Files to Create:**
```
src/crypto/verthash/
├── verthash.h                    # Main API
├── verthash.cpp                  # Core implementation
├── verthash_dataset.h            # Dataset management
├── verthash_dataset.cpp
├── verthash_cpu.cpp              # CPU-optimized version
├── verthash_test.h               # Test vectors
└── tiny_sha3/                    # SHA3 implementation (or use existing)
```

**Core Functions:**
```cpp
namespace xmrig {
namespace verthash {

// Dataset management
bool generate_dataset(const char* output_file);
bool verify_dataset(const char* file_path);
bool load_dataset(const char* file_path, uint8_t** data);

// Hashing
void verthash(
    const uint8_t* input,        // 80-byte block header
    uint8_t* output,              // 32-byte hash output
    const uint8_t* dataset_data   // 1.2GB dataset
);

// CPU-optimized version
void verthash_cpu(
    const uint8_t* input,
    uint8_t* output,
    const uint8_t* dataset_data,
    bool use_avx2 = true
);

}} // namespace xmrig::verthash
```

### 2. Dataset Management

**Dataset Generation:**
- Implement Blake2b-based generation algorithm
- Create verthash.dat file (1.2GB)
- Verify with known SHA-256 checksum
- One-time generation per miner instance

**Dataset Loading:**
- Memory-map the 1.2GB file for efficiency
- Huge pages support for better TLB performance
- NUMA-aware allocation for multi-socket systems
- Graceful degradation if huge pages unavailable

**Dataset Storage:**
```
Location options:
1. User-specified path (--verthash-data /path/to/verthash.dat)
2. Default locations:
   - Linux: ~/.x/verthash.dat
   - Windows: %APPDATA%/x/verthash.dat
   - macOS: ~/Library/Application Support/x/verthash.dat
```

### 3. CPU Backend Integration

**Files to Modify:**
```
src/backend/cpu/
├── CpuWorker.cpp                 # Add Verthash case
├── CpuBackend.cpp                # Register Verthash support
└── Cpu.cpp                       # Performance reporting
```

**Worker Loop Integration:**
```cpp
// In CpuWorker::start()
switch (job.algorithm().family()) {
    case Algorithm::VERTHASH:
        verthash::verthash_cpu(
            m_job.blob(),
            m_hash,
            m_verthashData  // Needs to be added to worker
        );
        break;
    // ... other algorithms
}
```

**Memory Requirements:**
- 1.2GB shared dataset (all CPU threads)
- Small per-thread scratchpad (~1KB)
- Total: ~1.2GB + (threads * 1KB)

### 4. GPU Backend Integration

**CUDA Implementation** (`src/backend/cuda/runners/CudaVerthashRunner.cpp`):
```cpp
class CudaVerthashRunner : public CudaBaseRunner {
public:
    // Dataset upload to GPU memory
    bool init(const VerthashConfig& config) override;

    // Mining kernel launch
    void run(uint32_t nonce, uint32_t* rescount, uint32_t* resnonce) override;

private:
    uint8_t* d_dataset;  // 1.2GB on GPU
    // ... other GPU resources
};
```

**OpenCL Implementation** (`src/backend/opencl/runners/OclVerthashRunner.cpp`):
- Similar structure to CUDA
- OpenCL kernel for Verthash
- Buffer management for 1.2GB dataset

**GPU Challenges:**
1. **Memory:** Requires GPUs with 2GB+ VRAM (1.2GB dataset + working memory)
2. **Transfer:** Initial dataset upload takes ~1-2 seconds
3. **Performance:** GPU implementation 10-50x faster than CPU

### 5. Algorithm Registry Integration

**Files to Modify:**
```
src/base/crypto/Algorithm.h       # Add VERTHASH enum
src/base/crypto/Algorithm.cpp     # Add "verthash" string mapping
src/base/crypto/Coin.cpp          # Add Vertcoin coin support
```

**Algorithm Definition:**
```cpp
// In Algorithm.h
enum Id : int {
    // ... existing algorithms
    VERTHASH,
    MAX
};

// In Algorithm.cpp
#ifdef XMRIG_ALGO_VERTHASH
const char *Algorithm::kVERTHASH = "verthash";
#endif
```

**Coin Configuration:**
```cpp
// In Coin.cpp
static const char *kVERT = "VERT";

// Vertcoin configuration
{
    Algorithm::VERTHASH,  // algorithm
    "VERT",               // name
    "VTC",                // ticker
    false,                // has second algorithm
    0                     // dataset epoch
}
```

### 6. Configuration Support

**Command-line Options:**
```bash
--algo verthash                   # Select Verthash algorithm
--coin VERT                       # Select Vertcoin
--verthash-data FILE              # Path to verthash.dat
--verthash-generate               # Generate verthash.dat if missing
```

**JSON Configuration:**
```json
{
  "algo": "verthash",
  "coin": "VERT",
  "verthash": {
    "dataset": "/path/to/verthash.dat",
    "auto-generate": true
  },
  "pools": [{
    "url": "stratum+tcp://pool.vertcoin.org:9171",
    "user": "YOUR_WALLET_ADDRESS",
    "algo": "verthash"
  }]
}
```

### 7. Testing & Validation

**Test Vectors:**
```cpp
// Known good hashes for validation
struct VerthashTestVector {
    const char* input_hex;      // 80-byte header
    const char* expected_hash;  // 32-byte output
};

static const VerthashTestVector test_vectors[] = {
    {
        // Test vector 1 (from Vertcoin repository)
        "...",
        "..."
    },
    // ... more test vectors
};
```

**Testing Checklist:**
- [ ] Dataset generation correctness
- [ ] Hash output matches reference implementation
- [ ] CPU performance benchmarks
- [ ] GPU performance benchmarks
- [ ] Memory leak tests (long-running)
- [ ] Stratum protocol compatibility
- [ ] Pool submission validation

---

## Implementation Timeline

### Phase 1: Core Algorithm (Week 1-2)

**Tasks:**
1. Implement Sha3-256 hashing (or integrate existing)
2. Implement verthash.dat generation
3. Core verthash hash function (CPU-only)
4. Unit tests with test vectors
5. Benchmark against reference implementation

**Deliverables:**
- Working CPU implementation
- Passing all test vectors
- Performance within 10% of reference

### Phase 2: X Integration (Week 2-3)

**Tasks:**
1. Integrate with Algorithm registry
2. Add to CPU backend worker loop
3. Dataset loading and caching
4. Configuration file support
5. Command-line options
6. Integration testing

**Deliverables:**
- X can mine Verthash on CPU
- Configuration examples
- Documentation

### Phase 3: GPU Implementation (Week 3-4)

**Tasks:**
1. CUDA kernel implementation
2. OpenCL kernel implementation
3. GPU memory management
4. Performance optimization
5. Multi-GPU support

**Deliverables:**
- Working GPU implementation
- GPU hashrate 10-50x faster than CPU
- Supports NVIDIA and AMD GPUs

### Phase 4: Optimization & Testing (Week 4-5)

**Tasks:**
1. CPU SIMD optimizations (AVX2, AVX-512)
2. GPU kernel tuning
3. Memory access pattern optimization
4. Pool testing on mainnet
5. Long-running stability tests
6. Documentation completion

**Deliverables:**
- Optimized implementation
- Complete documentation
- Production-ready code

---

## Technical Challenges

### 1. Dataset Management

**Challenge:** 1.2GB dataset must be efficiently loaded and accessed

**Solutions:**
- **Memory mapping:** Use mmap() for zero-copy access
- **Huge pages:** Request 1GB pages for better TLB performance
- **Lazy loading:** Load on-demand if memory constrained
- **Verification:** SHA-256 checksum on load to detect corruption

### 2. Memory Bandwidth

**Challenge:** Verthash is memory-bound (140+ random accesses per hash)

**Solutions:**
- **Prefetching:** CPU prefetch instructions for dataset access
- **Cache optimization:** Align data structures to cache lines
- **NUMA awareness:** Allocate dataset on correct NUMA node
- **GPU caching:** Utilize L2 cache effectively on GPUs

### 3. First-time Setup

**Challenge:** 1.2GB dataset generation takes 15-20 minutes

**Solutions:**
- **Progress indicator:** Show generation progress to user
- **One-time cost:** Dataset never needs regeneration
- **Optional download:** Provide pre-generated, verified dataset
- **Background generation:** Continue mining other coins while generating

### 4. GPU Memory Requirements

**Challenge:** Not all GPUs have 2GB+ VRAM

**Solutions:**
- **GPU filtering:** Detect and skip GPUs with insufficient memory
- **Fallback to CPU:** Gracefully fall back if GPU unsuitable
- **Clear error messages:** Inform user of memory requirements

---

## Performance Expectations

### CPU Performance

**Estimated Hashrates:**
| CPU | Cores | Expected H/s |
|-----|-------|--------------|
| Intel i9-13900K | 24 | 1.5-2.0 MH/s |
| AMD Ryzen 9 7950X | 16 | 1.8-2.2 MH/s |
| Intel i9-9880H | 8 | 0.6-0.8 MH/s |
| AMD Ryzen 5 5600X | 6 | 0.8-1.0 MH/s |

### GPU Performance

**Estimated Hashrates:**
| GPU | VRAM | Expected H/s |
|-----|------|--------------|
| NVIDIA RTX 4090 | 24GB | 150-200 MH/s |
| NVIDIA RTX 3080 | 10GB | 80-100 MH/s |
| AMD RX 6800 XT | 16GB | 70-90 MH/s |
| NVIDIA RTX 3060 | 12GB | 40-50 MH/s |

**Note:** GPUs with less than 2GB VRAM cannot mine Verthash

---

## Resources Required

### Development Team

**Minimum:** 1 senior developer
**Recommended:** 2 developers (1 algorithms, 1 GPU specialist)

**Skills Required:**
- C++14 expertise
- Cryptographic algorithm implementation
- CUDA/OpenCL programming
- Memory management and optimization
- Mining protocol knowledge

### Testing Infrastructure

**Required:**
- CPU test machine (modern multi-core)
- NVIDIA GPU (2GB+ VRAM)
- AMD GPU (2GB+ VRAM)
- Vertcoin testnet access
- Vertcoin pool account

### Documentation

**To Create:**
- User guide for Verthash mining
- Configuration examples
- Troubleshooting guide
- API documentation
- Performance tuning guide

---

## Risks & Mitigation

### Risk 1: Implementation Complexity

**Impact:** High
**Probability:** Medium
**Mitigation:**
- Reference implementation available (vertcoin-miner)
- Use existing Sha3 libraries
- Incremental development with testing

### Risk 2: Performance Below Expectations

**Impact:** Medium
**Probability:** Low
**Mitigation:**
- Profile early and often
- Compare against reference implementation
- Optimize memory access patterns
- Use SIMD where applicable

### Risk 3: Dataset Corruption

**Impact:** High (invalid shares)
**Probability:** Low
**Mitigation:**
- SHA-256 verification on load
- Periodic re-verification option
- Clear error messages
- Regeneration if corrupted

### Risk 4: Pool Compatibility Issues

**Impact:** High
**Probability:** Low
**Mitigation:**
- Test with multiple pools
- Follow Stratum spec closely
- Validate share submission format
- Monitor pool-side rejection rate

---

## Alternative: Lyra2REv3 Support

Vertcoin previously used Lyra2REv3 before switching to Verthash. Some pools may still support it.

**Pros:**
- Simpler implementation (~1 week vs 3-5 weeks)
- No large dataset required
- Less memory intensive

**Cons:**
- Deprecated by Vertcoin
- Limited pool support
- Not officially supported

**Recommendation:** Implement Verthash, not Lyra2REv3

---

## Conclusion

Adding Verthash support to X is a **medium-to-high complexity** project requiring:
- **3-5 weeks** of development time
- **1-2 experienced developers**
- Careful memory management and optimization
- Thorough testing on CPU and GPU

**Benefits:**
- Support for Vertcoin (VERT) mining
- Expands X's algorithm portfolio
- Attracts Vertcoin mining community
- Demonstrates X's extensibility

**Recommendation:**
1. **Phase 4 implementation** (after current optimizations complete)
2. Start with CPU implementation for faster validation
3. Add GPU support for production performance
4. Provide excellent documentation and examples

---

**Document Version:** 1.0
**Created:** December 3, 2025
**Author:** Claude Code Assistant
**Status:** Planning - Ready for Review

