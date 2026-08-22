# このリポジトリについて

AIと協業するためのワークスペース

# このリポジトリの使い方（Workspace / Space 運用）

本リポジトリでは、テーマや課題ごとに自己完結した作業領域（**Space / Workspace**）をリポジトリ直下に切り、調査・議論・意思決定・自動化コードを蓄積します。

### 1. Space（Workspace）の作成と基本構成
新しいテーマに取り組む際は、作成スクリプトを用いて標準レイアウトを自動生成します。

```bash
./scripts/create-workspace.sh <workspace-name> "<workspace-title>"
```

生成される標準ディレクトリ構造:
```
<workspace-name>/
├── AGENTS.md             # そのテーマ固有の規約・方針・スコープ
├── discussion.md         # 議論の方向性、要件定義、ロードマップ、進捗管理
├── note/                 # 調査・学習・技術メモ（01_xxx.md 形式で蓄積）
├── adr/                  # 確定した方針・アーキテクチャ選定 (0001-xxx.md)
└── scripts/              # そのテーマ専用のスクリプト・ツール・自動化コード
```

### 2. Space 内の協業フロー
1. **起票 (Scaffold)**: `create-workspace.sh` で Space を作成。
2. **要件・進捗管理 (`discussion.md`)**: 目的、ロードマップ、ToDo、議論の経緯を記録・更新。
3. **規約定義 (`AGENTS.md`)**: そのテーマ特有の制約、API利用規約、セキュリティ留意事項を明記。
4. **知見の蓄積 (`note/`)**: 調査した技術仕様や検証結果を `note/` に連番付きでドキュメント化。
5. **意思決定の記録 (`adr/`)**: 設計方針や採用技術の選定理由を `adr/` に記録。
6. **スクリプト化 (`scripts/`)**: 再現可能な実行コードやツールを `scripts/` に整備。汎用性の高いものは `.agents/skills/` への昇格を検討。

# Git Worktree 開発運用ルール

- 本リポジトリでのタスク作業は、ブランチの競合を防ぎ並行作業を安全に行うため、原則として **Git Worktree**（`.worktrees/<branch-name>`）を作成して行います。
- **ルート作業領域（`main` ブランチ）での直接作業・コミットは禁止**します。すべての変更はワークツリーでブランチを切り、Pull Request（PR）を作成してマージします。
- Worktree 間で共有したいファイル（環境変数 `.env`、共通データ等）は、ルートの **`.shared/`** ディレクトリ（`.gitignore` 対象）に配置し、シンボリックリンク等で参照します。
- 操作には `git-worktree` スキル（`./.agents/skills/git-worktree/scripts/worktree.sh`）を活用します。

# 人間に対する信頼性・透明性担保 (Human-Centric Transparency)

- UI、API ツール、ダッシュボード、計測スクリプトを実装する際は、ブラックボックスなモック感を排除し、生データ・実ログ・パラメータ完全同期を提供する **`.agents/rules/ui-transparency.md`** の原則を必ず遵守します。
- 画面操作が本物のバックエンドに届いていることを人間が独立して検証できるよう、リアルタイムログ監視コマンド（`kubectl logs -f` 等）を必ず提示します。

# システム設計とOSSロードマップレビュー (System Design Review)

- 新規プロジェクト（OSS、CLI、Webサービス等）の立ち上げやロードマップ策定を求められた際は、オーバーエンジニアリングの排除、可観測性（Observability）の担保、外部依存への防衛策などを定めた **`.agents/rules/system-design-review.md`** に基づいて、ベテランエンジニアとしてのレビューを実施します。

# 権限・セキュリティ設定 (Permissions)

- プロジェクト共通の許可・禁止ルールは `.agents/settings.json` または `presets/permissions.json` に定義します。
- 安全なコマンド（Git状態確認、リント、テスト、ビルド等）はAllowlistとして登録し、破壊的なコマンド（`rm -rf`, `git push --force`等）はDenylistに指定します。

# AGENTS.mdの修正提案

ai-workspace全体に関する規約やworkspace単位の規約について、不足がある場合は、AGENTS.mdに修正提案を行うことができます。

# ドキュメント・Mermaid 構文の Double-Check 規約 (Document & Mermaid Integrity)

- **Mermaid 構文エラーの撲滅**:
  - Mermaid 図を作成・更新する際は、ノードラベル、エッジテキスト（`-->|"..."|`）、SequenceDiagram の participant 名・Note 本文に含まれる特殊文字（`{`, `}`, `(`, `)`, `#`, `/`, `.`, `-` 等）を **必ずダブルクォート (`"..."`) でエスケープ・クォート** します。
  - 作成・編集後は、GitHub Markdown レンダラーで構文エラー（Parse error）が発生しないか **必ずセルフレビュー（Double-Check）** を実施してから PR を起票します。

# Skill作成・活用・レビュー

- 本リポジトリでの作業の中で、長めのプロンプトが渡されたり修正指示が何度も来た場合は、作業完了後にSkillとして `.agents/skills/<skill-name>/` にまとめることを提案します。
- スキルの作成・編集時は、`.agents/rules/skill-authoring.md` に基づきベストプラクティス（Frontmatter、Progressive Disclosure、スクリプト化、検証手順等）のセルフレビューを自動実施します。
- スキルの静的解析・品質チェックには `review-skill` スキル（または `./.agents/skills/review-skill/scripts/validate-skill.sh`）を活用します。
- コマンド許可プロンプトの頻発時は `auto-allow-command` スキルを活用してAllowlistの更新を提案します。