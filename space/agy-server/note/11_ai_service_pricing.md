# AI サービス価格・プラン比較（ヘッドレス利用観点）

最終更新: 2026-10-01（公式ページ・検索結果確認済み）

## 目的

ヘッドレスで呼び出せる AI コーディングエージェントを、定額サブスクリプションで利用するための
価格・プラン・制約を整理する。従量課金（API Key）を使わず、月額固定費でお金を気にせず使うことが前提。

---

## カテゴリ分類

| カテゴリ | 代表サービス | 特徴 |
|:---|:---|:---|
| A. 専用 CLI 型（コーディング特化） | agy, Codex CLI, Claude Code | CLI が最初から整備済み。AGENTS.md 等の統合あり |
| B. 定額 LLM アクセス型 | z.ai GLM Plan, MiniMax M Plan, DevPass | 任意の CLI ツールに API を提供。自分でラップが必要 |
| C. BYOK 型 OSS | OpenCode, Kilo Code, Aider | 自分で API キーを用意。低コストだが API 代が別途かかる |

---

## A. 専用 CLI 型（コーディング特化）

### A-1. Antigravity CLI (agy) — Google

公式: https://deepmind.google/antigravity/

| プラン名 | 月額（USD） | 利用枠 |
|:---|---:|:---|
| Google AI Pro | $20 | 標準枠（5時間ごとにリセット） |
| Google AI Ultra Entry | $100 | Pro の 5 倍枠 + 20TB ストレージ |
| Google AI Ultra Top | $200 | Pro の 20 倍枠 + 20TB+ ストレージ + 優先アクセス |

- ヘッドレス: `agy -p "..." --output-format json --dangerously-skip-permissions`
- AGENTS.md / MCP / スキルシステム統合済み
- `GOOGLE_API_KEY` 未設定でサブスクリプション利用

### A-2. Codex CLI — OpenAI

公式: https://chatgpt.com/pricing

| プラン名 | 月額（USD） | 特徴 |
|:---|---:|:---|
| ChatGPT Plus | $20 | 標準枠、個人向け |
| ChatGPT Pro 100 | $100 | 拡張枠 |
| ChatGPT Pro 200 | $200 | 高頻度利用向け |
| ChatGPT Pro 500 | $500 | Astra Ultrafast + 最高枠 |

- ヘッドレス: `codex exec "<prompt>" --full-auto`
- `OPENAI_API_KEY` **未設定**でサブスクリプション利用

### A-3. Claude Code — Anthropic

公式: https://claude.ai/pricing

| プラン名 | 月額（USD） | 利用枠の目安 |
|:---|---:|:---|
| Claude Pro | $20 | 標準枠（rolling window 制） |
| Claude Max 5x | $100 | Pro の約 5 倍枠 |
| Claude Max 20x | $200 | Pro の約 20 倍枠（約 900 prompts / 5 時間） |

- ヘッドレス: `claude -p "<prompt>" --output-format json --allowedTools Read,Write,Bash`
- 2026年6月以降、headless 実行はサブスクリプションの rolling window 枠を消費
- `ANTHROPIC_API_KEY` **未設定**でサブスクリプション利用
- Bot 用途には **Max 5x ($100) 以上を推奨**

---

## B. 定額 LLM アクセス型（任意の CLI ツールに API を提供）

これらは「Claude Code や OpenCode などの既存 CLI ツールのバックエンド API として使う」形態。
自分で CLI を起動し、API エンドポイントをこれらに向ける。

### B-1. z.ai（Zhipu AI / ChatGLM）— GLM Coding Plan

公式: https://zhipu-32152247.mintlify.app/  
対応ツール: Claude Code, Cline, OpenCode, Kilo Code 等

| プラン名 | 月額（USD） | 5時間クレジット枠 | 週間クレジット枠 |
|:---|---:|---:|---:|
| Lite | $18 | 2,000 | 10,000 |
| Pro | $72 | 12,000 | 60,000 |
| Max | $160 | 28,000 | 140,000 |

- オフピーク時間帯（月〜金 14:00〜18:00 SGT 以外）はクレジット消費 **50% 割引**
- 対応モデル: GLM-5.3, GLM-5.3-Flash 等
- **独自 CLI (ZCode Agent)** あり。Goal Mode で長時間自律タスクに対応
- API 従量課金: GLM-5.3 は $1.40/M input, $4.40/M output

### B-2. MiniMax — M Plan

公式: https://minimax.com

| プラン名 | 年払い月額換算（USD） | 月払い | トークン枠（目安） | 同時エージェント数 |
|:---|---:|---:|:---|:---|
| Plus | $18.33/月（$220/年） | 別途 | 約 1.7B tokens/月 | 3〜4 |
| Max | $45.83/月（$550/年） | 別途 | 約 5.1B tokens/月 | 4〜5 |
| Ultra | $110/月（$1,320/年） | 別途 | 約 12.5B tokens/月 | 6〜7 |

- **mcode** (`npm install -g @minimax-ai/code`): MiniMax 専用ヘッドレス CLI エージェント
- **mmx-cli** (`npm install -g mmx-cli`): Claude Code / Cursor 等から MiniMax のマルチモーダル機能（動画・音声・画像生成）を呼び出すブリッジ
- テキスト生成以外のマルチモーダル能力が強み

### B-3. DevPass — LLM Gateway

公式: https://devpass.ai（LLM Gateway）  
対応ツール: Claude Code, Cline, OpenCode 等

| プラン名 | 月額（USD） | 含まれる使用量（provider 換算） |
|:---|---:|:---|
| Lite | $29 | 約 $87 相当（3x leverage） |
| Pro | $79 | 約 $237 相当（3x leverage） |
| Max | $179 | 約 $537 相当（3x leverage） |

- 200 以上のモデルに OpenAI 互換 API でアクセス可能
- 月額料金の約 3 倍分のモデル利用料を内包（枠を使い切ると月内利用不可）
- 既存の CLI ツール（Claude Code 等）の `--api-url` をこちらに向けるだけで利用可能

---

## C. BYOK 型 OSS（自前 API キーが必要）

これらはツール自体は無料だが、モデル利用料は別途かかる。
z.ai や MiniMax の API（低コスト）と組み合わせることで低額運用が可能。

| ツール | 月額（ツール） | ヘッドレス対応 | 備考 |
|:---|---:|:---|:---|
| OpenCode（OSS） | $0 | `opencode run "<prompt>"` | BYOK。75+ プロバイダー対応 |
| OpenCode Go | $10 | 同上 | 厳選モデルへの定額アクセス付き |
| OpenCode Go Plus | $40 | 同上 | 高制限版 |
| Kilo Code（BYOK） | $0 | KiloClaw でクラウド実行可 | Roo Code の後継。BYOK は無料 |
| Kilo Pass | $19 / $49 / $199 | 同上 | クレジット制サブスク |
| Aider | $0 | `aider --message "..."` | Git ネイティブ。BYOK のみ |

---

## 全プラン価格一覧（まとめ）

| サービス | プラン名 | 月額（USD） | 完全定額か | headless | 推奨優先度 |
|:---|:---|---:|:---:|:---:|:---:|
| agy (Antigravity) | Google AI Pro | $20 | 定額 | あり | 1st |
| agy (Antigravity) | Google AI Ultra Entry | $100 | 定額 | あり | 1st |
| agy (Antigravity) | Google AI Ultra Top | $200 | 定額 | あり | 1st |
| Codex CLI | ChatGPT Plus | $20 | 定額 | あり | 2nd |
| Codex CLI | ChatGPT Pro 100 | $100 | 定額 | あり | 2nd |
| Codex CLI | ChatGPT Pro 200 | $200 | 定額 | あり | 2nd |
| Codex CLI | ChatGPT Pro 500 | $500 | 定額 | あり | 2nd |
| Claude Code | Claude Pro | $20 | 定額（枠消費大） | あり | 3rd |
| Claude Code | Claude Max 5x | $100 | 定額 | あり | 3rd |
| Claude Code | Claude Max 20x | $200 | 定額 | あり | 3rd |
| z.ai GLM Plan | Lite | $18 | 定額（クレジット制） | API 経由 | 補助（低コスト） |
| z.ai GLM Plan | Pro | $72 | 定額（クレジット制） | API 経由 | 補助 |
| z.ai GLM Plan | Max | $160 | 定額（クレジット制） | API 経由 | 補助 |
| MiniMax M Plan | Plus | $18/月（年払い） | 定額（トークン枠） | mcode CLI | 補助 |
| MiniMax M Plan | Max | $46/月（年払い） | 定額（トークン枠） | mcode CLI | 補助 |
| MiniMax M Plan | Ultra | $110/月（年払い） | 定額（トークン枠） | mcode CLI | 補助 |
| DevPass | Lite | $29 | 枠内定額（3x leverage） | API 経由 | 補助 |
| DevPass | Pro | $79 | 枠内定額（3x leverage） | API 経由 | 補助 |
| DevPass | Max | $179 | 枠内定額（3x leverage） | API 経由 | 補助 |
| OpenCode Go | Go | $10 | 定額（モデル範囲内） | あり | 補助 |
| OpenCode Go | Go Plus | $40 | 定額（モデル範囲内） | あり | 補助 |
| Kilo Pass | Starter | $19 | クレジット制 | KiloClaw | 参考 |
| Kilo Pass | Pro | $49 | クレジット制 | KiloClaw | 参考 |
| Kilo Pass | Max | $199 | クレジット制 | KiloClaw | 参考 |
| GitHub Copilot | Individual Pro | $10 | **超過で従量** | あり | 除外推奨 |
| GitHub Copilot | Business | $19 | **超過で従量** | あり | 除外推奨 |
| GitHub Copilot | Enterprise | $39 | **超過で従量** | あり | 除外推奨 |

---

## フォールバック構成案（コスト別）

### 最安構成（$38/月）
```
agy (Google AI Pro $20) → z.ai GLM Lite ($18) [Claude Code 経由]
```

### バランス構成（$40/月）
```
agy (Google AI Pro $20) → Codex CLI (ChatGPT Plus $20)
```

### フル構成（$320/月）
```
agy (Google AI Pro $20) → Codex CLI (Pro 200 $200) → Claude Max 5x ($100)
```

---

## 共通注意事項

### API キー環境変数を設定しない（定額利用時）

| サービス | 設定してはいけない環境変数 |
|:---|:---|
| Codex CLI | `OPENAI_API_KEY` |
| Claude Code | `ANTHROPIC_API_KEY` |
| agy | なし（Google OAuth で自動管理） |

### z.ai / MiniMax をフォールバックに使う場合

これらは直接 `agy` や `codex` のような統合 CLI ではないため、
OpenCode や Claude Code のバックエンド API として向ける形になる。

```
# Claude Code の API エンドポイントを z.ai に向ける例
claude -p "..." --api-url https://api.z.ai/api/paas/v4 --api-key <GLM_KEY>
```

ただし、この場合 **API キー（従量課金ではなく GLM Coding Plan のキー）** を使うことになるため
定額の枠内で動作する（枠を超えると通常 API 従量課金に切り替わる点に注意）。

---

## 関連ノート

- `note/09_headless_cli_agents_comparison.md` — 各エージェントの機能・ヘッドレス実行方法の比較
- `note/10_headless_fallback_design.md` — フォールバック実装の設計と Node.js コード例
