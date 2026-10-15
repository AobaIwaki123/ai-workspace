---
name: lifestyle-logger
description: Records, structures, and updates daily lifestyle activities, physical events, decisions, and conversation topics into API-ready JSON logs under private/data/lifestyle-logs/YYYY/MM/YYYY-MM-DD.json. Use this skill when the user asks to log their daily life, record activities, track decisions from the conversation, or update their personal lifestyle log.
---

# Lifestyle Logger Skill

本スキルは、ユーザーの生活行動、フィールドワーク、決定事項、および対話から得られた洞察を、将来のAPI配信（REST API / JSON）に直結する日付別JSONファイル（`private/data/lifestyle-logs/YYYY/MM/YYYY-MM-DD.json`）として構造化して記録・更新します。

---

## 1. ファイル配置とスキーマ仕様

- **保存場所**: `private/data/lifestyle-logs/<YEAR>/<MONTH>/<YYYY-MM-DD>.json`
- **スキーマ定義**: `private/data/lifestyle-logs/schema/lifestyle-log.schema.json`
- **主要フィールド**:
  - `date`: 日付（YYYY-MM-DD）
  - `summary`: その日の総括（1行）
  - `events`: 身体的・外的な行動イベント（散歩、サウナ、読書、現場等）
  - `decisions`: 対話や内省から下された決定事項（方針・受容等）
  - `dialogue_topics`: 会話の主要トピックと要約（Takeaways）、同期ノートへのリンク

---

## 2. 実行手順

### Step 1: ログの記録（スクリプト実行）
日常の出来事や会話内容に応じて、付属のPythonスクリプト `.agents/skills/lifestyle-logger/scripts/log.py` を呼び出してエントリを追記します。

```bash
# イベントの記録
./.agents/skills/lifestyle-logger/scripts/log.py event \
  --date 2026-10-13 \
  --category fieldwork \
  --location "代官山 T-SITE" \
  --title "夜の散歩と書店フィールドワーク" \
  --details "中目黒から徒歩で代官山T-SITEへ散歩。文化空間の空気を吸い、写真撮影・本棚を観測。" \
  --tags "culture,walk,daikanyama,bookstore" \
  --summary "代官山T-SITE散歩と高尚外殻ハックの始動"

# 決定事項の記録
./.agents/skills/lifestyle-logger/scripts/log.py decision \
  --date 2026-10-13 \
  --topic "高尚外殻ハック（純喫茶・美術館・読書・ジム）の採用" \
  --context "感情に頼らず、客観的に評価される社会的記号をシステムとして実行する" \
  --decision "内面空虚と高尚記号の対比をハックとして楽しみ、生活のログを残していく" \
  --tags "identity,lifestyle,hack"

# 対話トピックの記録
./.agents/skills/lifestyle-logger/scripts/log.py topic \
  --date 2026-10-13 \
  --topic "推し活の境界線と自己実現の代理トラップの解体" \
  --takeaways "他人の夢で自分の人生を乗っ取らない;推し活はテーマパーク運用にダウングレード;日常の地味な手触りを増やす" \
  --notes "private/space/interpersonal-communication/note/15_virtual_self_realization_trap_and_high_brow_shell_hack.md"
```

### Step 2: 整合性検証
生成されたJSONファイルが正しくフォーマットされ、スキーマに合致しているか確認します。

```bash
cat private/data/lifestyle-logs/YYYY/MM/YYYY-MM-DD.json | jq .
```
