# Discord MCP Tools Reference

本ドキュメントは、`discord-mcp` が提供する全 MCP ツールの仕様、引数定義、戻り値の形式、および Bot Token 利用時の可否マトリクスをまとめたリファレンスです。

---

## 1. ツール利用可否マトリクス

Discord の仕様上、認証種別（Bot Token / User Token）により実行可能なツールが異なります。公式かつ推奨される **Bot Token** 運用時の対応状況は以下の通りです。

| ツール名 | カテゴリ | Bot Token 利用 | 必須権限 / 条件 | 備考 |
| :--- | :--- | :---: | :--- | :--- |
| `discord_send_message` | メッセージ | 可 | `SEND_MESSAGES` | 最大2000文字。添付ファイル最大10件 |
| `discord_edit_message` | メッセージ | 可 | 自Botのメッセージ | 他者のメッセージは編集不可 |
| `discord_delete_message` | メッセージ | 可 | 自Botのメッセージ (他者は `MANAGE_MESSAGES`) | 削除操作 |
| `discord_add_reaction` | メッセージ | 可 | `ADD_REACTIONS`, `READ_MESSAGE_HISTORY` | Unicode絵文字またはカスタム絵文字 |
| `discord_remove_reaction` | メッセージ | 可 | `MANAGE_MESSAGES` (他者の場合) | 自身または指定ユーザーのリアクション削除 |
| `discord_get_message` | メッセージ | 可 | `READ_MESSAGE_HISTORY` | 特定メッセージの詳細・添付ファイル取得 |
| `discord_get_message_history` | メッセージ | 可 | `READ_MESSAGE_HISTORY` | 1回あたり最大100件取得 |
| `discord_search_messages` | メッセージ | 可 | `READ_MESSAGE_HISTORY` | ギルド検索API。失敗時は履歴検索へ自動フォールバック |
| `discord_get_channel` | チャンネル | 可 | `VIEW_CHANNEL` | チャンネルメタデータの取得 |
| `discord_create_dm` | チャンネル | 可 | なし | ユーザーIDを指定してDMチャンネルを開設 |
| `discord_get_dm_channels` | チャンネル | **不可** | なし (Bot禁止エンドポイント) | Discord API が 403 / 400 を返却 |
| `discord_download_attachment` | ファイル | 可 | なし (公開CDN URL) | Discord CDN から一時ファイルへダウンロード |
| `discord_cleanup_download` | ファイル | 可 | なし | ダウンロード一時ファイルの削除 |
| `discord_get_friends` | フレンド | **不可** | なし (Botにフレンド機能なし) | Discord API が 403 / 400 を返却 |
| `discord_add_friend` | フレンド | **不可** | なし (Botにフレンド機能なし) | Discord API が 403 / 400 を返却 |
| `discord_remove_friend` | フレンド | **不可** | なし (Botにフレンド機能なし) | Discord API が 403 / 400 を返却 |
| `discord_update_presence` | プレゼンス | 効果なし | なし (Gateway未接続) | `discord-mcp` 内部でログ出力のみ |
| `discord_clear_presence` | プレゼンス | 効果なし | なし (Gateway未接続) | `discord-mcp` 内部でログ出力のみ |

---

## 2. 各ツールの詳細仕様

### `discord_send_message`
指定チャンネルにメッセージを送信します。

- **引数**:
  - `channelId` (string, 必須): 送信先チャンネルID
  - `content` (string, 任意, default: `""`): メッセージ本文（最大2000文字）
  - `replyTo` (string, 任意): 返信先メッセージID
  - `tts` (boolean, 任意): テキスト読み上げ送信
  - `files` (array, 任意, 最大10件): 添付ファイル指定配列
    - `file` (string, 必須): MCPファイル参照
    - `filename` (string, 必須): アップロード時のファイル名
    - `spoiler` (boolean, 任意): スポイラー設定
- **呼び出し例**:
```json
{
  "channelId": "1555181295590580295",
  "content": "テストメッセージです。"
}
```

---

### `discord_edit_message`
過去に送信したメッセージを編集します。

- **引数**:
  - `channelId` (string, 必須): 対象チャンネルID
  - `messageId` (string, 必須): 編集対象メッセージID
  - `content` (string, 必須): 新しいメッセージ本文（最大2000文字）
- **呼び出し例**:
```json
{
  "channelId": "1555181295590580295",
  "messageId": "1555186101402996747",
  "content": "更新後のメッセージ本文です。"
}
```

---

### `discord_delete_message`
メッセージを削除します。

- **引数**:
  - `channelId` (string, 必須): 対象チャンネルID
  - `messageId` (string, 必須): 削除対象メッセージID
- **呼び出し例**:
```json
{
  "channelId": "1555181295590580295",
  "messageId": "1555186101402996747"
}
```

---

### `discord_add_reaction`
メッセージにリアクション（絵文字）を付与します。

- **引数**:
  - `channelId` (string, 必須): 対象チャンネルID
  - `messageId` (string, 必須): 対象メッセージID
  - `emoji` (string, 必須): Unicode絵文字（例: `👍`）またはカスタム絵文字（例: `name:id`）
- **呼び出し例**:
```json
{
  "channelId": "1555181295590580295",
  "messageId": "1555186101402996747",
  "emoji": "👍"
}
```

---

### `discord_remove_reaction`
メッセージからリアクションを削除します。

- **引数**:
  - `channelId` (string, 必須): 対象チャンネルID
  - `messageId` (string, 必須): 対象メッセージID
  - `emoji` (string, 必須): 削除する絵文字
  - `userId` (string, 任意, default: `@me`): 削除対象ユーザーID（省略時はBot自身のリアクションを削除）

---

### `discord_get_message`
特定メッセージの詳細情報（送信者、日時、本文、添付ファイル一覧）を取得します。

- **引数**:
  - `channelId` (string, 必須): 対象チャンネルID
  - `messageId` (string, 必須): 対象メッセージID
- **戻り値**: 送信者、タイムスタンプ、本文、添付ファイルのURL・サイズ等を含む整形テキスト。

---

### `discord_get_message_history`
指定チャンネルの過去メッセージ履歴を取得します。

- **引数**:
  - `channelId` (string, 必須): 対象チャンネルID
  - `limit` (number, 任意, 1〜100, default: 50): 取得件数
  - `before` (string, 任意): このメッセージIDより前のメッセージを取得
  - `after` (string, 任意): このメッセージIDより後のメッセージを取得
  - `around` (string, 任意): このメッセージIDの周辺メッセージを取得
- **呼び出し例**:
```json
{
  "channelId": "1555181295590580295",
  "limit": 20
}
```

---

### `discord_search_messages`
指定チャンネル内のメッセージをキーワード検索します。

- **引数**:
  - `channelId` (string, 必須): 対象チャンネルID
  - `query` (string, 必須): 検索文字列
  - `limit` (number, 任意, 1〜25, default: 25): 取得件数
  - `authorId` (string, 任意): 特定送信者IDによる絞り込み
  - `hasAttachments` (boolean, 任意): 添付ファイル付きメッセージに限定
  - `hasImages` (boolean, 任意): 画像付きメッセージに限定
  - `hasFiles` (boolean, 任意): ファイル付きメッセージに限定
  - `before` (string, 任意): ISO形式日付以前
  - `after` (string, 任意): ISO形式日付以降
- **特徴**: Discord API のギルド検索エンドポイントを呼び出します。Bot権限等の理由でギルド検索が失敗した場合は、自動的に直近100件の履歴検索フィルタへフォールバックします。

---

### `discord_get_channel`
チャンネルのメタデータ（チャンネル名、種別、トピック等）を取得します。

- **引数**:
  - `channelId` (string, 必須): 対象チャンネルID
- **戻り値**: Discord チャンネルオブジェクトの JSON 文字列。

---

### `discord_create_dm`
特定ユーザーとのダイレクトメッセージ（DM）チャンネルを開設・取得します。

- **引数**:
  - `userId` (string, 必須): 対象ユーザーID
- **戻り値**: 開設または既存のDMチャンネルID（`✅ DM channel created (ID: ...)`）
- **後続操作**: 返却されたチャンネルIDを `discord_send_message` に渡すことで、個別ユーザーへのDM送信が可能です。

---

### `discord_download_attachment` / `discord_cleanup_download`
添付ファイルの一時保存およびクリーンアップを行います。

- **`discord_download_attachment`**:
  - `url` (string, 必須): Discord CDN の添付ファイル URL
  - 戻り値: 一時ディレクトリへ保存されたファイルパス
- **`discord_cleanup_download`**:
  - `path` (string, 必須): 削除対象のファイルパス
