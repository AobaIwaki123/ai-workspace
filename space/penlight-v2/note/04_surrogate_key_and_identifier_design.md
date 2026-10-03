# サロゲートキー設計と不変識別子アーキテクチャ (04_surrogate_key_and_identifier_design.md)

本ドキュメントは、「同姓同名の加入や改名・表記修正に耐えうる堅牢なデータモデル」を構築するため、名前やローマ字といった自然キー（Natural Key）を ID から完全排除し、不変な **サロゲートキー（Surrogate Key / プレフィックス付き CUID2/UUID）** を主キーとする識別子設計をまとめたものです。

---

## 1. 名前ベース ID（ナチュラルキー）が孕む脆弱性

旧来の設計でよくある `id: "kousaka-marino"` や `id: "watanabe-rika"` のような名前依存の ID には、以下の致命的な欠点が存在します。

1. **同姓同名・同音異字の衝突**:
   - 将来的にグループを跨いで、あるいは同一グループ内で同姓同名（または同姓・同ローマ字の別メンバー）が加入した瞬間に PRIMARY KEY 制約違反が発生し、スキーマ破綻を起こす。
2. **改名・誤字修正時のカスケード破壊**:
   - 漢字の誤記訂正、芸名の変更、結婚・活動名の変更時に、関連テーブル（推しメンカラー、クイズ回答ログ、画像ファイルパス）の全キーを書き換える必要が生じ、参照整合性が脆弱になる。
3. **名前空間の汚染**:
   - 画像ファイル名が `morita-hikaru.webp` のように名前に依存すると、ファイルキャッシュのパージや URL 変更が煩雑化する。

---

## 2. プレフィックス付きサロゲートキー（Stripe スタイル）の採用

ID は **「完全にランダムかつ不変で、人間と AI の双方が識別しやすい」** プレフィックス付き ID（NanoID / CUID2 / ULID 方式）を採用します。

### プレフィックス規約
| エンティティ | プレフィックス | ID 例 | 役割 |
| :--- | :--- | :--- | :--- |
| **Member** (メンバー) | `mem_` | `mem_01hqxyz789abc` | メンバーの一意識別子 |
| **Group** (グループ) | `grp_` | `grp_sakurazaka` / `grp_aobazaka` | グループの一意識別子 |
| **Color** (カラー) | `col_` | `col_sakura_pink` | ペンライトカラーマスター |
| **Question** (クイズ問題) | `q_` | `q_987654321` | 出題セッションごとの問題 ID |

### プレフィックス付きサロゲートキーのメリット
* **名前の変更に 100% 影響を受けない**:
  - `name` や `kana` は単なる「表示用属性」に過ぎず、いつでも安全に UPDATE 可能。
* **同姓同名が何人入っても完全に分離**:
  - `mem_01a...` と `mem_01b...` で同一姓名のメンバーが共存可能。
* **ログ・デバッグ・AI 協業での可視性**:
  - `mem_` を見るだけで「メンバーの ID」であることが AI にも人間にも一目で分かり、引数の取り違えミスをゼロにできる。

---

## 3. 改定後のスキーマ定義 (TypeScript & SQLite)

### 3.1 Drizzle ORM / SQLite スキーマ (`src/db/schema.ts`)
```typescript
import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';

// グループテーブル
export const groups = sqliteTable('groups', {
  id: text('id').primaryKey(), // 'grp_sakurazaka', 'grp_aobazaka'
  name: text('name').notNull(), // '櫻坂46'
  shortName: text('short_name').notNull(), // '櫻坂'
  themeColor: text('theme_color').notNull(), // '#F19CA7'
  textColor: text('text_color').notNull().default('#FFFFFF'),
  displayOrder: integer('display_order').notNull().default(0),
  isActive: integer('is_active', { mode: 'boolean' }).notNull().default(true),
});

// カラーマスターテーブル
export const colors = sqliteTable('colors', {
  id: text('id').primaryKey(), // 'col_sakura_pink'
  groupId: text('group_id').notNull().references(() => groups.id),
  name: text('name').notNull(), // 'サクラピンク'
  hex: text('hex').notNull(), // '#FFB7C5'
  textColor: text('text_color').default('#000000'),
  displayOrder: integer('display_order').notNull().default(0),
});

// メンバーテーブル（名前依存を完全排除）
export const members = sqliteTable('members', {
  id: text('id').primaryKey(), // 'mem_01hq...' (サロゲートキー)
  groupId: text('group_id').notNull().references(() => groups.id),
  name: text('name').notNull(), // '幸阪茉里乃'
  kana: text('kana').notNull(), // 'こうさか まりの'
  generation: integer('generation').notNull(), // 2
  status: text('status', { enum: ['active', 'graduated'] }).notNull().default('active'),
  imagePath: text('image_path').notNull(), // '/images/members/mem_01hq....webp'
  leftColorId: text('left_color_id').notNull().references(() => colors.id),
  rightColorId: text('right_color_id').notNull().references(() => colors.id),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
  updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull(),
});
```

### 3.2 TypeScript インターフェース (`src/types/index.ts`)
```typescript
export interface Member {
  id: string; // 'mem_01hq...' (不変のサロゲートキー)
  groupId: string; // 'grp_sakurazaka'
  name: string; // '森田ひかる'
  kana: string; // 'もりた ひかる'
  generation: number;
  status: 'active' | 'graduated';
  imagePath: string; // '/images/members/mem_01hq....webp'
  penlight: {
    leftColor: ColorMaster;
    rightColor: ColorMaster;
  };
}
```

---

## 4. 画像ストレージとファイル名運用

メンバー画像の保存先も、名前に依存させず **メンバー ID（`id`）をベースにしたファイル名** で固定します。

* **パス命名規則**:
  ```text
  /public/images/members/{groupId}/{id}.webp
  例: /public/images/members/grp_sakurazaka/mem_01hq7x9z.webp
  ```
* **効果**:
  * メンバーの氏名表記が変わっても、画像ファイルの移動・リネームは一切不要。
  * ブラウザキャッシュを破棄したい場合は、クエリパラメータ（`?v=20261003`）または更新日時タイムスタンプを付与するだけで安全に即時反映できます。
