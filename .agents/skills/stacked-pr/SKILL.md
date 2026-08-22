---
name: stacked-pr
description: >-
  Manages Stacked Pull Requests (creating chained PRs, submitting via GitHub CLI,
  syncing/restacking upon parent changes, converting existing PRs to stacked PRs,
  and updating base branches after merge). Supports Git Worktrees and protected branch merging.
  Use when breaking large features into small dependent PRs, creating chained PRs,
  or managing stacked PR workflows.
---

# Stacked PR Skill

本スキルは、大規模な開発や段階的なタスクを小さく独立した一連のPull Request（Stacked PR / 積み上げ型PR）に分割して作成・同期・管理するための手順およびヘルパーを提供します。

---

## 1. 発動トリガー

以下のような状況でこのスキルを実行します:
- **未マージの先行PRに依存する作業・関連タスクを開始する時 (最重要)**
- ユーザーが「Stacked PRを作って」「PRを積み上げて」「親PRをベースにしたPRを作成して」と指示した時
- 大規模な機能開発やリファクタリングを複数ステップに分割してレビューを高速化したい時
- 既存の独立したPRを後から特定の親PRの上にスタック化（Base Branch変更）したい時
- 親ブランチの変更を子ブランチに追従（restack / rebase / merge）させたい時
- 親PRがマージされた後に子PRのベースブランチ（Base Branch）を `main` 等に更新したい時

---

## 2. 運用ルール & ライフサイクル

1. **ブランチ階層の定義**:
   - 基盤となる親ブランチ（例: `feature/part-1`）から子ブランチ（例: `feature/part-2`）を作成。
   - Git Worktree 環境では `--worktree` オプションを用いて `.worktrees/<child-branch>` を作成する。
2. **PR作成時のBase指定**:
   - 子PRのベースブランチには必ず「親ブランチ名」を指定（差分を子ブランチ固有のものに限定）。
3. **既存PRのスタック化**:
   - 誤って `main` 向けに作成したPRは `stack-on <pr-number> <parent-branch>` で即座に親PRへスタック化。
4. **親更新時の同期 (Restack & Merge Fallback)**:
   - 親に変更が入ったら、子ブランチに親ブランチの変更を取り込む。
   - ブランチ保護（Force push 禁止）が有効な環境では `--merge` オプションで安全にマージ同期を行う。
5. **マージ時のBase更新**:
   - 親PRが `main` にマージされたら、子PRのベースブランチを `main` に切り替える。
6. **詳細ガイド**:
   - 詳細な設計・Gitコマンド解説は [references/stacked-pr-guide.md](./references/stacked-pr-guide.md) を参照。

---

## 3. 実行手順

付属のスクリプト [scripts/stacked-pr.sh](./scripts/stacked-pr.sh) を使用して操作します。

### Step 1: 積み上げ用ブランチ（Worktree）の作成
親ブランチから新しい子ブランチ（および Worktree）を作成します。

```bash
# 通常のブランチ作成
./.agents/skills/stacked-pr/scripts/stacked-pr.sh create feature/<child-task> feature/<parent-task>

# Git Worktree で作成する場合
./.agents/skills/stacked-pr/scripts/stacked-pr.sh create feature/<child-task> feature/<parent-task> --worktree
```

### Step 2: Stacked PR の作成・提出
親ブランチをベースとして GitHub Pull Request を作成します。

```bash
./.agents/skills/stacked-pr/scripts/stacked-pr.sh submit feature/<child-task> feature/<parent-task> "feat: implement child task (Stacked on #1)"
```

### Step 3: 既存 PR のスタック化 (後から Stacked PR にする場合)
誤って `main` 向けに作成された PR を、親ブランチの上にスタック化します。

```bash
./.agents/skills/stacked-pr/scripts/stacked-pr.sh stack-on <CHILD_PR_NUMBER> feature/<parent-task>
```

### Step 4: 親ブランチ変更時の同期 (Restack)
親ブランチにコミットが追加された場合、子ブランチに追従させます。

```bash
# 通常の rebase 追従
./.agents/skills/stacked-pr/scripts/stacked-pr.sh restack feature/<child-task> feature/<parent-task>

# ブランチ保護（Force-push禁止）環境でのマージ追従
./.agents/skills/stacked-pr/scripts/stacked-pr.sh restack feature/<child-task> feature/<parent-task> --merge
```

### Step 5: 親PRマージ後のBase Branch更新
親PRが `main` にマージされた後、子PRのベースブランチを `main` に切り替えます。

```bash
./.agents/skills/stacked-pr/scripts/stacked-pr.sh update-base <CHILD_PR_NUMBER> main
```

---

## 4. 検証ステップ

作業後は必ず以下を実行して状態を確認します:
1. `gh pr view <CHILD_PR_NUMBER>` で、PRの Base Branch が期待通り（親ブランチまたはmain）に設定されているか確認。
2. GitHub 上の Files changed で、親ブランチの差分が含まれず、子ブランチ固有の差分のみが表示されていることを確認。
