---
name: taite-tenant-scaffold
description: Scaffolds and registers a new idol group tenant in taite-board with data schema, frontend routing, ingress, and TimeTree/X intake.
---

# taite-tenant-scaffold

X アカウントや TimeTree を持つ任意のアイドルグループを `taite-board` のマルチテナント基盤（`<group_id>.iorin.net`）へ新規追加・構成するための手順と契約情報。

---

## 1. 構成対象ファイル一覧（変更箇所）

新規テナントの追加には以下の 4 ファイルを更新・配置する。

| ファイル | 役割 | 出典 / リファレンス |
|---|---|---|
| [`data/groups.json`](file:///Users/aobaiwaki/ai-workspace/space/taite-board/data/groups.json) | バックエンド、CLI、フィルタ、名寄せ判定の共通グループ定義 | [note/15_dollykiss_multigroup...md](file:///Users/aobaiwaki/ai-workspace/space/taite-board/note/15_dollykiss_multigroup_and_e2e_crawler_verification_plan.md) |
| [`apps/web/src/config/group.ts`](file:///Users/aobaiwaki/ai-workspace/space/taite-board/apps/web/src/config/group.ts) | フロントエンドのサブドメイン（`*.iorin.net`）解決・テーマ定義 | [apps/web/src/config/group.ts](file:///Users/aobaiwaki/ai-workspace/space/taite-board/apps/web/src/config/group.ts) |
| `data/groups/<group_id>/schedule.json` | テナント固有のスケジュール永続化データ（必須メタデータを含む） | [data/groups/dollykiss/schedule.json](file:///Users/aobaiwaki/ai-workspace/space/taite-board/data/groups/dollykiss/schedule.json) |
| [`k8s/manifests/ingress.yaml`](file:///Users/aobaiwaki/ai-workspace/space/taite-board/k8s/manifests/ingress.yaml) | Cloudflare Tunnel Ingress のホスト名ルーティング | [cluster/addons/networking/cloudflare-tunnel](file:///Users/aobaiwaki/k8s-cluster/cluster/addons/networking/cloudflare-tunnel) |

---

## 2. 契約仕様と追加手順

### Step 1. グループ定義の追加 (`data/groups.json`)

`groups.<group_id>` に以下を定義する。

```json
"<group_id>": {
  "id": "<group_id>",
  "name": "グループ正式名称",
  "short_name": "略称",
  "x_account": "Twitter公式ID (@なし)",
  "aliases": ["公式名", "略称", "ローマ字表記等"],
  "timetree_id": "公開カレンダーのaliasCode (ない場合は空文字)",
  "data_path": "data/groups/<group_id>/schedule.json",
  "theme": {
    "primary": "Tailwindカラー名 (例: rose, pink, sky, emerald)",
    "accent": "Tailwindカラー名 (例: purple, amber, sky)"
  }
}
```

### Step 2. 初期スケジュールの配置 (`data/groups/<group_id>/schedule.json`)

空配列または初期イベントを含む最小構造を配置する。
※ Web 開発・ビルド同期用として `apps/web/public/data/groups/<group_id>/schedule.json` にも同一内容を配置する。

```json
{
  "schema_version": 1,
  "group_id": "<group_id>",
  "generated_at": "YYYY-MM-DDTHH:MM:SS+09:00",
  "timezone": "Asia/Tokyo",
  "sessions": []
}
```

### Step 3. フロントエンドのルーティング登録 (`apps/web/src/config/group.ts`)

`REGISTERED_GROUPS` に追加。サブドメイン `<group_id>.iorin.net` から自動解決される。

```typescript
<group_id>: {
  id: '<group_id>',
  name: 'グループ正式名称',
  shortName: '略称',
  logoText: '🎀',
  dataUrl: 'data/groups/<group_id>/schedule.json',
  fallbackDataUrl: 'schedule.json',
  storagePrefix: '<group_id>_',
  theme: {
    primary: '<primary_color>',
    accent: '<accent_color>',
  },
},
```

### Step 4. Cloudflare Tunnel Ingress への追加 (`k8s/manifests/ingress.yaml`)

`spec.rules` にホストを追加する。
`ingressClassName: cloudflare-tunnel` により、Kubernetes 側の変更を Cloudflare Ingress Controller が検知し、Cloudflare DNS（`iorin.net`）へ CNAME を自動プロビジョニングする。個別 DNS 登録の手動作業は不要。

```yaml
- host: <group_id>.iorin.net
  http:
    paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ribonclock
            port:
              name: http
```

### Step 5. 初期データの取得（TimeTree が存在する場合）

TimeTree カレンダーがある場合、`lumitree` API を利用して初回データを同期する。

- API: `https://lumitree.aooba.net/api/v1/calendars/{timetree_id}/events?year={YYYY}&month={MM}`
- 同期・マージ規約: `.agents/skills/taite-timetree-sync/SKILL.md` を参照。

### Step 6. スキーマ検証

```bash
# space/taite-board にてスキーマ妥当性を検証
taite validate
```
