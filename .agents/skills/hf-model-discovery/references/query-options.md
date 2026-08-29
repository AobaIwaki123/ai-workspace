# Hugging Face Model Discovery Options & SDK Reference

## 1. 概要
本リファレンスは、`huggingface_hub` Python SDK および公式 CLI (`hf`) を用いて、特定条件（リリース年・パラメータ規模・量子化フォーマット・ダウンロード数）に適合する LLM モデルを効率的に検索・抽出するためのパラメータ仕様書です。

## 2. 主要な検索・ソートパラメータ

| パラメータ | 説明 | 指定例 |
| :--- | :--- | :--- |
| `filter` | タグによる絞り込み | `["gguf"]`, `["text-generation"]` |
| `sort` | ソート基準 | `"downloads"` (累計DL数), `"trending_score"` (急上昇), `"likes"` (評価数) |
| `search` | キーワード検索 | `"Qwen3.5"`, `"Llama-3.2"`, `"DeepSeek-R1"` |
| `limit` | 取得件数 | `20`, `50`, `100` |

## 3. CLI (`hf`) による直接実行例

```bash
# GGUF タグかつダウンロード数上位のモデル一覧を取得
hf models ls --sort downloads --limit 20

# 特定キーワードで検索
hf models ls --search "Qwen3.5" --limit 10
```
