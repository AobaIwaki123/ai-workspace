# ADR-0001: Mirrored ネットワークモードの採用

## ステータス

承認 / 適用済み (Accepted)

---

## コンテキスト (背景と課題)

WSL2 上で構築したサーバー（SSH, Docker, Web/API, DB）を同一 LAN 内の他端末（Mac, PC, スマホ等）からアクセス可能にするにあたり、従来の「NAT ネットワークモード」には以下の運用上の課題が存在していました：

1. **WSL IP アドレスの変動**:
   WSL の起動・再起動のたびに仮想サブネットの IP（`eth0`）が変化するため、Windows 側のポート転送（`netsh interface portproxy`）をスクリプト等で毎回同期・再設定する必要があった。
2. **ポート転送設定の二重管理とサスペンド問題**:
   Windows ホストと WSL 間でポートプロキシを挟むことによるオーバーヘッド、および WSL セッションがアイドル状態になった際の仮想アダプタ休止による接続断が発生しやすかった。
3. **IPv6 やローカル名前解決（mDNS）の制約**:
   NAT モードでは IPv6 透過性やマルチキャスト通信に制限があった。

---

## 意思決定 (Decision)

Windows 11 (22H2 22621.2361+) および WSL 2.0+ の機能である **「Mirrored ネットワークモード (`networkingMode=mirrored`)」** を標準ネットワーク構成として採用する。

### 設定内容 (`%USERPROFILE%\.wslconfig`)

```ini
[wsl2]
networkingMode=mirrored
firewall=true
```

---

## 結果と影響 (Consequences)

### メリット (Positive)
- **ポート転送 (portproxy) の完全撤廃**:
  WSL 内で起動したプロセス（sshd, nginx, docker 等）が、Windows ホストの物理 LAN IP アドレスで直接リッスンされるため、`netsh` コマンドによる転送設定が一切不要になる。
- **IP アドレスの一意性**:
  WSL 再起動時にもクライアント側は同一の Windows ホスト IP でそのままアクセスを継続できる。
- **高速な通信と IPv6 対応**:
  ホストネットワークスタックと統合され、オーバーヘッドが低減し IPv6 もシームレスに機能する。

### デメリット・留意点 (Negative / Risks)
- **ホスト側ポートとの競合管理**:
  Windows 側と WSL 側で同一ポート（例: ポート 22）を同時にバインドできないため、Windows 側の「OpenSSH SSH Server」サービスを停止・無効化しておく必要がある。
- **Windows ファイアウォールの受信規則**:
  外部端末から接続する場合は、Windows Defender ファイアウォールにて該当ポート（ポート 22 等）の受信規則（Inbound Rule）を許可する必要がある。
