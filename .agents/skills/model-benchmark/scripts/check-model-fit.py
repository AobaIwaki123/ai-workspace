#!/usr/bin/env python3
"""
Pre-flight check tool to evaluate whether a target GGUF/safetensors model fits in 4GB VRAM / WSL2 RAM.
Prevents OOM crashes and checks compatibility before downloading.
"""
import sys
import json
import urllib.request
import urllib.error
import re

VRAM_MAX_MB = 4000
VRAM_SAFE_MB = 3200
WSL_RAM_MAX_MB = 7500

def check_huggingface_url(url_or_repo: str):
    print("=" * 70)
    print("  🔍 Model Pre-flight Hardware & Compatibility Check")
    print(f"  Target: {url_or_repo}")
    print("  Host Specs: NVIDIA GTX 1650 Ti (4GB VRAM) / WSL2 (7.5GB RAM)")
    print("=" * 70)

    # If full URL, extract repo and filename
    if "huggingface.co" in url_or_repo:
        parts = url_or_repo.split("huggingface.co/")[-1].split("/")
        repo_id = f"{parts[0]}/{parts[1]}"
    else:
        repo_id = url_or_repo

    api_url = f"https://huggingface.co/api/models/{repo_id}"
    req = urllib.request.Request(api_url, headers={"User-Agent": "Antigravity-Model-Guard/1.0"})

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            model_info = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"[ERROR] Failed to query Hugging Face API ({e.code}): {e.reason}")
        return False
    except Exception as e:
        print(f"[ERROR] Connection error: {e}")
        return False

    tags = model_info.get("tags", [])
    siblings = [s.get("rfilename", "") for s in model_info.get("siblings", [])]
    is_gguf = "gguf" in tags or any(s.endswith(".gguf") for s in siblings)
    is_reasoning = any("reasoning" in t.lower() or "r1" in t.lower() or "think" in t.lower() for t in tags)

    print(f"Model ID:      {model_info.get('id')}")
    print(f"Release Date:  {model_info.get('createdAt', 'Unknown')[:10]}")
    print(f"Format:        {'GGUF (Native llama.cpp compatible)' if is_gguf else 'safetensors (Needs quantization)'}")
    print(f"Type:          {'Reasoning / Thinking' if is_reasoning else 'Instruct / Chat / Dense'}")
    print("-" * 70)

    # Check GGUF files
    gguf_files = [s for s in siblings if s.endswith(".gguf")]
    if not gguf_files:
        print("[WARNING] No .gguf files found in this repository.")
        print("  ➔ To run on local llama-server, please look for a quantized GGUF repo (e.g. unsloth/, bartowski/).")
        return False

    # Check size of Q4_K_M or first GGUF
    target_gguf = None
    for f in gguf_files:
        if "Q4_K_M" in f or "q4_k_m" in f or "Q4_0" in f:
            target_gguf = f
            break
    if not target_gguf:
        target_gguf = gguf_files[0]

    # Get file size via HEAD request
    file_url = f"https://huggingface.co/{repo_id}/resolve/main/{target_gguf}"
    head_req = urllib.request.Request(file_url, method="HEAD")
    size_mb = 0
    try:
        with urllib.request.urlopen(head_req, timeout=10) as resp:
            content_length = resp.headers.get("Content-Length")
            if content_length:
                size_mb = int(content_length) / (1024 * 1024)
    except Exception:
        pass

    size_gb = size_mb / 1024.0
    print(f"Target File:   {target_gguf}")
    print(f"File Size:     {size_gb:.2f} GB ({size_mb:.1f} MB)")
    print("-" * 70)

    # Assessment
    if size_mb == 0:
        print("[INFO] Could not determine exact size. Please verify file size.")
        return True

    if size_mb <= VRAM_SAFE_MB:
        print(f"✅ \033[1;32mPERFECT FIT (100% GPU Offload Supported)\033[0m")
        print(f"  VRAM Usage: ~{size_mb:.0f} MB / {VRAM_MAX_MB} MB (Safe margin: {VRAM_MAX_MB - size_mb:.0f} MB)")
        print(f"  Expected Speed: 12〜60 tokens/sec (Vulkan GPU Acceleration)")
        fit = True
    elif size_mb <= VRAM_MAX_MB:
        print(f"⚠️  \033[1;33mTIGHT FIT (Near 4GB VRAM Limit)\033[0m")
        print(f"  VRAM Usage: ~{size_mb:.0f} MB / {VRAM_MAX_MB} MB")
        print(f"  Context size should be limited to 2048 to prevent VRAM spillover.")
        fit = True
    elif size_mb <= WSL_RAM_MAX_MB:
        print(f"⚠️  \033[1;33mCPU OFFLOAD REQUIRED (Exceeds 4GB VRAM)\033[0m")
        print(f"  Will spill into System RAM. Speed will drop significantly (1〜3 tokens/sec).")
        fit = False
    else:
        print(f"❌ \033[1;31mOOM DANGER (Exceeds Total WSL RAM {WSL_RAM_MAX_MB} MB)\033[0m")
        print(f"  Model size ({size_gb:.2f} GB) will trigger Linux Out-Of-Memory killer and crash WSL.")
        fit = False

    if is_reasoning:
        print("\n💡 \033[1;34m[Architecture Notice]\033[0m")
        print("  This is a Reasoning / Thinking model. It will generate thinking tokens before answering,")
        print("  which may increase response latency for simple 1-word conversion tasks.")

    return fit

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 check-model-fit.py <huggingface-url-or-repo>")
        sys.exit(1)
    check_huggingface_url(sys.argv[1])
