## 概要

GitHub CopilotをCI/CDパイプラインから呼び出す仕組みの検証・実装用workspaceを追加

## 変更内容

### 新規ファイル
- `.github/workflows/copilot-ci.yml` - 基本的なCopilot CI（PRレビュー、手動実行）
- `.github/workflows/copilot-pr-assistant.yml` - PRアシスタント（説明生成、コメント応答、改善提案）
- `scripts/copilot-ci.sh` - 再利用可能なCLIヘルパースクリプト
- `copilot-ci/AGENTS.md` - workspace規約
- `copilot-ci/README.md` - 詳細ドキュメント

### 更新
- `README.md` - workspace一覧を管理するルートREADME

## 機能

1. **自動コードレビュー** - PR作成時にCopilotがレビュー
2. **PR説明自動生成** - 変更内容から説明を生成
3. **コメント応答** - `/copilot <prompt>` でCopilotに質問可能
4. **ファイル別改善提案** - 変更ファイルごとにレビュー
5. **CLIツール** - ローカル/CI共通で利用可能

## 使い方

```bash
# ローカルでテスト
gh extension install github/gh-copilot
gh auth login
./scripts/copilot-ci.sh suggest "最適化の提案をして"

# GitHub Actionsで自動実行（PR作成時に自動で動作）
```

## テスト

- [ ] PR作成時にcopilot-ci.ymlが動作すること
- [ ] 手動ワークフロー実行でカスタムプロンプトが動くこと
- [ ] PRコメント `/copilot` への応答が動くこと
- [ ] CLIツール各コマンドが動作すること