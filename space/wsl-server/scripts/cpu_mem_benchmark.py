#!/usr/bin/env python3
import time
import concurrent.futures
import numpy as np
import os

def cpu_worker(n):
    val = 0
    for i in range(1, n):
        val = (val + i * 3) ^ (i & 0xFF)
    return val

def benchmark_cpu():
    print("=" * 60)
    print("  [1/2] CPU Multiprocessing Benchmark (Ryzen 5 4600H - 6C/12T)")
    print("=" * 60)
    
    threads_to_test = [1, 2, 4, 6, 12]
    workloads = 15_000_000
    
    # 1 Worker baseline
    print("Measuring 1 Core (Single Process) Baseline...")
    start = time.perf_counter()
    cpu_worker(workloads)
    t1 = time.perf_counter() - start
    print(f"  1 Worker Time:   {t1:.3f} s (1.00x Baseline)")
    
    for p in threads_to_test[1:]:
        start = time.perf_counter()
        with concurrent.futures.ProcessPoolExecutor(max_workers=p) as executor:
            futures = [executor.submit(cpu_worker, workloads) for _ in range(p)]
            _ = [f.result() for f in futures]
        elapsed = time.perf_counter() - start
        
        speedup = (t1 * p) / elapsed
        print(f"  {p:2d} Workers Time:  {elapsed:.3f} s | Multi-Core Speedup: {speedup:.2f}x ({speedup/p*100:.0f}% efficiency)")
    
    print("-" * 60)

def benchmark_memory():
    print("=" * 60)
    print("  [2/2] Memory (RAM & Cache Hierarchy) Bandwidth")
    print("=" * 60)
    
    sizes = [
        ("L1 Cache range (64 KB)", 64 * 1024),
        ("L2 Cache range (1 MB)", 1 * 1024 * 1024),
        ("L3 Cache range (4 MB)", 4 * 1024 * 1024),
        ("RAM / Main Memory (256 MB)", 256 * 1024 * 1024),
        ("RAM / Main Memory (1 GB)", 1024 * 1024 * 1024),
    ]
    
    for name, size_bytes in sizes:
        num_elements = size_bytes // 8
        a = np.ones(num_elements, dtype=np.float64)
        b = np.ones(num_elements, dtype=np.float64)
        c = np.zeros(num_elements, dtype=np.float64)
        
        scalar = 3.14159
        iterations = max(2, int((2 * 1024 * 1024 * 1024) / (size_bytes * 3)))
        
        # Warmup
        np.add(a, b * scalar, out=c)
        
        start = time.perf_counter()
        for _ in range(iterations):
            np.add(a, b * scalar, out=c)
        elapsed = time.perf_counter() - start
        
        total_data_gb = (size_bytes * 3 * iterations) / (1024 ** 3)
        bandwidth = total_data_gb / elapsed
        print(f"  {name:28s} -> {bandwidth:6.2f} GB/s")
    
    print("=" * 60)

def main():
    benchmark_cpu()
    benchmark_memory()

if __name__ == "__main__":
    main()
