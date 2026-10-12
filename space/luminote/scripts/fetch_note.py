#!/usr/bin/env python3
"""
fetch_note.py - note.com 記事のテキスト・Markdown取得スクリプト
外部依存なし（Python 3 標準ライブラリのみ）で動作します。

使用例:
    python3 scripts/fetch_note.py https://note.com/amamiya_saku/n/n004679417efb
    python3 scripts/fetch_note.py n004679417efb -o article.md
"""

import sys
import re
import json
import html
import argparse
import urllib.request


def extract_note_key(url_or_key: str) -> str:
    match = re.search(r"n/([a-zA-Z0-9]+)", url_or_key)
    if match:
        return match.group(1)
    if re.match(r"^n[a-zA-Z0-9]+$", url_or_key):
        return url_or_key
    return url_or_key


def html_to_markdown(html_text: str) -> str:
    # 改行・段落変換
    text = re.sub(r"<br\s*/?>", "\n", html_text)
    text = re.sub(r"</p>", "\n\n", text)
    text = re.sub(r"<p[^>]*>", "", text)

    # 見出し
    text = re.sub(r"<h[2-3][^>]*>(.*?)</h[2-3]>", r"\n## \1\n", text)

    # 装飾
    text = re.sub(r"<strong[^>]*>(.*?)</strong>", r"**\1**", text)
    text = re.sub(r"<b[^>]*>(.*?)</b>", r"**\1**", text)
    text = re.sub(r"<em[^>]*>(.*?)</em>", r"*\1*", text)

    # リンク
    text = re.sub(r'<a\s+href="([^"]+)"[^>]*>(.*?)</a>', r"[\2](\1)", text)

    # 残りのHTMLタグを除去
    text = re.sub(r"<[^>]+>", "", text)

    # HTML実体参照デコード
    text = html.unescape(text)

    # 連続改行の正規化
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def fetch_note(note_key: str) -> dict:
    api_url = f"https://note.com/api/v3/notes/{note_key}"
    req = urllib.request.Request(
        api_url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            )
        },
    )
    with urllib.request.urlopen(req) as res:
        data = json.loads(res.read().decode("utf-8"))
        return data["data"]


def format_markdown(note_data: dict) -> str:
    title = note_data.get("name", "無題")
    author = note_data.get("user", {}).get("nickname", "不明")
    urlname = note_data.get("user", {}).get("urlname", "")
    publish_at = note_data.get("publish_at", "")
    like_count = note_data.get("like_count", 0)
    note_url = note_data.get("note_url", "")
    body_html = note_data.get("body", "")

    body_md = html_to_markdown(body_html)

    header = f"""# {title}

- **著者**: {author} (@{urlname})
- **公開日時**: {publish_at}
- **スキ数**: {like_count}
- **元記事**: {note_url}

---

"""
    return header + body_md


def main():
    parser = argparse.ArgumentParser(description="note.com 記事をMarkdownで取得")
    parser.add_argument("url_or_key", help="noteの記事URLまたはnote_key")
    parser.add_argument("-o", "--output", help="保存先ファイルパス（省略時は標準出力）")

    args = parser.parse_args()
    note_key = extract_note_key(args.url_or_key)

    try:
        data = fetch_note(note_key)
        md_text = format_markdown(data)

        if args.output:
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(md_text)
            print(f"Saved to {args.output}", file=sys.stderr)
        else:
            print(md_text)
    except Exception as e:
        print(f"Error fetching note ({note_key}): {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
