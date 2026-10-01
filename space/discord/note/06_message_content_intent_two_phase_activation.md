# Discord Message Content Intent の 2 段階有効化ルールと Token ライフサイクル

本ドキュメントは、Discord Bot においてメッセージ本文を取得するために必要な **Message Content Intent（特権インテント）の 2 段階有効化メカニズム**、トークン再生成や反映遅延に関する仕様、および権限境界の知見をまとめた技術ノートです。

---

## 1. Message Content Intent の 2 段階有効化ルール

Discord API において、Bot がメッセージ本文 (`message.content`) を受信するには、**「サーバー側の許可」と「クライアント側の要求」の双方が完全に一致して初めて成立する** 仕様になっています。

| ステップ | 担当領域 | 設定箇所・操作 | 未設定時の挙動 |
| :--- | :--- | :--- | :--- |
| **ステップ 1: サーバー側の許可** | Discord Developer Portal | `Applications -> Bot -> Privileged Gateway Intents -> MESSAGE CONTENT INTENT` を ON にして保存 | クライアント側で要求しても `[DISALLOWED_INTENTS]` (code 4014) で Gateway 接続が拒否される。 |
| **ステップ 2: クライアント側の要求** | Bot プログラムコード | `Client` 初期化時の `intents` 配列に `GatewayIntentBits.MessageContent` を指定 | **Portal で ON にしていても、Gateway は「この Bot は本文を不要としている」と判断し、`message.content` を空文字 (`""`) で配信する。** |

### 今回発生した事象の根本原因
Developer Portal でトグルを ON にしたにもかかわらず、Bot が「プロンプトを指定してください」と返答していたのは、**ステップ 2（コード側の `GatewayIntentBits.MessageContent` の追加）が未反映のまま動作していたため** でした。

コード側に以下を反映して再起動することで即時解決しました:

```javascript
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent, // 必須
  ],
  partials: [Partials.Channel, Partials.Message]
});
```

---

## 2. トークン再生成 (Regenerate) や反映遅延に関する仕様

設定変更が反映されない際に生じやすい 2 つの疑問に対する公式仕様は以下の通りです。

1. **Bot Token の再生成（リセット）は必要か？**:
   - **不要です**。特権インテントの有効・無効は Discord の認可サーバー側でフラグ管理されており、既存の Bot Token の有効性に一切影響しません。
2. **反映に時間がかかるのか？**:
   - **即時（数秒以内）に反映されます**。Developer Portal で「Save Changes」を押した瞬間から、次の Gateway WebSocket ハンドシェイク（Bot 再起動）において有効になります。

---

## 3. 特権インテント (Privileged Gateway Intents) とセキュリティ

Discord はスパム防止とプライバシー保護のため、以下の 3 つを「特権インテント」として厳格に管理しています:

1. **`MESSAGE_CONTENT`**: メッセージ本文、埋め込み、添付ファイル情報の読み取り。
2. **`GUILD_MEMBERS`**: サーバーメンバーの一覧取得や参加・退出イベントの検知。
3. **`GUILD_PRESENCES`**: ユーザーのオンライン状態やプレイ中アクティビティの取得。

100 サーバー未満の個人・開発用 Bot であれば、審査なしで Developer Portal から自由に有効化できます（100 サーバー以上の公開 Bot の場合は認証審査が必要）。

---

## 4. 参考リソース・一次情報源

* [Discord Developer Portal: Gateway Intents Documentation](https://discord.com/developers/docs/topics/gateway#gateway-intents)
* [Discord Developer Portal: Message Content Privileged Intent FAQ](https://support-dev.discord.com/hc/en-us/articles/4404772028055-Message-Content-Privileged-Intent-FAQ)
* [discord.js Guide: Gateway Intents](https://discordjs.guide/popular-topics/intents.html)
