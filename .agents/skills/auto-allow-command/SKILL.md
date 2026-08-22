---
name: auto-allow-command
description: >-
  Detects when the user encounters command permission prompts, expresses frustration with command approval requests,
  or asks to allow specific terminal commands. Evaluates the command's safety and automatically suggests or applies
  permission allowlist entries to reduce confirmation friction.
---

# Auto Allow Command Skill

本スキルは、ユーザーがターミナルコマンドの実行許可プロンプトに煩わしさを感じている場合や、特定の安全なコマンドを自動許可（Allowlist登録）したい場合に発動します。

## 1. 発動トリガー

以下のような状況でこのスキルを実行します:
- ユーザーが「コマンドの許可が面倒」「このコマンドを常に許可して」「許可プロンプトを出さないで」と発言した時
- 頻繁に実行する安全なコマンド（`git status`, `npm test`, `ls` 等）で確認が発生した時
- コマンド実行時の権限設定を最適化したい時

---

## 2. 安全性評価（Safety Check）

コマンドを Allowlist に追加する前に、必ず [references/safe-patterns.md](./references/safe-patterns.md) を参照して安全性を判定します。

| 判定区分 | コマンド例 | 推奨アクション |
| :--- | :--- | :--- |
| **安全（Allow推奨）** | `git status`, `git diff`, `npm test`, `ls`, `grep`, `cat`, `gh pr view` | Allowlistへの追加を提案・即時反映 |
| **条件付き安全（パターン指定）** | `npm run lint.*`, `npm run build.*`, `git checkout .*` | 正規表現やプレフィックスでAllowlistに追加 |
| **危険・破壊的（Deny / Ask維持）** | `rm -rf *`, `git push --force`, `git reset --hard`, `sudo` | **Allowlistへの追加を拒否/警告**し、DenyまたはAskの維持を推奨 |

---

## 3. 実行手順

### Step 1: 追加するルール形式の特定
コマンドに応じた `action(target)` 形式を作成します。
- 単一コマンド: `command(git status)`
- サブコマンド群: `command(git diff .*)` または `command(git)`
- 引数付きビルド: `command(npm run lint.*)`

### Step 2: 適用スコープの選択
- **プロジェクト単位（このリポジトリのみ）**: `.agents/settings.json` に追加（チームで共有可能）
- **グローバル単位（全リポジトリ共通）**: `~/.gemini/antigravity-cli/settings.json` に追加

### Step 3: 自動追記スクリプトの実行
付属のヘルパースクリプト [scripts/add-permission.sh](./scripts/add-permission.sh) を使用して設定ファイルを更新します。

```bash
# プロジェクト設定に追加する場合
./.agents/skills/auto-allow-command/scripts/add-permission.sh -w "<コマンドパターン>"

# グローバル設定に追加する場合
./.agents/skills/auto-allow-command/scripts/add-permission.sh "<コマンドパターン>"
```

### Step 4: ユーザーへの報告と代替手順の案内
更新完了後、以下をユーザーに簡潔に報告します:
1. 追加された許可ルール（例: `command(git status)`）
2. 反映先ファイル（`.agents/settings.json` または `~/.gemini/antigravity-cli/settings.json`）
3. 対話的UIで確認・編集したい場合の案内（`/permissions` コマンド）
