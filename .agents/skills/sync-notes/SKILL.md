---
name: sync-notes
description: >-
  Extracts and organizes insights, discussions, and decisions from the current conversation
  into categorized, sequentially numbered markdown notes (note/*.md) within a specified or active workspace.
  Use when the user asks to "note", "save notes", "extract to notes", or summarize the conversation into workspace notes.
---

# Sync Notes

本スキルは、ユーザーとの壁打ち・議論・思考プロセスの中から得られた構造的知見、意思決定、課題分析を抽出し、指定されたワークスペース（またはアクティブなSpace）配下の `note/` ディレクトリに連番形式のMarkdownノート（`XX_topic_name.md`）として体系的に分類・出力します。

---

## 1. 発動トリガー

- ユーザーが「一旦noteに出力」「noteにして」「会話の内容をnoteにまとめて」「分類ごとにnoteを出力して」と指示した時
- 単一の「note」という呼び出しでも、直前の対話履歴から論点を自律的に分類・抽出し、複数ノートに分割保存する時

---

## 2. 実行手順

### Step 1: 会話内容の論点クラスタリング
直前の会話ログから、以下の分類基準に従って論点をクラスタリングします：
- **構造的病理・認知パターン**（なぜ問題が起きていたかのメカニズム分析）
- **意思決定・受容・損切り**（何を捨て、何をベースラインとして受容したか）
- **行動プロトコル・ハードウェアハック**（具体的にどのような手順・習慣・ルーチンを実行するか）
- **リソース・作品・外部データ**（具体的な選定リスト、参考文献、入力素材）

※ 1つの巨大なノートに詰め込まず、**1テーマ1ファイル（単一責任の原則）**で分割します。

### Step 2: 既存ノートの採番確認
対象ワークスペースの `note/` 配下を走査し、最新の連番を確認します。

```bash
ls -1 <workspace-path>/note/
```

既存の最大番号（例: `07_xxx.md`）の次（`08_xxx.md`、`09_xxx.md`...）を自動採番します。

### Step 3: ノートの作成・書き出し
各ノートは以下の標準フォーマットに従って記述します：

```markdown
# XX: <トピックタイトル（簡潔・構造的）>

## 1. 背景と現象の観察
...

## 2. 構造分析 / メカニズム
...

## 3. アクションプロトコル / 運用ルール
...

---

## 参考文献 (Authoritative References)
- <学術論文、著者名、一次ソースの公式リンク>
```

### Step 4: 整合性確認とユーザー報告
- 作成した各ノートのパスと、それぞれのノートが担当する論点のサマリーを提示します。
- 規約に基づき、ユーザーの指示があるまでコミットやPR作成は行わず作業ツリー上に保持します。
