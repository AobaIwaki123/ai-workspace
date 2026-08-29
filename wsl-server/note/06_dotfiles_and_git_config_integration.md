# Dotfiles & Git Config 統合管理方式の検討 (note/06)

## 1. 概要

`git config` やシェル設定（`.bashrc`, `.zshrc`, `.tmux.conf`）などの環境設定を、WSL サーバー上で安全かつメンテナンス性高く同期・管理するための統合パターンの比較とベストプラクティスです。

---

## 2. 統合パターンの比較

| パターン | 方式 | メリット | デメリット / 留意点 | おすすめユースケース |
| :--- | :--- | :--- | :--- | :--- |
| **A. Git Include 方式** | `~/.gitconfig` に `[include] path = ...` を追加 | マシン固有の `user.email` や署名設定を残しつつ、共通エイリアス・差分設定を Git 管理できる | Git Config に特化した方式（他ファイルは別途対応が必要） | **最も安全・おすすめ** |
| **B. Symlink 方式** | リポジトリ内のファイルを `ln -sf` でホームにリンク | すべての設定ファイル（Git, Zsh, Tmux 等）を統一的に管理可能 | 既存の設定ファイルが上書きされるリスク（バックアップ必須） | **ドットファイル全般を一括管理したい場合** |
| **C. 既存 dotfiles 連携** | 既存の dotfiles リポジトリを `git clone` して呼出 | 既存の資産をそのまま活用でき、WSL 以外（Mac 等）と完全共通化 | リポジトリが 2 つに分かれる | **すでに完成した dotfiles リポジトリがある場合** |

---

## 3. 推奨設計: Git Include + テンプレート構成

Git の設定は「全マシン共通の設定（エイリアス、カラー、core、delta）」と「マシン固有の設定（メールアドレス、署名鍵）」が存在するため、**Git Include 方式** が最もトラブルが起きません。

```ini
# ~/.gitconfig (マシン固有)
[user]
    name = Your Name
    email = your.email@example.com

# 共通設定を ai-workspace からインクルード
[include]
    path = ~/ai-workspace/wsl-server/dotfiles/.gitconfig_common
```
