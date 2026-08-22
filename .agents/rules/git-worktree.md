# Git Worktree Standard Workflow Rule

本リポジトリにおける開発作業は、ブランチの競合を防ぎ、安全に並行開発を行うため、原則として **Git Worktree** を使用して行います。

---

## 1. ワークツリー運用方針

1. **作業ディレクトリの配置**:
   - 新規タスク・ブランチでの作業は、すべて **`.worktrees/<branch-name>`** 配下で行います。
   - ルートの作業ツリーで直接作業を進めず、タスク開始時に Worktree を作成してください。

2. **Worktree 間でのファイル共有**:
   - 環境変数ファイル（`.env`）、ローカルキャッシュ、共通設定など、Worktree 間で共有したいファイルは **`.shared/`** ディレクトリに配置します。
   - 各 Worktree からはシンボリックリンクまたは相対パスで `.shared/` のファイルを参照します。

3. **ツールの活用**:
   - Worktree の作成・削除・ファイル同期には、スキル付属のスクリプト `./.agents/skills/git-worktree/scripts/worktree.sh` を活用してください。

---

## 2. タスク完了後の片付け

- PR 作成・マージ完了後は、不要になった Worktree を `git worktree remove`（または `./.agents/skills/git-worktree/scripts/worktree.sh remove <branch>`）で削除し、リポジトリを整理してください。
