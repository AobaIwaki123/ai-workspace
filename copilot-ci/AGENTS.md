# copilot-ci workspace 規約

## 目的
GitHub CopilotをCI/CDパイプラインから呼び出す仕組みの検証・実装

## スコープ
- GitHub Actions ワークフローでの `gh copilot` 活用
- PR自動レビュー、説明生成、コメント応答
- 再利用可能なCLIヘルパースクリプト

## 開発フロー
1. `discussion.md` で設計・検討を記録
2. 実装は `copilot-ci/` 配下で行う
3. 検証結果は `note/` にまとめる
4. 確定した設計判断は `adr/` に記録

## 命名規則
- ワークフロー: `copilot-<目的>.yml`
- スクリプト: `copilot-ci.sh` (kebab-case)
- note: `YYYYMMDD-<トピック>.md`
- adr: `NNNN-<タイトル>.md` (ADR番号順)

## Git運用
- mainブランチ保護: PR必須、レビュー1名以上
- コミット: Conventional Commits準拠
- タグ: `v<major>.<minor>.<patch>` でリリース