# /// script
# requires-python = ">=3.11"
# ///

import sqlite3


def setup():
    conn = sqlite3.connect("master.sqlite")
    cursor = conn.cursor()

    # テーブルの作成
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS idols (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        yomi TEXT
    )
    """)

    # 既存のデータがあれば一旦クリア（テスト用）
    cursor.execute("DELETE FROM idols")

    # テストデータの挿入
    test_data = [
        ("iLiFE",),
        ("JamsCollection",),
        ("=LOVE",),
        ("CANDY TUNE",),
        ("Lollipop♡CHU",),
    ]

    cursor.executemany("INSERT INTO idols (name) VALUES (?)", test_data)

    conn.commit()
    conn.close()
    print("✅ master.sqlite の作成とテストデータの挿入が完了しました。")


if __name__ == "__main__":
    setup()
