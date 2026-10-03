# 設定および環境変数仕様書 (21_configuration_and_environment_variables_specification.md)

本ドキュメントは、Penlight Quiz v2 における環境変数の過剰定義（オーバーエンジニアリング）を排除し、**「外部から注入しなければ動作しない機密値およびマウントパス」のみに極小化した最小設定仕様書** です。

---

## 1. 設定設計原則: 徹底した YAGNI とゼロコンフィグ

1. **YAGNI (You Aren't Gonna Need It) の徹底**:
   - 「あった方が変更しやすいかも」という理由でポート番号、タイムアウト値、バッファサイズ、ログ形式などを環境変数化することを禁止します。
   - アプリケーション内部の設計定数（コード内の `const`）で十分なものはすべてコードに固定します。
2. **ゼロコンフィグローカル起動 (Zero-Config Development)**:
   - 開発環境では `.env` ファイルすら不要で、バイナリを叩くだけでデフォルト（`./data` 配下）で完全動作します。
3. **環境変数は「機密値（Secrets）」と「ボリュームマウントパス」のみ**:
   - Git にコミットできない秘密鍵と、コンテナ外（k8s PVC）からマウントされる永続ストレージパスだけを環境変数として扱います。

---

## 2. 環境変数一覧（必要最小限の 4 つ）

本システムで定義・利用する環境変数は **以下の 4 つのみ** です。

| 環境変数名 | 型 | デフォルト値 (Local) | 本番設定例 (k8s) | 機密性 | 必須 | 用途・注入理由 |
|---|---|---|---|---|---|---|
| `DATA_DIR` | string | `./data` | `/data` | 公開 | 任意 | k8s PVC マウント先のベースディレクトリ（DB とアセットを一元管理） |
| `SESSION_SECRET` | string | `dev-insecure-secret-key-32bytes-min!!` | (ランダム 64 hex 文字列) | **極秘** | **本番必須** | セッション Cookie HMAC-SHA256 署名用シークレット鍵 |
| `GOOGLE_CLIENT_ID` | string | (空文字: ゲストモード) | `xxx.apps.googleusercontent.com` | 公開 | OAuth 時 | Google OAuth 2.0 クライアント ID |
| `GOOGLE_CLIENT_SECRET` | string | (空文字: ゲストモード) | `GOCSPX-xxxxxx` | **極秘** | OAuth 時 | Google OAuth 2.0 クライアントシークレット |

> **未設定時の挙動**:
> - `GOOGLE_CLIENT_*` が空の場合は、Google ログインを無効化し、完全ローカル／ゲストモードとして起動します（開発時に Google API 登録が不要）。
> - `DATA_DIR` が未設定の場合は、カレントディレクトリ直下の `./data`（`./data/penlight.db`, `./data/assets/`）が自動作成されます。

---

## 3. コード内定数として固定するもの（環境変数から全廃）

以下の項目は「あったら便利」で環境変数化されがちですが、本システムでは **コード内の定数（`const`）として固定** します。

| 項目 | 固定値 | 固定する理由 |
|---|---|---|
| **待受ポート (`PORT`)** | `8080` 固定 | コンテナ内は 8080 固定で十分。ポート変更が必要なら k8s Service や Docker のポートマッピング側で解決する。 |
| **データベースパス (`DB_PATH`)** | `filepath.Join(DataDir, "penlight.db")` | `DATA_DIR` 配下に置くことが確定しているため、別個に環境変数を用意する必要がない。 |
| **画像アセットパス (`STORAGE_DIR`)** | `filepath.Join(DataDir, "assets")` | 同上。データとアセットの配置場所を 1 つのパスで統一。 |
| **SQLite ビジータイムアウト** | `5 * time.Second` | WAL モードにおける最適なビジー待機時間。外部から微調整する必要はない。 |
| **最大アップロードサイズ** | `10 * 1024 * 1024` (10MB) | メンバー写真の制限値。10MB で十分であり環境ごとに変える理由がない。 |
| **セッション有効期限** | `30 * 24 * time.Hour` (30日) | クイズアプリのログイン保持期間。固定で十分。 |
| **CORS 許可オリジン** | 同一オリジン + 開発用 `localhost` | フロントエンドは Go バイナリに内包される（`embed.FS`）ため、本番は常に同一オリジン。CORS の複雑な外部注入は不要。 |
| **ログレベル・形式** | Go 標準 `slog` (デフォルト Text / JSON) | 本番コンテナは JSON、開発時は Text を自動判別（`DATA_DIR == "/data"` 等で判定）すれば環境変数不要。 |

---

## 4. Go 設定構造体 (`pkg/config/config.go`)

環境変数が 4 つしかないため、外部の巨大な設定ライブラリを使わず、**Go 標準の `os.Getenv` だけで 30 行以内で完結** します。

```go
package config

import (
	"errors"
	"os"
	"path/filepath"
)

type Config struct {
	DataDir            string
	DBPath             string
	AssetDir           string
	SessionSecret      string
	GoogleClientID     string
	GoogleClientSecret string
}

func Load() (*Config, error) {
	dataDir := os.Getenv("DATA_DIR")
	if dataDir == "" {
		dataDir = "./data"
	}

	sessionSecret := os.Getenv("SESSION_SECRET")
	if sessionSecret == "" {
		sessionSecret = "dev-insecure-secret-key-32bytes-min!!"
	}

	cfg := &Config{
		DataDir:            dataDir,
		DBPath:             filepath.Join(dataDir, "penlight.db"),
		AssetDir:           filepath.Join(dataDir, "assets"),
		SessionSecret:      sessionSecret,
		GoogleClientID:     os.Getenv("GOOGLE_CLIENT_ID"),
		GoogleClientSecret: os.Getenv("GOOGLE_CLIENT_SECRET"),
	}

	// 本番判定 (PVC /data がマウントされている場合) のみシークレットを厳格検証
	if cfg.DataDir == "/data" && (cfg.SessionSecret == "dev-insecure-secret-key-32bytes-min!!" || len(cfg.SessionSecret) < 32) {
		return nil, errors.New("SESSION_SECRET must be set to a secure key (>= 32 bytes) in production")
	}

	return cfg, nil
}
```

---

## 5. Kubernetes マニフェスト（大幅簡素化）

環境変数の削減により、k8s マニフェストの ConfigMap は実質不要となり、**Secret 1 つ（`SESSION_SECRET`, `GOOGLE_CLIENT_*`）を Pod に注入するだけ** の極小構成となります。
