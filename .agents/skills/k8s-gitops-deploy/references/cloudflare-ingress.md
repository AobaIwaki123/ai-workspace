# Cloudflare Tunnel Ingress Reference

Kubernetes クラスタ内のサービスを Cloudflare Zero Trust (Cloudflare Tunnel) 経由で安全に外部公開するためのマニフェスト仕様と設定リファレンスです。

---

## 1. Cloudflare Ingress の基本マニフェスト

コントローラーとして `cloudflare-tunnel-ingress-controller`（`strrl.dev`）がデプロイされているクラスタにおいて、以下の標準 Ingress リソースで外部ドメインが自動ルーティングされます。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <app-name>
  namespace: <app-name>
  annotations:
    cloudflare-tunnel-ingress-controller.strrl.dev/backend-protocol: "http"
    cloudflare-tunnel-ingress-controller.strrl.dev/tunnel-name: "cf-tunnel-ingress-controller"
spec:
  ingressClassName: cloudflare-tunnel
  rules:
    - host: <subdomain>.aooba.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: <service-name>
                port:
                  number: 80
```

---

## 2. アノテーション仕様

| アノテーション | 設定値 | 説明 |
|---|---|---|
| `cloudflare-tunnel-ingress-controller.strrl.dev/backend-protocol` | `http` (デフォルト), `https`, `grpc`, `tcp` | クラスタ内 Service へトンネルから転送する際の通信プロトコル |
| `cloudflare-tunnel-ingress-controller.strrl.dev/tunnel-name` | `cf-tunnel-ingress-controller` | 利用する Cloudflare Tunnel の識別名 |
| `cloudflare-tunnel-ingress-controller.strrl.dev/proxy-ssl-verify` | `"true"` / `"false"` | バックエンドが自己署名 HTTPS の場合に TLS 検証をスキップ |

---

## 3. マニフェスト一括構成（All-in-One パターン）

GitOps では、単一リポジトリの `k8s/app.yaml` に以下をまとめて定義するのが標準的です：

1. **`Namespace`**: アプリケーション専用の名前空間
2. **`Deployment`**: コンテナ実行定義（ポート、TZ、リソース制限、Probes）
3. **`Service`**: クラスタ内ポート 80 ➔ コンテナポート転送
4. **`Ingress`**: `ingressClassName: cloudflare-tunnel` による外部公開

---

## 4. トラブルシューティング

### 502 Bad Gateway が返る場合
- **Service 名・ポートの不一致**: Ingress の `backend.service.name` および `number` が `Service` の定義と一致しているか確認。
- **ReadinessProbe 失敗**: Pod がまだ Ready 状態になっていない可能性があります。`kubectl describe pod -n <namespace>` で確認。

### 530 / 1033 Cloudflare エラーが返る場合
- **Tunnel コントローラーの稼働確認**: `kubectl get pods -n cloudflare-tunnel-ingress-controller` でトンネル Pod が正常稼働しているか確認。
- **CNAME / DNS 未反映**: 新規ホストの場合、Cloudflare 側の DNS レコード生成に数秒〜数十秒かかる場合があります。
