```
llama serve -hf unsloth/Qwen3.5-0.8B-GGUF:UD-Q4_K_XL

uv run setup_db.py && uv run enrich.py
✅ master.sqlite の作成とテストデータの挿入が完了しました。
--- エンリッチメント開始 (5件) ---
[iLiFE] -> イリフェ
[JamsCollection] -> ジャムコレクション
[=LOVE] -> イコールラブ
[CANDY TUNE] -> カンディチューン
[Lollipop♡CHU] -> ラップルイッシュ
--- 処理完了 ---
```

```
llama serve -hf LiquidAI/LFM2.5-1.2B-JP-202606-GGUF:Q4_K_M
```