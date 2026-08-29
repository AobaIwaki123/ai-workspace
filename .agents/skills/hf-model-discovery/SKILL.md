---
name: hf-model-discovery
description: >-
  Discovers, filters, and ranks the latest open-source LLM models (GGUF/safetensors) on Hugging Face using the official
  huggingface_hub Python SDK and the hf CLI. Use this skill when the user asks to find recent models (e.g. 2025, 2026),
  rank models by downloads/likes/trending score, or identify compatible small models (0.5B to 4B) for local GPU deployment.
---

# Hugging Face Model Discovery Skill

本スキルは、Hugging Face 上に日々公開される膨大なオープンソース LLM の中から、リリース時期（2025年/2026年等）、パラメータ規模（1B〜4B 等）、量子化フォーマット（GGUF 等）、および人気度（ダウンロード数・いいね数）に基づいて最適なモデルを公式 SDK 経由で迅速かつ網羅的に探索・ランク付けします。

---

## 1. 発動トリガー

以下のような状況でこのスキルを実行します:
- ユーザーが「2025年や2026年の最新モデルを探して」「Hugging Face で人気の小型モデルはある？」と尋ねた時
- 特定のパラメータサイズ（例: 4GB VRAM に収まる 1B〜4B クラス）で最新の GGUF モデルを一覧取得したい時
- モデルのリリース日・ダウンロード数・トレンドランキングを客観的データで確認したい時

---

## 2. 実行手順

### Step 1: 探索スクリプトの実行

付属の探索スクリプト [`scripts/discover-models.py`](./scripts/discover-models.py) を実行します。

```bash
# 2025年以降、4.5B 以下、ダウンロード数順で上位20件を取得
uv run --with huggingface_hub python3 .agents/skills/hf-model-discovery/scripts/discover-models.py

# 急上昇トレンド（trending_score）順で取得
uv run --with huggingface_hub python3 .agents/skills/hf-model-discovery/scripts/discover-models.py --sort trending_score

# 特定キーワード（例: Qwen3.5）で検索
uv run --with huggingface_hub python3 .agents/skills/hf-model-discovery/scripts/discover-models.py --search "Qwen3.5"
```

### Step 2: モデルの選定とサイズ・適合性確認

探索結果から候補モデルを選び、ファイルサイズとローカル VRAM（本機: 4GB VRAM）への適合性を確認します。

```bash
# GGUF ファイル一覧の確認
hf models ls --search "<model-id>"
```

### Step 3: モデルのダウンロードとデプロイ

選定した GGUF を `manage-gpu-service.sh` を用いて取得・稼働させます。

```bash
./wsl-server/scripts/manage-gpu-service.sh switch "https://huggingface.co/<repo>/resolve/main/<model>.gguf"
```

---

## 3. 関連リファレンス

- [**`references/query-options.md`**](./references/query-options.md): 詳細な検索パラメータ・CLI オプション仕様書
