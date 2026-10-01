#!/usr/bin/env python3
import time
import torch

def main():
    print("=" * 60)
    print("  WSL2 GPU / CPU Performance Benchmark (PyTorch / CUDA)")
    print("=" * 60)

    # 1. Device Info
    cuda_available = torch.cuda.is_available()
    print(f"CUDA Available: {cuda_available}")
    if not cuda_available:
        print("ERROR: CUDA is not available.")
        return

    device_name = torch.cuda.get_device_name(0)
    device_props = torch.cuda.get_device_properties(0)
    vram_gb = device_props.total_memory / (1024 ** 3)
    print(f"Device: {device_name}")
    print(f"VRAM Capacity: {vram_gb:.2f} GB ({device_props.total_memory / (1024**2):.0f} MiB)")
    print(f"CUDA Capability: {device_props.major}.{device_props.minor}")
    print(f"PyTorch Version: {torch.__version__}")
    print(f"CUDA Version (PyTorch): {torch.version.cuda}")
    print("-" * 60)

    # 2. Host <-> Device Memory Transfer Bandwidth
    print("[1/3] Measuring Memory Transfer Bandwidth (PCIe)...")
    size_mb = 256
    num_elements = (size_mb * 1024 * 1024) // 4  # float32 = 4 bytes
    x_cpu = torch.randn(num_elements, dtype=torch.float32)

    # Warmup
    _ = x_cpu.cuda()
    torch.cuda.synchronize()

    # Host to Device
    trials = 10
    start = time.perf_counter()
    for _ in range(trials):
        x_gpu = x_cpu.to('cuda', non_blocking=False)
        torch.cuda.synchronize()
    h2d_time = (time.perf_counter() - start) / trials
    h2d_bandwidth = size_mb / h2d_time / 1024  # GB/s

    # Device to Host
    start = time.perf_counter()
    for _ in range(trials):
        x_back = x_gpu.to('cpu', non_blocking=False)
        torch.cuda.synchronize()
    d2h_time = (time.perf_counter() - start) / trials
    d2h_bandwidth = size_mb / d2h_time / 1024  # GB/s

    print(f"  Host -> GPU Bandwidth: {h2d_bandwidth:.2f} GB/s (Latency: {h2d_time*1000:.2f} ms for {size_mb}MB)")
    print(f"  GPU -> Host Bandwidth: {d2h_bandwidth:.2f} GB/s (Latency: {d2h_time*1000:.2f} ms for {size_mb}MB)")
    print("-" * 60)

    # 3. CPU Matrix Multiplication (GEMM)
    print("[2/3] Measuring CPU Matrix Multiplication (Float32)...")
    matrix_size = 4096
    flops_per_gemm = 2 * (matrix_size ** 3)  # 2 * N^3 operations

    a_cpu = torch.randn(matrix_size, matrix_size, dtype=torch.float32)
    b_cpu = torch.randn(matrix_size, matrix_size, dtype=torch.float32)

    # CPU warm-up
    _ = torch.mm(a_cpu, b_cpu)

    cpu_trials = 3
    start = time.perf_counter()
    for _ in range(cpu_trials):
        _ = torch.mm(a_cpu, b_cpu)
    cpu_time = (time.perf_counter() - start) / cpu_trials
    cpu_gflops = (flops_per_gemm / cpu_time) / 1e9

    print(f"  CPU Matrix Size: {matrix_size}x{matrix_size} (Float32)")
    print(f"  CPU Average Time: {cpu_time*1000:.2f} ms")
    print(f"  CPU Compute Throughput: {cpu_gflops:.2f} GFLOPS ({cpu_gflops/1000:.3f} TFLOPS)")
    print("-" * 60)

    # 4. GPU Matrix Multiplication (GEMM Float32 & Float16)
    print("[3/3] Measuring GPU Matrix Multiplication...")
    a_gpu = a_cpu.cuda()
    b_gpu = b_cpu.cuda()

    # GPU Float32 Warm-up
    for _ in range(5):
        _ = torch.mm(a_gpu, b_gpu)
    torch.cuda.synchronize()

    gpu_trials = 20
    start = time.perf_counter()
    for _ in range(gpu_trials):
        _ = torch.mm(a_gpu, b_gpu)
    torch.cuda.synchronize()
    gpu_fp32_time = (time.perf_counter() - start) / gpu_trials
    gpu_fp32_gflops = (flops_per_gemm / gpu_fp32_time) / 1e9

    # GPU Float16
    a_gpu_fp16 = a_gpu.half()
    b_gpu_fp16 = b_gpu.half()
    for _ in range(5):
        _ = torch.mm(a_gpu_fp16, b_gpu_fp16)
    torch.cuda.synchronize()

    start = time.perf_counter()
    for _ in range(gpu_trials):
        _ = torch.mm(a_gpu_fp16, b_gpu_fp16)
    torch.cuda.synchronize()
    gpu_fp16_time = (time.perf_counter() - start) / gpu_trials
    gpu_fp16_gflops = (flops_per_gemm / gpu_fp16_time) / 1e9

    print(f"  GPU FP32 Matrix Size: {matrix_size}x{matrix_size}")
    print(f"  GPU FP32 Average Time: {gpu_fp32_time*1000:.2f} ms")
    print(f"  GPU FP32 Throughput: {gpu_fp32_gflops:.2f} GFLOPS ({gpu_fp32_gflops/1000:.3f} TFLOPS)")
    print(f"  Speedup vs CPU (FP32): {cpu_time / gpu_fp32_time:.1f}x Faster")
    print()
    print(f"  GPU FP16 Matrix Size: {matrix_size}x{matrix_size}")
    print(f"  GPU FP16 Average Time: {gpu_fp16_time*1000:.2f} ms")
    print(f"  GPU FP16 Throughput: {gpu_fp16_gflops:.2f} GFLOPS ({gpu_fp16_gflops/1000:.3f} TFLOPS)")
    print(f"  Speedup vs CPU (FP16): {cpu_time / gpu_fp16_time:.1f}x Faster")
    print("=" * 60)

if __name__ == "__main__":
    main()
