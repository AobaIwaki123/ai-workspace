# ヘッドレス AI エージェントのフォールバック実装設計

## 目的

Discord Bot 等から AI コーディングエージェントをサブプロセスとして呼び出す構成において、
usage limit に到達した際に次の候補エージェントへ自動的にフォールバックする仕組みを実装する。

---

## フォールバックチェーン

```
agy (Antigravity CLI)            ← メイン
  └─ usage limit / quota 検知
       └─ Codex CLI              ← 1st フォールバック
            └─ usage limit 検知
                 └─ Claude Code  ← 2nd フォールバック
                      └─ usage limit 検知
                           └─ Discord に「全エージェント制限中」を返す
```

### 各エージェントのヘッドレスコマンド

| エージェント | コマンド | 非インタラクティブフラグ |
|:---|:---|:---|
| agy | `agy -p "<prompt>" --output-format json` | `--dangerously-skip-permissions` |
| Codex CLI | `codex exec "<prompt>"` | `--full-auto` |
| Claude Code | `claude -p "<prompt>" --output-format json` | `--allowedTools Read,Write,Bash` |

---

## usage limit の検知方法

### agy（Antigravity CLI）

- **exit code**: 非ゼロ（エラー時）
- **stderr パターン**: `quota`, `rate limit`, `429`, `retryable: true`
- **実例**:
  ```
  AGY_ERROR: {"short_error":"...","retryable":true,"error_code":2}
  ```

### Codex CLI

- **exit code**: `1`（429 到達後のリトライ消尽時）
- **stderr パターン**: `429`, `rate limit`, `quota exceeded`

### Claude Code

- **exit code**: 非ゼロ
- **stderr パターン**: `rate limit`, `overload`, `credits`, `usage limit`

### 統一検知関数

```js
function isUsageLimitError(exitCode, stderr = '') {
  if (exitCode === 0) return false;
  return /quota|rate.?limit|429|usage.?limit|exhausted|credits|overload|retryable.*true/i.test(stderr);
}
```

---

## 実装例（Node.js / discord.js v14）

### エージェント定義

```js
// space/discord/bot/agents.js

const AGENTS = [
  {
    name: 'agy',
    cmd: 'agy',
    buildArgs: (prompt, cwd) => [
      '-p', prompt,
      '--output-format', 'json',
      '--dangerously-skip-permissions',
    ],
    parseOutput: (stdout) => {
      const data = JSON.parse(stdout);
      return data.response ?? data.result ?? stdout;
    },
  },
  {
    name: 'codex',
    cmd: 'codex',
    buildArgs: (prompt) => ['exec', prompt, '--full-auto'],
    parseOutput: (stdout) => stdout.trim(),
  },
  {
    name: 'claude',
    cmd: 'claude',
    buildArgs: (prompt) => [
      '-p', prompt,
      '--output-format', 'json',
      '--allowedTools', 'Read,Write,Bash',
    ],
    parseOutput: (stdout) => {
      const data = JSON.parse(stdout);
      return data.result ?? stdout;
    },
  },
];
```

### フォールバック実行関数

```js
// space/discord/bot/index.js（抜粋）

const { spawn } = require('child_process');

function spawnAgent(cmd, args, cwd, timeoutMs = 120_000) {
  return new Promise((resolve, reject) => {
    const proc = spawn(cmd, args, { cwd, env: process.env });
    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (d) => { stdout += d.toString(); });
    proc.stderr.on('data', (d) => { stderr += d.toString(); });

    const timer = setTimeout(() => {
      proc.kill();
      reject({ exitCode: 1, stderr: 'timeout', stdout });
    }, timeoutMs);

    proc.on('close', (code) => {
      clearTimeout(timer);
      if (code === 0) resolve(stdout);
      else reject({ exitCode: code, stderr, stdout });
    });
  });
}

async function executeWithFallback(prompt, cwd) {
  for (const agent of AGENTS) {
    try {
      console.log(`[agent] trying ${agent.name}...`);
      const stdout = await spawnAgent(agent.cmd, agent.buildArgs(prompt), cwd);
      const response = agent.parseOutput(stdout);
      console.log(`[agent] ${agent.name} succeeded`);
      return { agent: agent.name, response };
    } catch (err) {
      if (isUsageLimitError(err.exitCode, err.stderr)) {
        console.warn(`[agent] ${agent.name} hit usage limit, trying next...`);
        continue;
      }
      // usage limit 以外のエラーは上位に伝播
      throw new Error(`${agent.name} failed: ${err.stderr ?? err.message}`);
    }
  }
  throw new Error('すべてのエージェントが usage limit に達しています。しばらく待ってから再試行してください。');
}
```

### Discord スラッシュコマンドへの組み込み

```js
client.on(Events.InteractionCreate, async (interaction) => {
  if (!interaction.isChatInputCommand()) return;
  if (interaction.commandName !== 'agy') return;

  await interaction.deferReply();

  const prompt = interaction.options.getString('prompt', true);
  const cwd = '/Users/aobaiwaki/ai-workspace';

  try {
    const { agent, response } = await executeWithFallback(wrapPromptForDiscord(prompt), cwd);
    const prefix = agent !== 'agy' ? `[${agent} にフォールバック]\n` : '';
    await sendChunked(interaction, prefix + response);
  } catch (err) {
    await interaction.editReply(`エラー: ${err.message}`);
  }
});
```

---

## 注意事項

### サブスクリプション利用時の API キー設定

定額サブスクリプションでヘッドレス呼び出しを行う場合、**API キー系の環境変数を設定してはならない**。
設定すると従量課金モードに切り替わる。

| エージェント | 設定しては**いけない**環境変数 |
|:---|:---|
| Codex CLI | `OPENAI_API_KEY` |
| Claude Code | `ANTHROPIC_API_KEY` |
| agy | （Google 認証は別管理、API キーなし） |

### cwd の固定

各エージェントの `cwd` を同一リポジトリルートに固定することで、
AGENTS.md やプロジェクトのコンテキストを引き継がせることができる。

### 並行実行の競合

複数リクエストが同時にフォールバックチェーンを実行すると、
同じエージェントが同時に起動し、ファイル編集の競合が発生しうる。
将来的には FIFO キューまたは Mutex による直列化を検討する。

参考: `note/07_concurrency_and_multiple_messages.md`

---

## 関連ノート

- `note/09_headless_cli_agents_comparison.md` — 各エージェントの機能・定額プラン比較
- `note/11_ai_service_pricing.md` — 各 AI サービスの価格・プラン詳細
- `note/07_concurrency_and_multiple_messages.md` — 並行実行時の競合リスク
- `note/05_network_timeout_and_retry_design.md` — タイムアウトとリトライ設計
