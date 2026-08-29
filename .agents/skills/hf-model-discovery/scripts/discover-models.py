#!/usr/bin/env python3
"""
Hugging Face Model Discovery Script.
Discovers and ranks GGUF/LLM models using the official huggingface_hub SDK.
Supports sorting by downloads, trending_score, likes, and filtering by year/size.
"""
import sys
import argparse
from datetime import datetime
from huggingface_hub import HfApi

def discover_models(min_year=2025, max_params=4.5, sort_by="downloads", limit=20, search_query=None):
    api = HfApi()
    
    print("=" * 100)
    print(f"  Hugging Face Model Discovery (Min Year: {min_year}, Max Params: ~{max_params}B, Sort: {sort_by})")
    print("=" * 100)

    filter_tags = ["gguf"]
    
    try:
        models = api.list_models(
            filter=filter_tags,
            sort=sort_by,
            search=search_query,
            limit=300
        )
    except Exception as e:
        print(f"[ERROR] Failed to fetch models from Hugging Face: {e}", file=sys.stderr)
        sys.exit(1)

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

        if dt.year < min_year:
            continue

        model_id = m.id
        downloads = getattr(m, "downloads", 0) or 0
        likes = getattr(m, "likes", 0) or 0
        trending = getattr(m, "trending_score", 0) or 0
        pipeline = getattr(m, "pipeline_tag", "") or ""

        lower_id = model_id.lower()
        # Parameter size filtering for small models
        is_small = any(k in lower_id for k in ["0.5b", "0.8b", "1b", "1.1b", "1.5b", "1.7b", "2b", "2.4b", "2.5b", "2.6b", "3b", "3.2b", "3.4b", "3.5b", "3.8b", "4b", "mini", "nano"])
        # Exclude large models
        if any(k in lower_id for k in ["32b", "35b", "70b", "72b", "8x7b", "14b", "27b", "122b"]):
            continue

        if is_small or search_query:
            discovered.append({
                "id": model_id,
                "created": dt.strftime("%Y-%m-%d"),
                "downloads": downloads,
                "likes": likes,
                "trending": trending,
                "pipeline": pipeline
            })

    # Sort
    if sort_by == "trending_score":
        discovered.sort(key=lambda x: x["trending"], reverse=True)
    elif sort_by == "likes":
        discovered.sort(key=lambda x: x["likes"], reverse=True)
    else:
        discovered.sort(key=lambda x: x["downloads"], reverse=True)

    print(f"{'#':<3} | {'Release Date':<12} | {'Model ID':<55} | {'Likes':<6} | {'Downloads':<10}")
    print("-" * 100)
    for idx, item in enumerate(discovered[:limit], 1):
        print(f"{idx:<3} | {item['created']:<12} | {item['id']:<55} | {item['likes']:<6} | {item['downloads']:<10}")

    print("=" * 100)
    return discovered[:limit]

def main():
    parser = argparse.ArgumentParser(description="Discover and rank latest GGUF models on Hugging Face")
    parser.add_argument("--year", type=int, default=2025, help="Minimum release year (default: 2025)")
    parser.add_argument("--max-params", type=float, default=4.5, help="Max parameter size in billions (default: 4.5)")
    parser.add_argument("--sort", choices=["downloads", "trending_score", "likes"], default="downloads", help="Sort criteria")
    parser.add_argument("--limit", type=int, default=20, help="Number of models to list")
    parser.add_argument("--search", type=str, default=None, help="Search keyword")
    args = parser.parse_args()

    discover_models(
        min_year=args.year,
        max_params=args.max_params,
        sort_by=args.sort,
        limit=args.limit,
        search_query=args.search
    )

if __name__ == "__main__":
    main()
