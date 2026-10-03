# クイズ出題アルゴリズムの Strategy パターン設計 (13_quiz_generation_strategy_pattern.md)

本ドキュメントは、ペンライトクイズの設問生成ロジック（ダミー選択肢の選出、難易度調整、ユーザー苦手克服）をハードコードせず、**要件や利用シーンに応じて動的・プラグイン的に差し替え可能な Strategy パターン** の設計仕様書です。

---

## 1. 課題と設計目的

クイズアプリにおいて、「出題ロジック」は最も頻繁にチューニング・変更が求められる領域です。
- 「初心者には色が全く違う選択肢を出して分かりやすくしたい」
- 「上級者には似た色（スカイブルーとパステルブルー等）ばかりを並べて歯ごたえを出したい」
- 「ライブ前には推しメンや新期生に絞って出題したい」
- 「過去に間違えた問題ばかりを集めた復習モードを作りたい」

これらを 1 つの巨大な `switch-case` や `if-else` で分岐させるとコードがスパゲッティ化するため、**Go のインターフェースを用いた Strategy パターン** を採用し、ロジックの追加・調整を完全に独立させます。

---

## 2. Strategy インターフェース定義 (Go)

```go
package quiz

import (
	"context"
	"github.com/aobaiwaki/ai-workspace/space/penlight-v2/backend/pkg/model"
)

// GenerationParams holds runtime constraints for question generation.
type GenerationParams struct {
	GroupID     *model.ID       // Optional group filter
	Generation  *int            // Optional generation filter
	Count       int             // Number of questions
	UserID      *model.ID       // Optional authenticated user ID
}

// Strategy defines the interface for generating penlight quiz questions.
type Strategy interface {
	// Name returns the unique strategy identifier (e.g. "similar_color", "random")
	Name() string

	// GenerateQuestion generates a single 4-choice question for the target member.
	GenerateQuestion(
		ctx context.Context,
		target model.Member,
		allMembers []model.Member,
		colorMap map[model.ID]model.Color,
		userHistory []model.AnswerLog,
	) (model.QuizQuestion, error)
}
```

---

## 3. 実装ストラテジー一覧

| ストラテジー名 | 識別子 (`strategy`) | 対象ターゲット | ダミー選択肢（誤答 3 枠）の選定ルール |
|---|---|---|---|
| **類似色ひっかけ (デフォルト)** | `similar_color` | 一般〜中級者 | 正解色との **CIELAB 色差 ($\Delta E$)** を計算し、色が近い（紛らわしい）メンバーを優先選出 |
| **完全ランダム** | `random` | 初心者向け | 全メンバーからランダムに 3 名を均等選出 |
| **同期生限定 (高難度)** | `same_generation` | コアファン向け | 出題メンバーと同一グループ・同一期生の中から 3 名を選出（難問） |
| **忘却曲線・苦手克服** | `spaced_repetition` | 復習モード | ユーザーの回答履歴（`ans_`）から過去の誤答率が高いメンバーを優先選出 |

---

## 4. 色差アルゴリズム (CIELAB $\Delta E$ による類似色計算)

`similar_color` ストラテジーでは、RGB の数値を人間の視覚特性に適合した **CIE $L^*a^*b^*$ 色空間** に変換し、色差を算出します。

$$\Delta E = \sqrt{(L_1^* - L_2^*)^2 + (a_1^* - a_2^*)^2 + (b_1^* - b_2^*)^2}$$

- $\Delta E < 10$: 人間の目にはほぼ同色に見える（超難問）
- $10 \le \Delta E \le 25$: 「スカイブルー」と「パステルブルー」のような絶妙な類似色
- $\Delta E > 50$: 明らかに異なる色（赤と青など）

ダミー選定時に $10 \le \Delta E \le 30$ の範囲にあるメンバーを優先して 2 名、完全に異なる色（$\Delta E > 50$）を 1 名混ぜることで、**「絶妙に悩ませつつも理不尽すぎない極上のクイズ体験」** を自動生成します。

---

## 5. ストラテジーレジストリと動的切り替え

リクエストのクエリパラメータ `GET /api/v1/quiz/generate?strategy=similar_color` に応じて、レジストリから適切なストラテジーを取得して実行します。

```go
type Registry struct {
	strategies map[string]Strategy
}

func (r *Registry) Get(name string) Strategy {
	if s, ok := r.strategies[name]; ok {
		return s
	}
	return r.strategies["similar_color"] // デフォルトフォールバック
}
```

また、TypeScript 側（フロントエンド）にも同一の Strategy インターフェースを実装することで、**オフライン PWA 動作時でも全く同じアルゴリズムでクイズを生成可能** にします。

---

## 6. 参考文献・公式仕様

- [Strategy Pattern - Refactoring Guru](https://refactoring.guru/design-patterns/strategy)
- [CIE Color Space & Delta E (CIELAB) - Bruce Lindbloom](http://www.brucelindbloom.com/)
- [Color difference - Wikipedia](https://en.wikipedia.org/wiki/Color_difference)
