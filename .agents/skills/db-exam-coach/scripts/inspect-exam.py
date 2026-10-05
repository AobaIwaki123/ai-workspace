#!/usr/bin/env python3
"""IPA Database Specialist Past Exam Link Helper and Asset Manager."""

import argparse
from datetime import datetime, timezone, timedelta
import json
from pathlib import Path
import sys

# IPA standard URL patterns for DB past exams
IPA_BASE_URL = "https://www.ipa.go.jp/shiken/mondai-kaiotu"

# Recent years mapping (Reiwa era)
EXAM_YEARS = {
    "r06": {"name": "令和6年度 秋期 (2024)", "prefix": "2024r06a_db", "dir": "2024-r06"},
    "r05": {"name": "令和5年度 秋期 (2023)", "prefix": "2023r05a_db", "dir": "2023-r05"},
    "r04": {"name": "令和4年度 秋期 (2022)", "prefix": "2022r04a_db", "dir": "2022-r04"},
    "r03": {"name": "令和3年度 秋期 (2021)", "prefix": "2021r03a_db", "dir": "2021-r03"},
    "r02": {"name": "令和2年度 10月 (2020)", "prefix": "2020r02o_db", "dir": "2020-r02"},
}

SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[4]  # /Users/aobaiwaki/ai-workspace
NOTE_DIR = REPO_ROOT / "space" / "database-specialist" / "note"
ASSETS_DIR = REPO_ROOT / "space" / "database-specialist" / "assets" / "past-exams"

JST = timezone(timedelta(hours=9))


def create_asset_scaffold(year_code, pm_num, q_num):
    info = EXAM_YEARS[year_code]
    prefix = info["prefix"]
    pm_str = f"pm{pm_num}"
    title = f"{info['name']} 午後{ 'I' if pm_num == 1 else 'II' } 問{q_num}"
    q_dir = ASSETS_DIR / info["dir"] / f"pm{pm_num}-q{q_num}"
    q_dir.mkdir(parents=True, exist_ok=True)

    # 1. question.md
    question_file = q_dir / "question.md"
    if not question_file.exists():
        content_q = f"""# {title} 問題文アセット

- **公式問題冊子**: `{prefix}_{pm_str}_qs.pdf`
- **問題概要**: 
- **出題分野**: 概念データモデル / 関係スキーマ / SQL / 物理設計

---

## 業務要件定義・問題文テキスト

ここに問題文の本文・業務ルール・関係スキーマ（未完成版）を転記・保存します。
"""
        with open(question_file, "w", encoding="utf-8") as f:
            f.write(content_q)
        print(f"Created question asset: {question_file}")

    # 2. official_answer.md
    answer_file = q_dir / "official_answer.md"
    if not answer_file.exists():
        content_a = f"""# {title} 公式解答例 ＆ 採点講評アセット

- **公式解答例**: `{prefix}_{pm_str}_ans.pdf`
- **公式採点講評**: `{prefix}_{pm_str}_cmnt.pdf`

---

## 1. IPA公式解答例

| 設問番号 | 公式解答・模範解答 | 配点目安 |
| :--- | :--- | :--- |
| 設問1 (1) | | |
| 設問1 (2) | | |
| 設問2 | | |

---

## 2. IPA公式採点講評（出題意図と誤答トラップ）

ここに採点講評の原文（出題趣旨、受験者が陥った誤答、配慮すべき点）を転記します。
AIはこれを絶対前提として壁打ち時のハルシネーションを防ぎます。
"""
        with open(answer_file, "w", encoding="utf-8") as f:
            f.write(content_a)
        print(f"Created official answer asset: {answer_file}")

    # 3. coaching_history.jsonl
    history_file = q_dir / "coaching_history.jsonl"
    if not history_file.exists():
        history_file.touch()
        print(f"Initialized history log: {history_file}")

    print(f"Asset store ready at: {q_dir}")


def show_pm_score_summary():
    if not ASSETS_DIR.exists():
        print("過去問アセットはまだ作成されていません。")
        return

    history_files = list(ASSETS_DIR.glob("*/*/coaching_history.jsonl"))
    if not history_files:
        print("過去問アセットの演習記録はまだありません。")
        return

    records = []
    for hf in history_files:
        rel_q = hf.parent.relative_to(ASSETS_DIR)
        with open(hf, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        data = json.loads(line)
                        data["question_path"] = str(rel_q)
                        records.append(data)
                    except json.JSONDecodeError:
                        continue

    print("=" * 65)
    print(" データベーススペシャリスト (DB) 午後試験 演習進捗・得点モニタリング")
    print("=" * 65)
    if not records:
        print("演習履歴データ（coaching_history.jsonl）はまだ空です。")
        print("午後問題を解いた後、得点と壁打ちログを記録すると予想得点が算出されます。")
        print("=" * 65)
        return

    # Aggregate by question
    by_q = {}
    for r in records:
        qp = r["question_path"]
        if qp not in by_q:
            by_q[qp] = []
        by_q[qp].append(r)

    print(f"・演習済み大問数: {len(by_q)} 問")
    print(f"・総演習セッション数: {len(records)} 回")
    print()
    print("【各大問の最新得点・周回状況 (50点満点)】")
    print(f"{'大問':<20} | {'周回数':<6} | {'最新得点':<8} | {'直近演習日'}")
    print("-" * 65)
    latest_scores = []
    for qp, atts in sorted(by_q.items()):
        latest = atts[-1]
        score = latest.get("score_estimated", 0)
        latest_scores.append(score)
        date_str = latest.get("timestamp", "")[:10]
        print(f"{qp:<20} | {len(atts):<6} | {score:>4} / 50点 | {date_str}")
    print("-" * 65)

    if len(latest_scores) >= 2:
        # Sum of top/recent 2 questions for PM1 100-scale
        pm1_pred = sum(latest_scores[-2:])
        status = "合格安全圏" if pm1_pred >= 80 else "合格圏" if pm1_pred >= 60 else "要対策 (60点未満)"
        print()
        print(f"★ 午後I 暫定予想得点: {pm1_pred} 点 / 100点満点 (直近2問合算)")
        print(f"★ 現在の実力判定:   {status}")
    else:
        print()
        print("※ 午後Iの予想得点を算出するには、最低2つの大問演習が必要です（現在1問）。")
    print("=" * 65)


def main():
    parser = argparse.ArgumentParser(description="IPA Database Specialist Past Exam Helper and Asset Store")
    parser.add_argument("-y", "--year", type=str, choices=list(EXAM_YEARS.keys()), default="r05",
                        help="Exam year code (e.g. r06, r05, r04. default: r05)")
    parser.add_argument("-p", "--pm", type=int, choices=[1, 2], default=1,
                        help="PM section: 1 for 午後I, 2 for 午後II (default: 1)")
    parser.add_argument("-q", "--question", type=int, default=1,
                        help="Question number (default: 1)")
    parser.add_argument("--create-asset", action="store_true",
                        help="Create asset directories (question.md, official_answer.md, coaching_history.jsonl)")
    parser.add_argument("--scaffold-note", action="store_true",
                        help="Create a study note scaffold in space/database-specialist/note/")
    parser.add_argument("--score-summary", action="store_true",
                        help="Show afternoon exam performance and predicted scores")
    args = parser.parse_args()

    if args.score_summary:
        show_pm_score_summary()
        return

    info = EXAM_YEARS[args.year]
    prefix = info["prefix"]
    pm_str = f"pm{args.pm}"
    title = f"{info['name']} 午後{ 'I' if args.pm == 1 else 'II' } 問{args.question}"

    print("=" * 65)
    print(f" IPA データベーススペシャリスト過去問リファレンス")
    print(f" 対象: {title}")
    print("=" * 65)
    print(f"・IPA過去問公式ポータル: {IPA_BASE_URL}/index.html")
    print(f"・問題冊子PDF (予想パス): {IPA_BASE_URL}/{prefix}_{pm_str}_qs.pdf")
    print(f"・解答例PDF (予想パス):   {IPA_BASE_URL}/{prefix}_{pm_str}_ans.pdf")
    print(f"・採点講評PDF (予想パス): {IPA_BASE_URL}/{prefix}_{pm_str}_cmnt.pdf")
    print("=" * 65)

    if args.create_asset:
        create_asset_scaffold(args.year, args.pm, args.question)

    if args.scaffold_note:
        NOTE_DIR.mkdir(parents=True, exist_ok=True)
        note_file = NOTE_DIR / f"exam_{args.year}_pm{args.pm}_q{args.question}.md"
        if note_file.exists():
            print(f"Note file already exists: {note_file}")
            return

        content = f"""# {title} 過去問演習・導出過程検討ノート

## 1. 問題の前提情報
- **試験区分**: {title}
- **公式問題冊子**: `{prefix}_{pm_str}_qs.pdf`
- **公式解答例**: `{prefix}_{pm_str}_ans.pdf`
- **公式採点講評**: `{prefix}_{pm_str}_cmnt.pdf`

---

## 2. 業務ルールの抽出とマーキング (Evidence Extraction)
問題文から抽出したエンティティ、属性、カーディナリティの制約条件を引用します。

| 該当段落 / 箇所 | 問題文の記述（業務ルール） | 導出される設計・制約 |
| :--- | :--- | :--- |
| 例: [業務ルール1] | 「1人の顧客は複数の注文を行うことができる」 | 顧客と注文は 1:N の関係 |

---

## 3. 概念データモデル・関係スキーマの導出プロセス (Step-by-Step)

### 3.1 エンティティの特定
- 

### 3.2 カーディナリティ（多重度）の判定
- 

### 3.3 主キー・外部キーの確定
- 

---

## 4. 公式解答例との突合・解説

- **公式解答**:
  - 
- **思考プロセスの整合確認**:
  - なぜその解答になるのか、問題文の記述との因果関係を整理。

---

## 5. 採点講評からの学び・誤答分析
- **採点講評の指摘事項**:
  - 
- **自己の思考との差分・再発防止策**:
  - 
"""
        with open(note_file, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Created study note scaffold: {note_file}")


if __name__ == "__main__":
    main()

