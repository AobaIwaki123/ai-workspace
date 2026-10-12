# ISUCON14 / ISURIDE 移行ランブック

この文書は、AWS EC2上の演習環境をProxmox自宅環境へ移すときの詳細手順です。
`SKILL.md` の概要を実行に落とすためのリファレンスであり、ホスト名・IP・VMID・
認証情報は既存のSSH Config、Terraform、Ansibleを正とします。

## 0. 移行方針

### 推奨構成

| 役割 | 推奨配置 | 理由 |
| --- | --- | --- |
| ISUCONアプリ、Nginx、MySQL | 専用Proxmox VM | systemd、OS、CPU、ファイルI/Oの挙動を保ちやすい |
| ベンチマーカー | K8s Job、別VM、または既存のベンチ環境 | 対象サーバーと負荷生成を分離できる |
| ログ・解析 | K8sまたはVM | alp、スロークエリ、pprofを集約しやすい |
| AWS EC2 | 移行確認中は保持、確認後に停止 | ロールバック用。停止後もEBSは残す |

Kubernetes Podへ全面移植する場合は、コンテナ化、Service、永続ボリューム、
Ingress、ベンチマーカーの到達性を別途設計する。公式ワークロードの再現性を優先する
段階では、VMをアプリ実行場所にする。

## 1. 事前確認

### 1.1 接続先を特定する

SSH Configや既存の管理資料から、次の役割を特定する。ここで値を推測してはいけない。

| 役割 | 探すもの |
| --- | --- |
| PVEノード | `pve` を含むホスト名、またはProxmoxの管理IP |
| Terraform実行環境 | Terraform Providerと既存のVM定義があるホスト |
| Ansible実行環境 | インベントリとPlaybookがあるホスト |
| K8sクラスタ | `kubectl config current-context` の接続先 |
| AWS対象 | `isucon14-practice` を識別できるInstance IDまたはタグ |

読み取り専用の例:

```bash
ssh -G <pve-alias>
ssh root@<pve-host> 'hostname; pveversion --verbose'
ssh <terraform-host> 'hostname; test -d <terraform-repository>'
kubectl config current-context
kubectl get nodes -o wide
```

`kubectl` のContextが存在しても、`kubectl get nodes` が失敗するならK8sを移行先と
して扱わず、ネットワークまたはクラスタ状態を先に解決する。

### 1.2 変更前の安全確認

次の操作は対象と影響を確認してから行う。

- `terraform apply`
- Ansibleの変更系Playbook
- `kubectl apply`、Namespace削除、Job実行
- DNS、`/etc/hosts`、SSH Configの切り替え
- EC2の停止・終了

VM作成を許可された場合でも、VM名、VMID、IP、CPU、メモリ、ディスク、配置ノードを
実行直前に表示して確認する。既存VMID・IP・ホスト名との衝突を先に検査する。

## 2. AWSベースラインを保存する

移行前にAWS版を変更せず、次の情報を保存する。

1. Instance ID、タグ、状態、インスタンスタイプ、AMI、現在のIP。
2. HTTP/HTTPSのヘルスチェックとドメイン解決結果。
3. アプリのソース、ビルド方法、環境変数名、systemdユニット、Nginx設定。
4. MySQLのバージョン、データベース・ユーザー・スキーマ、必要な初期データ。
5. ベンチマーカーの実体、対象URL、オプション、実行時間、ログ保存場所。
6. ベンチ結果の論理的な `pass`、score、エラーコード、失敗理由。
7. `access.log`、Nginxログ、MySQL slow log、アプリログなどの解析材料。

アーカイブやDBダンプを作る場合は保存先と保持期間を決め、秘密情報をチャットやGitに
出さない。ベンチスクリプトがDiscord等へ通知する場合は、通知しないラッパーを優先し、
Webhook URLを出力しない。

ベンチプロセスの終了コードだけでは判定しない。プロセスが終了コード0でも、論理的な
支払い失敗や `pass=false` であることがあるため、結果本文と生成ログを確認する。

## 3. 移行先を選ぶ

| 目的 | 移行先 | 判断 |
| --- | --- | --- |
| AWS版に近いOS・DB・systemdの練習 | Proxmox専用VM | 第一候補 |
| K8sのDeployment/Service/Ingressを練習 | 既存のK8s模擬環境 | AWS版の完全移行とは分ける |
| 実行はVM、運用・計測はK8s | VM + K8s | 現実的な段階移行 |
| 公式環境をPodへ完全移植 | K8s | 追加設計・差分検証が必要 |

`space/isucon/k8s` は簡易Nginx + Go + MySQL環境であり、AWS版ISUCON14/ISURIDEの
移行先ではない。そこで `make bench` が通っても、公式環境の移行成功とは判定しない。

## 4. Proxmox VMを構築する

1. 既存Terraformリポジトリの変数、テンプレート、ネットワーク、ストレージ、SSH公開鍵を確認する。
2. 新しいVM名・VMID・IPを既存資産と照合する。
3. `terraform init` と `terraform plan` を対象環境で実行し、作成・変更・削除の一覧を確認する。
4. planに意図しない削除、既存VMの置換、別VMの変更があれば停止する。
5. 明示的な実行許可後に `terraform apply` を行う。
6. PVE上のVM状態、コンソール、NIC、IP、ディスク、cloud-init完了を確認する。

既存のTerraform/Ansibleに統合ラッパーがある場合はそれを優先する。ただし、ラッパーが
`apply`、VM停止、削除まで含む場合は、対象と作用を表示してから実行する。

## 5. Ansibleで環境を再構築する

Ansibleは次の順に適用し、各段階で状態を確認する。

1. OS、時刻、ホスト名、ネットワーク、必要パッケージ。
2. Go等のビルド環境、アプリの配置、systemdユニット。
3. MySQL、スキーマ、初期データ、ユーザー権限。
4. Nginx、upstream、TLSまたはHTTP、アクセスログ形式。
5. アプリのビルド、サービス起動、再起動後の自動起動。
6. ベンチマーカーからの到達性とログの書き込み。

MySQLのデータ移行には、異なるバージョン間でデータディレクトリを直接コピーせず、
原則として論理ダンプとリストアを使う。AWS固有のメタデータ、IAM、cloud-init、
Elastic IP前提の設定はVM用に置き換える。

## 6. 動作確認とベンチ比較

### 6.1 ベンチ前の確認

- 対象ドメインが新VMを指している、またはベンチ側のhosts/DNSで新VMへ解決される。
- Nginxが期待するHostヘッダーを受けている。
- アプリ、MySQL、Nginxのサービスが稼働している。
- DBスキーマと初期データが存在する。
- ベンチマーカーから新VMのポートへ到達できる。
- AWS版へ誤って負荷を送らない。

### 6.2 同じ条件で比較する

AWS版とProxmox版で、可能な限り以下をそろえる。

- ベンチマーカーのバージョン、対象URL、時間、同時実行条件。
- アプリのコミットまたはソース、DBスキーマ、初期データ。
- Nginxログ形式とログ収集範囲。
- ベンチ結果の `pass`、score、エラーコード、失敗理由。

CPUやストレージが違うためscoreの完全一致は要求しないが、論理的な失敗がないこと、
主要エンドポイントが正常であること、ログ解析が可能であることを必須とする。

`pass=false`、支払い失敗、5xx、接続エラーが残る場合は切り替えず、AWS版を維持する。

## 7. 切り替え、停止、ロールバック

### 切り替え

1. 新VMでベンチを成功させる。
2. SSH Config、hosts/DNS、ベンチ対象URLを新VMに切り替える。
3. 切り替え後にヘルスチェックとベンチを再実行する。
4. AWS版をすぐに終了せず、一定期間は停止可能な状態で保持する。
5. 安定確認後にEC2を停止する。停止後もEBS、スナップショット、関連IPの課金状態を確認する。

### ロールバック

1. AWSインスタンスを起動する。
2. AWS版の現在IPまたはドメインを確認する。
3. SSH Config、hosts/DNS、ベンチ対象URLをAWSへ戻す。
4. AWS版のヘルスチェックとベンチ結果を確認する。
5. 新VMの変更を削除・破棄するのは、影響範囲を確認してから行う。

EC2の終了（terminate）やVMの削除は、このランブックの通常の切り替え手順に含めない。
バックアップとロールバック確認後、人間が明示的に指定した場合だけ実行する。

## 8. 完了記録

次の項目を `space/isucon` の議論またはノートへ記録する。

- PVEノード、VM名、VMID、IP、CPU、メモリ、ディスク。
- TerraformとAnsibleの実行対象・コミット・plan結果。
- AWS版とProxmox版のベンチ結果（pass、score、コード、時刻）。
- 既知の性能差、未移行の機能、残っている課金項目。
- EC2を再開するコマンドと、hosts/SSH Configを戻す方法。
- 実行していない項目と、次に人間が判断する項目。
