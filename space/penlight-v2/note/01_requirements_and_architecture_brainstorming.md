# Penlight Quiz v2 要件定義とアーキテクチャ壁打ちノート (01_requirements_and_architecture_brainstorming.md)

本ドキュメントは、坂道ペンライトクイズ完全刷新プロジェクト（Penlight Quiz v2）における 5 つのコア要件（k8s 完結、軽量 DB、GitHub Registry、Next.js/Mantine の UI 継承、TypeScript/Go バックエンド）を深掘りし、レガシー版の課題を解消する新アーキテクチャの選定案をまとめたものです。

---

## 1. ユーザー定義のコア要件と理想

| 項目 | ユーザーの理想・要件 | 設計方針・アーキテクチャへの反映 |
| :--- | :--- | :--- |
| **1. k8s 完結** | クラウド依存を廃止し、k8s クラスタ内で自己完結 | 自宅 Proxmox k8s クラスタ上で Deployment / Service / Ingress / ArgoCD GitOps 完結 |
| **2. 軽量 DB** | オブジェクトストレージを使わない前提で、SQLite または軽量 RDS | BigQuery 依存を完全廃止。マスタデータ・出題に特化した **SQLite**（または軽量 Postgres）を採用 |
| **3. Registry は GitHub** | コンテナレジストリを GitHub に集約 | GCP GCR/Artifact Registry を廃止し、**GitHub Packages (`ghcr.io`)** と GitHub Actions で完結 |
| **4. Frontend の継承** | 今の UI/UX の良さを引き継ぐ | **Next.js (App Router) + Mantine v8 + Zustand + react-rewards** の洗練された UI と演出を継承 |
| **5. Backend の言語** | **TypeScript 完結** または **Go** | 型共有と開発速度を優先する TS 完結案 vs 超軽量・低リソースの Go 案の比較選定 |

---

## 2. レガシー版 (v1) の構造分析と脱却ポイント

旧実装（`sakamichi-penlight-quiz`）のコードベース調査により、以下の歪み（レガシー負債）が特定されました。

1. **Next.js からの BigQuery 直結 (`@google-cloud/bigquery`)**:
   - フロントエンド（Next.js）の `package.json` に `@google-cloud/bigquery` が含まれ、本来分析用 DWH である BigQuery を Web アプリのオンライン DB として直叩きしていた。
   - これにより GCP プロジェクト、サービスアカウント鍵、GCP 課金が必須となり、ローカル開発や自宅 k8s への移行を阻害していた。
2. **GCR / 非推奨レジストリへの依存**:
   - `push-to-gcr.sh` など、非推奨となった Google Container Registry (GCR) に結合していた。
3. **データ更新フローの断絶**:
   - Dataform パイプラインを介していたため、新メンバーの追加やカラー変更の反映が複雑化していた。

---

## 3. アーキテクチャ選定案の比較 (TypeScript 完結 vs Go)

### パターン A: TypeScript 完結型 (Next.js フルスタック / Hono API)
```
[ Browser ] 
     │ (HTTPS)
[ Next.js App Router (Pod) ]
     │ (Server Actions / Route Handlers)
[ SQLite Database (better-sqlite3 / Drizzle ORM) ]
```
* **メリット**:
  * **単一言語・単一リポジトリ**: フロントとバックで型定義（`Member`, `PenlightColor`, `QuizQuestion`）を 100% 共有。
  * **ポッド数最小**: Next.js 1 ポッドの中に API も SQLite も完結でき、k8s のリソース消費が極めて小さい。
  * **Discord Bot との親和性**: 共通の TS ロジックや DB を Discord Bot からそのまま import 可能。
* **懸念点**:
  * Next.js の Node.js ランタイムメモリ消費（約 100〜200MB）。

### パターン B: Go マイクロサービス + Next.js フロントエンド分離型
```
[ Browser ] ──(HTTPS)──> [ Next.js Frontend (Pod) ]
                               │ (REST / gRPC)
                         [ Go API Backend (Pod) ]
                               │
                         [ SQLite / PostgreSQL ]
```
* **メリット**:
  * **圧倒的な省リソース・高パフォーマンス**: Go API は 10〜20MB のメモリで数千 RPS を処理。
  * **強固な境界**: バックエンドのデータモデルがフロントエンドのビルド・デプロイから完全に独立。
* **懸念点**:
  * 2 ポッド構成となり、API スキーマ同期（OpenAPI 等）の手間が発生。

---

## 4. データベース設計方針 (SQLite の適用性)

ペンライトクイズのデータ特性:
* **データ量**: 坂道 3 グループ（乃木坂・櫻坂・日向坂）の現役・卒業生合わせても **約 200〜300 レコード程度**。
* **アクセス特性**: 99.9% が読み取り（Read-heavy）。更新はメンバー加入・卒業・カラー変更時（月数回程度）。

> **結論**:
> オブジェクトストレージや巨大な RDS は完全に不要。**SQLite**（ファイルサイズ数 MB 未満）をコンテナ内マウント、またはイメージ内に静的シードデータとしてバンドルすることで、レイテンシ 0ms・外部 DB 依存ゼロの究極にシンプルな k8s 運用が実現できます。

---

## 5. 次の検討論点

1. **バックエンド構成の確定**:
   - Next.js フルスタック（TS 完結）でミニマルにいくか、Go + Next.js のマイクロサービス構成にするか。
2. **マスタデータの管理元**:
   - YAML / JSON ファイルで Git 管理し、ビルド時に SQLite を生成する構成にするか。
3. **k8s デプロイ方針**:
   - 既存の Proxmox 自宅クラスタへのマニフェスト（Helm / Kustomize / plain YAML）および Cloudflare Tunnel / Ingress 設定。
