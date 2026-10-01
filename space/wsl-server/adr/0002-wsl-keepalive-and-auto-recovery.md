# ADR-0002: WSL 常駐化および内部再起動時の自動復旧（Keep-Alive Loop）の採用

## ステータス

承認 / 適用済み (Accepted)

---

## コンテキスト (背景と課題)

WSL2 を 24時間稼働のサーバーとして運用する際、以下の 2 つの停止リスクが存在していました：

1. **アイドル終了（省電力停止）**:
   フォアグラウンドのターミナル画面やアクティブなセッションを閉じると、WSL2 が自動的にインスタンスを終了（Stopped）させてしまう。
2. **Linux 内部再起動時の停止（Stopped）**:
   Ubuntu 内部でパッケージ更新やカーネル更新に伴い `sudo reboot` や再起動要求が発生した場合、WSL2 インスタンスが終了（Exit）し、Windows 側から再度 `wsl.exe` を叩かない限り電源オフ状態のまま放置される。単なる「1回限りのログオン時起動タスク」では再起動後の自動復旧が不可能。

---

## 意思決定 (Decision)

Windows タスクスケジューラにて、**PowerShell による常駐監視ループ（Keep-Alive Loop Watcher）** をバックグラウンド（Hidden）で実行する方式を採用する。

```powershell
while ($true) {
    wsl.exe -d Ubuntu -u root --exec sleep infinity
    Start-Sleep -Seconds 2
}
```

### アーキテクチャの挙動
1. 通常時: `sleep infinity` が WSL セッションを永続維持し、ターミナルを閉じても Stopped にならない。
2. Ubuntu 内部で `sudo reboot` やクラッシュが発生した時:
   `sleep infinity` が exit するが、外側の PowerShell ループが **2秒後に自動で `wsl.exe` を再実行**するため、数秒で新セッション・systemd・SSH サーバーが自動復旧する。
3. Windows 起動時: ログオン時に自動でこのウォッチャータスクが非表示で立ち上がる。

---

## 結果と影響 (Consequences)

### メリット (Positive)
- **Ubuntu 内部での再起動（`reboot`）に対応**: Ubuntu 側で再起動がかかっても、ユーザーが Windows 側を操作することなく数秒で自動復旧する。
- **ターミナル画面の完全クローズ可能**: ターミナルを立ち上げっぱなしにする必要が一切なくなる。
- **追加ソフトウェア不要**: サードパーティのサービス化ツール（NSSM 等）をインストールせず、Windows 標準の PowerShell とタスクスケジューラのみで完結する。

### デメリット・留意点 (Negative / Risks)
- 意図的に WSL を完全停止させたい場合は、タスクを一時停止（`Stop-ScheduledTask -TaskName WSL-AutoStart-Server`）してから `wsl.exe --shutdown` を実行する必要がある。
