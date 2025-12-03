# AVX-512 Implementation Plan for X Miner

**Status**: Infrastructure Complete, Assembly Implementation Pending
**Expected Performance Gain**: 5-10% on supported CPUs
**Date**: 2025-12-02

## Executive Summary

This document outlines the implementation plan for adding AVX-512 support to the RandomX JIT compiler in X miner. AVX-512 is a 512-bit SIMD instruction set that can provide significant performance improvements for cryptographic hashing workloads on supported CPUs.

## Current State

### ✅ Completed Infrastructure

1. **CPU Detection** (BasicCpuInfo.cpp:149)
   - `has_avx512f()` function detects AVX-512F (foundation) support
   - `has_xcr_avx512()` checks OS support for AVX-512 registers
   - FLAG_AVX512F flag is properly set

2. **ICpuInfo Interface** (ICpuInfo.h:107)
   - Added `virtual bool hasAVX512() const = 0;` to interface

3. **BasicCpuInfo Implementation** (BasicCpuInfo.h:50)
   - Implemented `hasAVX512()` method: `{ return has(FLAG_AVX512F); }`

4. **JitCompilerX86 Flags** (jit_compiler_x86.hpp:102-104)
   - Added `bool hasAVX512;` - CPU capability detection
   - Added `bool initDatasetAVX512;` - Dataset initialization mode selector

5. **JIT Compiler Logic** (jit_compiler_x86.cpp:228, 285-309)
   - AVX-512 detection: `hasAVX512 = xmrig::Cpu::info()->hasAVX512();`
   - CPU vendor-specific logic for Intel and AMD (Zen4/Zen5)
   - Memory allocation sized for AVX-512 code: `CodeSize * 6`
   - Fallback hierarchy: AVX-512 → AVX2 → baseline

### 📋 Pending Implementation

The following components need to be implemented to enable AVX-512:

## Implementation Roadmap

### Phase 1: Assembly Code Generation (High Priority)

#### 1.1 Create AVX-512 Assembly Stubs
**File**: `src/crypto/randomx/jit_compiler_x86_static.asm` (or new .S file)

Create AVX-512 versions of key functions:
- `randomx_dataset_init_avx512_prologue`
- `randomx_dataset_init_avx512_loop_end`
- `randomx_dataset_init_avx512_epilogue`
- `randomx_dataset_init_avx512_ssh_load`
- `randomx_dataset_init_avx512_ssh_prefetch`

**Key changes from AVX2**:
- Use ZMM registers (zmm0-zmm31) instead of YMM (ymm0-ymm15)
- 512-bit operations instead of 256-bit
- EVEX encoding instead of VEX
- Potential use of AVX-512 mask registers (k0-k7)

#### 1.2 Update jit_compiler_x86_static.hpp
Add macros for AVX-512 code sections:
```cpp
#define codeDatasetInitAVX512Prologue ADDR(randomx_dataset_init_avx512_prologue)
#define codeDatasetInitAVX512LoopEnd ADDR(randomx_dataset_init_avx512_loop_end)
#define codeDatasetInitAVX512Epilogue ADDR(randomx_dataset_init_avx512_epilogue)
#define codeDatasetInitAVX512SshLoad ADDR(randomx_dataset_init_avx512_ssh_load)
#define codeDatasetInitAVX512SshPrefetch ADDR(randomx_dataset_init_avx512_ssh_prefetch)
```

#### 1.3 Implement Dataset Initialization
**File**: `src/crypto/randomx/jit_compiler_x86.cpp` (~line 400)

Add AVX-512 dataset initialization following the AVX2 pattern:
```cpp
if (initDatasetAVX512) {
    // Generate AVX-512 dataset initialization code
    emit(codeDatasetInitAVX512Prologue, datasetInitAVX512PrologueSize, code, codePos);

    for (size_t i = 0; i < superscalarProgramCount; ++i) {
        emit(codeDatasetInitAVX512SshLoad, datasetInitAVX512SshLoadSize, code, codePos);
        // ... (similar to AVX2 implementation)
    }

    emit(codeDatasetInitAVX512LoopEnd, datasetInitAVX512LoopEndSize, code, codePos);
    emit(codeDatasetInitAVX512Epilogue, datasetInitAVX512EpilogueSize, code, codePos);
}
```

#### 1.4 Template Specialization for AVX-512
**File**: `src/crypto/randomx/jit_compiler_x86.cpp` (~line 504)

Create AVX-512 template specialization:
```cpp
template<>
void JitCompilerX86::generateSuperscalarHash<true, true>(SuperscalarProgram(&programs)[N]) {
    // AVX-512 implementation
    // Use 512-bit vector operations for Blake2b hashing
}
```

### Phase 2: JIT Code Generation (Medium Priority)

#### 2.1 Update Instruction Handlers
Enhance instruction handlers to use AVX-512 when available:
- Vectorized floating-point operations (VFMADD, VFMSUB with zmm)
- 512-bit memory operations
- Gather/scatter instructions for dataset access

#### 2.2 Register Allocation
Update register allocation to use:
- ZMM0-ZMM31 (32 registers vs 16 in AVX2)
- Mask registers k0-k7 for predicated operations

### Phase 3: Testing & Validation (High Priority)

#### 3.1 Unit Tests
- Verify AVX-512 detection on various CPUs
- Test fallback to AVX2/baseline when AVX-512 unavailable
- Validate correctness of hash outputs

#### 3.2 Performance Testing
**Target CPUs**:
- Intel Skylake-X, Ice Lake, Sapphire Rapids
- AMD Zen4 (Ryzen 7000 series)
- AMD Zen5 (Ryzen 9000 series)

**Benchmarks**:
- Dataset initialization time
- Hashing throughput (H/s)
- CPU utilization
- Memory bandwidth usage

#### 3.3 Compatibility Testing
- Ensure no regression on non-AVX-512 CPUs
- Test on CPUs with partial AVX-512 support
- Verify OS support (Linux, Windows, macOS)

### Phase 4: Optimization (Low Priority)

#### 4.1 CPU-Specific Tuning
- Intel vs AMD optimization
- Consider AVX-512 frequency scaling impact
- Power consumption vs performance tradeoff

#### 4.2 Hybrid Approaches
- Evaluate mixed AVX2/AVX-512 for thermal management
- Implement dynamic switching based on CPU temperature

## Technical Challenges

### 1. AVX-512 Frequency Scaling
**Issue**: Some Intel CPUs reduce clock speed when executing AVX-512 instructions
**Mitigation**:
- Make AVX-512 optional via configuration
- Monitor performance vs AVX2 on specific hardware
- Provide user control over instruction set usage

### 2. Thermal Considerations
**Issue**: AVX-512 can increase power consumption and heat
**Mitigation**:
- Document thermal implications
- Allow users to disable AVX-512
- Consider duty cycling for sustained workloads

### 3. Limited Hardware Availability
**Issue**: AVX-512 only available on recent Intel and AMD CPUs
**Mitigation**:
- Maintain robust fallback to AVX2/baseline
- Thorough testing on available hardware
- Community testing program

## CPU Support Matrix

| Vendor | Architecture | AVX-512 Support | Notes |
|--------|--------------|----------------|-------|
| Intel | Skylake-X | ✅ AVX-512F, CD, BW, DQ, VL | May have frequency scaling |
| Intel | Ice Lake | ✅ Full AVX-512 + VNNI | Better performance |
| Intel | Sapphire Rapids | ✅ Full AVX-512 + AMX | Best Intel option |
| AMD | Zen4 | ✅ AVX-512F, CD, BW, DQ, VL | No frequency scaling penalty |
| AMD | Zen5 | ✅ Full AVX-512 | Best AMD option |
| AMD | Zen3 and earlier | ❌ No support | Fall back to AVX2 |

## Implementation Timeline

### Immediate (Week 1-2)
- ✅ Infrastructure setup (COMPLETED)
- 📋 Document implementation plan (IN PROGRESS)
- 📋 Research AVX-512 Blake2b optimizations

### Short-term (Week 3-6)
- 📋 Implement AVX-512 assembly stubs
- 📋 Create basic dataset initialization
- 📋 Unit testing framework

### Medium-term (Week 7-10)
- 📋 JIT instruction handler updates
- 📋 Performance benchmarking
- 📋 CPU-specific optimizations

### Long-term (Week 11-12)
- 📋 Community testing
- 📋 Documentation updates
- 📋 Production release

## Performance Expectations

Based on theoretical analysis and similar implementations:

| CPU Type | Expected Gain | Confidence |
|----------|---------------|------------|
| Intel Skylake-X | 3-7% | Medium (frequency scaling) |
| Intel Ice Lake+ | 7-12% | High |
| AMD Zen4 | 8-15% | High (49% faster than AVX2 observed) |
| AMD Zen5 | 10-20% | High |

**Note**: Actual performance will vary based on:
- Dataset size
- Memory bandwidth
- Thermal throttling
- Algorithm-specific characteristics

## References

### RandomX Specification
- [RandomX Design](https://github.com/tevador/RandomX/blob/master/doc/design.md)
- [RandomX Specs](https://github.com/tevador/RandomX/blob/master/doc/specs.md)

### AVX-512 Documentation
- [Intel AVX-512 Guide](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-avx-512-instructions.html)
- [AMD AVX-512 Implementation](https://www.amd.com/en/technologies/zen-core-architecture)

### Similar Implementations
- Argon2 AVX-512 (already in codebase: `src/3rdparty/argon2/arch/x86_64/lib/argon2-avx512f.c`)
- Blake2b AVX-512 implementations

## Decision Points

### 1. Enable AVX-512 by Default?
**Recommendation**: Start disabled (require opt-in)
**Rationale**:
- Allows thorough community testing
- Avoids thermal issues on unknown configurations
- Can enable by default after validation

### 2. Support Partial AVX-512?
**Recommendation**: Require AVX-512F at minimum
**Rationale**:
- AVX-512F provides foundation
- Additional features (VNNI, etc.) can be optional extensions
- Simplifies implementation

### 3. Maintain AVX2 Code Path?
**Recommendation**: Yes, absolutely
**Rationale**:
- Most CPUs still use AVX2
- Fallback for thermal management
- Safety net for compatibility

## Next Steps

1. **Research Phase** (Current)
   - Study existing AVX-512 implementations in Argon2
   - Analyze Blake2b AVX-512 optimizations
   - Create assembly code prototypes

2. **Implementation Phase**
   - Write AVX-512 assembly stubs
   - Integrate into JIT compiler
   - Create test harness

3. **Validation Phase**
   - Functional testing
   - Performance benchmarking
   - Thermal monitoring

4. **Deployment Phase**
   - Documentation
   - Release notes
   - User guide

## Contact & Collaboration

This is a complex optimization requiring:
- Assembly language expertise (x86-64, AVX-512)
- JIT compiler knowledge
- Cryptographic algorithm understanding
- Hardware access for testing

Community contributions welcome! See `CONTRIBUTING.md` for guidelines.

---

**Document Version**: 1.0
**Last Updated**: 2025-12-02
**Author**: X Development Team
**Status**: Infrastructure Complete, Awaiting Assembly Implementation
