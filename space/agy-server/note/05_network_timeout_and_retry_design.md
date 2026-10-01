# gRPC / SSE ストリーミング接続のタイムアウト原因と自動リトライ設計

本ドキュメントは、Antigravity CLI (`agy`) をバックエンドとして長時間または連続で稼働させる際に発生するネットワーク通信エラー (`read: operation timed out`) のメカニズム、エラー分類、および自動再試行（Exponential Backoff リトライ）の耐障害性設計をまとめた技術ノートです。

---

## 1. 発生事象とエラーログの解析

### 1.1 発生したエラー
`agy` の実行中にプロセスが終了コード 3 で異常終了し、以下の標準エラー出力が記録されました:

```
error: There was a network issue connecting to the server, please try again.
AGY_ERROR: {
  "short_error": "agent executor error: generating and executing: request failed: Post \"https://daily-cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse\": read tcp 192.168.11.16:55471->172.217.112.4:443: read: operation timed out",
  "status": "UNKNOWN",
  "error_code": 2,
  "code_kind": "grpc",
  "retryable": true,
  "error_id": "56b29732-4d4a-437a-9f32-0f66e6247880-3"
}
```

### 1.2 エラーの根本原因
1. **長時間の推論コネクション**:
   - 推論エフォート（`effort: high`）で複雑なプロンプトを処理する際、Google Cloud バックエンド（`daily-cloudcode-pa.googleapis.com`）との間で HTTP/2 または gRPC の SSE (Server-Sent Events) ストリーミング接続を長時間維持し続けます。
2. **ソケットタイムアウト**:
   - 家庭内ルーター、NAT、Wi-Fi の瞬断、または Google API 側のアイドルタイムアウト上限に達し、TCP 読み取り待機中に `read: operation timed out` が発生しました。
3. **`retryable: true` の意味**:
   - JSON ログに明記されている通り、このエラーは「モデルが壊れた」「認証が無効になった」のではなく、**「一時的な通信瞬断であり、直ちに再試行すれば成功する」** タイプの一時的障害 (Transient Fault) です。

---

## 2. 自動リトライ機構の実装設計

ユーザーに生のエラーログ（AGY_ERROR JSON）をそのまま見せるのではなく、Bot 側で自動的に検知して再試行を行います。

### 2.1 リトライ判定ロジック
エラーメッセージに以下の一時障害キーワードが含まれている場合にリトライ対象と判定します:
- `network issue`
- `timed out` / `operation timed out`
- `"retryable":true`
- `connection reset`

### 2.2 実装パターン (Node.js)

```javascript
async function executeAgyWithRetry(prompt, conversationId = null, effort = 'low', maxRetries = 2) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await executeAgyOnce(prompt, conversationId, effort);
    } catch (err) {
      const errMsg = err.message || '';
      const isRetryable = errMsg.includes('network issue') || 
                          errMsg.includes('timed out') || 
                          errMsg.includes('retryable":true') ||
                          errMsg.includes('connection reset');

      if (isRetryable && attempt < maxRetries) {
        console.warn(`[agy] Attempt ${attempt} failed with retryable error. Retrying in 2s...`);
        await new Promise(r => setTimeout(r, 2000));
        continue;
      }
      throw err;
    }
  }
}
```

### 2.3 ユーザー向けエラーメッセージのサニタイズ
最大試行回数（2回）を超えて通信エラーが継続した場合、スタックトレースではなく親切なメッセージをチャットに返します:

```javascript
let userError = 'タスクの実行中にエラーが発生しました。';
if (err.message && (err.message.includes('network issue') || err.message.includes('timed out'))) {
  userError = '一時的なネットワーク通信タイムアウトが発生しました。数秒置いて再度お試しください。';
}
await interaction.editReply(userError);
```

---

## 3. 参考リソース

* [gRPC Error Handling Best Practices](https://grpc.io/docs/guides/error-handling/)
* [AWS Architecture Center: Exponential Backoff And Jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)
* [Microsoft Azure Architecture Center: Transient Fault Handling](https://learn.microsoft.com/en-us/azure/architecture/best-practices/transient-faults)
