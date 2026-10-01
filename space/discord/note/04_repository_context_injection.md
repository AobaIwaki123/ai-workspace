# リポジトリ知識（規約・スキル・ナレッジ）の自律継承メカニズム

本ドキュメントは、Discord Bot から Antigravity CLI (`agy`) を呼び出す際、本リポジトリ (`ai-workspace`) に蓄積された規約、ツール、スキル、および過去の調査ノートをエージェントに自動認識させ、意図通りの自律タスクを実行させるための設計知見をまとめた技術ノートです。

---

## 1. カレントディレクトリ (`cwd`) の固定によるコンテキスト継承

Antigravity CLI は、プロセスの起動ディレクトリ (`cwd`) を「作業対象のリポジトリルート」として認識し、そこに含まれるメタデータや設定を自動的にインデックスします。

Bot プログラム内で `agy` サブプロセスを生成する際、`cwd` をリポジトリの絶対パス（`/Users/aobaiwaki/ai-workspace`）に明示固定します。

```javascript
const WORKSPACE_ROOT = path.resolve(__dirname, '../../..');

const proc = spawn('agy', args, {
  cwd: WORKSPACE_ROOT, // リポジトリルートを固定
  env: {
    ...process.env,
    PATH: `${process.env.PATH}:/Users/aobaiwaki/.local/bin:/opt/homebrew/bin:/usr/local/bin`
  }
});
```

---

## 2. エージェントが自動認識・活用するリソース

`cwd` を固定した結果、Discord からプロンプトを受け取った `agy` は、プロンプト内で長々と前提を説明しなくても以下のリソースを自律的に活用できます:

### 2.1 リポジトリ共通規約 (`AGENTS.md`)
- 作業ブランチの運用ルール（main 未コミット保持規約、PR-Only Workflow）
- ドキュメント規約（絵文字の不使用、Mermaid 構文ルール、一次ソースリンク義務付け）
- 人間に対する信頼性・透明性担保ルール

### 2.2 リポジトリ定義スキル (`.agents/skills/`)
- `lumitree`: TimeTree 公開カレンダーからのアイドル・ライブ日程取得 (`scripts/fetch-events.py`)
- `discord-mcp`: Discord チャンネル操作・履歴検索
- `isucon-sandbox`: ISUCON 練習環境の自動構築
- `auto-allow-command`, `stacked-pr`, `review-skill`

### 2.3 過去の調査ナレッジ (`space/*/note/`)
- テーマごとの技術調査メモ、API 仕様、トラブルシューティング記録。

---

## 3. 実機検証での成功事例

Discord から以下のプロンプトを実行した際、エージェントは自発的に `.agents/skills/` 配下を走査し、リポジトリ固有のスキル一覧をマークダウン表にして返信することに成功しました:

- **実行コマンド**: `/agy prompt:このリポジトリのスキル一覧を教えて`
- **エージェントの自律動作**:
  1. カレントディレクトリの `.agents/skills/` をスキャン。
  2. 各スキルの `SKILL.md` の Frontmatter（`name`, `description`）を抽出。
  3. 各スキルの役割とファイルパスを Markdown 表形式に整形して返答。

---

## 4. 参考リソース

* [Google Antigravity CLI Reference](https://antigravity.google/docs/cli/reference)
* [Google Antigravity Customizations: Skills](https://antigravity.google/docs/skills)
