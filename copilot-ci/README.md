# GitHub Copilot CI Integration Examples

このリポジトリには、GitHub ActionsからGitHub Copilotを呼び出す様々な例が含まれています。

## ワークフロー (ルート `.github/workflows/`)

### 1. 基本的なCopilot CI (`.github/workflows/copilot-ci.yml`)

- PR作成時の自動コードレビュー
- 手動実行でのカスタムプロンプト実行

### 2. PR アシスタント (`.github/workflows/copilot-pr-assistant.yml`)

- PR説明の自動生成
- `/copilot <prompt>` コメントへの自動応答
- 変更ファイルごとの改善提案

## ヘルパースクリプト (ルート `scripts/copilot-ci.sh`)

ローカルやCI内で簡単にCopilotを呼び出せるCLIツール。

### 使い方

```bash
# 一般的な質問
./scripts/copilot-ci.sh suggest "How to optimize Docker builds?"

# ファイルの説明
./scripts/copilot-ci.sh explain src/main.py

# コードレビュー
./scripts/copilot-ci.sh review src/api.ts --pr 42

# テスト生成
./scripts/copilot-ci.sh test src/utils.ts

# バグ修正提案
./scripts/copilot-ci.sh fix src/buggy.py

# コミットメッセージ生成
./scripts/copilot-ci.sh commit

# PR説明生成
./scripts/copilot-ci.sh pr-description origin/main
```

## セットアップ

1. GitHub CLI (`gh`) をインストール
2. Copilot拡張をインストール:
   ```bash
   gh extension install github/gh-copilot
   ```
3. 認証:
   ```bash
   gh auth login
   ```

## GitHub Actions での使用

ワークフロー内で直接使用:

```yaml
- name: Run Copilot
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    gh extension install github/gh-copilot
    gh copilot suggest -t shell "Review this code" --repo ${{ github.repository }} --pr ${{ github.event.pull_request.number }}
```

またはヘルパースクリプトを使用:

```yaml
- name: Run Copilot via script
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    ./scripts/copilot-ci.sh review src/main.py --repo ${{ github.repository }} --pr ${{ github.event.pull_request.number }}
```

## 必要な権限

ワークフローで以下の権限が必要:

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
```

## 注意事項

- `gh copilot` は GitHub Copilot サブスクリプションが必要
- API制限あり（分あたりのリクエスト数）
- PRコメントへの応答は `issue_comment` イベントでトリガー

## Workspace構成

詳細な規約・設計は [`copilot-ci/`](copilot-ci/) を参照