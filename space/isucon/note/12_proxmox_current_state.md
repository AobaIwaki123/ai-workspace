# 12: ISUCON14 Proxmox環境の現在地（2026-10-12）

## 1. 背景と現象の観察

AWS EC2上で動かしていたISUCON14/ISURIDE演習環境を、費用削減と自宅での再現性確保のためProxmox VMへ移行した。現在はアプリケーション、Nginx、MySQL、ベンチマーカーを専用VMで動かし、Tailscale経由でチームメンバーがアクセスする構成になっている。

### 実行環境

| 項目 | 現在値 |
| :--- | :--- |
| Proxmoxノード | `pve201` |
| VM | `isucon14` / VMID `236` |
| VMリソース | 2 vCPU / 4 GiB / 32 GiB |
| LANアドレス | `192.168.11.236` |
| Tailscaleアドレス | `100.127.83.117` |
| アプリ構成 | Goアプリ、Nginx、MySQL、matcher、payment mock |
| ベンチ対象 | VM内の `http://127.0.0.1` |

SSHはローカルの`~/.ssh/config`で以下を使い分ける。

```text
ssh isucon14       # Tailscale SSH / User isucon
ssh isucon14-pve   # 自宅LAN / User aoba
```

AWS EC2は停止済みで、ロールバック用に終了せず保持している。

## 2. 構造分析 / メカニズム

### デプロイ経路

GitHubリポジトリはVM上で直接`git pull`できる認証状態にしていないため、ローカルの`/Users/aobaiwaki/isucon14-retry`から`rsync`で同期する。`make deploy`は次を行う。

1. `webapp/`、`env.sh`、ベンチラッパー、MySQL設定をVMへ同期
2. VM上でGo 1.23ツールチェーンを使ってビルド
3. `isuride-go`を再起動し、`active`を確認

MySQL設定は`make mysql-config`で`mysqld --validate-config`を通してから反映する。AppArmorが`/home`配下の設定ファイルを拒否したため、`/etc/mysql/mysql.conf.d/mysqld.cnf`へroot所有の実ファイルとして配置する方針にした。

### pt-query-digestが出なかった原因

当初は`pt-query-digest`自体はVMにインストールされていたが、以下の不一致があった。

- MySQLの実効値が`slow_query_log=0`、`long_query_time=10`
- 実効slow logパスは`/var/lib/mysql/isucon14-slow.log`
- ベンチラッパーは`/var/log/mysql/mysql-slow.log`を固定参照
- リポジトリのMySQL設定がVMへ反映されていなかった

そのため、ベンチ後にコピーする入力ファイルが存在せず、`pt-query-digest.txt`も生成されなかった。

現在は次の値を確認済みである。

```text
slow_query_log=1
slow_query_log_file=/var/log/mysql/mysql-slow.log
long_query_time=0
/usr/bin/pt-query-digest が存在
```

ラッパーはMySQLから実効slow logパスを取得し、slow logが無効・空・解析ツール未導入の場合も診断内容を成果物へ出力する。

## 3. 検証結果と現在の変更状態

2026-10-11の実ベンチで、以下の成果物を生成できた。

```text
/home/isucon/logs/20261011_073411/mysql-slow.log
/home/isucon/logs/20261011_073411/pt-query-digest.txt
```

`pt-query-digest.txt`は約19 KiBで、約34.8万クエリ、約5.2k QPSの集計結果を含む。ログ収集問題は解決済みと判断する。

一方、このベンチでは評価APIのHTTP 502（CODE=5）が89件発生した。ベンチの判定は`pass=true`、スコアは979だったが、アプリケーションの評価処理には未解決の問題が残っている。

### Git状態

- PR #24（Proxmoxデプロイ・ベンチ基盤）はマージ済み。
- pt-query-digest修正はPR [#25](https://github.com/sharehouse-sanhaimu/isucon14-retry/pull/25)でレビュー待ち。
- PR #25のコミットは`f09a16f`。
- ローカル作業ツリーは`main`へ戻してクリーンな状態。
- VMにはPR #25相当のラッパーとMySQL設定を先行反映済み。

## 4. 次のアクションプロトコル

1. PR #25をレビュー・マージする。
2. マージ後の`main`から`make deploy`を実行し、VM上の状態をリポジトリと一致させる。
3. `CODE=5`の502を、Nginx access/error log、`isuride-go`のjournal、matcher/payment mockの状態で切り分ける。
4. エラー解消後に同一条件でベンチを再実行し、`pass`、スコア、pt-query-digestの3点を確認する。
5. AWS EC2はProxmox版の安定稼働とロールバック手順確認まで停止状態で保持し、終了は別途判断する。

## 参考文献 (Authoritative References)

- [MySQL 8.0 Reference Manual: The Slow Query Log](https://dev.mysql.com/doc/refman/8.0/en/slow-query-log.html)
- [Percona Toolkit: pt-query-digest](https://docs.percona.com/percona-toolkit/pt-query-digest.html)
- [Ubuntu Server documentation: AppArmor](https://ubuntu.com/server/docs/security-apparmor)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
