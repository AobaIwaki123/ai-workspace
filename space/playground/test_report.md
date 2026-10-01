# 女性アイドルグループ名 -> カタカナ変換 自動テストレポート (非重複評価)

## 📊 テスト結果概要

- **正答率 (Accuracy)**: 72.2% (13 / 18 件)
- **Few-shot 知識量 (K)**: 6 件
- **知識効率スコア (Efficiency)**: 34.7 pts
- **テスト日時**: 2026-08-25 01:07:19

## 💡 Few-shot に使用した例 (6 件)

| Input | Katakana | 狙い |
| :--- | :--- | :--- |
| =LOVE | イコールラブ | 記号（=）の読み替えルール |
| ≠ME | ノットイコールミー | 否定記号（≠）の読み替えルール |
| FRUITS ZIPPER | フルーツジッパー | 英語複合語・スペース除去 |
| ASP | エーエスピー | 略称・頭字語のアルファベット読み |
| chuLa | チュラ | 大文字小文字混じりの発音 |
| CYNHN | スウィーニー | 特殊な非英語・造語の読み |

## ✅ 成功したケース

| Idol Group | Katakana (Output) |
| :--- | :--- |
| ≒JOY | ニアリーイコールジョイ |
| Lollipop♡CHU | ロリポップチュー |
| Appare! | アッパレ |
| FES☆TIVE | フェスティブ |
| Devil ANTHEM. | デビルアンセム |
| CANDY TUNE | キャンディーチューン |
| JamsCollection | ジャムズコレクション |
| NEO JAPONISM | ネオジャポニズム |
| iLiFE | アイライフ |
| BiSH | ビッシュ |
| BiS | ビス |
| ukka | ウッカ |
| AMEFURASSHI | アメフラッシ |

## ❌ 失敗したケース

| Idol Group | Expected | Output |
| :--- | :--- | :--- |
| SWEET STEADY | スイートステディ | スウィートステディ |
| CUTIE STREET | キューティーストリート | チュリーストリート |
| Peel the Apple | ピールジアップル | ピールザアップル |
| Task have Fun | タスクハブファン | タスクハファン |
| BABYMETAL | ベビーメタル | ベイメタル |
