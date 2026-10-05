---
name: db-exam-coach
description: Guides step-by-step derivation and reasoning for the IPA Database Specialist Examination (DB) afternoon problems (午後I・午後II). Use this skill when the user asks to analyze past exam questions, review afternoon conceptual data models (ER diagrams) or relation schemas, dissect derivation steps from official problem statements, or compare their answers with official answer keys without hallucination.
---

# Database Specialist Exam Coach Skill

IPA高度情報処理技術者「データベーススペシャリスト試験（DB）」の午後記述式問題（午後I・午後II）において、AIのハルシネーション（誤読・独自の解釈創作）を完全に排除し、公式解答例と採点講評を絶対的なアンカーとした論理的導出プロセスを壁打ち・解説するスキルです。

## 壁打ちプロトコル（セーフガード）

午後問題の解説・壁打ちを行う際は、以下の原則を厳守します。

1. **公式解答・採点講評の絶対前提化**:
   - AI自律の解答推測を行わず、IPA公式の「解答例」と「採点講評」を確定事実として固定し、問題文からの「逆引き導出」に徹する。
2. **根拠の直接引用 (Evidence Integrity)**:
   - なぜその設計（エンティティ、主キー、外部キー、多重度）になるのかを解説する際は、必ず問題文中の該当する業務ルール記述を直接引用する。
3. **採点講評の照合**:
   - 採点講評に記載された「受験者が陥りやすかった誤答パターン」と照合し、ユーザーの解答や疑問とのギャップを論理的に言語化する。

## 導出フレームワーク（4ステップ）

1. **業務ルールの抽出とマーキング**: カーディナリティ（1対多、多対多）、履歴管理、状態遷移に関する記述を抽出。
2. **エンティティの特定**: リソース系（マスタ）とイベント系（トランザクション）を分類し、連関エンティティで多対多を解消。
3. **主キー・外部キーの確定**: 最小の識別属性セットと外部キーの配置（多側に親の主キー）を決定。
4. **関係スキーマ・ER図の検証**: 問題文の用語と一致しているか、カーディナリティの向きが正しいか検証。

詳細な導出テクニックと過去の採点講評パターンは [references/derivation-guide.md](file:///Users/aobaiwaki/ai-workspace/.agents/skills/db-exam-coach/references/derivation-guide.md) を参照してください。

## 過去問演習・アセット作成スクリプト

特定の過去問について演習・壁打ちを進める際、トークンを浪費しないよう**オンデマンドで公式リソースから該当問題の情報をfetchし、アセット（問題文・公式解答・周回履歴）を生成・拡張**します。

```bash
# 対象年度・大問のリファレンスを表示
python3 .agents/skills/db-exam-coach/scripts/inspect-exam.py -y r05 -p 1 -q 1

# 過去問アセット領域（question.md, official_answer.md, coaching_history.jsonl）を生成
python3 .agents/skills/db-exam-coach/scripts/inspect-exam.py -y r05 -p 1 -q 1 --create-asset

# 検討用ノートテンプレートを space/database-specialist/note/ に生成
python3 .agents/skills/db-exam-coach/scripts/inspect-exam.py -y r05 -p 1 -q 1 --scaffold-note
```

