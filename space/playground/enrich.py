import re
import sqlite3
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8080/v1",
    api_key="local-unsloth",
)

MODEL_NAME = "default"

# 代表的なパターンをカバーするFew-shot例（6件）
FEW_SHOT_EXAMPLES = [
    ("=LOVE", "イコールラブ"),
    ("≠ME", "ノットイコールミー"),
    ("FRUITS ZIPPER", "フルーツジッパー"),
    ("ASP", "エーエスピー"),
    ("chuLa", "チュラ"),
    ("CYNHN", "スウィーニー"),
]

def get_yomi(name: str) -> str:
    target_name = name
    if "≒" in target_name:
        target_name = target_name.replace("≒", "NearlyEqual ")

    prompt = """指示:
日本の女性アイドルグループ名の英語表記を、日本の公式カタカナ読みに変換してください。

【読み方ルール】
・NearlyEqual → ニアリーイコール
・JOY → ジョイ
・SWEET → スイート
・STEADY → ステディ
・CHU → チュー
・Peel the Apple → ピールジアップル
・Task have Fun → タスクハブファン
・BABY → ベビー
・CUTIE → キューティー
・STREET → ストリート
・TUNE → チューン
・CANDY → キャンディー
・Jams → ジャムズ
・iLiFE → アイライフ
・NEO → ネオ
・ANTHEM → アンセム
・Appare → アッパレ
・AMEFURASSHI → アメフラッシ

【出力形式】
・アルファベットやスペース、装飾記号（!, ♡, ☆, . 等）は残さず、連続したカタカナのみを出力してください。

"""

    for ex_name, ex_yomi in FEW_SHOT_EXAMPLES:
        prompt += f"English: {ex_name}\nKatakana: {ex_yomi}\n---\n"

    prompt += f"English: {target_name}\nKatakana:"

    response = client.completions.create(
        model=MODEL_NAME,
        prompt=prompt,
        max_tokens=30,
        stop=["\n", "---", "<", "[", "English:"],
        temperature=0.0,
    )

    raw_text = response.choices[0].text.strip()
    # 記号や空白の正規化
    cleaned = re.sub(r"[\s\.\!！\?？♡☆★♪。・]+", "", raw_text)
    return cleaned

def main():
    conn = sqlite3.connect("master.sqlite")
    cursor = conn.cursor()

    cursor.execute("SELECT id, name FROM idols")
    target_rows = cursor.fetchall()

    print(f"--- エンリッチメント開始 ({len(target_rows)}件) ---")

    for row_id, name in target_rows:
        try:
            yomi = get_yomi(name)
            print(f"[{name}] -> {yomi}")
            cursor.execute("UPDATE idols SET yomi = ? WHERE id = ?", (yomi, row_id))
        except Exception as e:
            print(f"エラー発生 ({name}): {e}")
            continue

    conn.commit()
    conn.close()
    print("--- 処理完了 ---")

if __name__ == "__main__":
    main()
