# Proxmox VM プロビジョニング手順と AI フレンドリーな自動化基盤設計 (09_proxmox_vm_provisioning_and_ai_friendly_automation.md)

本ドキュメントは、Discord Bot 常駐用として Proxmox 上に新規 Ubuntu VM を構築した実際の一連の作業手順（Runbook）を記録し、現行の運用におけるフリクション（課題）を分析した上で、AI エージェントが自律的かつ安全にプロビジョニングを実行できる「AI フレンドリーなインフラ運用基盤」の改変設計案をまとめたものです。

---

## 1. 実際の作業手順記録 (Execution Runbook)

### 1.1 Tailscale 疎通障害の特定と復旧
* **現象**: Mac クライアントから Proxmox クラスタノード（`pve201-ts.node` / `100.114.144.77`）への SSH 接続が遮断され、ProxyJump 経由の VM アクセスが全滅。
* **原因分析**: `tailscale ping 100.114.144.77` により `peer's node key has expired` を検知。ノードキー有効期限切れによりサーバー側 Tailscale デーモンがログアウト状態（`Logged out.`）になっていた。
* **復旧対処**: 自宅 LAN IP（`192.168.11.201`）へ直接 SSH し、`tailscale up` を実行してノードを即座に再アクティブ化。

### 1.2 Terraform による VM 作成 (`terraform.vm`)
* **ホスト環境**: `terraform.vm` (`192.168.11.210`, ユーザー `aoba`)
* **リポジトリ**: `/home/aoba/Proxmox-Terraform`
* **実行手順**:
  1. 環境スキャフォールドの作成:
     ```bash
     make create-vm ENV=discord-bot
     ```
  2. パラメータ定義 (`envs/discord-bot/terraform.tfvars`):
     * ホスト名: `discord-bot`
     * VMID: `235` / IP アドレス: `192.168.11.235/24` (ゲートウェイ: `192.168.11.1`)
     * スペック: 2 コア CPU, 4096 MB RAM, 32 GB ディスク (virtio0, local-lvm)
     * ベーステンプレート: `ubuntu-24.04a` (Cloud-init 対応)
     * 公開鍵: Mac 端末鍵および `ansible.lxc` の `id_ecdsa.pub`
  3. 初期化とプロビジョニング実行:
     ```bash
     export PATH="$HOME/.asdf/shims:$HOME/.asdf/bin:$HOME/.tfenv/bin:$PATH"
     make init ENV=discord-bot
     make plan ENV=discord-bot
     make apply ENV=discord-bot
     ```
  4. 結果: Proxmox ノード `pve201` 上に VMID 235 がクローン作成され、正常に起動完了。

### 1.3 SSH 構成の更新
Mac 側の `~/.ssh/config.d/pve` に新規ホスト定義を追記:
```ssh-config
Host discord-bot.vm
    Hostname 192.168.11.235
```
これにより、`ssh discord-bot.vm` による直接 SSH ログインが可能となった。

### 1.4 Ansible による初期構成 (`ansible.lxc`)
* **ホスト環境**: `ansible.lxc` (`192.168.11.211`, ユーザー `root`)
* **リポジトリ**: `/root/ansible`
* **実行手順**:
  1. インベントリ (`/root/ansible/inventory/hosts`) および `~/.ssh/ssh_config.d/vm.conf` に `discord-bot.vm` を追加。
  2. 疎通テスト:
     ```bash
     export PATH="/root/miniconda3/envs/ansible/bin:$PATH"
     ansible -i inventory/hosts discord-bot.vm -m ping
     ```
  3. `init-vm` プレイブック実行:
     * `ANSIBLE_BECOME_ASK_PASS=False` を付与し、非対話型で sudo 実行。
     * 基本パッケージ、Docker、Tailscale の自動構成。

---

## 2. 現行運用の課題分析 (摩擦とフリクション)

手動コマンド実行の過程で、AI エージェントや CI/CD 自動化にとって大きな障壁となる以下のフリクションが浮き彫りとなりました。

| 領域 | 現行の課題・摩擦点 | AI / 自動化への影響 |
| :--- | :--- | :--- |
| **環境変数 (PATH)** | `~/.bashrc` の先頭にある `[ -z "$PS1" ] && return` により、非対話 SSH セッションで `asdf`, `tfenv`, `conda` 等のパスが失われる | コマンド実行時に `command not found` となり、毎回フルパスや明示的 `export PATH` の指定が必要となる |
| **対話型プロンプト** | `ansible.cfg` に `become_ask_pass = True` があるため、sudo パスワード不要の環境でも標準入力待ちでプロセスがハングする | エージェントがタイムアウトまで停止するか、タスクを強制終了して環境変数で抑止する必要が生じる |
| **分散した実行環境** | Terraform 用 VM、Ansible 用 LXC、PVE ノード、自機 Mac の 4 箇所にコンテキストが分散 | コマンド発行のホップ数が多く、エラー発生時の原因特定やコンテキスト追跡コストが高い |
| **鍵の有効期限切れ** | Tailscale ノードの Key Expiry（180日）による突然の切断 | 予告なくネットワーク到達性が失われ、自己修復できない外部閉塞に陥る |
| **設定の二重管理** | IP アドレス・VMID・ホスト名を Terraform tfvars、SSH config、Ansible hosts の 3 箇所に手動記述 | 記述漏れや IP 重複事故のリスクが生じ、自動化の単一責任原則（SSOT）に反する |

---

## 3. AI フレンドリーなプロビジョニング基盤への改変設計案

AI エージェントが 1 つの指示（単一のツール呼び出しや API リクエスト）で安全・確実・冪等に VM を起票できるよう、以下の 4 本柱でシステム改変を提案します。

### 3.1 統合ラッパースクリプト (Single Entrypoint) の導入
Mac または作業端末から 1 コマンドで全行程を実行できるスクリプトを整備します。

```bash
# 実行例（1 コマンドで完結）
./scripts/provision-vm.sh --name discord-bot --vmid 235 --ip 192.168.11.235 --cores 2 --memory 4096
```

#### 内部パイプライン構成
1. **事前検証 (Pre-flight Checks)**:
   - 対象 IP の ping による空き確認
   - PVE 上の既存 VMID 重複チェック
2. **Terraform 実行**:
   - `ssh terraform.vm` 経由で tfvars 生成から `init`, `apply` を非対話型（`-auto-approve`）で完遂。
3. **SSH / インベントリ同期**:
   - 作業端末の `~/.ssh/config.d/` と `ansible.lxc` のインベントリへ自動追記。
4. **Ansible 実行**:
   - `ssh ansible.lxc` 経由で `ANSIBLE_BECOME_ASK_PASS=False` を明示し、ターゲット VM をプロビジョニング。
5. **事後検証 (Health Check)**:
   - 新規 VM への SSH 疎通と cloud-init 完了（`cloud-init status --wait`）の確認。

### 3.2 非対話実行 (Non-Interactive) の徹底
* **/etc/environment への PATH 集約**:
  - `terraform.vm` および `ansible.lxc` において、`asdf`, `tfenv`, `miniconda3` のバイナリパスを `/etc/environment` または `/etc/profile.d/` に配置し、非対話 SSH セッション（`-c` 実行）でも自動的にロードされる状態にします。
* **Ansible 実行の非対話化**:
  - Cloud-init で作成される管理ユーザー（`aoba`）は `NOPASSWD: ALL` が保証されているため、Playbook 側で `ansible_become_ask_pass: false` を明示的に既定値とし、対話プロンプトを完全撲滅します。

### 3.3 Tailscale Key Expiry の恒久防止 (Tailscale Tags 運用)
Tailscale の仕様上、**タグ（`tag:*`）を付与されたデバイスは Key Expiry（鍵の有効期限）が自動的に無効（Never expire）** になります。

```bash
# サーバー側でのタグ付きログイン（例）
tailscale up --authkey=tskey-auth-... --advertise-tags=tag:server --reset
```
* これにより、Proxmox ノードや踏み台 VM、Bot サーバーが期限切れで突如到達不能になる障害をアーキテクチャレベルで防止します。

### 3.4 単一情報源 (SSOT) によるホスト定義の一元化
`hosts.yaml` などの単一設定ファイルから、Terraform の tfvars、Ansible インベントリ、SSH config をコード生成（Template 生成）する仕組みを導入し、手作業による同期ズレを排除します。

---

## 4. 権威ある参考リソース

* [Terraform Proxmox Provider Documentation (Telmate)](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
* [Ansible Non-Interactive & Privilege Escalation Best Practices](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_privilege_escalation.html)
* [Tailscale Machine Key Expiry and Tags Policy](https://tailscale.com/kb/1028/key-expiry)
* [Ubuntu Cloud-Init Architecture & Datasources](https://cloudinit.readthedocs.io/en/latest/)
* [OpenSSH ssh_config Specification](https://man.openbsd.org/ssh_config)
