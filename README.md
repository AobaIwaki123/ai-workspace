# ai-workspace

AIと協業するためのワークスペース集

## 構成

- **`AGENTS.md`**: 全体規約および進捗・セキュリティ管理ルール
- **`presets/`**: 共通プリセット集
  - [`presets/permissions.json`](presets/permissions.json): Antigravity用安全コマンド許可・禁止プリセット
- **`.agents/`**: Antigravityワークスペース設定・スキル
  - `.agents/settings.json`: プロジェクト別設定（コマンドAllowlist/Denylist）
  - `.agents/skills/auto-allow-command/`: コマンド許可プロンプト頻発時に自動でAllowlist登録を提案・実行するスキル
- **`copilot-ci/`**: GitHub Copilot を CI/CD パイプラインから呼び出す仕組みの検証・実装

---

## 権限・セキュリティ設定 (Antigravity Permissions)

本リポジトリでは、日常の開発作業で頻出する安全なコマンド（Git状態確認、リント、テスト、ビルド等）を事前定義したプリセットを用意しています。

### 1. プロジェクト設定の適用
`.agents/settings.json` に設定された Allowlist は本プロジェクト内で自動的に有効になります。

### 2. グローバル設定への反映
マシン全体（全リポジトリ共通）に反映したい場合は以下のいずれかで適用できます:
- **TUI**: チャット欄で `/permissions` を実行して設定
- **スクリプト**:
  ```bash
  ./.agents/skills/auto-allow-command/scripts/add-permission.sh "git status"
  ```

---

## スキル (Skills)

### `auto-allow-command`
- **目的**: コマンド実行時の許可プロンプトを検知し、安全性を判定した上で Allowlist（`.agents/settings.json` またはグローバル設定）への追加を提案・反映するスキル。
- **配置**: [`.agents/skills/auto-allow-command/`](.agents/skills/auto-allow-command/)