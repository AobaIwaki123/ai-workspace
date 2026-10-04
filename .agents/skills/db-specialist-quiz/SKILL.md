---
name: db-specialist-quiz
description: Conducts multiple-choice quizzes and knowledge checks for the IPA Database Specialist Examination (DB). Use this skill when the user asks to practice database specialist exam questions, test their database fundamentals knowledge (relational algebra, normalization, ACID, recovery, indexes, SQL), or run an interactive database quiz.
---

# Database Specialist Quiz Skill

IPA高度情報処理技術者「データベーススペシャリスト試験（DB）」の午前IIおよび基礎理論に関する四肢択一クイズを出題・採点・解説するスキルです。

## クイズの実行方法

### 1. ターミナル（CLI）での直接実行

ユーザー自身がターミナル上で対話的にクイズを進める場合、以下のスクリプトを実行します。

```bash
# デフォルト（ランダム5問出題・回答履歴を自動保存）
python3 .agents/skills/db-specialist-quiz/scripts/quiz.py

# 学習統計・弱点分野のレポートを表示
python3 .agents/skills/db-specialist-quiz/scripts/quiz.py --stats

# 直近で間違えた問題のみを復習出題（弱点克服モード）
python3 .agents/skills/db-specialist-quiz/scripts/quiz.py --review-wrong

# 出題数を指定（例: 10問）
python3 .agents/skills/db-specialist-quiz/scripts/quiz.py -n 10

# カテゴリを指定して出題
python3 .agents/skills/db-specialist-quiz/scripts/quiz.py -c "正規化理論"

# カテゴリ一覧の確認
python3 .agents/skills/db-specialist-quiz/scripts/quiz.py --list-categories
```

### 2. チャット上での対話式出題（エージェント経由）

ユーザーがチャット内でクイズの出題を求めた場合は、以下の手順で対話的に進行します。

1. `references/questions.json` から対象の問題を選択（ランダムまたは分野指定）。
2. `ask_question` ツールを用いて、問題文と4つの選択肢を提示。
3. ユーザーの選択後、正誤判定と詳細な解説（なぜ正解なのか、他の選択肢が誤りの理由）を提示。
4. 次の問題へ進むか終了するかを確認。

## 問題データと知識リファレンス

- 問題データ: [references/questions.json](file:///Users/aobaiwaki/ai-workspace/.agents/skills/db-specialist-quiz/references/questions.json)
- 基礎知識チェックリスト: [space/database-specialist/note/02_database-fundamentals-knowledge-list.md](file:///Users/aobaiwaki/ai-workspace/space/database-specialist/note/02_database-fundamentals-knowledge-list.md)
