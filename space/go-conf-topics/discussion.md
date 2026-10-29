# Go Conference 登壇向け技術検証 & Tech Blog 企画 (discussion.md)

このドキュメントでは、Go Conference 等の技術カンファレンス登壇を目指すための「ユーザー目線での新機能・低レイヤー挙動追試」に関する Tech Blog 企画と進捗を管理します。

---

## 目的・ゴール

- 単なる公式ドキュメントの紹介や「便利ライブラリ作りました」にとどまらず、**Go のコンパイラ、ランタイム（GC / メモリ / マップ）、および Kubernetes / Linux カーネルの境界に深く踏み込んだ知見** を解明する。
- ユーザー目線での実験・実測データ・落とし穴（Failure Mode）を軸にした、技術密度の高いトークプロポーザル（CFP）の土台を構築する。

---

## Tech Blog 草案一覧

| No | タイトル / テーマ | 分野 | 核心となる知見・面白さ | リンク |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **PGO と Devirtualization の光と影** | コンパイラ最適化 | 脱仮想化がアロケーションを削る瞬間と、Web API でシステムコールに最適化バジェットを奪われる落とし穴 | [note/01](note/01_pgo_devirtualization_and_io_pitfalls.md) |
| **2** | **10年ぶりの大刷新！Go 1.24 Swiss Tables** | データ構造・SIMD | SIMD による 16 スロット並列走査、負荷率 87.5% 向上によるメモリ密度とルックアップ高速化の解剖 | [note/02](note/02_go124_swiss_tables_map_internals.md) |
| **3** | **Go 1.24 弱参照 (`weak.Pointer`) の実態** | メモリ管理・GC | 従来の Finalizer 地獄との違い、GC のどのフェーズで回収されるのか、リークフリーキャッシュの実証 | [note/03](note/03_go124_weak_pointers_and_gc_reclaim.md) |
| **4** | **k8s In-Place Resize と Go ランタイムの戦い** | k8s × cgroup v2 | コンテナを再起動せずにメモリ縮小した際の Go の OOM 即死現象と、cgroup v2 イベント駆動追従 | [note/04](note/04_k8s_inplace_resize_and_cgroupv2_gomemlimit.md) |

---

## 直近のネクストアクション・進捗状況

- [x] **テーマ選定**: No 4「k8s In-Place Resize と Go ランタイムの戦い」をメインテーマとして採択
- [x] **実機検証と PoC 開発**:
  - 検証用 OSS ライブラリ [`inplace-gomemlimit`](https://github.com/AobaIwaki123/inplace-gomemlimit) を開発（cgroup v2 監視・`debug.SetMemoryLimit` 動的更新）
  - k8s v1.36.4+k0s 実クラスタ（Ubuntu 24.10, Linux 6.11）での実機検証を実施
  - メモリ削減時は k8s API により `RestartContainer` が強制される仕様（KEP-1287）を確認
  - メモリ拡張時は再起動ゼロ（`RESTARTS: 0`）で cgroup が広がるが、Go ランタイムは古い上限で凍結される現象を実測
  - 自作ウォッチャーにより、再起動ゼロのまま `GOMEMLIMIT` が即座に追従（460MiB → 921MiB）することを目視確認
- [x] **技術ブログ執筆・レビュー**:
  - `inplace-gomemlimit/docs/tech-blog-draft.md` に第 1 章〜第 5 章、おまけコラム（Go のヒープ vs カーネルの RSS）、用語集、参考リンクを完備
  - VPA の歴史的苦悩（`updateMode: Off` 運用の実態、Datadog ドキュメント、AEP-4016 等）を一次出典付きで第 1 章に拡充
  - 再現手順は独立ドキュメント `docs/reproduction-guide.md` に切り出し
- [x] **GopherCon Japan 2027 CFP 応募原稿作成 & 提出完了**:
  - 提出先: GopherCon Japan 2027（Sessionize / 締切: 2026 年 11 月 1 日 23:59 JST）
  - 提出日: 2026 年 10 月 28 日（提出完了）
  - タイトル: `Kubernetesの動的メモリ変更にGoは追従できるのか?`（28 文字）
  - ターゲット: `Internal Intermediate / 仕組みの深掘り・中級`
  - 応募枠: チャレンジセッション（20 分）を中心に Sessionize へエントリー完了（応募原稿: `inplace-gomemlimit/docs/proposal-gophercon-japan-2027.md`）
- [x] **スライド構成・Q&A 戦略の策定**:
  - 導入フック: 現場が長年悩んできた「VPA の Pod Evict・再起動によるダウンタイム」と KEP-1287 の期待から切り出す。
  - 他言語比較（JVM / V8 等）の扱い: メイン発表には含めず、「参考調査（事前AI調査ベース）」と明記した上で Q&A 用の補足スライド（Appendix）に留め、質問が出た場合のみ安全に回答する方針とする。

---

## 次のステップ（今後の作業候補）

1. **PR #1 のマージ**: `inplace-gomemlimit` の `feature/tech-blog` ブランチ（技術記事・再現手順書・CFP原稿）を `main` へマージ
2. **発展的探求（メモリ削減時の協調プロトコル）**:
   - 現在はメモリ削減に `RestartContainer` が必須となっているが、アプリとインフラが協調して安全にメモリを縮小（FreeOSMemory 連携等）できる将来像の調査・検討
3. **別テーマへの復帰**:
   - `atmo`（気圧アプリ）の iOS リリース準備（Apple Developer Program 登録、Xcode 設定、TestFlight 配信準備）
