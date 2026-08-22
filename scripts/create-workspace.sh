#!/usr/bin/env bash
# ==============================================================================
# Workspace Scaffolding Tool
#
# Usage:
#   ./scripts/create-workspace.sh <workspace-name> "<workspace-title>"
#
# Examples:
#   ./scripts/create-workspace.sh timetree "TimeTree 公開カレンダー連携・調査"
# ==============================================================================

set -euo pipefail

WORKSPACE_NAME="${1:-}"
WORKSPACE_TITLE="${2:-$WORKSPACE_NAME}"

if [[ -z "$WORKSPACE_NAME" ]]; then
  echo "❌ Error: Workspace name is required."
  echo "Usage: $0 <workspace-name> [workspace-title]"
  exit 1
fi

TARGET_DIR="./$WORKSPACE_NAME"

if [[ -d "$TARGET_DIR" ]]; then
  echo "⚠️ Workspace directory '$TARGET_DIR' already exists."
fi

echo "🚀 Scaffolding workspace '$WORKSPACE_NAME' ($WORKSPACE_TITLE)..."

mkdir -p "$TARGET_DIR/note"
mkdir -p "$TARGET_DIR/adr"
mkdir -p "$TARGET_DIR/scripts"

# 1. AGENTS.md
if [[ ! -f "$TARGET_DIR/AGENTS.md" ]]; then
  cat <<EOF > "$TARGET_DIR/AGENTS.md"
# $WORKSPACE_TITLE 規約 (AGENTS.md)

このワークスペースは、**$WORKSPACE_TITLE** に関する調査・設計・検証・自動化を推進するための協業領域です。

---

## 📁 ディレクトリ構成と役割

\`\`\`
$WORKSPACE_NAME/
├── AGENTS.md             # 本規約ファイル（スコープ・開発ルール）
├── discussion.md         # 議論の方向性、要件定義、進捗管理、アクションアイテム
├── note/                 # 調査・検証・技術メモ（01_xxx.md 形式で蓄積）
├── adr/                  # 確定した方針・アーキテクチャ選定 (0001-xxx.md)
└── scripts/              # 本テーマ専用のスクリプト・ツール・自動化コード
\`\`\`

---

## 📋 運用ルール

1. **進捗・議論の記録 (\`discussion.md\`)**
   - 議論の前提、目的、課題、ネクストアクションを常に最新に保ちます。
2. **知見の蓄積 (\`note/\`)**
   - 調査した仕様や技術検証の結果は \`note/\` に連番付きマークダウンで記録します。
3. **意思決定の記録 (\`adr/\`)**
   - 設計方針やアーキテクチャの選定理由は \`adr/\` に記録します。
4. **再現性の確保 (\`scripts/\`)**
   - 検証用スクリプトや実行手順は \`scripts/\` 配下にコード化して残します。
EOF
  echo "  ✅ Created $TARGET_DIR/AGENTS.md"
fi

# 2. discussion.md
if [[ ! -f "$TARGET_DIR/discussion.md" ]]; then
  cat <<EOF > "$TARGET_DIR/discussion.md"
# $WORKSPACE_TITLE ディスカッション & 進捗管理 (discussion.md)

このドキュメントでは、$WORKSPACE_TITLE に関する目的、ロードマップ、議論の経緯、進捗を記録・管理します。

---

## 🎯 目的・ゴール

- 

---

## 🗺️ ロードマップ / タスク

| Step | 項目 | 内容 | 状況 |
| :--- | :--- | :--- | :--- |
| **Step 1** | **調査・要件定義** | 仕様調査および実現可能性の検証 | 🔄 進行中 |
| **Step 2** | **設計・方針決定** | アーキテクチャや連携方法の決定 | 📋 未着手 |
| **Step 3** | **実装・スクリプト化** | 実行コード・自動化ツールの作成 | 📋 未着手 |

---

## 📝 決定事項 (ADR一覧)

- なし

---

## 📌 直近のネクストアクション

- [ ] 
EOF
  echo "  ✅ Created $TARGET_DIR/discussion.md"
fi

# Gitkeep files
touch "$TARGET_DIR/note/.gitkeep"
touch "$TARGET_DIR/adr/.gitkeep"
touch "$TARGET_DIR/scripts/.gitkeep"

echo "🎉 Workspace '$WORKSPACE_NAME' created successfully!"
