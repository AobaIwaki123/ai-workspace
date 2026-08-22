# ai-workspace

AIと協業するためのワークスペース集

## 構成

- **`AGENTS.md`**: 全体規約および進捗・セキュリティ管理ルール
- **`presets/`**: 共通プリセット集
  - [`presets/permissions.json`](presets/permissions.json): Antigravity用安全コマンド許可・禁止プリセット
- **`.agents/`**: Antigravityワークスペース設定・ルール・スキル
  - `.agents/settings.json`: プロジェクト別設定（コマンドAllowlist/Denylist）
  - `.agents/rules/git-worktree.md`: Git Worktree 開発ワークフロールール
  - `.agents/rules/skill-authoring.md`: スキル作成・編集時の自動レビュー規約
  - `.agents/skills/git-worktree/`: Git Worktree の作成・削除・ファイル共有管理スキル
  - `.agents/skills/auto-allow-command/`: コマンド許可プロンプト頻発時に自動でAllowlist登録を提案・実行するスキル
  - `.agents/skills/review-skill/`: スキルがベストプラクティスに準拠しているか静的検証・レビューするスキル
- **`.worktrees/`**: 各タスク用 Git Worktree の配置領域（`.gitignore` 対象）
- **`.shared/`**: Worktree 間で共有するファイル（環境変数 `.env`、キャッシュ等）の配置領域（`.gitignore` 対象）
- **`copilot-ci/`**: GitHub Copilot を CI/CD パイプラインから呼び出す仕組みの検証・実装

---

## Git Worktree 開発運用

本リポジトリでは原則として **Git Worktree** を用いて並行作業を行います。

```bash
# 新規タスク用Worktreeを作成
./.agents/skills/git-worktree/scripts/worktree.sh create feature/<task-name> main

# Worktree一覧を確認
./.agents/skills/git-worktree/scripts/worktree.sh list

# タスク完了後にWorktreeを削除
./.agents/skills/git-worktree/scripts/worktree.sh remove feature/<task-name>
```

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

## ルールとスキル (Rules & Skills)

### 1. スキル: `git-worktree`
- **目的**: 独立した作業ツリー（`.worktrees/<branch-name>`）の作成、`.shared/` 内ファイルの自動シンボリックリンク同期、クリーンアップ。
- **配置**: [`.agents/skills/git-worktree/`](.agents/skills/git-worktree/)

### 2. ルール: `skill-authoring`
- **概要**: `.agents/skills/` 配下のスキルファイル作成・編集時に自動適用される品質基準・セルフレビューチェックリスト。
- **配置**: [`.agents/rules/skill-authoring.md`](.agents/rules/skill-authoring.md)

### 3. スキル: `review-skill`
- **目的**: スキルの構成・Frontmatter・スクリプト権限・Progressive Disclosureを静的解析し、ベストプラクティス準拠を検証・レビューするスキル。
- **配置**: [`.agents/skills/review-skill/`](.agents/skills/review-skill/)
- **検証コマンド**:
  ```bash
  ./.agents/skills/review-skill/scripts/validate-skill.sh .agents/skills/<skill-name>
  ```

### 4. スキル: `auto-allow-command`
- **目的**: コマンド実行時の許可プロンプトを検知し、安全性を判定した上で Allowlist（`.agents/settings.json` またはグローバル設定）への追加を提案・反映するスキル。
- **配置**: [`.agents/skills/auto-allow-command/`](.agents/skills/auto-allow-command/)

### 5. スキル: `stacked-pr`
- **目的**: 巨大な変更を小さく独立したPRに分割・連鎖して作成（Stacked PR）、親変更時の追従（restack）、Base Branch更新を安全に管理するスキル。
- **配置**: [`.agents/skills/stacked-pr/`](.agents/skills/stacked-pr/)