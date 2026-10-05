#!/usr/bin/env python3
"""Database Specialist Multiple-Choice Quiz CLI with Persistent History."""

import argparse
from datetime import datetime, timezone, timedelta
import json
import random
import sys
from pathlib import Path

# Paths
SCRIPT_PATH = Path(__file__).resolve()
BASE_DIR = SCRIPT_PATH.parent.parent  # .agents/skills/db-specialist-quiz
QUESTIONS_FILE = BASE_DIR / "references" / "questions.json"
REPO_ROOT = SCRIPT_PATH.parents[4]    # /Users/aobaiwaki/ai-workspace
WORKSPACE_DATA_DIR = REPO_ROOT / "space" / "database-specialist" / "data"
HISTORY_FILE = WORKSPACE_DATA_DIR / "quiz_history.jsonl"

JST = timezone(timedelta(hours=9))


def load_questions():
    if not QUESTIONS_FILE.exists():
        print(f"Error: Question file not found at {QUESTIONS_FILE}", file=sys.stderr)
        sys.exit(1)
    with open(QUESTIONS_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def load_history():
    if not HISTORY_FILE.exists():
        return []
    records = []
    with open(HISTORY_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    records.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return records


def record_history_entry(question_id, category, user_choice_index, correct_index, is_correct, source="cli"):
    try:
        WORKSPACE_DATA_DIR.mkdir(parents=True, exist_ok=True)
        now_iso = datetime.now(JST).isoformat()
        entry = {
            "timestamp": now_iso,
            "question_id": question_id,
            "category": category,
            "user_choice_index": user_choice_index,
            "correct_index": correct_index,
            "is_correct": is_correct,
            "source": source,
        }
        with open(HISTORY_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception as e:
        print(f"Warning: Failed to record history: {e}", file=sys.stderr)


# Standard IPA Exam Category Weights (Morning II)
CATEGORY_WEIGHTS = {
    "正規化理論": 0.28,
    "トランザクション・同時実行制御": 0.24,
    "関係モデル・代数": 0.16,
    "障害回復": 0.12,
    "物理設計・インデックス": 0.12,
    "SQL・整合性制約": 0.08,
}


def calculate_predicted_score(history):
    if not history:
        return 0.0, "未受検", "なし"

    total = len(history)
    if total < 10:
        confidence = "低 (Low / 参考値: 回答数10問未満)"
    elif total < 20:
        confidence = "中 (Medium / 暫定推論: 回答数10〜19問)"
    else:
        confidence = "高 (High / 高精度推論: 回答数20問以上)"

    # Recent answers (up to 30) for trend
    recent_history = history[-30:]
    cat_stats = {}
    for h in recent_history:
        cat = h.get("category", "その他")
        if cat not in cat_stats:
            cat_stats[cat] = {"total": 0, "correct": 0}
        cat_stats[cat]["total"] += 1
        if h.get("is_correct"):
            cat_stats[cat]["correct"] += 1

    overall_recent_rate = sum(1 for h in recent_history if h.get("is_correct")) / len(recent_history)

    # Weighted calculation
    predicted = 0.0
    for cat, weight in CATEGORY_WEIGHTS.items():
        if cat in cat_stats and cat_stats[cat]["total"] > 0:
            rate = cat_stats[cat]["correct"] / cat_stats[cat]["total"]
        else:
            rate = overall_recent_rate
        predicted += rate * weight * 100

    if predicted >= 80:
        status = "合格安全圏 (Safe Pass)"
    elif predicted >= 65:
        status = "合格圏 (Passing)"
    elif predicted >= 55:
        status = "合格ボーダー (Borderline: あと一歩)"
    else:
        status = "要基礎強化 (Needs Review: 基準点未達)"

    return round(predicted, 1), status, confidence


def show_stats(questions):
    history = load_history()
    if not history:
        print("回答履歴はまだありません。クイズを実行すると自動的に記録されます。")
        return

    q_map = {q["id"]: q for q in questions}
    total_answers = len(history)
    correct_answers = sum(1 for h in history if h.get("is_correct"))
    overall_rate = (correct_answers / total_answers) * 100 if total_answers else 0

    pred_score, pred_status, confidence = calculate_predicted_score(history)

    print("=" * 65)
    print(" データベーススペシャリスト (DB) 学習履歴・得点能力モニタリング")
    print("=" * 65)
    print(f"・累計回答数: {total_answers} 問")
    print(f"・累計正解数: {correct_answers} 問 (通算正解率: {overall_rate:.1f}%)")
    print("-" * 65)
    print(f"★ 午前II 予想得点:  {pred_score} 点 / 100点満点 (基準点: 60点)")
    print(f"★ 現在の実力判定:  {pred_status}")
    print(f"★ 推論の信頼度:    {confidence}")
    print("=" * 65)
    print()

    # Category stats
    cat_stats = {}
    for h in history:
        cat = h.get("category", "その他")
        if cat not in cat_stats:
            cat_stats[cat] = {"total": 0, "correct": 0}
        cat_stats[cat]["total"] += 1
        if h.get("is_correct"):
            cat_stats[cat]["correct"] += 1

    print("【分野別 正解率・習熟度】")
    print(f"{'分野':<24} | {'回答数':<6} | {'正解数':<6} | {'正解率':<8} | {'判定'}")
    print("-" * 65)
    for cat, stats in sorted(cat_stats.items(), key=lambda x: (x[1]["correct"] / x[1]["total"] if x[1]["total"] else 0)):
        t = stats["total"]
        c = stats["correct"]
        r = (c / t) * 100 if t else 0
        status = "要復習" if r < 60 else "合格圏" if r >= 80 else "標準"
        print(f"{cat:<22} | {t:<8} | {c:<8} | {r:>6.1f}%  | {status}")
    print("-" * 65)
    print()

    # Problem-level stats (Identify weak questions)
    q_stats = {}
    for h in history:
        qid = h.get("question_id")
        if not qid:
            continue
        if qid not in q_stats:
            q_stats[qid] = {"total": 0, "correct": 0, "latest_correct": False}
        q_stats[qid]["total"] += 1
        if h.get("is_correct"):
            q_stats[qid]["correct"] += 1
        q_stats[qid]["latest_correct"] = bool(h.get("is_correct"))

    wrong_questions = [qid for qid, s in q_stats.items() if not s["latest_correct"]]
    print(f"【直近で不正解の弱点問題 (要復習)】: {len(wrong_questions)} 問")
    for qid in wrong_questions:
        q = q_map.get(qid)
        cat = q["category"] if q else "不明"
        q_text = (q["question"][:35] + "...") if q else ""
        s = q_stats[qid]
        print(f"・[{qid}] ({cat}) 正解率: {s['correct']}/{s['total']} - {q_text}")
    print("=" * 65)
    print("※ '--review-wrong' オプションで上記弱点問題を集中的に演習できます。")


def main():
    parser = argparse.ArgumentParser(description="Database Specialist (DB) Multiple-Choice Quiz with History")
    parser.add_argument("-n", "--count", type=int, default=5, help="Number of questions to ask (default: 5)")
    parser.add_argument("-c", "--category", type=str, default=None, help="Filter by specific category")
    parser.add_argument("--list-categories", action="store_true", help="List all available categories")
    parser.add_argument("--all", action="store_true", help="Ask all questions in random order")
    parser.add_argument("--stats", action="store_true", help="Show learning statistics and weak areas")
    parser.add_argument("--review-wrong", "-r", action="store_true", help="Review questions answered incorrectly last time")
    args = parser.parse_args()

    questions = load_questions()

    if args.stats:
        show_stats(questions)
        return

    categories = sorted(list(set(q["category"] for q in questions)))
    if args.list_categories:
        print("Available Categories:")
        for cat in categories:
            count = sum(1 for q in questions if q["category"] == cat)
            print(f"  - {cat} ({count} questions)")
        return

    if args.review_wrong:
        history = load_history()
        q_stats = {}
        for h in history:
            qid = h.get("question_id")
            if qid:
                q_stats[qid] = bool(h.get("is_correct"))
        wrong_ids = {qid for qid, is_correct in q_stats.items() if not is_correct}
        if not wrong_ids:
            print("直近で間違えた問題はありません！素晴らしい成果です。")
            return
        questions = [q for q in questions if q["id"] in wrong_ids]
        print(f">> 弱点復習モード: 過去に間違えた {len(questions)} 問から出題します。")

    elif args.category:
        filtered = [q for q in questions if args.category.lower() in q["category"].lower()]
        if not filtered:
            print(f"No questions found for category: '{args.category}'")
            print("Available categories:", ", ".join(categories))
            sys.exit(1)
        questions = filtered

    random.shuffle(questions)
    num_to_ask = len(questions) if (args.all or args.review_wrong) else min(args.count, len(questions))
    selected = questions[:num_to_ask]

    print("=" * 60)
    print(" データベーススペシャリスト (DB) 午前II対策 択一クイズ")
    print(f" 出題数: {num_to_ask}問 (回答履歴は自動保存されます)")
    print("=" * 60)
    print()

    correct_count = 0

    for i, q in enumerate(selected, 1):
        print(f"[第 {i} 問 / 全 {num_to_ask} 問] (分野: {q['category']})")
        print(f"ID: {q['id']}")
        print(q["question"])
        print()
        for idx, opt in enumerate(q["options"], 1):
            print(f"  {idx}. {opt}")
        print()

        user_choice = None
        while user_choice is None:
            try:
                raw_input = input("あなたの解答番号 (1-4, qで中断): ").strip()
            except (EOFError, KeyboardInterrupt):
                print("\n中断しました。")
                sys.exit(0)

            if raw_input.lower() == "q":
                print("\nクイズを中断しました。")
                sys.exit(0)

            if raw_input in ["1", "2", "3", "4"]:
                user_choice = int(raw_input) - 1
            else:
                print("1〜4の番号を入力してください。")

        correct_idx = q["answer_index"]
        is_correct = (user_choice == correct_idx)

        # Record to history file
        record_history_entry(
            question_id=q["id"],
            category=q["category"],
            user_choice_index=user_choice,
            correct_index=correct_idx,
            is_correct=is_correct,
            source="cli",
        )

        if is_correct:
            print("\n>> 正解！")
            correct_count += 1
        else:
            print(f"\n>> 不正解... (正解は {correct_idx + 1}. {q['options'][correct_idx]})")

        print("-" * 50)
        print("【解説】")
        print(q["explanation"])
        print("=" * 60)
        print()

    rate = (correct_count / num_to_ask) * 100
    print("=" * 60)
    print(f" 結果発表: {correct_count} / {num_to_ask} 問 正解 (正解率: {rate:.1f}%)")
    if rate >= 80:
        print(" 評価: 素晴らしい理解度です！午前II基準点（60%）を大幅にクリアしています。")
    elif rate >= 60:
        print(" 評価: 合格ライン（60%）到達です。間違えた分野を重点的に復習しましょう。")
    else:
        print(" 評価: 基礎知識の定着が必要です。解説とノートを見直しましょう。")
    print(" 履歴は space/database-specialist/data/quiz_history.jsonl に記録されました。")
    print(" 'python3 .agents/skills/db-specialist-quiz/scripts/quiz.py --stats' で分析を確認できます。")
    print("=" * 60)


if __name__ == "__main__":
    main()
