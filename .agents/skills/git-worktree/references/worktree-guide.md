# Git Worktree Comprehensive Guide

Git Worktree を利用すると、単一の Git リポジトリから複数のブランチを異なるディレクトリに同時にチェックアウトして並行作業を行うことができます。

---

## 1. 基本コマンドリファレンス

### A. ワークツリーの追加（作成）
```bash
# 新しいブランチを作成してワークツリーに追加
git worktree add -b <new-branch> .worktrees/<branch-name> <base-branch>

# 既存のリモートブランチをチェックアウトしてワークツリーに追加
git worktree add .worktrees/<branch-name> <existing-branch>
```

### B. ワークツリーの一覧表示
```bash
git worktree list
# 出力例:
# /path/to/ai-workspace                          7887b5e [main]
# /path/to/ai-workspace/.worktrees/feature-x     a1b2c3d [feature-x]
```

### C. ワークツリーの削除・クリーンアップ
```bash
# ワークツリーの安全な削除
git worktree remove .worktrees/<branch-name>

# 未コミットの変更があるワークツリーの強制削除（注意）
git worktree remove --force .worktrees/<branch-name>

# 削除済みディレクトリの管理情報の整理（プルーニング）
git worktree prune
```

---

## 2. 共有ディレクトリ（`.shared/`）の運用

Git Worktree 間で環境変数（`.env`）、キャッシュ、ビルド設定ファイルなどを共有するために、リポジトリルートに `.shared/` を用意します（`.gitignore` 対象）。

### シンボリックリンクによる共有
```bash
# 例: .shared/.env を作成
echo "API_SECRET=xyz" > .shared/.env

# ワークツリー側でシンボリックリンクを作成
ln -sf ../../.shared/.env .worktrees/<branch-name>/.env
```

---

## 3. 注意点・トラブルシューティング

1. **同一ブランチの複数チェックアウト禁止**:
   - Git では同一ブランチを複数のワークツリーで同時にチェックアウトすることはできません。ブランチを切り替えるか、新しいブランチ名を作成してください。
2. **ワークツリー削除時の注意**:
   - 手動でディレクトリを `rm -rf` した場合は、`git worktree prune` を実行してメタデータを同期してください。
3. **IDE / エディタでの利用**:
   - `antigravity .worktrees/<branch-name>` または `code .worktrees/<branch-name>` で独立したウィンドウとして作業環境を開けます。
