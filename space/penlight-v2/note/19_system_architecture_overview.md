# システム全体アーキテクチャ統合仕様書 (19_system_architecture_overview.md)

本ドキュメントは、Penlight Quiz v2 における **クライアント層、エッジ・ネットワーク層、バックエンド層、データ永続化層、および開発・自動生成ツールチェーン** の全体像を俯瞰するための総合アーキテクチャ仕様書です。

---

## 1. ランタイム・システム構成概要

| レイヤ | 実行環境 / コンポーネント | 採用技術 | 主な責務・境界 | 状態・データ保持 | 通信 / プロトコル | 根拠 ADR |
|---|---|---|---|---|---|---|
| **Client** | ブラウザ (Mobile / Desktop) | React 19, Next.js (SSG), Mantine v8 | UI描画、オフライン出題、回答一時保存 | CacheStorage (静的/画像), IndexedDB (マスタ/未送信キュー) | HTTPS, JSON | ADR-0007, ADR-0011 |
| **Edge / Ingress** | Cloudflare Edge, k8s Ingress | Cloudflare Tunnel, cert-manager | DNS、TLS終端、不変画像配信キャッシュ | エッジキャッシュ (`immutable`) | HTTP/2, QUIC | ADR-0003, ADR-0008 |
| **Server** | k8s Pod (自宅 Proxmox, 1 Replica) | Go 1.22+, `net/http` | REST API、出題ロジック、画像変換、認証管理 | ステートレス (セッションはCookie/DB照合) | REST (JSON), TypeID | ADR-0002, ADR-0009 |
| **Storage** | k8s PVC (Local Path) | SQLite (WAL), Litestream | マスタ・回答ログ永続化、オブジェクト差分同期 | SQLite ファイル, WebP アセット | ファイル I/O, S3 互換同期 | ADR-0005, ADR-0012 |

> **開発・ビルド時ツールチェーン (非ランタイム)**:
> スキーマ自動同期 (`tygo`, AST解析スクリプト) および静的検査・衛生ツール (`Biome`, `Knip`, `sqlc`, `typos`) はランタイムには含まれず、開発時・CIパイプライン上でのみ機能します（詳細は [ADR-0004](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/adr/0004-go-schema-as-single-source-of-truth.md), [ADR-0013](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/adr/0013-typescript-ai-agent-driven-development-toolchain.md) を参照）。

---

## 2. システム構成ブロック図 (Mermaid)

システム全体の物理境界とネットワーク通信経路を極限までシンプルに表現したブロック図です（内部モジュール細部を排除し、配置と通信に特化）。

```mermaid
flowchart LR
    Client["PWA Client\n(React 19 / IndexedDB)"]
    CF["Cloudflare Edge\n(CDN / Tunnel)"]
    Server["Backend Pod (1 Replica)\nGo Single Binary"]
    Storage[("PVC (Local Path)\nSQLite WAL + WebP Assets")]
    Backup[("Cloudflare R2 / MinIO\n(Litestream S3 Backup)")]

    Client <-->|"HTTPS (penlight.aooba.net)"| CF
    CF <-->|"Encrypted Tunnel"| Server
    Server <-->|"File I/O"| Storage
    Storage -.->|"WAL 秒単位レプリケーション"| Backup
```

---

## 3. クイズ出題・回答・オフライン同期シーケンス図 (Mermaid)

Local-First 設計における「マスタ同期」「出題」「オンライン即時採点」「会場圏外時のローカル退避とバッチ同期」の相互作用シーケンスです。

```mermaid
sequenceDiagram
    autonumber
    actor User as ユーザー
    participant UI as PWA UI (React)
    participant LocalDB as IndexedDB / Cache
    participant Server as Go Backend API
    participant DB as SQLite (WAL)

    %% 1. マスタ同期
    Note over User, DB: 1. 起動時マスタデータ同期
    UI->>Server: GET /api/v1/sync/bootstrap (If-None-Match)
    alt ETag 一致 (更新なし)
        Server-->>UI: 304 Not Modified
    else ETag 不一致 (更新あり)
        Server->>DB: マスタ一括取得 (Groups, Colors, Members)
        DB-->>Server: レコード返却
        Server-->>UI: 200 OK (最新マスタ JSON)
        UI->>LocalDB: IndexedDB マスタキャッシュを更新
    end

    %% 2. 出題 (クライアント完結)
    Note over User, DB: 2. クイズ出題 (完全クライアント完結)
    User->>UI: クイズ開始
    UI->>LocalDB: マスタデータ取得
    LocalDB-->>UI: グループ・メンバー・カラー情報
    UI->>UI: generateQuiz() 純粋関数で 4 択設問を動的生成
    UI-->>User: 設問・画像・選択肢を表示 (サーバー通信なし)

    %% 3. 回答処理 (オンライン vs オフライン)
    Note over User, DB: 3. 回答送信・採点
    User->>UI: 選択肢をタップ
    alt オンライン時 (通常通信)
        UI->>Server: POST /api/v1/quiz/answers
        Server->>DB: INSERT INTO answer_logs (ans_...)
        DB-->>Server: 成功
        Server-->>UI: 200 OK (正誤結果・解説)
        UI-->>User: 正解演出を表示
    else ライブ会場混雑時 (圏外・オフライン)
        UI->>UI: クライアント側でローカル即時採点
        UI-->>User: 正解演出を表示 (体験を阻害しない)
        UI->>LocalDB: ans_... を IndexedDB (Outbox キュー) に退避
    end

    %% 4. バックグラウンドバッチ同期
    Note over User, DB: 4. 回線復旧時の自動バッチ同期
    LocalDB->>UI: 回線回復イベント検知 (navigator.onLine)
    UI->>LocalDB: 未送信キュー (AnswerLog[]) を取得
    LocalDB-->>UI: キュー返却
    UI->>Server: POST /api/v1/quiz/answers/batch (未送信配列)
    Server->>DB: INSERT OR IGNORE INTO answer_logs (ans_... 冪等コミット)
    DB-->>Server: コミット完了
    Server-->>UI: 200 OK (synced_ids)
    UI->>LocalDB: 送信完了レコードをキューから削除
```

---

## 4. データフローと状態ライフサイクル仕様

### 4.1 クイズ出題・回答同期ライフサイクル (Online / Offline Sync)

| フェーズ | アクター / トリガー | 処理内容 / 通信 | 入力 / 出力 | 永続化先 | 障害・オフライン時ハンドリング |
|---|---|---|---|---|---|
| **マスタ同期** | クライアント起動 / 定期取得 | `GET /api/v1/sync/bootstrap` | In: `If-None-Match: <ETag>`<br>Out: 304 Not Modified または マスタJSON (`groups`, `colors`, `members`) | クライアント `IndexedDB:master` | 通信切断時はローカル IndexedDB の既存データを継続利用 |
| **出題生成** | クイズ画面遷移 | クライアント側純粋関数 (`generateQuiz`) による抽出 | In: 選択グループ/期生ID, ColorMap<br>Out: `QuizQuestion` (4択設問データ) | クライアント メモリ (Zustand) | 完全クライアント完結 (サーバーアクセス不要) |
| **回答処理 (オンライン)** | ユーザー選択 | `POST /api/v1/quiz/answers` | In: `quiz_id`, `member_id`, `selected_choice`<br>Out: 採点結果, 正解メタデータ, `ans_...` | サーバー SQLite `answer_logs` | 通信失敗・タイムアウト時は「回答一時退避」へフォールバック |
| **回答一時退避 (オフライン)** | 回答時の通信エラー / 圏外判定 | ローカル採点およびキューイング | In: 回答データ<br>Out: 画面上への採点結果即時反映 | クライアント `IndexedDB:outbox` | 最大1,000件保持 (FIFO)。未同期フラグ付きで保持 |
| **バッチ同期** | ネットワーク復旧 (`online` イベント) | `POST /api/v1/quiz/answers/batch` | In: `AnswerLog[]` (未同期キュー)<br>Out: 同期完了IDリスト (`ans_id[]`) | サーバー SQLite `answer_logs` | クライアント生成の TypeID (`ans_...`) による主キー重複排除 (冪等性保証) |

### 4.2 メンバー・画像アセット登録ライフサイクル (Asset Pipeline)

| フェーズ | 担当コンポーネント | 処理内容 | 入出力 | 格納先 / キャッシュ制御 |
|---|---|---|---|---|
| **1. リクエスト受付** | Go API (`POST /api/v1/admin/members`) | 認証検証 (Admin権限) およびマルチパートフォーム受信 | In: フォームデータ (`name`, `group_id`, `color_ids`, 画像バイナリ) | 一時メモリバッファ |
| **2. 画像最適化** | Go パイプライン (`pkg/image`) | EXIFメタデータ完全除去、長辺400pxへの縮小リサイズ、WebPエンコード (品質82) | In: 原本バイナリ (JPEG/PNG)<br>Out: WebP バイナリ | ファイル名決定: `mem_<uuidv7>.webp` |
| **3. アセット保存** | Go ファイル I/O | ディスク書き込み | In: WebP バイナリ | k8s PVC (`/data/assets/mem_<uuidv7>.webp`) |
| **4. レコード登録** | Go SQLite リポジトリ | `Member` レコードをトランザクション内で作成 | In: `Member` struct (`image_url: /assets/mem_...webp`) | SQLite `members` テーブル |
| **5. 配信・キャッシュ** | Go 静的ハンドラ + Cloudflare Edge | HTTP ヘッダー付与による配信 | In: `GET /assets/mem_*.webp`<br>Out: 200 OK + WebP | `Cache-Control: public, max-age=31536000, immutable`<br>Cloudflare エッジキャッシュ 1年間保持 (パージ不要) |

---

## 5. 参考文献・関連ドキュメント

- [ADR 一覧・分類インデックス](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/adr/README.md)
- [正本スキーマ仕様書 (note/05)](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/note/05_schema_and_domain_specification.md)
- [自動生成 ER 図 (assets/schema/er-diagram.md)](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/assets/schema/er-diagram.md)
- [総合 API 仕様書 (note/10)](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/note/10_api_specification_and_endpoints.md)
- [Local-First オフライン PWA 設計 (note/11)](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/note/11_local_first_offline_pwa_architecture.md)
