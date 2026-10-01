# Antigravity CLI ヘッドレス実行オプション仕様

本ドキュメントは、Antigravity CLI (`agy`) を外部スクリプト、Web サーバー、デーモンプロセスから非対話的（ヘッドレス）に呼び出すためのコマンドラインオプションの仕様、入出力形式、およびセッション管理の知見をまとめた技術ノートです。

---

## 1. ヘッドレス実行を支える主要フラグ一覧

`agy` は通常ターミナルでの対話型 TUI として動作しますが、プロセス間通信 (IPC) やバッチ自動化のためのネイティブオプションを標準搭載しています。

| オプション | 引数 / 形式 | 機能・挙動 | サーバー / Bot 連携における役割 |
| :--- | :--- | :--- | :--- |
| **`--print` (`-p`)** | 文字列 (`<prompt>`) | プロンプトを非対話的に 1 回実行して結果を出力し終了 | API リクエストを引数として受け取り、同期的に処理する基本モード。 |
| **`--output-format`** | `text`, `json`, `stream-json` | 出力フォーマットの指定 (デフォルト: `text`) | `json` はトークン消費量や所要時間を含む構造化データ。`stream-json` はイベント単位の NDJSON。 |
| **`--input-format`** | `text`, `stream-json` | 標準入力 (stdin) からの受付形式 | `stream-json` を指定すると、常駐プロセスとして stdin から NDJSON を 1 行ずつ読み込み継続ターンを実行。 |
| **`--dangerously-skip-permissions`** | なし (フラグ) | ツール実行時の対話確認プロンプトを自動承認 | ファイル編集やコマンド実行時にプロンプト待ちでブロックされるのを完全に防止。 |
| **`--effort`** | `low`, `medium`, `high`, `max` | 推論・思考（Thinking）の深さ | `low` は思考トークンを最小化し高速応答。`high` は網羅的コード調査。 |
| **`--conversation`** | 会話 ID (`<uuid>`) | 以前の会話セッションの再開・継続 | Discord スレッドや Web チャットセッション単位で文脈を引き継ぐ際に指定。 |
| **`--json-schema`** | JSON スキーマ文字列 / ファイルパス | エージェントの最終出力を特定スキーマに強制 | 型安全な API レスポンスや後続パイプライン連携に利用。 |

---

## 2. 出力フォーマットの使い分け

### 2.1 JSON 形式 (`--output-format json`)
REST API のエンドポイントなど、同期的なリクエスト/レスポンスに適した形式です。
所要時間やトークン消費量が詳細に含まれます。

```bash
agy -p "Respond with exactly: PONG" --output-format json --dangerously-skip-permissions
```

**出力例**:
```json
{
  "conversation_id": "c0f19e05-f9d2-4132-93d5-8f3b54e93b49",
  "status": "SUCCESS",
  "response": "PONG\n",
  "duration_seconds": 2.159419,
  "num_turns": 1,
  "usage": {
    "input_tokens": 16472,
    "output_tokens": 102,
    "thinking_tokens": 100,
    "cache_read_tokens": 0,
    "total_tokens": 16574
  }
}
```

### 2.2 ストリーミング形式 (`--output-format stream-json`)
思考プロセス、ツール実行、生成テキストをリアルタイムにクライアントへストリーミング（SSE / WebSocket）する際に適した形式です。
Newline Delimited JSON (NDJSON) で 1 行 1 イベントとして逐次出力されます。

```bash
agy -p "Count from 1 to 3" --output-format stream-json --dangerously-skip-permissions
```

**出力ストリーム例**:
```json
{"event":"init","conversation_id":"e399cb17-8a78-408c-800e-1a8b5686c937","init":{"cwd":"/workspace","tools":[...]}}
{"event":"step_update","step_update":{"conversation_id":"e399cb17-...","step_index":0,"state":"DONE","step_type":"user_input"}}
{"event":"step_update","step_update":{"conversation_id":"e399cb17-...","step_index":1,"state":"ACTIVE","step_type":"agent_response","text_delta":"1, 2, 3"}}
{"event":"result","result":{"conversation_id":"e399cb17-...","status":"SUCCESS","response":"1, 2, 3\n"}}
```

---

## 3. 会話セッションの継続 (`--conversation`)

会話 ID を指定することで、複数ターンにわたるステートフルな対話が可能です。

```bash
# 1 ターン目
agy -p "My name is Aoba." --output-format json --dangerously-skip-permissions
# 返却された conversation_id: "c0f19e05-f9d2-4132-93d5-8f3b54e93b49"

# 2 ターン目 (文脈を維持)
agy -p "What is my name?" --conversation "c0f19e05-f9d2-4132-93d5-8f3b54e93b49" --output-format json --dangerously-skip-permissions
# 回答: "Your name is Aoba."
```

---

## 4. 参考リソース

* [Google Antigravity CLI Reference](https://antigravity.google/docs/cli/reference)
* [Google Antigravity CLI Best Practices](https://antigravity.google/docs/cli/best-practices)
