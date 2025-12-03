# Memory Management Analysis

## Overview

This document provides a comprehensive analysis of the memory management system in X miner, including virtual memory allocation, memory pooling, huge pages support, and NUMA-aware memory allocation.

**Analysis Date**: 2025-12-02
**X Version**: 1.0.0 (based on XMRIG 6.24.0)
**Analyst**: Development Team

---

## Table of Contents

1. [Memory Management Architecture](#memory-management-architecture)
2. [VirtualMemory Class](#virtualmemory-class)
3. [Memory Pool System](#memory-pool-system)
4. [NUMA-Aware Memory Allocation](#numa-aware-memory-allocation)
5. [Huge Pages Support](#huge-pages-support)
6. [Memory Allocation Strategies](#memory-allocation-strategies)
7. [Performance Considerations](#performance-considerations)
8. [Optimization Opportunities](#optimization-opportunities)
9. [Platform-Specific Implementations](#platform-specific-implementations)

---

## Memory Management Architecture

The X miner uses a sophisticated memory management system optimized for cryptocurrency mining workloads, particularly RandomX which requires:

- **Large memory allocations**: 2GB+ for dataset
- **High-performance access**: Minimizing TLB misses
- **NUMA awareness**: Optimal placement on multi-socket systems
- **Huge pages support**: Reducing memory management overhead

### Component Overview

```
Memory Management Hierarchy
├── VirtualMemory (Low-level allocator)
│   ├── Huge Pages (2MB)
│   ├── 1GB Pages (Linux only)
│   └── Standard Pages (4KB fallback)
├── IMemoryPool (Interface)
│   ├── MemoryPool (Single-node pool)
│   └── NUMAMemoryPool (Multi-node pool)
└── Platform-Specific Implementations
    ├── Linux (mmap, madvise, mbind)
    ├── Windows (VirtualAlloc, NUMA API)
    └── macOS (mmap, limited huge pages)
```

**Code References**:
- `src/crypto/common/VirtualMemory.{h,cpp}` - Core memory allocator
- `src/crypto/common/MemoryPool.{h,cpp}` - Memory pooling
- `src/crypto/common/NUMAMemoryPool.{h,cpp}` - NUMA support
- `src/backend/common/interfaces/IMemoryPool.h` - Pool interface

---

## VirtualMemory Class

### Purpose

The `VirtualMemory` class is the low-level memory allocator that handles platform-specific memory allocation with support for huge pages, 1GB pages, and NUMA binding.

**Location**: `src/crypto/common/VirtualMemory.{h,cpp}`

### Key Features

1. **Multiple Page Size Support**:
   - Standard pages: 4 KB (default fallback)
   - Huge pages: 2 MB (Linux/Windows)
   - 1GB pages: 1 GB (Linux only, requires special setup)

2. **NUMA Binding**: Binds memory to specific NUMA nodes for local access

3. **Memory Protection**: Can set memory as RW, RX, or RWX (for JIT code)

4. **Memory Pool Integration**: Can allocate from shared memory pool

### Constructor Parameters

```cpp
VirtualMemory(
    size_t size,        // Size to allocate
    bool hugePages,     // Try to use huge pages (2MB)
    bool oneGbPages,    // Try to use 1GB pages (Linux)
    bool usePool,       // Allocate from shared pool
    uint32_t node,      // NUMA node ID
    size_t alignSize    // Alignment (default 64 bytes)
);
```

**Code Reference**: `src/crypto/common/VirtualMemory.h:45`

### Allocation Strategy

The `VirtualMemory` constructor follows this allocation strategy:

```
1. If usePool=true:
   a. Try to allocate from existing pool
   b. If pool has huge pages, use those
   c. Fall through if pool allocation fails

2. If oneGbPages=true:
   a. Try allocateOneGbPagesMemory()
   b. Requires root/admin + kernel support
   c. Linux only

3. If hugePages=true:
   a. Try allocateLargePagesMemory()
   b. Uses OS-specific huge pages API
   c. Requires huge pages configured in OS

4. Fallback:
   a. Use _mm_malloc() for standard allocation
   b. Aligned to alignSize (default 64 bytes)
```

**Code Reference**: `src/crypto/common/VirtualMemory.cpp:48-78`

### Memory Flags

The class uses a bitset to track memory properties:

```cpp
enum Flags {
    FLAG_HUGEPAGES,  // Allocated with huge pages
    FLAG_1GB_PAGES,  // Allocated with 1GB pages
    FLAG_LOCK,       // Memory locked (not swappable)
    FLAG_EXTERNAL,   // Allocated from pool
    FLAG_MAX
};
```

**Code Reference**: `src/crypto/common/VirtualMemory.h:78-84`

### Static Methods

**Memory Protection** (for JIT code):
- `protectRW()` - Read/Write access
- `protectRX()` - Read/Execute access (for JIT code)
- `protectRWX()` - Read/Write/Execute access (during JIT compilation)

**Huge Pages Query**:
- `isHugepagesAvailable()` - Check if huge pages are available
- `isOneGbPagesAvailable()` - Check if 1GB pages are available

**NUMA**:
- `bindToNUMANode(affinity)` - Bind current thread to NUMA node

**Utility**:
- `align(pos, align)` - Round up to alignment
- `alignToHugePageSize(pos)` - Align to current huge page size

**Code Reference**: `src/crypto/common/VirtualMemory.h:59-75`

---

## Memory Pool System

### Purpose

Memory pools reduce allocation overhead by pre-allocating large blocks of memory and dividing them among threads/workers. This is especially important for:
- Reducing system calls
- Ensuring huge pages are used efficiently
- Minimizing memory fragmentation

### IMemoryPool Interface

**Location**: `src/backend/common/interfaces/IMemoryPool.h`

```cpp
class IMemoryPool {
public:
    virtual bool isHugePages(uint32_t node) const = 0;
    virtual uint8_t *get(size_t size, uint32_t node) = 0;
    virtual void release(uint32_t node) = 0;
};
```

**Methods**:
- `isHugePages(node)` - Check if pool uses huge pages for this node
- `get(size, node)` - Allocate memory from pool
- `release(node)` - Release allocation (reference counting)

**Code Reference**: `src/backend/common/interfaces/IMemoryPool.h:33-44`

---

### MemoryPool Implementation

**Location**: `src/crypto/common/MemoryPool.{h,cpp}`

**Purpose**: Single-node memory pool for systems without NUMA or single-socket systems.

#### Architecture

```cpp
class MemoryPool : public IMemoryPool {
private:
    size_t m_refs;           // Reference count
    size_t m_offset;         // Current allocation offset
    size_t m_alignOffset;    // Alignment adjustment
    VirtualMemory *m_memory; // Backing memory
};
```

**Code Reference**: `src/crypto/common/MemoryPool.h:41-59`

#### Allocation Strategy

```
Pool Layout:
┌──────────────┬────────────────────────────────┐
│ Align Offset │  Usable Memory (2MB chunks)    │
│ (padding)    │                                 │
└──────────────┴────────────────────────────────┘
      ^                    ^
  m_alignOffset        m_offset (grows)
```

**Alignment**: 16MB boundaries (`1 << 24`) for optimal cache behavior

**Code Reference**: `src/crypto/common/MemoryPool.cpp:44-55`

#### Memory Allocation (`get()`)

```cpp
uint8_t *MemoryPool::get(size_t size, uint32_t node)
{
    // Validate size is multiple of pageSize (2MB)
    assert(!(size % pageSize));

    // Check if enough space remaining
    if (m_memory->size() - m_offset - m_alignOffset < size) {
        return nullptr;
    }

    // Return pointer to next available chunk
    uint8_t *out = m_memory->scratchpad() + m_alignOffset + m_offset;
    m_offset += size;
    ++m_refs;

    return out;
}
```

**Key Points**:
- Allocations must be in 2MB chunks (`pageSize`)
- Linear allocation (bump allocator)
- No deallocation tracking (pool-level only)
- Reference counting for pool lifetime

**Code Reference**: `src/crypto/common/MemoryPool.cpp:70-84`

#### Memory Release (`release()`)

```cpp
void MemoryPool::release(uint32_t node)
{
    if (m_refs > 0) {
        --m_refs;
    }

    // When all references released, reset pool
    if (m_refs == 0) {
        m_offset = 0;
    }
}
```

**Note**: This is a simple reference counting scheme. When all allocations are released, the entire pool is reset. No individual deallocation.

**Code Reference**: `src/crypto/common/MemoryPool.cpp:87-98`

---

### NUMAMemoryPool Implementation

**Location**: `src/crypto/common/NUMAMemoryPool.{h,cpp}`

**Purpose**: NUMA-aware memory pool that creates per-node memory pools for optimal memory locality on multi-socket systems.

#### Architecture

```cpp
class NUMAMemoryPool : public IMemoryPool {
private:
    bool m_hugePages;
    size_t m_nodeSize;  // Size per NUMA node
    size_t m_size;      // Total size
    mutable std::map<uint32_t, IMemoryPool*> m_map;
};
```

**Code Reference**: `src/crypto/common/NUMAMemoryPool.h:44-65`

#### Per-Node Pool Creation

The `NUMAMemoryPool` lazily creates `MemoryPool` instances for each NUMA node:

```cpp
IMemoryPool *NUMAMemoryPool::getOrCreate(uint32_t node) const
{
    auto pool = get(node);
    if (!pool) {
        // Create new MemoryPool bound to this NUMA node
        pool = new MemoryPool(m_nodeSize, m_hugePages, node);
        m_map.insert({ node, pool });
    }
    return pool;
}
```

**Benefits**:
- Memory allocated on same NUMA node as worker thread
- Reduces cross-socket memory traffic
- Better cache coherency
- Only creates pools for nodes actually used

**Code Reference**: `src/crypto/common/NUMAMemoryPool.cpp:88-97`

#### Node Size Calculation

```cpp
NUMAMemoryPool::NUMAMemoryPool(size_t size, bool hugePages) :
    m_hugePages(hugePages),
    m_nodeSize(std::max<size_t>(size / Cpu::info()->nodes(), 1)),
    m_size(size)
{
}
```

Example: 8GB pool on 2-socket system → 4GB per node

**Code Reference**: `src/crypto/common/NUMAMemoryPool.cpp:37-42`

---

## NUMA-Aware Memory Allocation

### What is NUMA?

**NUMA (Non-Uniform Memory Access)**: In multi-socket systems, each CPU has "local" memory that's faster to access than "remote" memory attached to other CPUs.

```
System Architecture Example:
┌─────────────────┐          ┌─────────────────┐
│   CPU Socket 0  │          │   CPU Socket 1  │
│   (NUMA Node 0) │          │   (NUMA Node 1) │
├─────────────────┤          ├─────────────────┤
│  Local Memory   │          │  Local Memory   │
│      32 GB      │          │      32 GB      │
└────────┬────────┘          └────────┬────────┘
         │                            │
         └────────────────────────────┘
              Interconnect (slower)
```

**Performance Impact**:
- Local memory access: ~100ns latency
- Remote memory access: ~150-200ns latency (50-100% slower)
- Bandwidth also reduced for remote access

### NUMA Support in X

X automatically detects and uses NUMA when available:

```cpp
void VirtualMemory::init(size_t poolSize, size_t hugePageSize)
{
#ifdef XMRIG_FEATURE_HWLOC
    if (Cpu::info()->nodes() > 1) {
        // Multi-socket system: use NUMA pool
        pool = new NUMAMemoryPool(
            align(poolSize, Cpu::info()->nodes()),
            hugePageSize > 0
        );
    } else
#endif
    {
        // Single-socket or no NUMA: use standard pool
        pool = new MemoryPool(poolSize, hugePageSize > 0);
    }
}
```

**Code Reference**: `src/crypto/common/VirtualMemory.cpp:120-134`

### NUMA Node Binding

**Method**: `VirtualMemory::bindToNUMANode(int64_t affinity)`

When a worker thread starts:
1. Determine which CPU it's running on
2. Determine which NUMA node that CPU belongs to
3. Allocate memory from that node's pool
4. Bind thread affinity to CPUs on that node

**Benefits**:
- All memory access is local
- Maximizes memory bandwidth
- Reduces latency
- Better cache utilization

**Implementation**: Platform-specific (hwloc library on Linux/Windows)

**Code Reference**: `src/crypto/common/VirtualMemory_hwloc.cpp` (platform-specific)

---

## Huge Pages Support

### What Are Huge Pages?

**Standard Pages**: 4 KB per page
**Huge Pages**: 2 MB per page (512x larger)
**1GB Pages**: 1 GB per page (262,144x larger)

### Why Huge Pages Matter for Mining

**TLB (Translation Lookaside Buffer)**:
- CPU cache for virtual→physical address mappings
- Limited size (typically 64-1024 entries)
- With 4KB pages: 64 entries = 256 KB coverage
- With 2MB pages: 64 entries = 128 MB coverage
- With 1GB pages: 64 entries = 64 GB coverage

**RandomX Memory Access Pattern**:
- 2GB+ dataset accessed randomly
- Scratchpad: 2MB per thread accessed randomly
- Standard pages: Constant TLB misses (major performance hit)
- Huge pages: TLB can cover entire working set

**Performance Impact**: 10-30% hashrate improvement with huge pages

### Huge Pages Configuration

**Page Size Constants**:
```cpp
constexpr static size_t kDefaultHugePageSize = 2U * 1024U * 1024U;  // 2 MB
constexpr static size_t kOneGiB = 1024U * 1024U * 1024U;             // 1 GB
```

**Code Reference**: `src/crypto/common/VirtualMemory.h:42-43`

### Platform-Specific Setup

#### Linux

**2MB Huge Pages**:
```bash
# Check current setting
cat /proc/sys/vm/nr_hugepages

# Set 1280 huge pages (2.5 GB)
sudo sysctl -w vm.nr_hugepages=1280

# Make permanent
echo "vm.nr_hugepages=1280" | sudo tee -a /etc/sysctl.conf
```

**1GB Pages** (requires root and CPU support):
```bash
# Add to kernel boot parameters
default_hugepagesz=1G hugepagesz=1G hugepages=4

# Or at runtime (if supported)
echo 4 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
```

**Verification**:
```bash
cat /proc/meminfo | grep -i huge
```

#### Windows

Windows automatically uses "Large Pages" (equivalent to huge pages) if:
1. User has "Lock pages in memory" privilege
2. Physical memory is available

**Enable Privilege**:
1. Run `secpol.msc`
2. Navigate to: Security Settings → Local Policies → User Rights Assignment
3. Open "Lock pages in memory"
4. Add your user account
5. Reboot

#### macOS

macOS has limited huge pages support:
- No user-space huge pages API
- System automatically uses "superpages" internally
- Cannot be explicitly requested
- X will use standard allocation on macOS

### Huge Pages Detection

```cpp
static bool isHugepagesAvailable();     // Check if 2MB pages available
static bool isOneGbPagesAvailable();    // Check if 1GB pages available
```

These methods check OS capabilities at runtime and guide allocation strategy.

**Code Reference**: `src/crypto/common/VirtualMemory.h:59-60`

---

## Memory Allocation Strategies

### Strategy Selection

X uses different memory allocation strategies based on the use case:

#### 1. **RandomX Dataset** (2GB+)

**Strategy**: Huge pages, optionally from pool

```cpp
// From RxDataset.cpp
new VirtualMemory(
    size,           // ~2GB
    hugePages,      // true
    oneGbPages,     // false (typically)
    cache,          // false (dedicated allocation)
    node            // NUMA node
);
```

**Rationale**:
- Large allocation benefits most from huge pages
- Dedicated allocation (not pooled) for long-lived data
- Per-NUMA-node allocation for multi-socket systems

**Code Reference**: `src/crypto/rx/RxDataset.cpp:55-70`

---

#### 2. **RandomX Cache** (256MB)

**Strategy**: Huge pages with JIT support

```cpp
// From RxCache.cpp
new VirtualMemory(
    RANDOMX_CACHE_MAX_SIZE,  // 256 MB
    hugePages,               // true
    false,                   // no 1GB pages
    false,                   // not from pool
    nodeId                   // NUMA node
);
```

**Additional**: May allocate executable memory for JIT-compiled dataset initialization code

**Code Reference**: `src/crypto/rx/RxCache.cpp` (implementation)

---

#### 3. **Scratchpad** (2MB per thread)

**Strategy**: From memory pool with huge pages

```cpp
// Typically allocated via dataset's tryAllocateScratchpad()
pool->get(2 * 1024 * 1024, node);  // 2 MB
```

**Rationale**:
- Many small allocations (one per thread)
- Pooling reduces allocation overhead
- Pooling ensures huge pages used efficiently

**Code Reference**: `src/crypto/rx/RxDataset.cpp:tryAllocateScratchpad()`

---

#### 4. **JIT Code** (varies, typically <1MB)

**Strategy**: Executable memory with protection changes

```cpp
VirtualMemory::allocateExecutableMemory(size, hugePages);
// Later: protectRWX() during compilation
//        protectRX() after compilation
```

**Rationale**:
- Must be executable (W^X policy)
- Protection changes for security
- Huge pages less critical (small size)

**Code Reference**: `src/crypto/randomx/jit_compiler_*.cpp`

---

## Performance Considerations

### Memory Bandwidth Bottleneck

RandomX is often **memory bandwidth limited**, especially on systems with:
- High CPU core count
- Limited memory channels
- Older/slower RAM

**Optimal Configuration**:
- Dual-channel DDR4-3200 minimum
- Quad-channel for high-end systems (Threadripper, Xeon)
- Avoid single-channel RAM

### Memory Latency Impact

**Latency Sources**:
1. **DRAM latency**: ~50-100ns
2. **TLB miss penalty**: +100-200ns (without huge pages)
3. **NUMA remote access**: +50-100ns additional
4. **Cache miss**: +10-50ns

**Mitigations**:
- Huge pages (eliminate TLB miss penalty)
- NUMA binding (eliminate remote access)
- Proper memory alignment (better cache utilization)

### Thread Scaling

**Memory Pool Size Calculation**:
```
dataset_size = 2GB (per NUMA node if NUMA)
cache_size = 256MB (per NUMA node if NUMA)
scratchpad_size = 2MB * num_threads

total_pool_size = dataset_size + cache_size + scratchpad_size
```

**Example** (16 threads, single socket):
```
2048 MB (dataset) + 256 MB (cache) + 32 MB (16 scratchpads) = 2336 MB
```

**With NUMA** (32 threads, 2 sockets):
```
Per node: 2048 + 256 + 32 = 2336 MB
Total: 2336 * 2 = 4672 MB
```

### Memory Overhead

**Alignment Overhead**:
- 16MB alignment per pool (up to 16MB wasted)
- 64-byte alignment per allocation (negligible)

**Huge Page Overhead**:
- Rounded up to 2MB boundaries
- For 2336 MB: actual allocation = 2340 MB (4 MB overhead = 0.17%)

---

## Optimization Opportunities

Based on the memory management analysis, here are identified optimization opportunities:

### 1. **Dynamic Pool Sizing**

**Current**: Fixed pool size at startup

**Opportunity**:
- Dynamic pool resizing based on active threads
- Shrink pool when threads are idle
- Grow pool when new algorithms activated

**Impact**: Moderate (reduces memory footprint for variable workloads)

**Location**: `src/crypto/common/VirtualMemory.cpp:init()`

---

### 2. **Transparent Huge Pages (Linux)**

**Current**: Explicit huge pages only

**Opportunity**:
- Fallback to transparent huge pages (THP) if explicit unavailable
- Use `madvise(MADV_HUGEPAGE)` on standard allocations
- Better for systems without pre-configured huge pages

**Impact**: Low to Moderate (better compatibility)

**Location**: `src/crypto/common/VirtualMemory_unix.cpp`

---

### 3. **Memory Prefetching**

**Current**: No explicit prefetching

**Opportunity**:
- Software prefetch hints for dataset access
- Prefetch next cache line in scratchpad operations
- Compiler intrinsics: `__builtin_prefetch()`

**Impact**: Low to Moderate (3-5% possible on some CPUs)

**Location**: RandomX VM execution loops

---

### 4. **Pool Fragmentation Handling**

**Current**: Simple bump allocator, resets when all freed

**Opportunity**:
- Better fragmentation handling for mixed allocation sizes
- Multiple size classes (2MB, 4MB, 8MB)
- Free list for reuse

**Impact**: Low (current design works well for mining workload)

**Location**: `src/crypto/common/MemoryPool.cpp`

---

### 5. **NUMA Distance Optimization**

**Current**: Binary local/remote distinction

**Opportunity**:
- Prefer nearby NUMA nodes over distant ones
- Use hwloc distance matrix
- Fallback to "closest available" instead of "any available"

**Impact**: Low to Moderate (multi-socket systems only)

**Location**: `src/crypto/common/NUMAMemoryPool.cpp`

---

### 6. **Memory Locking (mlock)**

**Current**: Not explicitly locked

**Opportunity**:
- Lock dataset/cache memory to prevent swapping
- Use `mlock()` on Linux, `VirtualLock()` on Windows
- Critical for systems with insufficient RAM

**Impact**: Moderate (prevents swap-induced stalls)

**Location**: `src/crypto/common/VirtualMemory.cpp`

---

### 7. **Huge Pages on Windows**

**Current**: Large pages support, but requires manual privilege setup

**Opportunity**:
- Automatic privilege check and user guidance
- Runtime detection of "Lock pages in memory" privilege
- Fallback with clear error message

**Impact**: Moderate (better Windows UX)

**Location**: `src/crypto/common/VirtualMemory_win.cpp`

---

### 8. **Memory Alignment Optimization**

**Current**: 16MB alignment for pools

**Opportunity**:
- Dynamic alignment based on detected CPU cache size
- Smaller alignment for systems with limited memory
- Configurable alignment parameter

**Impact**: Low (marginal memory savings)

**Location**: `src/crypto/common/MemoryPool.cpp:50`

---

### 9. **Per-Algorithm Memory Profiles**

**Current**: Fixed allocation strategy

**Opportunity**:
- Different memory strategies per algorithm
  - RandomX: huge pages, NUMA critical
  - CryptoNight: smaller allocations, less critical
  - KawPow: GPU memory, different constraints
- Algorithm-specific pool configurations

**Impact**: Moderate (better multi-algorithm support)

**Location**: New feature - spans multiple modules

---

### 10. **Memory Usage Monitoring**

**Current**: Basic huge pages info

**Opportunity**:
- Real-time memory usage stats via API
- Pool utilization metrics
- Fragmentation monitoring
- Memory bandwidth estimation

**Impact**: Low for performance, High for diagnostics

**Location**: API endpoints, logging system

---

## Platform-Specific Implementations

### Linux

**Files**:
- `src/crypto/common/VirtualMemory_unix.cpp`
- `src/crypto/common/VirtualMemory_hwloc.cpp`

**Features**:
- `mmap()` with `MAP_HUGETLB` for huge pages
- `madvise(MADV_HUGEPAGE)` for THP
- `mbind()` for NUMA memory binding
- `mlock()` for memory locking
- 1GB pages support via `MAP_HUGETLB | MAP_HUGE_1GB`

**NUMA Support**: via hwloc library

---

### Windows

**File**: `src/crypto/common/VirtualMemory_win.cpp`

**Features**:
- `VirtualAlloc()` with `MEM_LARGE_PAGES` for large pages
- NUMA API: `VirtualAllocExNuma()`
- `VirtualLock()` for memory locking
- Privilege checking for large pages

**NUMA Support**: Native Windows NUMA API

---

### macOS

**File**: `src/crypto/common/VirtualMemory_unix.cpp`

**Features**:
- `mmap()` for standard allocation
- Limited huge pages support (system-managed only)
- `mlock()` for memory locking
- Single-socket systems typically (no NUMA)

**Limitations**:
- No explicit huge pages
- No user-space NUMA control
- Relies on system automatic optimizations

---

## Best Practices

### For Users

1. **Always enable huge pages** on Linux:
   ```bash
   sudo sysctl -w vm.nr_hugepages=1280
   ```

2. **Enable large pages privilege** on Windows (via secpol.msc)

3. **Monitor memory usage**:
   ```bash
   cat /proc/meminfo | grep -i huge  # Linux
   ```

4. **Ensure sufficient RAM**:
   - RandomX: 4GB minimum, 8GB+ recommended
   - Multiple algorithms: Add memory requirements

5. **Use NUMA when available**:
   - Multi-socket systems benefit significantly
   - Verify with `numactl --hardware`

---

### For Developers

1. **Prefer pool allocations** for small, frequent allocations

2. **Use huge pages** for allocations >2MB

3. **Respect NUMA** - always pass correct node ID

4. **Check allocation success** - handle nullptr returns

5. **Align allocations** to cache line boundaries (64 bytes)

6. **Profile memory access** - use tools like `perf mem`

---

## References

### Internal Documentation
- `docs/RANDOMX_ANALYSIS.md` - RandomX implementation details
- `PERFORMANCE.md` - Performance tuning guide
- `BUILD.md` - Build instructions

### Source Files
- `src/crypto/common/VirtualMemory.{h,cpp}` - Core allocator (line 1-135)
- `src/crypto/common/MemoryPool.{h,cpp}` - Memory pooling (line 1-99)
- `src/crypto/common/NUMAMemoryPool.{h,cpp}` - NUMA support (line 1-98)
- `src/backend/common/interfaces/IMemoryPool.h` - Pool interface (line 1-52)

### External Resources
- [Linux Huge Pages Documentation](https://www.kernel.org/doc/Documentation/vm/hugetlbpage.txt)
- [NUMA Best Practices](https://www.kernel.org/doc/html/latest/vm/numa.html)
- [hwloc Documentation](https://www.open-mpi.org/projects/hwloc/)
- [Windows Large Pages](https://docs.microsoft.com/en-us/windows/win32/memory/large-page-support)

---

## Next Steps

Based on this analysis, recommended next steps:

1. ✅ **Memory Pool Analysis** - Completed
2. ⏳ **Create Utility Scripts** - Next task
3. ⏳ **Profile Memory Access Patterns** - Use perf/vtune
4. ⏳ **Implement THP Fallback** - Linux improvement
5. ⏳ **Add Memory Monitoring** - API endpoints
6. ⏳ **Test on Various Hardware** - Validate NUMA optimizations

---

**Document Version**: 1.0
**Last Updated**: 2025-12-02
**Status**: Initial Analysis Complete
