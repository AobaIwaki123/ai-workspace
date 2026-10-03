# スキーマ規約およびドメインモデル仕様書 (Schema & Domain Specification)

本書は、Penlight Quiz v2 におけるデータ構造、識別子規約、およびエンティティ間のリレーションを統括する公式スキーマ仕様である。
適当な JSON サンプルによる仕様の曖昧化を防ぐため、**Go の構造体（Struct）を正本（Single Source of Truth）** として定義し、厳密なバリデーションルールおよび統括規約を明文化する。

> **自動生成データモデル構成図 (Asset)**:
> スキーマから自動出力された最新の ER 図は [assets/schema/er-diagram.md](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/assets/schema/er-diagram.md) を参照。

---

## 1. 全体を統括する識別子規約 (Prefix Rule / TypeID Convention)

本システム内の全エンティティは、自然キー（名前や略称）を主キーとすることを禁止し、**「プレフィックス + UUID v7」** によるサロゲートキーを採用する。

### プレフィックス一覧

| プレフィックス | 対象エンティティ | 形式例 | 役割・用途 |
|---|---|---|---|
| `grp_` | グループ (Group) | `grp_019245a0...` | グループマスタの不変識別子 |
| `col_` | ペンライトカラー (Color) | `col_019245a1...` | ペンライトカラーマスタの不変識別子 |
| `mem_` | メンバー (Member) | `mem_019245a2...` | アイドルメンバーの不変識別子（画像名にも使用） |
| `quiz_` | クイズ設問 (QuizQuestion) | `quiz_019245a3...` | クイズセッション・設問の識別子 |
| `usr_` | ユーザー (User) | `usr_019245a4...` | Google認証/ゲストユーザーの不変識別子 |
| `ans_` | 回答ログ (AnswerLog) | `ans_019245a5...` | ユーザーの各設問への回答・正誤記録の識別子 |

### プレフィックス規約の遵守事項
1. **エンティティ誤用の防止**: プレフィックスにより、API レスポンスやログを見ただけでどのエンティティの ID かを人間・システムが即時判別可能とする。
2. **UUID v7 による時系列順ソート**: 先頭 48 ビットが UNIX ミリ秒タイムスタンプであるため、B-Tree インデックスの肥大化を防ぎ、自然な時系列順ソートを実現する。
3. **名前ベースの自然キー排除**: 同姓同名、改名、表記揺れによって主キーが変化・衝突するリスクをゼロにする。

---

## 2. 正本スキーマ定義 (Go Struct Definition)

スキーマの実装・型定義ファイル:
- 識別子規約: [`backend/pkg/model/id.go`](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/backend/pkg/model/id.go)
- グループ: [`backend/pkg/model/group.go`](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/backend/pkg/model/group.go)
- カラー: [`backend/pkg/model/color.go`](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/backend/pkg/model/color.go)
- メンバー: [`backend/pkg/model/member.go`](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/backend/pkg/model/member.go)
- クイズ: [`backend/pkg/model/quiz.go`](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/backend/pkg/model/quiz.go)

### 2.1 識別子定義 (`id.go`)

```go
package model

type Prefix string

const (
	PrefixGroup  Prefix = "grp"
	PrefixColor  Prefix = "col"
	PrefixMember Prefix = "mem"
	PrefixQuiz   Prefix = "quiz"
)

// ID represents a prefixed UUID v7 identifier (e.g. mem_019245a08c9d7a1e8f2b3c4d5e6f7a8b)
type ID string
```

### 2.2 グループスキーマ (`group.go`)
青葉坂46などの新グループ誕生に対応するため、コード上にグループ名・Enum を一切ハードコードしない動的マスタ構成。

```go
type Group struct {
	ID            ID        `json:"id"`              // grp_<uuidv7> (必須・不変)
	Name          string    `json:"name"`            // 正式名称: "日向坂46", "青葉坂46" (必須)
	ShortName     string    `json:"short_name"`      // 略称表示: "日向坂", "青葉坂" (必須)
	Slug          string    `json:"slug"`            // URL用スラッグ: "hinatazaka46", "aobazaka46" (必須・一意)
	ThemeColorHex string    `json:"theme_color_hex"` // 公式テーマカラー: "#7CC7E8" (必須・#RRGGBB)
	DisplayOrder  int       `json:"display_order"`   // UIタブ表示順 (必須・昇順)
	IsActive      bool      `json:"is_active"`       // 有効フラグ (必須)
	CreatedAt     time.Time `json:"created_at"`      // 作成日時 (必須)
	UpdatedAt     time.Time `json:"updated_at"`      // 更新日時 (必須)
}
```

### 2.3 カラーマスタスキーマ (`color.go`)
各グループ固有のペンライトカラー、または共通カラーを管理。

```go
type Color struct {
	ID           ID        `json:"id"`                     // col_<uuidv7> (必須・不変)
	GroupID      *ID       `json:"group_id,omitempty"`     // 所属グループID (任意・nil時は全グループ共通カラー)
	Name         string    `json:"name"`                   // カラー名: "スカイブルー", "白" (必須)
	HexCode      string    `json:"hex_code"`               // カラーコード: "#00BFFF" (必須・#RRGGBB)
	DisplayOrder int       `json:"display_order"`          // パレット表示順 (必須・昇順)
	CreatedAt    time.Time `json:"created_at"`             // 作成日時 (必須)
	UpdatedAt    time.Time `json:"updated_at"`             // 更新日時 (必須)
}
```

### 2.4 メンバースキーマ (`member.go`)
同姓同名対策として、氏名は単なる属性とし、左右のペンライトカラー、活動ステータスを保持。

```go
type MemberStatus string

const (
	StatusActive    MemberStatus = "active"    // 現役活動中
	StatusGraduated MemberStatus = "graduated" // 卒業
	StatusHiatus    MemberStatus = "hiatus"    // 休業中
)

type PenlightPair struct {
	LeftColorID  ID   `json:"left_color_id"`  // 左手/1本目カラー (col_<uuidv7>, 必須)
	RightColorID ID   `json:"right_color_id"` // 右手/2本目カラー (col_<uuidv7>, 必須)
	Ordered      bool `json:"ordered"`        // 左右の順序区別があるか (必須)
}

type Member struct {
	ID             ID           `json:"id"`                    // mem_<uuidv7> (必須・不変)
	GroupID        ID           `json:"group_id"`              // 所属グループ (grp_<uuidv7>, 必須)
	FamilyName     string       `json:"family_name"`           // 姓: "加藤" (必須)
	GivenName      string       `json:"given_name"`            // 名: "史帆" (必須)
	FamilyNameKana string       `json:"family_name_kana"`      // 姓カナ: "かとう" (必須)
	GivenNameKana  string       `json:"given_name_kana"`       // 名カナ: "しほ" (必須)
	Generation     int          `json:"generation"`            // 期生: 1, 2, 3... (必須)
	Status         MemberStatus `json:"status"`                // active, graduated, hiatus (必須)
	Penlight       PenlightPair `json:"penlight"`              // ペンライト2色 (必須)
	ImageKey       string       `json:"image_key"`             // 画像参照名: "mem_<uuidv7>.webp" (必須)
	JoinedAt       *time.Time   `json:"joined_at,omitempty"`   // 加入日 (任意)
	GraduatedAt    *time.Time   `json:"graduated_at,omitempty"`// 卒業日 (任意)
	CreatedAt      time.Time    `json:"created_at"`            // 作成日時 (必須)
	UpdatedAt      time.Time    `json:"updated_at"`            // 更新日時 (必須)
}
```

### 2.5 クイズ出題・回答スキーマ (`quiz.go`)

```go
type QuizOption struct {
	MemberID    ID           `json:"member_id"`   // mem_<uuidv7>
	MemberName  string       `json:"member_name"` // 選択肢表示名
	Generation  int          `json:"generation"`  // 期生
	Penlight    PenlightPair `json:"penlight"`    // カラーID組
	LeftHex     string       `json:"left_hex"`    // UI描画用HEX (#RRGGBB)
	RightHex    string       `json:"right_hex"`   // UI描画用HEX (#RRGGBB)
	LeftName    string       `json:"left_name"`   // カラー名
	RightName   string       `json:"right_name"`  // カラー名
	IsCorrect   bool         `json:"is_correct"`  // 正解フラグ
}

type QuizQuestion struct {
	ID             ID           `json:"id"`               // quiz_<uuidv7>
	TargetMemberID ID           `json:"target_member_id"` // mem_<uuidv7>
	TargetMember   Member       `json:"target_member"`    // 出題対象メンバー
	Options        []QuizOption `json:"options"`          // 4択固定スライス (要素数4)
	CorrectIndex   int          `json:"correct_index"`    // 正解インデックス (0..3)
	GeneratedAt    time.Time    `json:"generated_at"`     // 出題生成日時
}
```

---

## 3. バリデーションルールおよび整合性制約

1. **識別子の一意性と形式**:
   - 正規表現: `^(grp|col|mem|quiz)_[0-9a-f]{32}$`
2. **カラーコード形式**:
   - 正規表現: `^#[0-9A-Fa-f]{6}$`（6桁16進数大文字小文字対応、標準化時は大文字）
3. **同姓同名の重複許容**:
   - `(FamilyName, GivenName)` の一意制約は設定しない（同姓同名の共存を認める）。
   - 一意制約は主キー `ID` および URL 用の `Group.Slug` のみに課す。
4. **画像ファイル名の不変性**:
   - 画像ファイル名はメンバーの `ID` に連動した `{ID}.webp` のみとし、メンバー名・改名・グループ移籍によるファイル名変更を排除する。

---

## 4. 参考文献・公式仕様

- [RFC 9562 - Universally Unique IDentifiers (UUID)](https://www.rfc-editor.org/rfc/rfc9562.html)
- [TypeID Specification (Jetify / formerly Determinate Systems)](https://github.com/jetify-com/typeid)
