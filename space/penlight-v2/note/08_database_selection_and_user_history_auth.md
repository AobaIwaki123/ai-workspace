# データベース選定精査・ユーザー回答履歴蓄積・Google認証設計 (08_database_selection_and_user_history_auth.md)

本ドキュメントは、以下の 3 つの課題に対する比較検証およびアーキテクチャ確定方針をまとめたものです。
1. **SQLite は 2026 年現在でも最適か、あるいは新世代 DB の方が優れているか**
2. **ユーザーごとの正答・誤答ログの永続蓄積と分析・復習機能のデータモデル**
3. **Google ログイン (OIDC) によるアカウント連携・セッション管理**

---

## 1. データベース最新動向比較 (2026年時点)

近年、DuckDB や libSQL、PGlite、CloudNativePG などの新しい組み込み・エッジ DB が登場しています。特性を比較し、本システムに最適な DB を選定します。

| データベース | 内部アーキテクチャ | 特性・強み | 本システムへの適合性 | 評価 |
|---|---|---|---|---|
| **SQLite (WAL モード)** | 行指向 (Row-based) OLTP 組み込み型 | ゼロコンフィグ、Cgo 不要 (`modernc.org/sqlite`)、1 Pod 内で完結。WAL モードにより並行読み取りが無制限、書き込みは秒間数千トランザクション可能 | **最適**。クイズの読み取り・回答 INSERT に最もシンプルで堅牢 | **採用** |
| **DuckDB** | 列指向 (Columnar) OLAP 分析型 | 数千万件の Parquet / 集計クエリが極めて高速 | 不適。単一行の更新・INSERT（回答ログの逐次記録）には向かない | 見送り |
| **libSQL (Turso)** | SQLite フォーク / 分散レプリケーション | HTTP 接続対応、Cloudflare Workers 等のエッジ同期 | 不要。本システムは自宅 k8s クラスタ内の単一 Pod で完結するため、分散オーバーヘッドが無駄 | 見送り |
| **PGlite** | WASM 組み込み PostgreSQL | ブラウザ内や Node.js で Postgres が動く | 不適。Go バックエンドからの組み込み運用には成熟度・オーバーヘッド面で SQLite に劣る | 見送り |
| **PostgreSQL (CloudNativePG)** | クラスタ型 RDBMS | 複数 Pod からの同時並行書き込み、高度な JSON/分析機能 | 将来用。同時アクセスが毎秒数万に達し、Pod を複数にスケールアウトする段階になれば移行候補 | 将来候補 |

### 判定
本システムの規模・運用体制（自宅 k8s、1 Pod 完結、外部依存ゼロ）において、**SQLite (WAL モード)** は 2026 年時点でも **圧倒的に最も保守コストが低く壊れない最強の選択肢** です。
WAL (Write-Ahead Logging) モードを有効化（`PRAGMA journal_mode=WAL;`）することで、クイズ出題の読み取りとユーザー回答の追記が一切ブロックせず並行動作します。

---

## 2. ユーザーごとの正答・誤答蓄積データモデル

クイズアプリとしての継続利用価値を高めるため、各ユーザーの回答履歴を永続化し、正答率や苦手分析を行えるようにします。

### 新設プレフィックス
- `usr_`: ユーザー (User)
- `ans_`: 回答ログ (AnswerLog)

### データモデル定義 (Go 構造体)

```go
// User represents an authenticated or guest user.
type User struct {
	ID            ID        `json:"id" db:"id,pk"`                       // usr_<uuidv7>
	GoogleSub     *string   `json:"google_sub,omitempty" db:"google_sub"` // Google OIDC 'sub' 一意識別子
	Email         *string   `json:"email,omitempty" db:"email"`           // Google メールアドレス
	DisplayName   string    `json:"display_name" db:"display_name"`       // 表示名
	AvatarURL     string    `json:"avatar_url" db:"avatar_url"`           // Google アイコン URL
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	LastLoginAt   time.Time `json:"last_login_at" db:"last_login_at"`
}

// AnswerLog records every single quiz question attempt by a user.
type AnswerLog struct {
	ID             ID        `json:"id" db:"id,pk"`                       // ans_<uuidv7>
	UserID         ID        `json:"user_id" db:"user_id,fk"`             // usr_<uuidv7> (認証ユーザーまたは匿名ゲストID)
	QuizQuestionID ID        `json:"quiz_question_id" db:"quiz_question_id"` // quiz_<uuidv7>
	TargetMemberID ID        `json:"target_member_id" db:"target_member_id,fk"` // mem_<uuidv7>
	GroupID        ID        `json:"group_id" db:"group_id,fk"`           // grp_<uuidv7> (集計の高速化用)
	IsCorrect      bool      `json:"is_correct" db:"is_correct"`         // 正誤フラグ
	ResponseTimeMs int       `json:"response_time_ms" db:"response_time_ms"` // 回答時間 (ミリ秒)
	AnsweredAt     time.Time `json:"answered_at" db:"answered_at"`       // 回答日時
}
```

### 提供可能になるユーザー体験
1. **総合・グループ別・期生別 正答率ダッシュボード**:
   - 「日向坂46: 正答率 92%」「青葉坂46: 正答率 60%」等の可視化。
2. **「苦手克服モード (Weakness Review)」**:
   - 直近で誤答したメンバー（`IsCorrect = false`）を優先出題するアルゴリズム。
3. **平均回答速度 (Speed Run) ランキング**:
   - 正解かつ回答速度（`ResponseTimeMs`）のスコア集計。

---

## 3. Google ログイン (OIDC) 認証アーキテクチャ

ユーザーにパスワード管理の負担をかけず、安全にログインできるように **Google OpenID Connect (OIDC)** を採用します。

### 認証フロー

```
[フロントエンド (Next.js)] ───── 1. Google ログインボタン押下 ─────► [Google OAuth 2.0]
          │                                                                   │
          │ ◄─────────────────── 2. 認可コード返却 ───────────────────────────┘
          │
          └─── 3. POST /api/auth/google/callback (認可コード) ──► [Go バックエンド]
                                                                        │
                                   4. トークン検証 & sub 取得 ─────────┤
                                   5. User テーブル存在確認 (JIT 作成)  │
                                   6. セッション Cookie 発行 (HttpOnly) │
          ◄─── 7. 200 OK (Set-Cookie: session_id=...) ─────────────────┘
```

### セキュリティと UX の設計方針
1. **段階的オンボーディング (Progressive Onboarding)**:
   - ログインなし（ゲスト）でもクイズは即座に遊べる設計。
   - ゲスト回答ログはブラウザの `localStorage` または一時セッションに保存。
   - 後から Google ログインした際に、ゲスト時の履歴を `User.ID` にマージ可能。
2. **Cookie セッション管理**:
   - JWT を localStorage に保存する方式は XSS 攻撃に脆弱なため不採用。
   - バックエンドが `HttpOnly`, `Secure`, `SameSite=Lax` のセッション Cookie を発行し、セッションテーブル（または SQLite 内のセッション）で検証。
3. **必要なパーミッションの最小化**:
   - スコープは `openid email profile` のみ。不要な権限は一切要求しない。

---

## 4. 参考文献・公式ドキュメント

- [SQLite Write-Ahead Logging (WAL) Official Guide](https://www.sqlite.org/wal.html)
- [Google Identity: OpenID Connect Overview](https://developers.google.com/identity/openid-connect/openid-connect)
- [RFC 6749 - The OAuth 2.0 Authorization Framework](https://www.rfc-editor.org/rfc/rfc6749.html)
- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
