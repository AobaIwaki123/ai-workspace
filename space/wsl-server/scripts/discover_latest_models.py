#!/usr/bin/env python3
"""
Discover and rank the latest GGUF models on Hugging Face (2025-2026).
Uses the official huggingface_hub Python SDK with structured sorting and filtering.
"""
from datetime import datetime
from huggingface_hub import HfApi

def discover_latest_small_models(limit=25):
    api = HfApi()
    print("=" * 95)
    print("  Hugging Face Official Discovery: Top Trending & Most Downloaded Models (2025-2026)")
    print("=" * 95)
    
    # Fetch models sorted by downloads with gguf filter
    models = api.list_models(
        filter=["gguf"],
        sort="downloads",
        limit=500
    )

    discovered = []
    for m in models:
        created = getattr(m, "created_at", None) or getattr(m, "createdAt", None)
        if not created:
            continue
        
        if isinstance(created, str):
            try:
                dt = datetime.fromisoformat(created.replace("Z", "+00:00"))
            except Exception:
                continue
        elif isinstance(created, datetime):
            dt = created
        else:
            continue

        # Released from 2025 onwards
        if dt.year < 2025:
            continue

        model_id = m.id
        downloads = getattr(m, "downloads", 0) or 0
        likes = getattr(m, "likes", 0) or 0
        pipeline = getattr(m, "pipeline_tag", "") or ""

        lower_id = model_id.lower()
        # Filter for small models (1B to 4.5B)
        is_small = any(k in lower_id for k in ["0.5b", "1b", "1.5b", "1.7b", "2b", "2.4b", "2.5b", "2.6b", "3b", "3.2b", "3.4b", "3.5b", "3.8b", "4b", "mini", "nano"])
        # Exclude large models that happen to contain '3b' (e.g. 32b, 35b-a3b)
        if any(k in lower_id for k in ["32b", "35b", "70b", "72b", "8x7b", "14b"]):
            continue

        if is_small:
            discovered.append({
                "id": model_id,
                "created": dt.strftime("%Y-%m-%d"),
                "downloads": downloads,
                "likes": likes,
                "pipeline": pipeline
            })

    discovered.sort(key=lambda x: x["downloads"], reverse=True)

    print(f"{'#':<3} | {'Release Date':<12} | {'Model ID':<52} | {'Likes':<6} | {'Downloads':<10}")
    print("-" * 95)
    for idx, item in enumerate(discovered[:limit], 1):
        print(f"{idx:<3} | {item['created']:<12} | {item['id']:<52} | {item['likes']:<6} | {item['downloads']:<10}")

    print("=" * 95)
    return discovered[:limit]

if __name__ == "__main__":
    discover_latest_small_models()
