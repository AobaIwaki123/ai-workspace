# Git Worktree Standard Workflow Rule

本リポジトリ（`ai-workspace`）は、知見・調査・ドキュメントの蓄積が中心であり、重厚なコードビルドや依存環境の競合が発生しにくいため、**Git Worktree の利用は必須ではなく任意（オプショナル）**です。

通常作業時はリポジトリ直下でトピックブランチを作成（`git switch -c <branch>`）して作業を進めて構いません。複数の並行タスクを同一リポジトリで同時に進行させたい場合や、独立したディレクトリで環境分離を行いたい場合に限り、本 Worktree ワークフローを活用します。

---

## 1. ワークツリー運用方針（利用時）

1. **作業ディレクトリの配置**:
   - Worktree を利用する場合、新規タスク・ブランチでの作業はすべて **`.worktrees/<branch-name>`** 配下で行います。

2. **Worktree 間でのファイル共有**:
   - 環境変数ファイル（`.env`）、ローカルキャッシュ、共通設定など、Worktree 間で共有したいファイルは **`.shared/`** ディレクトリに配置します。
   - 各 Worktree からはシンボリックリンクまたは相対パスで `.shared/` のファイルを参照します。

3. **ツールの活用**:
   - Worktree の作成・削除・ファイル同期には、スキル付属のスクリプト `./.agents/skills/git-worktree/scripts/worktree.sh` を活用してください。

---

## 2. タスク完了後の片付け

- PR 作成・マージ完了後は、不要になった Worktree を `git worktree remove`（または `./.agents/skills/git-worktree/scripts/worktree.sh remove <branch>`）で削除し、リポジトリを整理してください。
