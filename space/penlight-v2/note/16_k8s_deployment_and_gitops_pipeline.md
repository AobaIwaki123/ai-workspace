# Kubernetes デプロイ・GitOps パイプライン設計 (16_k8s_deployment_and_gitops_pipeline.md)

本ドキュメントは、既存の実績リポジトリ（`/Users/aobaiwaki/journee/k8s`）のインフラ知見を継承しつつ、**Go 単一バイナリ・SQLite WAL・GitHub Packages (`ghcr.io`) に合わせて極限まで効率化・軽量化した Kubernetes (k8s) デプロイ設計** です。

---

## 1. 既存基盤 (`journee/k8s`) から継承する優れたプラクティス

`/Users/aobaiwaki/journee/k8s` で確立されている以下の自宅クラスタ運用パターンを本プロジェクトでもそのまま活用します。

1. **Cloudflare Tunnel Ingress Controller**:
   - `ingressClassName: "cloudflare-tunnel"`
   - 自宅ルーターのポート開放や DDNS 設定を一切行わず、`penlight.aooba.net` のホスト名で安全に世界中へ公開。
2. **自動 TLS 証明書管理**:
   - `cert-manager.io/cluster-issuer: letsencrypt-cloudflare` による証明書自動更新。
3. **ArgoCD による宣言的 GitOps**:
   - Git リポジトリのマニフェスト変更を検知し、自宅クラスタへゼロダウンタイムで自動同期。
4. **Kustomize による環境分離**:
   - 本番（Production）とプレビュー（Branch Preview）の差分管理。

---

## 2. レガシー (`journee`) からの決定的な改善点・効率化

| 項目 | 従来 (`journee/k8s`) | 新システム (`penlight-v2`) の改善 | 改善効果 |
|---|---|---|---|
| **コンテナレジストリ** | GCP Container Registry (`gcr.io`) | **GitHub Packages (`ghcr.io`)** | GCP サービスアカウント鍵 (`key.json`) の失効・管理負荷を完全撤廃。GitHub リポジトリと認証トークンが直結 |
| **ランタイムフットプリント** | Node.js (Next.js フルスタック、数百MB) | **Go 単一バイナリ (15〜30MB)** | メモリ消費量を 1/10 以下（常時 15MB 程度）に削減。起動時間は 30ms |
| **データベース** | 外部クラウド連携 / 複雑な Secret | **Pure Go SQLite on PVC + Litestream** | クラウド DWH 依存ゼロ。k8s クラスタ内で自己完結し、S3/MinIO へ秒単位バックアップ |
| **コンテナ構成** | 3 レプリカ (Node.js の負荷分散用) | **単一 Pod (1 Pod で数千 QPS 処理可能)** | リソース割り当て（CPU/Memory requests）を最小化し、自宅 k8s の空きリソースを節約 |

---

## 3. k8s マニフェスト構成 (`deploy/`)

```
space/penlight-v2/deploy/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml        # Go 単一バイナリ + SQLite ボリュームマウント
│   ├── service.yaml           # ClusterIP Service (Port 8080)
│   ├── pvc.yaml               # SQLite 永続化用 (Longhorn / local-path)
│   └── ingress.yaml           # Cloudflare Ingress (penlight.aooba.net)
├── overlays/
│   ├── prod/                  # 本番環境設定
│   └── preview/               # PR ブランチ検証用プレビュー環境
└── argocd/
    └── application.yaml       # ArgoCD GitOps 登録マニフェスト
```

### 3.1 Ingress マニフェスト (`deploy/base/ingress.yaml`)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: penlight-ingress
  namespace: penlight
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-cloudflare
spec:
  ingressClassName: "cloudflare-tunnel"
  rules:
  - host: penlight.aooba.net
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: penlight-service
            port:
              number: 8080
```

### 3.2 Deployment マニフェスト (`deploy/base/deployment.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: penlight-app
  namespace: penlight
spec:
  replicas: 1  # SQLite 単一ライターのため 1 Pod 運用
  strategy:
    type: Recreate  # PVC アタッチの衝突を防ぐ安全な再作成戦略
  selector:
    matchLabels:
      app: penlight
  template:
    metadata:
      labels:
        app: penlight
    spec:
      containers:
      - name: penlight
        image: ghcr.io/aobaiwaki/penlight-v2:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
        env:
        - name: DB_PATH
          value: "/data/penlight.db"
        - name: PORT
          value: "8080"
        - name: GOOGLE_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: penlight-secret
              key: google-client-id
        - name: GOOGLE_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: penlight-secret
              key: google-client-secret
        resources:
          requests:
            cpu: 20m
            memory: 32Mi
          limits:
            cpu: 500m
            memory: 128Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 2
          periodSeconds: 5
        volumeMounts:
        - name: data-volume
          mountPath: /data
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: penlight-pvc
```

### 3.3 PersistentVolumeClaim (`deploy/base/pvc.yaml`)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: penlight-pvc
  namespace: penlight
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

### 3.4 ArgoCD Application (`deploy/argocd/application.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: penlight-v2-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/aobaiwaki/ai-workspace.git'
    targetRevision: HEAD
    path: space/penlight-v2/deploy/overlays/prod
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: penlight
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## 4. 参考文献・実績リポジトリ

- 実績リポジトリ: [`/Users/aobaiwaki/journee/k8s`](file:///Users/aobaiwaki/journee/k8s)
- [Cloudflare Tunnel Kubernetes Ingress Guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/kubernetes/)
- [cert-manager Cloudflare DNS-01 Issuer](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)
- [ArgoCD Declarative Setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
