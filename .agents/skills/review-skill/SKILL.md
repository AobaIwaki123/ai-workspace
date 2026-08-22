---
name: review-skill
description: >-
  Reviews and validates Antigravity skills against official design best practices.
  Use when the user asks to review, audit, lint, or improve a skill, or after creating/editing any skill.
---

# Review Skill

本スキルは、Antigravity スキル（`SKILL.md`、スクリプト、リファレンス等）が公式ベストプラクティスおよび品質基準を満たしているかを静的解析・検証し、改善を提案・実施します。

## 1. 発動トリガー

- ユーザーが「スキルをレビューして」「スキルの書き方が合っているか確認して」「skillをリントして」と指示した時
- スキルを新規作成または大幅に編集した後、品質保証を行う時

---

## 2. レビュー手順

### Step 1: 自動バリデーションの実行
付属の検証スクリプト [scripts/validate-skill.sh](./scripts/validate-skill.sh) を実行し、構文・構造・権限をチェックします。

```bash
# 対象スキルディレクトリを指定して検証
./.agents/skills/review-skill/scripts/validate-skill.sh .agents/skills/<skill-name>
```

### Step 2: 評価観点の精査
[references/checklist.md](./references/checklist.md) に基づき、以下のポイントをレビューします:

1. **YAML Frontmatter の精度**:
   - `name` が kebab-case かつディレクトリ名と一致しているか
   - `description` が 3人称で、発動条件（What & When）が具体的か
2. **段階的情報開示（Progressive Disclosure）**:
   - `SKILL.md` 本文が長大化（200行超）していないか
   - 詳細ドキュメントが `references/` に分離され、相対リンクが正しく貼られているか
3. **スクリプトの安全性・実行権限**:
   - `scripts/` 内のスクリプトに `chmod +x` が付与されているか
   - `set -euo pipefail` などのエラーハンドリングが適切か
4. **検証ループの有無**:
   - 完了時の成功確認・テスト手順が明記されているか

### Step 3: レビュー結果の提示と改善の実施
- エラーまたは警告がある場合は、具体的な修正コードまたは diff を提示して修正を実施します。
- 問題がなければ、品質基準を満たしている旨をユーザーに報告します。
