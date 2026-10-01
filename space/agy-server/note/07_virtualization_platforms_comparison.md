# 仮想化基盤の技術選定比較 (Lima, Firecracker, Multipass, Proxmox/KVM)

本ドキュメントは、Antigravity AI サーバーを稼働させるための仮想マシン基盤（Hypervisor / microVM）について、起動速度、リソース効率、ホスト環境との親和性、および運用シナリオごとの技術選定をまとめたノートです。

---

## 1. 仮想化基盤の比較マトリクス

| 仮想化技術 | 主な対象 OS | 起動速度 | リソース消費 | ポート転送・ファイル共有 | 推奨ユースケース |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Lima (Linux on Mac)** | macOS (Apple Silicon / Intel) | 5 〜 10 秒 | 低 (Virtualization.framework) | **標準で完全統合** (自動 localhost 転送) | **Mac ローカルでの検証・開発環境に最適**。brew で導入可能。 |
| **Multipass (Canonical)** | macOS / Linux / Windows | 10 〜 20 秒 | 中 (QEMU / Hyper-V) | 手動設定が必要 (`multipass mount`) | 開発者のクロスプラットフォーム統一環境。 |
| **Firecracker (microVM)** | Linux (KVM 有効) | **5 ミリ秒 〜 1 秒** | **極めて低い** (数 MB RAM) | TAP デバイス / iptables 制御 | **リクエスト単位で使い捨てる大規模 AI サーバー基盤**。 |
| **Proxmox VE / KVM** | 自宅サーバー / 専用物理機 | 15 〜 30 秒 | 中〜高 (完全仮想化) | Web UI / API 管理 | 24 時間常時稼働のプライベート AI サーバー・ホームラボ。 |
| **Cloud VM (GCE / EC2)** | パブリッククラウド | 30 〜 60 秒 | 従量課金 | セキュリティグループ / VPC | チーム共有の本番運用、GPU インスタンス活用時。 |

---

## 2. 各基盤の詳細分析

### 2.1 Lima (macOS 環境での第一候補)
- **特徴**:
  - macOS のネイティブハイパーバイザ（Virtualization.framework）を利用しており、非常に高速でバッテリー消費が少ない。
  - ホスト上のポート（例: `8080`）と VM 内部のポートが自動バインドされるため、Mac からそのまま `curl localhost:8080` でアクセス可能。
  - `limactl shell <vm-name>` で対話型シェルに入ることができ、設定のコピーも `limactl copy` で容易。
- **導入手順**:
  ```bash
  brew install lima
  limactl start template://ubuntu-lts
  ```

### 2.2 Firecracker (クラウド / 自前 Linux サーバーでの最強候補)
- **特徴**:
  - AWS Lambda や AWS Fargate、Fly.io が採用する Rust 製の超軽量 microVM。
  - 不要な仮想デバイス（PCI バスやグラフィック等）を極限まで削ぎ落とし、最小限のシリアルと virtio のみで起動。
  - コンテナと同等の起動速度（数ミリ秒〜数百ミリ秒）でありながら、完全な KVM ハードウェア分離を実現。
- **制約**:
  - ホスト側に Linux カーネルと KVM (`/dev/kvm`) が必須（macOS 上では直接動かない）。

---

## 3. 推奨ロードマップ

1. **フェーズ 1 (現在)**:
   - 手元の Mac 上で Node.js プロセスとして Bot Runner を稼働（最速 PoC）。
2. **フェーズ 2 (ローカル分離)**:
   - Mac 上に `lima` で軽量 Ubuntu VM を立ち上げ、その中で `agy` + Bot を稼働させてホストから完全に切り離す。
3. **フェーズ 3 (常時運用)**:
   - 自宅 Linux サーバー（Proxmox / KVM）またはクラウド VM にデプロイし、24時間常時待受の AI サーバーとして運用。

---

## 4. 参考リソース

* [Lima: Linux virtual machines on macOS](https://github.com/lima-vm/lima)
* [Firecracker: Secure and fast microVMs for serverless computing](https://firecracker-microvm.github.io/)
* [Multipass Official Documentation](https://multipass.run/docs)
* [Apple Developer: Virtualization Framework](https://developer.apple.com/documentation/virtualization)
