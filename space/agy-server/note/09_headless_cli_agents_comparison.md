# ヘッドレス呼び出し可能な定額AIコーディングエージェント比較

## 目的

Discord Bot 等からサブプロセスとして `agy` を呼び出す構成において、usage limit 到達時のフォールバック先を選定する。
選定基準は以下の3点:

1. **ヘッドレス実行が可能**（非インタラクティブ、スクリプトから呼び出せる）
2. **定額サブスクリプションで利用できる**（API キー従量課金ではない）
3. **コーディング用の環境セットアップが最初から整っている**（ファイル編集・実行・Git 操作等）

---

## 主要候補の比較

| ツール | ヘッドレスコマンド例 | 定額プラン | 月額目安 | 備考 |
|:---|:---|:---|:---|:---|
| **Antigravity CLI (agy)** | `agy -p "..." --output-format json` | Google One AI Premium 等 | $20〜 | 本構成のメイン |
| **Codex CLI** | `codex exec "..."` | ChatGPT Plus / Pro | $20 / $200 | `--full-auto` で承認不要化 |
| **Claude Code** | `claude -p "..." --output-format json` | Claude Pro / Max 5x / Max 20x | $20 / $100 / $200 | headless は subscription 枠を消費 |
| **GitHub Copilot CLI** | `copilot -p "..."` | Copilot Individual / Business | $10〜$19 | AI Credits 制で重量タスクは従量超過あり |
| **OpenCode** | `opencode run "..."` | OpenCode Go ($10) / Go Plus ($40) | $10〜$40 | 任意の LLM に接続可能（BYOS） |

---

## 各ツールの詳細

### Antigravity CLI (agy)

- **ヘッドレス**: `agy -p "..." --output-format json --dangerously-skip-permissions`
- **出力形式**: `json`（`{conversation_id, status, response, duration_seconds, usage}`）または `stream-json`（NDJSON）
- **サブスクリプション**: Google One AI Premium または Workspace Business/Enterprise プランに付帯
- **usage limit**: gRPC タイムアウトまたは quota エラー（`retryable: true`）で検知可能
- **特徴**: AGENTS.md 読み込み・MCP ツール・スキルシステムが統合済み

### Codex CLI（OpenAI）

- **ヘッドレス**: `codex exec "..."` / `--full-auto` / `--sandbox danger-full-access`
- **出力**: stdout にテキスト結果、stderr に進捗（JSON フラグは版依存）
- **サブスクリプション**: ChatGPT Plus（$20）または Pro（$200）で利用可能
- **usage limit**: 429 エラー → exit code 1 で検知
- **注意**: `OPENAI_API_KEY` を設定すると従量課金モードに切り替わるため、サブスクリプション利用時は未設定にする

### Claude Code（Anthropic）

- **ヘッドレス**: `claude -p "..." --allowedTools Read,Write,Bash --output-format json`
- **出力**: JSON または stream-json
- **サブスクリプション**: Pro（$20）、Max 5x（$100）、Max 20x（$200）
- **usage limit**: 2026年6月以降、`claude -p` のような自動実行は subscription の rolling window 枠を消費。Pro では頻繁にリミットに当たる可能性あり
- **注意**: `ANTHROPIC_API_KEY` を設定すると従量課金に切り替わる（サブスクリプション利用時は未設定）

### GitHub Copilot CLI

- **ヘッドレス**: `copilot -p "..."` / `--headless --port <port>` (サーバーモード)
- **サブスクリプション**: Individual（$10/月）、Business（$19/月）
- **usage limit**: AI Credits 制のため重量タスクで従量超過が発生しうる。完全定額とは言い切れない
- **認証課題**: OAuth ブラウザフローが前提で、完全ヘッドレス環境では `hosts.json` を手動転送する回避策が必要
- **評価**: 認証の手間と Credits 超過リスクから、フォールバック先としては優先度低

### OpenCode（OSS + OpenCode Go）

- **ヘッドレス**: `opencode run "..."` / `--standalone` で独立プロセス実行
- **サブスクリプション**: OpenCode Go（$10/月）、Go Plus（$40/月）。OSS 本体は無料
- **特徴**: 75 以上の LLM プロバイダーに接続可能。ChatGPT Plus や GitHub Copilot のサブスクリプションをそのまま渡せる（BYOS）
- **評価**: 任意の LLM を統一インターフェースで呼べるため、フォールバックチェーンの中間レイヤーとして有力

---

## フォールバックチェーン設計案

```
agy (Antigravity CLI)
  └─ usage limit / gRPC timeout 検知（retryable: true または quota エラー）
       └─ Codex CLI (ChatGPT Plus/Pro)
            └─ usage limit 検知（exit code 1 + 429）
                 └─ Claude Code (Claude Pro/Max)
                      └─ usage limit 検知（rate limit エラー）
                           └─ エラーメッセージを Discord に返す
```

### 検知ロジックの統一

```js
function detectUsageLimit(exitCode, stderr) {
  if (exitCode === 0) return false;
  return /quota|rate.?limit|429|usage.?limit|exhausted|credits/i.test(stderr);
}
```

### 各 CLI の呼び出し統一ラッパー（案）

```js
const AGENTS = [
  { name: 'agy',   cmd: 'agy',   args: (p) => ['-p', p, '--output-format', 'json', '--dangerously-skip-permissions'] },
  { name: 'codex', cmd: 'codex', args: (p) => ['exec', p, '--full-auto'] },
  { name: 'claude',cmd: 'claude',args: (p) => ['-p', p, '--output-format', 'json', '--allowedTools', 'Read,Write,Bash'] },
];

async function executeWithFallback(prompt) {
  for (const agent of AGENTS) {
    try {
      const result = await spawnAgent(agent.cmd, agent.args(prompt));
      return { agent: agent.name, result };
    } catch (err) {
      if (detectUsageLimit(err.exitCode, err.stderr)) {
        console.warn(`[${agent.name}] usage limit, trying next agent...`);
        continue;
      }
      throw err; // usage limit 以外のエラーは上位に投げる
    }
  }
  throw new Error('All agents exhausted their usage limits.');
}
```

---

## 選定推奨

| 優先度 | ツール | 理由 |
|:---:|:---|:---|
| 1st | **agy (Antigravity CLI)** | 本構成のメイン。AGENTS.md・MCP・スキル統合が最も充実 |
| 2nd | **Codex CLI** | ChatGPT Plus/Pro に含まれ、exit code で usage limit 検知が容易 |
| 3rd | **Claude Code** | Pro/Max プランで定額。JSON 出力・ツール制限フラグが整備済み |
| 参考 | **OpenCode** | 中間レイヤーとして複数 LLM を束ねたい場合に有力 |
| 除外 | **GitHub Copilot CLI** | AI Credits 超過リスクと認証の手間から優先度低 |
