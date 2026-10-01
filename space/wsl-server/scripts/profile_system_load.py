#!/usr/bin/env python3
import time
import subprocess
import threading
import json
import urllib.request
import os
import sys

# ==============================================================================
# Comprehensive System Load Profiler (GPU / CPU / Memory / Thermal / Power)
# ==============================================================================

def get_gpu_metrics():
    """Extract GPU utilization, VRAM, temperature, power from nvidia-smi."""
    try:
        smi_bin = "/usr/lib/wsl/lib/nvidia-smi"
        if not os.path.exists(smi_bin):
            smi_bin = "nvidia-smi"
        cmd = [
            smi_bin,
            "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw",
            "--format=csv,noheader,nounits"
        ]
        out = subprocess.check_output(cmd, encoding="utf-8").strip()
        parts = [p.strip() for p in out.split(",")]
        gpu_util = float(parts[0])
        vram_used = float(parts[1])
        vram_total = float(parts[2])
        temp = float(parts[3])
        power = float(parts[4]) if len(parts) > 4 and parts[4] != "[N/A]" else 0.0
        return {
            "gpu_util": gpu_util,
            "vram_used_mb": vram_used,
            "vram_total_mb": vram_total,
            "vram_percent": (vram_used / vram_total) * 100,
            "temp_c": temp,
            "power_w": power
        }
    except Exception as e:
        return {
            "gpu_util": 0.0,
            "vram_used_mb": 0.0,
            "vram_total_mb": 4096.0,
            "vram_percent": 0.0,
            "temp_c": 0.0,
            "power_w": 0.0,
            "error": str(e)
        }

def get_cpu_and_mem():
    """Extract CPU percentage and memory from /proc/stat and /proc/meminfo."""
    # Mem
    mem = {}
    with open("/proc/meminfo", "r") as f:
        for line in f:
            parts = line.split(":")
            if len(parts) == 2:
                key = parts[0].strip()
                val = parts[1].strip().split()[0]
                mem[key] = int(val) # kB

    mem_total_mb = mem.get("MemTotal", 0) / 1024
    mem_avail_mb = mem.get("MemAvailable", 0) / 1024
    mem_used_mb = mem_total_mb - mem_avail_mb
    swap_total_mb = mem.get("SwapTotal", 0) / 1024
    swap_free_mb = mem.get("SwapFree", 0) / 1024
    swap_used_mb = swap_total_mb - swap_free_mb

    # Load avg
    load1, load5, load15 = os.getloadavg()

    return {
        "mem_total_mb": mem_total_mb,
        "mem_used_mb": mem_used_mb,
        "mem_percent": (mem_used_mb / mem_total_mb) * 100 if mem_total_mb > 0 else 0,
        "swap_used_mb": swap_used_mb,
        "swap_total_mb": swap_total_mb,
        "load_1m": load1,
        "load_5m": load5,
    }

class LoadSampler(threading.Thread):
    def __init__(self, interval=0.1):
        super().__init__()
        self.interval = interval
        self.running = True
        self.samples = []

    def run(self):
        while self.running:
            gpu = get_gpu_metrics()
            sys_info = get_cpu_and_mem()
            ts = time.time()
            self.samples.append({
                "ts": ts,
                "gpu_util": gpu["gpu_util"],
                "vram_used_mb": gpu["vram_used_mb"],
                "temp_c": gpu["temp_c"],
                "power_w": gpu["power_w"],
                "mem_used_mb": sys_info["mem_used_mb"],
                "mem_percent": sys_info["mem_percent"],
                "swap_used_mb": sys_info["swap_used_mb"],
            })
            time.sleep(self.interval)

    def stop(self):
        self.running = False
        self.join()

def trigger_inference_requests(n_requests=10):
    """Fire parallel/sequential LLM inferences to generate GPU load."""
    words = [
        "Kubernetes, Docker, Prometheus, Grafana, Terraform",
        "GCP, AWS, Azure, CI/CD, DevOps, SRE",
        "Python, TypeScript, Golang, Rust, JavaScript",
        "AKB, CEO, CTO, NASA, FBI, CIA, WHO, SDGs",
        "PostgreSQL, MongoDB, Redis, SQLite, Kafka"
    ]
    endpoint = "http://127.0.0.1:8080/v1/chat/completions"
    latencies = []

    for i in range(n_requests):
        word = words[i % len(words)]
        payload = {
            "model": "default-llm",
            "messages": [
                {
                    "role": "system",
                    "content": "あなたは英単語や略語を日本語カタカナ読みに変換するAIです。カタカナのみ出力してください。"
                },
                {"role": "user", "content": f"次の読みをカタカナに変換:\n{word}"}
            ],
            "temperature": 0.0,
            "max_tokens": 64
        }
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(endpoint, data=data, headers={"Content-Type": "application/json"})
        
        t0 = time.perf_counter()
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                _ = resp.read()
            lat = time.perf_counter() - t0
            latencies.append(lat)
        except Exception as e:
            print(f"  [Request {i+1}] Error: {e}")

    return latencies

def main():
    print("=" * 70)
    print("  WSL2 Server Hardware & System Load Profile (Inference Benchmark)")
    print("=" * 70)

    # 1. Baseline Idle Load
    print("[1/3] Measuring Baseline Idle Load (2 seconds)...")
    idle_sampler = LoadSampler(interval=0.1)
    idle_sampler.start()
    time.sleep(2)
    idle_sampler.stop()
    idle_samples = idle_sampler.samples

    avg_idle_gpu = sum(s["gpu_util"] for s in idle_samples) / len(idle_samples)
    avg_idle_vram = sum(s["vram_used_mb"] for s in idle_samples) / len(idle_samples)
    avg_idle_temp = sum(s["temp_c"] for s in idle_samples) / len(idle_samples)
    avg_idle_mem = sum(s["mem_used_mb"] for s in idle_samples) / len(idle_samples)
    avg_idle_swap = sum(s["swap_used_mb"] for s in idle_samples) / len(idle_samples)

    # 2. Active Load under Inference
    print("[2/3] Measuring Active Load under 10 Consecutive LLM Inferences...")
    active_sampler = LoadSampler(interval=0.05)
    active_sampler.start()

    lats = trigger_inference_requests(n_requests=10)

    active_sampler.stop()
    active_samples = active_sampler.samples

    if not active_samples:
        print("[ERROR] No samples collected during inference.")
        return

    peak_gpu = max(s["gpu_util"] for s in active_samples)
    avg_gpu = sum(s["gpu_util"] for s in active_samples) / len(active_samples)
    peak_vram = max(s["vram_used_mb"] for s in active_samples)
    avg_temp = sum(s["temp_c"] for s in active_samples) / len(active_samples)
    peak_temp = max(s["temp_c"] for s in active_samples)
    avg_mem = sum(s["mem_used_mb"] for s in active_samples) / len(active_samples)
    peak_mem = max(s["mem_used_mb"] for s in active_samples)
    avg_swap = sum(s["swap_used_mb"] for s in active_samples) / len(active_samples)

    # 3. Summary Report
    print("\n" + "=" * 70)
    print("  System Load Profile Summary")
    print("=" * 70)
    print(f"  {'Metric':<25} | {'Idle (Baseline)':<18} | {'Inference (Peak / Avg)':<22}")
    print("-" * 70)
    print(f"  {'GPU Utilization (%)':<25} | {avg_idle_gpu:6.1f} %          | {peak_gpu:5.1f} % (avg: {avg_gpu:4.1f}%)")
    print(f"  {'VRAM Usage (MiB)':<25} | {avg_idle_vram:6.1f} MiB        | {peak_vram:5.1f} / 4096.0 MiB")
    print(f"  {'GPU Temperature (°C)':<25} | {avg_idle_temp:6.1f} °C          | {peak_temp:5.1f} °C (avg: {avg_temp:4.1f}°C)")
    print(f"  {'RAM Usage (MiB)':<25} | {avg_idle_mem:6.1f} MiB        | {peak_mem:5.1f} MiB (avg: {avg_mem:4.1f})")
    print(f"  {'Swap Usage (MiB)':<25} | {avg_idle_swap:6.1f} MiB        | {avg_swap:5.1f} MiB")
    print("-" * 70)
    if lats:
        print(f"  Inference Latency: avg {sum(lats)/len(lats)*1000:.1f} ms / req (total: {len(lats)} reqs)")
    print("=" * 70)

if __name__ == "__main__":
    main()
