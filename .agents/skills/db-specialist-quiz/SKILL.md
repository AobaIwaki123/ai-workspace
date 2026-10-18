---
name: db-specialist-quiz
description: Conducts multiple-choice quizzes and knowledge checks for the IPA Database Specialist Examination (DB). Use this skill when the user asks to practice database specialist exam questions, test their database fundamentals knowledge (relational algebra, normalization, ACID, recovery, indexes, SQL), or run an interactive database quiz.
---

# Database Specialist Quiz Skill

IPA高度情報処理技術者「データベーススペシャリスト試験（DB）」の午前IIおよび基礎理論に関する四肢択一クイズを出題・採点・解説するスキルです。

## クイズの実行方法

### 1. ターミナル（CLI）での直接実行

`spec` コマンドは PATH（`~/.local/bin/spec`）が通っているため、ターミナル上の任意のディレクトリから直接実行できます（選択肢は常時ランダムシャッフル）。

```bash
# デフォルト（ランダム5問出題・回答履歴を自動保存）
spec

# 学習統計・午前II予想得点・弱点分野のレポートを表示
spec stats

# 直近で間違えた問題のみを復習出題（弱点克服モード）
spec -r

# 出題数を指定（例: 10問）
spec -n 10

# カテゴリを指定して集中出題
spec -c "正規化理論"

# 分野一覧と問題数の確認
spec categories

# 過去問PDFの非同期バックグラウンド取得
spec fetch --all -d
spec fetch --status
```

### 2. チャット上での対話式出題（エージェント連携）

1. **問題の取得**:
   - `spec question --json` を実行して対象問題を取得（選択肢は自動シャッフル済み）。
2. **出題**:
   - `ask_question` ツールを用いて、問題文と4つの選択肢を提示。
3. **判定と解説**:
   - ユーザーの選択後、正誤判定と詳細な解説を提示。
4. **履歴の即時保存（許可プロンプトなし）**:
   - `spec record --id <問題ID> --choice <回答番号-1>` を実行（例: `spec record --id db-011 --choice 2`）。
5. **進捗・次のアクション**:
   - 次の問題へ進むか、終了して `spec stats` で実力モニタリングを確認するかを案内。

## 問題データと知識リファレンス

- 問題データ: [references/questions.json](file:///Users/aobaiwaki/ai-workspace/.agents/skills/db-specialist-quiz/references/questions.json)
- 基礎知識チェックリスト: [space/database-specialist/note/02_database-fundamentals-knowledge-list.md](file:///Users/aobaiwaki/ai-workspace/space/database-specialist/note/02_database-fundamentals-knowledge-list.md)
