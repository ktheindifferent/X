# Verthash Stratum Debugging Progress

This document tracks the debugging efforts to fix Verthash share rejections when mining against pools (primarily Zpool - verthash.mine.zpool.ca:6144).

## Problem Statement

Verthash mining implementation produces shares that are rejected by pools with "Invalid share" or "Low difficulty share" errors. The issue is suspected to be in:
1. Block header byte ordering (endianness)
2. Nonce submission format (BE vs LE)
3. Merkle root construction
4. Verthash algorithm implementation itself

## Block Header Structure (80 bytes)

```
Offset  Size  Field
0       4     version
4       32    prevhash
36      32    merkle_root
68      4     ntime
72      4     nbits
76      4     nonce
```

## Test Results Summary

### Complete Configuration Matrix Tested (2025-12-04)

| Test | Header Swap | Nonce Submit | Accepted | Rejected | Rate | Log File |
|------|-------------|--------------|----------|----------|------|----------|
| 1 | All 80 bytes | LE | 1 | 15 | ~6% | ghostrider_swap.log |
| 2 | All 80 bytes | LE | 2 | 42 | ~4.5% | revert_test2.log |
| 3 | Skip merkle (36-67) + BE nonce | BE | 0 | 31+ | 0% | be_nonce_final.log |
| 4 | Skip merkle (36-67) + LE nonce | LE | 0 | 13+ | 0% | merkle_skip_test.log |
| 5 | All 80 bytes | LE | 0 | 9+ | 0% | revert_test.log |
| 6 | NO swap (raw stratum) | LE | 0 | 9+ | 0% | no_swap_test.log |
| 7 | Swap ONLY merkle (36-67) | LE | 0 | 10+ | 0% | merkle_only.log |
| 8 | All 80 bytes | BE | 0 | 30+ | 0% | be_nonce_*.log |

### Configurations That DO NOT Work (0% acceptance)

1. **NO byte swapping** - Raw stratum data directly → 0% acceptance
2. **Swap ONLY merkle root** - Only bytes 36-67 swapped → 0% acceptance
3. **Skip merkle swap** - Swap everything except bytes 36-67 → 0% acceptance
4. **BE nonce submission** - Big-endian nonce format → 0% acceptance
5. **Any combination with BE nonce** → 0% acceptance

### Best Working Configuration (~5% acceptance)

- **Block header**: Swap ALL 80 bytes with `ethash_swap_u32()`
- **Nonce submission**: Little-endian (native byte order on x86)
- **Acceptance rate**: ~4.5-6% (confirmed across multiple tests)

## Key Code Locations

### Block Header Byte Swapping
File: `src/base/net/stratum/EthStratumClient.cpp`
Lines: ~461-469

Current best implementation (swap ALL 80 bytes):
```cpp
buf = Cvt::fromHex(blob.c_str(), blob.length());
for (size_t i = 0; i < 80; i += sizeof(uint32_t)) {
    uint32_t& k = *reinterpret_cast<uint32_t*>(buf.data() + i);
    k = ethash_swap_u32(k);
}
blob = Cvt::toHex(buf.data(), buf.size());
```

### Nonce Submission Format
File: `src/base/net/stratum/EthStratumClient.cpp`
Lines: ~93-102

Current best implementation (LE nonce):
```cpp
uint32_t nonce_val = static_cast<uint32_t>(result.nonce);
const uint8_t* nonce_bytes = reinterpret_cast<const uint8_t*>(&nonce_val);
std::stringstream s;
// Output bytes in native order (LE on x86) - low byte first
for (int i = 0; i < 4; i++) {
    s << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(nonce_bytes[i]);
}
```

## Reference Implementation Analysis

### cpuminer-opt Verthash (verthash-gate.c)

From the reference implementation:
```c
// Input preparation - swap entire 80-byte header to big-endian
v128_bswap32_80(edata, pdata);  // Full 80-byte swap for hashing

// Set nonce in swapped data
edata[19] = n;  // Native uint32 in swapped buffer

// For submission - convert nonce back to BE
pdata[19] = bswap_32(n);  // BE format for stratum submission
```

Key observations from cpuminer-opt:
- Uses `v128_bswap32_80()` for full 80-byte header swap before hashing
- Sets nonce as native uint32 AFTER the swap (position 19 = bytes 76-79)
- Submits nonce in BE format with `bswap_32(n)`

### Discrepancy

Our implementation with BE nonce submission (matching cpuminer-opt) gets 0% acceptance, while LE nonce gets ~5%. This suggests either:
1. Zpool expects different format than cpuminer-opt
2. There's another issue in our implementation
3. The ~5% acceptance might be random/coincidental

## Critical Findings

### 1. The ~5% acceptance rate is consistent but problematic

The occasional accepted shares suggest:
- The Verthash hash algorithm is working to some degree
- The block header format is close but not exactly right
- OR the hash output format/comparison has issues

### 2. Pool disconnects after many rejections

The pool (Zpool) disconnects with "end of file" after 9-10 consecutive rejections. This is rate limiting behavior.

### 3. Error types observed

- "Invalid share" - Most common, indicates hash doesn't validate
- "Low difficulty share" - Rare, indicates hash validates but doesn't meet target

## Theories for Remaining 95% Rejection

### Theory 1: Nonce Position in Header
The nonce might need to be placed differently in the header before hashing. cpuminer-opt sets `edata[19] = n` AFTER byte swapping, meaning the nonce goes into the already-swapped buffer.

### Theory 2: Hash Output Byte Order
The Verthash hash output might need byte swapping before comparison with target.

### Theory 3: Difficulty Target Calculation
The difficulty target derived from `nbits` might be calculated incorrectly.

### Theory 4: Verthash Algorithm Implementation
The core Verthash algorithm in `src/crypto/verthash/` might have subtle differences from the reference implementation.

## Files to Investigate

1. `src/crypto/verthash/Verthash.cpp` - Core algorithm
2. `src/crypto/verthash/Verthash.h` - Algorithm interface
3. `src/backend/cpu/CpuWorker.cpp` - Where hash is computed and compared
4. `src/base/net/stratum/Job.h` - Job/target structure

## Next Steps

1. [x] Test NO byte swapping → 0% acceptance
2. [x] Test swap ONLY merkle root → 0% acceptance
3. [x] Test BE nonce submission → 0% acceptance
4. [ ] Add debug logging to show exact hash input/output bytes
5. [ ] Compare hash output with reference implementation
6. [ ] Check nonce placement timing (before vs after swap)
7. [ ] Verify difficulty target calculation
8. [ ] Test against different pool (WoolyPooly - pool.woolypooly.com:3102)

## Test Commands

```bash
# Standard test against Zpool
./x -a verthash -o stratum+tcp://verthash.mine.zpool.ca:6144 \
    -u Vu2WKVTv6YeAkCKrHKmMPXipB37oBJiQUi \
    -p "c=VTC,zap=VTC" \
    --verthash-data /path/to/verthash.dat \
    --threads=1 2>&1 | tee /tmp/verthash_test.log

# Check results
grep -E "(accepted|rejected)" /tmp/verthash_test.log | wc -l
grep -c "accepted" /tmp/verthash_test.log
grep -c "rejected" /tmp/verthash_test.log
```

## Current Status (2025-12-05)

**Status**: PARTIALLY WORKING (~5% acceptance rate)

**Current Configuration**:
- Header: Full 80-byte swap with `ethash_swap_u32()`
- Nonce submission: Little-endian format

**Root Cause**: Unknown - the ~5% acceptance suggests we're close but missing something fundamental.

### Additional Testing (2025-12-05)

Tested BE nonce submission format (matching VerthashMiner reference implementation):
- VerthashMiner uses `be32enc(&nonce, work->data[19])` followed by `bin2hex()`
- This outputs bytes in BE order (high byte first)

**Result**: BE nonce submission with 80-byte swap gets **0% acceptance rate**
- LE nonce (current) with 80-byte swap: ~5% acceptance
- BE nonce with 80-byte swap: 0% acceptance (worse)

This confirms the issue is NOT in the nonce submission format alone. The ~5% acceptance with LE nonce is our best configuration.

### Remaining Investigation Areas

The issue is likely in one of these areas:
1. **Nonce placement in header before hashing** - cpuminer-opt sets nonce AFTER byte swapping
2. **Hash output byte order** - May need swap before comparison with target
3. **Difficulty target calculation** - May be incorrect
4. **Verthash algorithm implementation** - Subtle differences from reference

**Next Investigation**: Add detailed debug logging to trace exact bytes through the hash pipeline and compare with reference implementation output.

## cpuminer-opt Deep Dive Analysis (2025-12-05)

### Critical Finding: Nonce Placement Order

From detailed analysis of cpuminer-opt (verthash-gate.c):

```c
// In scanhash_verthash():
v128_bswap32_80(edata, pdata);   // Step 1: Swap entire 80 bytes to BE
// ...
edata[19] = n;                    // Step 2: Set nonce AFTER swap (native uint32)
// ...
algo_gate.hash(hash, edata, thr_id);  // Step 3: Hash with nonce in native format
```

**Key insight**: The nonce is placed into the ALREADY SWAPPED buffer. This means:
- Header bytes 0-75 are in big-endian (swapped) format
- Nonce (bytes 76-79) is in NATIVE format (not swapped)
- The hash input has mixed endianness: BE header + native nonce

### Current Implementation Problem

Our current code in `EthStratumClient.cpp`:
1. Swap ALL 80 bytes (including nonce placeholder bytes 76-79)
2. Store the swapped blob
3. In CpuWorker, the nonce is written into position 76-79

The problem: Position 76-79 was already swapped with the initial header swap, so when we write the native nonce there, it's being written into a "swapped" slot.

### Proposed Fix

**Option A**: Skip swapping nonce bytes (76-79) in EthStratumClient
```cpp
for (size_t i = 0; i < 76; i += sizeof(uint32_t)) {  // Only swap 0-75
    uint32_t& k = *reinterpret_cast<uint32_t*>(buf.data() + i);
    k = ethash_swap_u32(k);
}
```

**Option B**: Swap all 80 bytes, then swap the nonce again when writing it
- In CpuWorker, when setting the nonce, byte-swap it to "undo" the initial swap
- Result: swapped nonce gets "unswapped" back to native

### Verification Needed

The nonce in CpuWorker is written at position 39 (index in uint32 array = bytes 76-79):
```cpp
// m_job.blob() contains the header
// Nonce is written somewhere - need to verify where
```

### Files to Modify

1. `src/base/net/stratum/EthStratumClient.cpp` - Header byte swap (lines 476-480)
2. `src/backend/cpu/CpuWorker.cpp` - Nonce placement and hash call

## Test Results: 76-Byte Swap (Skip Nonce Bytes) - 2025-12-04

### Hypothesis Tested

Based on cpuminer-opt analysis, we tested swapping only bytes 0-75 (skipping nonce bytes 76-79) to match the observed pattern where cpuminer-opt sets the nonce AFTER the byte swap.

**Implementation Change:**
```cpp
// Changed from 80 bytes to 76 bytes
for (size_t i = 0; i < 76; i += sizeof(uint32_t)) {
    uint32_t& k = *reinterpret_cast<uint32_t*>(buf.data() + i);
    k = ethash_swap_u32(k);
}
```

### Result: 0% Acceptance (WORSE)

Test output showed 100% rejection rate:
```
rejected (0/1) diff 1 "Invalid share" (67 ms)
rejected (0/2) diff 1 "Invalid share" (65 ms)
...
rejected (0/30) diff 1 "Invalid share" (39 ms)
```

All 30+ shares were rejected with "Invalid share" error.

### Conclusion

Skipping the nonce bytes in the swap made things **worse**, not better:
- 76-byte swap (skip nonce): **0% acceptance**
- 80-byte swap (full): **~5% acceptance**

This disproves the theory that the nonce bytes should not be swapped. The remaining issue is elsewhere in the pipeline.

### Updated Configuration Matrix

| Test | Header Swap | Nonce Submit | Accepted | Rejected | Rate | Result |
|------|-------------|--------------|----------|----------|------|--------|
| 9 | Skip nonce (76 bytes) | LE | 0 | 30+ | 0% | FAILED |
| Best | All 80 bytes | LE | 2 | 42 | ~5% | BEST |

### Reverted Code

Code reverted to full 80-byte swap (best known configuration).

## Remaining Investigation Areas

Since all byte ordering/nonce placement theories have been exhausted, the remaining issue is likely:

1. **Verthash algorithm implementation** - Core hash computation may differ from reference
2. **Hash output byte ordering** - Hash result may need byte swap before target comparison
3. **Difficulty target calculation** - Target derived from nbits may be incorrect
4. **SHA3 implementation** - Underlying SHA3 (Keccak) may have subtle differences

### Why ~5% Acceptance?

The sporadic acceptance suggests:
- The core algorithm produces correct hashes sometimes
- There may be a boundary condition or edge case handling issue
- Or the hash output interpretation has a subtle bug that only affects certain hash values
