---
name: isucon14-proxmox-migration
description: >-
  このスキルは、AWS EC2上のISUCON14/ISURIDE演習環境をProxmox VMへ移行し、
  必要に応じて自宅Kubernetesと組み合わせて検証する手順を案内する。EC2費用の削減、
  置き換え環境の構築、ベンチ結果の比較、AWS環境の停止・終了を行うときに使用する。
---

# ISUCON14 Proxmox移行

## 目的

AWS上のISUCON14演習環境を自宅環境へ移し、ベンチマークの挙動とロールバック手段を
維持するために使用する。

標準の移行先は、アプリケーション、Nginx、MySQLを稼働させる専用Proxmox VMとする。
Kubernetesはベンチマーカー、ログ収集、管理層として組み合わせてもよい。公式ワーク
ロードをKubernetes Podへ再構築する場合は別の選択肢として扱い、自動的に前提としない。

## 重要な境界

- 変更前に、既存のSSH Config、Terraformリポジトリ、Ansibleインベントリ、AWSインス
  タンス、Kubernetes Contextを確認する。
- `terraform apply`、Ansibleによる変更、DNS・hosts変更、EC2停止の前に、`terraform
  plan`、ヘルスチェック、ベンチ比較を判定ゲートにする。
- 置き換え先が同じ論理ベンチマークに合格し、ロールバック用の成果物が保持されるまで、
  AWSインスタンスを終了しない。
- SSH秘密鍵、APIトークン、DB認証情報、Webhook URL、未加工ログをチャット、ソース、
  生成レポートへ出さない。
- ローカルにKubernetes ContextがあってもAPIサーバーへ到達できるとは限らない。Nodeと
  Serviceへの接続を明示的に確認する。

## 手順の概要

1. [移行ランブック](references/migration-runbook.md)を読み、PVE、Terraform、Ansible、
   AWS、Kubernetesの実際の接続先を棚卸しする。
2. AWS版の状態、エンドポイント、ベンチ結果、アプリ・設定、DBスキーマまたはダンプ、
   診断ログを保存する。
3. 移行先を選ぶ。OSレベルの再現性を優先するならVM、模擬環境の挙動を目的とする場合
   だけKubernetes模擬環境を選ぶ。
4. 既存のTerraformとAnsibleで移行先を構築・設定する。適用前にplanと対象識別子を確認する。
5. 実際のベンチマーク経路から検証し、プロセスの終了ステータスだけでなく、論理的な
   `pass`とscoreも確認する。
6. 比較結果が許容できてから切り替える。AWSインスタンスは保持したまま停止し、移行先が
   安定するまでEBSとバックアップを残す。
7. 実行コマンド、結果、未解決の差分、正確なロールバック手順を記録する。

## 環境固有の注意

リポジトリの`space/isucon/k8s`マニフェストは、簡易的なNginx + Goアプリケーション +
MySQLの模擬環境を定義している。AWS版ISUCON14/ISURIDEを自動的にデプロイするものではない。
同ディレクトリの`make bench`が成功しても、AWS版ワークロードの移行成功とは判定しない。
