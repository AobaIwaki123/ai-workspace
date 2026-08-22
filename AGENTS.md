# このリポジトリについて

AIと協業するためのワークスペース

# このリポジトリの使い方

1. テーマに沿ってworkspaceを作成する
2. AGENTS.mdとdiscussion.mdで進捗管理を行う
   1. AGENTS.mdでは、そのworkspaceにおける規約を定義する
   2. discussion.mdでは、そのworkspaceにおける議論の方向性や進捗を記録する
3. ある程度まとまった調査ができたらnote/にまとめる
4. 洗練されたnoteはadr/にまとめる

# 権限・セキュリティ設定 (Permissions)

- プロジェクト共通の許可・禁止ルールは `.agents/settings.json` または `presets/permissions.json` に定義します。
- 安全なコマンド（Git状態確認、リント、テスト、ビルド等）はAllowlistとして登録し、破壊的なコマンド（`rm -rf`, `git push --force`等）はDenylistに指定します。

# AGENTS.mdの修正提案

ai-workspace全体に関する規約やworkspace単位の規約について、不足がある場合は、AGENTS.mdに修正提案を行うことができます。

# Skill作成・活用

- 本リポジトリでの作業の中で、長めのプロンプトが渡されたり修正指示が何度も来た場合は、作業完了後にSkillとして `.agents/skills/<skill-name>/` にまとめることを提案します。
- コマンド許可プロンプトの頻発時は `auto-allow-command` スキルを活用してAllowlistの更新を提案します。