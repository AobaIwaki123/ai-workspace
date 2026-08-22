---
name: git-worktree
description: >-
  Manages Git Worktrees for isolated task execution. Guides creating, switching, listing,
  and removing worktrees, and syncing shared files across worktrees via a dedicated shared directory.
  Use when starting a new task, managing parallel branches in worktrees, or cleaning up completed worktrees.
---

# Git Worktree Skill

本スキルは、Git Worktree を用いて複数のタスクやブランチを独立したディレクトリ環境（`.worktrees/`）で安全かつ並行して作業するための手順およびヘルパーを提供します。

## 1. 発動トリガー

以下のような状況でこのスキルを実行します:
- ユーザーが「新しい作業をworktreeで始めて」「worktreeを作って」「ワークツリーを切り替えて/削除して」と指示した時
- 新規機能開発やバグ修正タスクを開始する際（ワークスペース基本方針としてWorktreeを推奨）
- 複数のブランチ間で設定ファイルや `.env` を共有したい時

---

## 2. ワークツリー運用ルール

1. **作業ディレクトリ**:
   - 新規タスクの Worktree はすべてリポジトリ直下の **`.worktrees/<branch-name>`** に作成します。
2. **共有ファイルの配置**:
   - Worktree 間で共有したいファイル（`.env`、共通データ等）は **`.shared/`** に配置します。
3. **詳細ガイド**:
   - コマンドの詳細仕様や注意点は [references/worktree-guide.md](./references/worktree-guide.md) を参照してください。

---

## 3. 実行手順

### Step 1: ワークツリーの作成
付属のスクリプト [scripts/worktree.sh](./scripts/worktree.sh) を使用して、指定ブランチの Worktree を作成します。

```bash
# 新規ブランチでWorktreeを作成（mainから分岐し、.shared/ のファイルも自動リンク）
./.agents/skills/git-worktree/scripts/worktree.sh create feature/<task-name> main
```

### Step 2: 共有ファイルの同期（必要に応じて）
`.shared/` 配下に新しい共有ファイルを追加した場合、以下のコマンドで対象 Worktree にシンボリックリンクを反映します。

```bash
./.agents/skills/git-worktree/scripts/worktree.sh sync-shared .worktrees/feature/<task-name>
```

### Step 3: ワークツリー一覧・状態確認
現在の Worktree 一覧を確認します。

```bash
./.agents/skills/git-worktree/scripts/worktree.sh list
```

### Step 4: タスク完了後のクリーンアップ
PR がマージされた後、不要になった Worktree を安全に削除します。

```bash
./.agents/skills/git-worktree/scripts/worktree.sh remove feature/<task-name>
```

---

## 4. 検証ステップ

作業後は必ず以下を実行して状態を確認します:
1. `git worktree list` で対象の Worktree が期待通り作成・削除されていることを確認。
2. 必要に応じて `.shared/` のファイルへのシンボリックリンクが正しく機能しているか確認。
