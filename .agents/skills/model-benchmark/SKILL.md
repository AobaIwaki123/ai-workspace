---
name: model-benchmark
description: Pre-flight checks hardware compatibility (4GB VRAM/WSL2 RAM limit), searches suitable models, and runs end-to-end automated LLM benchmarks (llama-bench, phonetic accuracy, JSON upsert, and Markdown report rendering). Use when evaluating new LLM models, benchmarking GGUFs, or verifying VRAM fit before download.
---

# Model Benchmark & Hardware Pre-flight Skill (`model-benchmark`)

Evaluates LLM models before download, executes automated inference & accuracy benchmarks on NVIDIA GeForce GTX 1650 Ti (4GB VRAM), and updates the unified benchmark data store (`data/benchmarks.json`) and Markdown reports.

---

## 1. Core Capabilities

1. **Pre-flight Hardware Fit & OOM Guard (`check-model-fit.py`)**:
   - Queries Hugging Face API to retrieve model file size, parameter count, format, and architecture tags.
   - Evaluates if the model fits 100% in 4GB VRAM (Safe limit: ≤ 3.2 GB) or triggers an OOM crash (> 7.5 GB).
   - Detects Reasoning / Thinking architectures that might introduce high latency on single-word tasks.
2. **End-to-End Automated Pipeline (`run-pipeline-benchmark.py`)**:
   - Downloads/switches model via `manage-gpu-service.sh` (with 10-model retention & SSD fstrim).
   - Measures raw prompt (pp128) and token generation (tg32) throughput with `llama-bench`.
   - Runs strict 67-case phonetic conversion accuracy benchmark.
   - Upserts results to `data/benchmarks.json` and triggers `render_benchmark_report.py`.
3. **Benchmark JSON Metadata API (`serve_benchmark_api.py`)**:
   - Serves `data/benchmarks.json` via lightweight REST API (`GET /api/benchmarks` on port 8088).

---

## 2. Quick Usage

### (1) Pre-flight Check (Check VRAM & OOM Risk Before Download)

```bash
python3 .agents/skills/model-benchmark/scripts/check-model-fit.py <huggingface-url-or-repo>
```

**Example Output**:
```text
Model ID:      bartowski/Llama-3.2-3B-Instruct-GGUF
Release Date:  2024-09-25
Format:        GGUF (Native llama.cpp compatible)
Type:          Instruct / Chat / Dense
File Size:     1.79 GB (1832.9 MB)
✅ PERFECT FIT (100% GPU Offload Supported)
  VRAM Usage: ~1833 MB / 4000 MB (Safe margin: 2167 MB)
  Expected Speed: 12〜60 tokens/sec
```

### (2) Full End-to-End Benchmark Execution

```bash
python3 .agents/skills/model-benchmark/scripts/run-pipeline-benchmark.py <gguf-download-url-or-local-file>
```

---

## 3. Hardware Boundaries & Rules

| VRAM / Memory Range | Status | Behavior & Recommendation |
| :--- | :--- | :--- |
| **≤ 3.2 GB** | **PERFECT FIT (Green)** | 100% GPU Offload (`ngl=99`). 12〜60 tokens/sec. **Recommended.** |
| **3.2 GB 〜 4.0 GB** | **TIGHT FIT (Yellow)** | Fully offloaded, but context size (`-c`) must be ≤ 2048 to prevent VRAM overflow. |
| **4.0 GB 〜 7.5 GB** | **CPU OFFLOAD (Orange)** | Spills into system RAM. Speed drops to 1〜3 tokens/sec. |
| **> 7.5 GB** | **OOM DANGER (Red)** | Exceeds WSL2 memory allocation. **DO NOT DOWNLOAD** (Will crash WSL). |

---

## 4. Integration with `hf-model-discovery`

When a model is incompatible (e.g. OOM or safetensors-only), use the companion `hf-model-discovery` skill to find suitable alternatives:

```bash
python3 .agents/skills/hf-model-discovery/scripts/discover-models.py --min-params 2B --max-params 4B --sort downloads
```
