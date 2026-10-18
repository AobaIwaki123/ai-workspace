# 個人用タイムスタンプメモ管理 CLI (memo-cli)

本ツールは、`private/memo/` に保存される時間減衰型メモ（`YYYY-MM-DD-HHMM_<slug>.md`）をターミナルから素早く一覧・閲覧・作成・鮮度管理するための Go 製 CLI ツールです。

---

## 1. 主な機能

1. **`memo list`**:
   - `🔥 HOT` (0〜48h), `⛅ WARM` (2〜7d), `❄️ COLD` (7d+), `✅ DONE` のステータスと経過時間をカラーバッジで一覧表示。
   - `-status=hot`, `-all`, `-json`, `-limit=N` などのフィルタリングに対応。
2. **`memo show [query]`**:
   - 最新の HOT メモ（または指定したファイル・スラッグ）のタイトル、タグ、メタデータ、本文をターミナルに表示。
   - `-path` を指定するとファイルパスのみを出力。
3. **`memo path [query]`**:
   - 最新メモ（または指定メモ）の絶対パスを出力（`code $(memo path)` などのシェル連携用）。
4. **`memo new <slug>`**:
   - 現在時刻（JST）から `YYYY-MM-DD-HHMM_<slug>.md` を自動計算し、Frontmatter 付きのマークダウンテンプレートを即座に作成。
   - `-title="タイトル"`, `-tags="tag1,tag2"`, `-open`（エディタ自動起動）に対応。
5. **`memo decay`**:
   - 48時間を過ぎた HOT メモを自動的に WARM へ、7日を過ぎた WARM メモを COLD へ一括ステータス更新。
   - `-dry-run` による事前シミュレーションに対応。

---

## 2. 使い方

```bash
# 1. ワークスペースルートから実行
./scripts/memo list
./scripts/memo show
./scripts/memo new "sunday-reflection" -title="日曜夕方の振り返り" -tags="reflection,weekend"
./scripts/memo decay -dry-run

# 2. GOPATH/bin にインストール済みのため、PATHが通っていれば直接実行可能
memo list
memo show
memo path
```

---

## 3. ディレクトリ構成

```text
space/memo-cli/
├── go.mod
├── go.sum
├── README.md
├── AGENTS.md
├── discussion.md
├── cmd/
│   └── memo/
│       └── main.go         # サブコマンドのディスパッチとフラグ処理
├── pkg/
│   └── memo/
│       ├── memo.go         # Frontmatter, Memo 構造体, YAMLパース
│       ├── store.go        # ディレクトリ自動探索, 一覧取得, 新規作成, 減衰処理
│       └── formatter.go    # ターミナルカラーバッジ・テーブルレンダラー
└── scripts/
    └── verify-all.sh       # 静的検証・ビルド・スモークテスト
```

---

## 4. 検証

```bash
./scripts/verify-all.sh
```
