import time
import math
from enrich import get_yomi, FEW_SHOT_EXAMPLES

# FEW_SHOT_EXAMPLES に含まれる例（=LOVE, ≠ME, FRUITS ZIPPER, ASP, chuLa, CYNHN）を除いた未見のテストケース
TEST_CASES = {
    # 記号を含む女性アイドルグループ
    "≒JOY": "ニアリーイコールジョイ",
    "Lollipop♡CHU": "ロリポップチュー",
    "Appare!": "アッパレ",
    "FES☆TIVE": "フェスティブ",
    "Devil ANTHEM.": "デビルアンセム",
    # 代表的な女性アイドルグループ（英語表記・複合語）
    "CANDY TUNE": "キャンディーチューン",
    "SWEET STEADY": "スイートステディ",
    "CUTIE STREET": "キューティーストリート",
    "JamsCollection": "ジャムズコレクション",
    "Peel the Apple": "ピールジアップル",
    "Task have Fun": "タスクハブファン",
    "NEO JAPONISM": "ネオジャポニズム",
    "BABYMETAL": "ベビーメタル",
    # 特殊な読み・造語・小文字混じりの女性アイドルグループ
    "iLiFE": "アイライフ",
    "BiSH": "ビッシュ",
    "BiS": "ビス",
    "ukka": "ウッカ",
    "AMEFURASSHI": "アメフラッシ",
}


def main():
    total_count = len(TEST_CASES)
    k_shot = len(FEW_SHOT_EXAMPLES)
    print(
        f"=== 未知の女性アイドルグループ名 -> カタカナ変換テスト (計 {total_count} 件) ==="
    )
    print(f"[INFO] 評価プロンプトの Few-shot 件数: {k_shot} 件\n")

    correct_count = 0
    results = []

    for name, expected in TEST_CASES.items():
        try:
            actual = get_yomi(name)
            if actual == expected:
                print(f"[OK] {name} -> {actual}")
                correct_count += 1
                results.append((name, expected, actual, True))
            else:
                print(
                    f"[NG] {name}\n     Expected: {expected}\n     Actual  : {actual}"
                )
                results.append((name, expected, actual, False))
        except Exception as e:
            print(f"[ERROR] {name}: {e}")
            results.append((name, expected, f"Error: {e}", False))

        time.sleep(0.05)

    accuracy = (correct_count / total_count) * 100
    efficiency_score = accuracy / math.log(k_shot + 2)

    print("\n=== テスト結果 ===")
    print(f"Few-shot 知識量: {k_shot} 件")
    print(f"Accuracy: {correct_count} / {total_count} ({accuracy:.1f}%)")
    print(f"Efficiency Score: {efficiency_score:.1f} pts")

    report_content = f"""# 女性アイドルグループ名 -> カタカナ変換 自動テストレポート (非重複評価)

## 📊 テスト結果概要

- **正答率 (Accuracy)**: {accuracy:.1f}% ({correct_count} / {total_count} 件)
- **Few-shot 知識量 (K)**: {k_shot} 件
- **知識効率スコア (Efficiency)**: {efficiency_score:.1f} pts
- **テスト日時**: {time.strftime("%Y-%m-%d %H:%M:%S")}

## 💡 Few-shot に使用した例 ({k_shot} 件)

| Input | Katakana | 狙い |
| :--- | :--- | :--- |
| =LOVE | イコールラブ | 記号（=）の読み替えルール |
| ≠ME | ノットイコールミー | 否定記号（≠）の読み替えルール |
| FRUITS ZIPPER | フルーツジッパー | 英語複合語・スペース除去 |
| ASP | エーエスピー | 略称・頭字語のアルファベット読み |
| chuLa | チュラ | 大文字小文字混じりの発音 |
| CYNHN | スウィーニー | 特殊な非英語・造語の読み |

## ✅ 成功したケース

| Idol Group | Katakana (Output) |
| :--- | :--- |
"""
    for name, exp, act, is_ok in results:
        if is_ok:
            report_content += f"| {name} | {act} |\n"

    report_content += """
## ❌ 失敗したケース

| Idol Group | Expected | Output |
| :--- | :--- | :--- |
"""
    for name, exp, act, is_ok in results:
        if not is_ok:
            report_content += f"| {name} | {exp} | {act} |\n"

    with open("test_report.md", "w", encoding="utf-8") as f:
        f.write(report_content)


if __name__ == "__main__":
    main()
