#!/usr/bin/env python3
import time
import sys
from llama_cpp import Llama

def main():
    model_path = "/home/aoba/ai-workspace/scratch/models/qwen2.5-0.5b-instruct-q4_k_m.gguf"
    
    print("=" * 60)
    print("  llama.cpp LLM Inference Benchmark (CPU vs GPU)")
    print("=" * 60)

    # 1. CPU Benchmark (n_gpu_layers = 0)
    print("\n[1/2] Benchmarking CPU Inference (n_gpu_layers=0, n_threads=6)...")
    llm_cpu = Llama(
        model_path=model_path,
        n_ctx=1024,
        n_threads=6,
        n_gpu_layers=0,
        verbose=False
    )
    
    prompt = "日本の首都について教えてください。歴史や文化、観光地について詳しく説明してください。"
    
    # Warmup
    _ = llm_cpu(prompt, max_tokens=16)

    # Benchmark Generation
    start = time.perf_counter()
    output_cpu = llm_cpu(prompt, max_tokens=128, temperature=0.7)
    elapsed_cpu = time.perf_counter() - start
    
    usage_cpu = output_cpu["usage"]
    prompt_tokens = usage_cpu["prompt_tokens"]
    completion_tokens = usage_cpu["completion_tokens"]
    cpu_tg_speed = completion_tokens / elapsed_cpu
    
    print(f"  Prompt tokens: {prompt_tokens}, Completion tokens: {completion_tokens}")
    print(f"  Elapsed Time: {elapsed_cpu:.2f} s")
    print(f"  CPU Generation Speed: {cpu_tg_speed:.2f} tokens/sec")
    
    del llm_cpu

    # 2. GPU Benchmark (n_gpu_layers = -1 / All Layers Offloaded)
    print("\n[2/2] Benchmarking GPU Inference (n_gpu_layers=-1 / GTX 1650 Ti)...")
    try:
        llm_gpu = Llama(
            model_path=model_path,
            n_ctx=1024,
            n_threads=6,
            n_gpu_layers=-1,
            verbose=False
        )
        
        # Warmup
        _ = llm_gpu(prompt, max_tokens=16)

        # Benchmark Generation
        start = time.perf_counter()
        output_gpu = llm_gpu(prompt, max_tokens=128, temperature=0.7)
        elapsed_gpu = time.perf_counter() - start
        
        usage_gpu = output_gpu["usage"]
        gpu_tg_speed = usage_gpu["completion_tokens"] / elapsed_gpu
        
        print(f"  Prompt tokens: {usage_gpu['prompt_tokens']}, Completion tokens: {usage_gpu['completion_tokens']}")
        print(f"  Elapsed Time: {elapsed_gpu:.2f} s")
        print(f"  GPU Generation Speed: {gpu_tg_speed:.2f} tokens/sec")
        print(f"  Speedup vs CPU: {gpu_tg_speed / cpu_tg_speed:.2f}x")
        print("\n  Sample Response:")
        print(f"  \"{output_gpu['choices'][0]['text'].strip()[:100]}...\"")
    except Exception as e:
        print(f"  GPU Inference Error or Not Supported: {e}")
    
    print("=" * 60)

if __name__ == "__main__":
    main()
