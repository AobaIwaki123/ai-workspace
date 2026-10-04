# クラウド (AWS / GCP) での ISUCON 過去問環境構築・運用ガイド (07_cloud_practice_env.md)

ISUCON公式およびコミュニティが公開している資産（公式パブリックAMI、AWS CloudFormation、GCP cloud-init）を活用し、AWS または GCP（Google Cloud Platform）上に過去問演習環境を構築・運用・撤収するための実践ガイドです。
CLI / AIエージェントに操作を委任する際に必要となる最小IAM権限ポリシーも網羅しています。

---

## 1. おすすめの過去問と公式AMI一覧 (東京リージョン: ap-northeast-1)

コミュニティ（[matsuu/aws-isucon](https://github.com/matsuu/aws-isucon)）により、東京リージョン向けにパブリックAMIが提供されています。

| 過去問 | 東京AMI ID | 推奨インスタンス | 特徴と主な学び |
| :--- | :--- | :--- | :--- |
| **ISUCON11 予選** (ISUCONDITION) | `ami-0796be4f4814fc3d5` | `c5.large` / `t3.medium` | N+1解消、インデックス最適化、外部APIモック、複数台分散の王道（最優先推奨） |
| **ISUCON12 予選** (ISUPORTER) | `ami-073140ad092048333` | `c5.large` / `t3.medium` | SQLite WALモード、キャッシュ無効化設計、地理情報計算 |
| **ISUCON13** (ISUPipe) | `ami-006d211cb716fe8a0` | `c5.large` / `t3.medium` | ライブ配信、Websocket、画像配信、SingleFlight、最新構成 |
| **ISUCON14** | `ami-0fcf9e8e8675a9ee4` | `c5.large` / `t3.medium` | 最新大会問題 |
| **ISUCON10 予選** (ISUUMO) | `ami-03bbe60df80bdccc0` | `c5.large` / `t3.medium` | 不動産・椅子検索、MySQL Fulltext / 空間インデックス |

---

## 2. 必要な IAM 権限の定義

CLI または AI エージェントに環境構築〜撤収を一任する場合に必要な権限です。

### AWS の認証方式と必要な IAM 権限

AWS CLI での認証には、以下の3つの方式があります。AI エージェントと協業しながら平文キーをディスクに残さない運用としては、**「1Password CLI 連携 (方式 A)」が最も安全で強力**です。

---

#### 方式 A: 1Password CLI 連携 (`credential_process`・AI協業に最適)
1Password の Vault に保管されたアクセスキーを参照し、AWS CLI 実行時のみメモリ上で認証を行う最も安全な手法です。ディスク上に平文キー（`~/.aws/credentials`）が一切書き込まれず、AI エージェントにも生キーが露出することがありません。

##### 設定手順
1. 1Password 上に対象のアクセスキーアイテム（例: `AWS Access Key: isucon`）を作成。
2. 認証情報ブリッジスクリプト（`~/.aws/op-credential-process.sh`）を作成:
   ```bash
   #!/bin/bash
   AKID=$(op read "op://Personal/<ITEM_UUID>/access key id")
   SAK=$(op read "op://Personal/<ITEM_UUID>/secret access key")

   cat << JSON
   {
     "Version": 1,
     "AccessKeyId": "$AKID",
     "SecretAccessKey": "$SAK"
   }
   JSON
   ```
3. `~/.aws/config` に `credential_process` を設定:
   ```ini
   [default]
   region = ap-northeast-1
   output = json
   credential_process = /Users/<username>/.aws/op-credential-process.sh
   ```
4. 以降は `aws` コマンドを実行するだけで、1Password 経由で透過的に認証されます。

---

#### 方式 B: `aws login` (ブラウザベース認証)
長期的なアクセスキー（`AKIA...`）を発行・保存せず、ブラウザログイン経由で最大12時間有効な一時クレデンシャルを取得する安全な認証方式です（AWS CLI v2.32.0 以上が必要）。

##### 必要な IAM 権限
1. **root ユーザーでサインインする場合**: 追加のポリシーアタッチは不要です。
2. **IAM ユーザー / ロールでサインインする場合**: 以下の2つの AWS 管理ポリシーをアタッチします。
   - **`SignInLocalDevelopmentAccess`** (公式ドキュメント参照: `aws login` のローカル認証プロセスの許可)
   - **`AmazonEC2FullAccess`** (演習用 EC2 / セキュリティグループ / キーペアの作成・破棄権限)

##### サインイン手順
```bash
# ブラウザが自動起動し、コンソールログイン後に認証完了
aws login --region ap-northeast-1

# 有効期限終了時または演習終了時のログアウト
aws logout
```

---

#### 方式 C: アクセスキー認証 (`aws configure`)
従来の IAM ユーザーにアクセスキー（Access Key ID / Secret Access Key）を発行して手元に登録する方式です。

##### 必要な IAM 権限
- AWS 管理ポリシー: **`AmazonEC2FullAccess`**
- （最小権限に絞る場合）: 以下のカスタムポリシー JSON を使用。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "IsuconEc2Management",
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:StopInstances",
        "ec2:StartInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:CreateKeyPair",
        "ec2:DeleteKeyPair",
        "ec2:DescribeKeyPairs",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeImages",
        "ec2:CreateTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IsuconCloudFormationManagement",
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks",
        "cloudformation:DescribeStackEvents",
        "cloudformation:GetTemplate"
      ],
      "Resource": "*"
    }
  ]
}
```

---

### GCP の場合

演習用サービスアカウントまたはユーザーアカウントに以下の事前定義ロールを付与します。

| ロール名 | ロールID | 用途 |
| :--- | :--- | :--- |
| **Compute インスタンス管理者 (v1)** | `roles/compute.instanceAdmin.v1` | GCE VMインスタンスの作成、起動、停止、削除 |
| **Compute ネットワーク管理者** | `roles/compute.networkAdmin` | ファイアウォールルール（ポート80/443/3000開放）の管理 |
| **サービス アカウント ユーザー** | `roles/iam.serviceAccountUser` | VMにデフォルトサービスアカウントを紐付けて起動するために必要 |

---

## 3. AWS 環境の構築・操作手順

AWS CLI を使用して、パブリック AMI から直接インスタンスを起動する手順です。

### 手順 1: SSHキーペアの作成
```bash
aws ec2 create-key-pair \
    --region ap-northeast-1 \
    --key-name isucon-key \
    --query "KeyMaterial" \
    --output text > ~/.ssh/isucon-key.pem

chmod 400 ~/.ssh/isucon-key.pem
```

### 手順 2: セキュリティグループの作成とポート開放
自宅・作業場所のグローバルIPからのアクセスのみを許可します。
```bash
# セキュリティグループ作成
SG_ID=$(aws ec2 create-security-group \
    --region ap-northeast-1 \
    --group-name isucon-sg \
    --description "Security group for ISUCON practice" \
    --output text --query "GroupId")

# 自身のグローバルIPを取得して SSH(22), HTTP(80), HTTPS(443), App(3000) を開放
MY_IP=$(curl -s https://checkip.amazonaws.com)

aws ec2 authorize-security-group-ingress \
    --region ap-northeast-1 \
    --group-id "$SG_ID" \
    --protocol tcp --port 22 --cidr "${MY_IP}/32"

aws ec2 authorize-security-group-ingress \
    --region ap-northeast-1 \
    --group-id "$SG_ID" \
    --protocol tcp --port 80 --cidr "${MY_IP}/32"

aws ec2 authorize-security-group-ingress \
    --region ap-northeast-1 \
    --group-id "$SG_ID" \
    --protocol tcp --port 443 --cidr "${MY_IP}/32"
```

### 手順 3: EC2 インスタンスの起動 (例: ISUCON11 予選)
```bash
INSTANCE_ID=$(aws ec2 run-instances \
    --region ap-northeast-1 \
    --image-id ami-0796be4f4814fc3d5 \
    --instance-type c5.large \
    --key-name isucon-key \
    --security-group-ids "$SG_ID" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=isucon11q-practice}]' \
    --output text --query "Instances[0].InstanceId")

# 起動完了待ち
aws ec2 wait instance-running --region ap-northeast-1 --instance-ids "$INSTANCE_ID"

# パブリックIPアドレスの取得
PUBLIC_IP=$(aws ec2 describe-instances \
    --region ap-northeast-1 \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

echo "Instance IP: $PUBLIC_IP"
```

### 手順 4: SSH 接続とベンチマーク実行
```bash
# 接続（ubuntu ユーザー）
ssh -i ~/.ssh/isucon-key.pem ubuntu@$PUBLIC_IP

# isucon ユーザーにスイッチしてベンチマーク実行
sudo -i -u isucon
cd bench
./bench -all-addresses 127.0.0.11 -target 127.0.0.11:443 -tls -jia-service-url http://127.0.0.1:4999
```

> **ISUCON11 予選の注意点 (macOSでのポートフォワード)**:
> ISUCON11予選はJIA APIの認証通信が発生するため、ブラウザで管理画面を操作する際はローカルポートフォワードを使用します。
> ```bash
> ssh -i ~/.ssh/isucon-key.pem -L 5001:127.0.0.1:5000 ubuntu@$PUBLIC_IP
> ```
> ※ macOSで5000番ポートがAirPlay等で使用されている場合があるため、手元側を5001に設定します。

### 手順 5: 演習終了後の撤収（課金防止）
```bash
# インスタンスの削除
aws ec2 terminate-instances --region ap-northeast-1 --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --region ap-northeast-1 --instance-ids "$INSTANCE_ID"

# セキュリティグループとキーペアの削除
aws ec2 delete-security-group --region ap-northeast-1 --group-id "$SG_ID"
aws ec2 delete-key-pair --region ap-northeast-1 --key-name isucon-key
rm -f ~/.ssh/isucon-key.pem
```

---

## 4. GCP 環境の構築・操作手順 (GCE + cloud-init)

GCE 上でゼロから自動構成（cloud-init）して起動する手順です。

### 手順 1: cloud-config の取得とファイアウォール設定
```bash
# ISUCON11予選の cloud-config を取得
curl -LO https://raw.githubusercontent.com/matsuu/cloud-init-isucon/main/isucon11q/isucon11q.cfg

# ファイアウォールルールの作成（初回のみ）
gcloud compute firewall-rules create allow-isucon \
    --project=<GCP_PROJECT_ID> \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80,tcp:443,tcp:3000 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=isucon-node
```

### 手順 2: GCE インスタンスの作成
```bash
gcloud compute instances create isucon11q \
    --project=<GCP_PROJECT_ID> \
    --zone=asia-northeast1-b \
    --machine-type=e2-standard-4 \
    --boot-disk-size=30GB \
    --boot-disk-type=pd-ssd \
    --image-family=ubuntu-2004-lts \
    --image-project=ubuntu-os-cloud \
    --tags=isucon-node \
    --metadata-from-file user-data=isucon11q.cfg
```

### 手順 3: 構築進捗確認とベンチマーク実行
```bash
# SSHログイン
gcloud compute ssh isucon11q --zone=asia-northeast1-b

# 構築ログの監視（約10分で完了）
sudo tail -f /var/log/cloud-init-output.log

# 完了後、ベンチマーク実行
sudo -i -u isucon
cd bench
./bench -all-addresses 127.0.0.11 -target 127.0.0.11:443 -tls -jia-service-url http://127.0.0.1:4999
```

### 手順 4: 演習終了後の撤収（課金防止）
```bash
gcloud compute instances delete isucon11q \
    --project=<GCP_PROJECT_ID> \
    --zone=asia-northeast1-b \
    --delete-disks=all --quiet
```

---

## 5. 初回ログイン後の共通初動フロー

インスタンスへのSSH接続完了後、直ちに実行する基本セットアップです。

1. **Git 管理化と初期コミット**:
   ```bash
   sudo -i -u isucon
   git init
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   git add /home/isucon/webapp /etc/nginx /etc/mysql
   git commit -m "initial commit"
   ```

2. **Nginx ログフォーマットの追加 (alp用 LTSV)**:
   `/etc/nginx/nginx.conf` の `http` ブロックに LTSV ログ設定を投入し、`sudo systemctl reload nginx` を実行。

3. **MySQL スロークエリログの有効化**:
   `/etc/mysql/mysql.conf.d/mysqld.cnf` にスロークエリログ出力設定（`slow_query_log = 1`, `long_query_time = 0`）を投入し、`sudo systemctl restart mysql` を実行。

4. **初回ベンチマークとベースライン確定**:
   ベンチマークを実行し、初期スコア、alp のレスポンスタイム上位エンドポイント、スロークエリログの上位クエリを記録。

---

## 6. 参考文献・公式リソース

客観的信頼性と一次情報へのアクセスを担保するため、公式リソースおよびコミュニティの参照先を以下に示します。

- [ISUCON 公式サイト](https://isucon.net/)
- [ISUCON 公式 Blog: ISUCONの過去問にチャレンジするためのシンプルな環境構築](https://isucon.net/archives/54946542.html)
- [ISUCON 公式 GitHub オーガニゼーション](https://github.com/isucon)
- [matsuu/aws-isucon (GitHub)](https://github.com/matsuu/aws-isucon) - AWS用 AMI & Packer リポジトリ
- [matsuu/docker-isucon (GitHub)](https://github.com/matsuu/docker-isucon) - Docker Compose用 過去問コンテナリポジトリ
- [matsuu/cloud-init-isucon (GitHub)](https://github.com/matsuu/cloud-init-isucon) - cloud-init 定義集
- [AWS EC2 run-instances CLI リファレンス](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/run-instances.html)
- [AWS Sign-In ユーザーガイド: Sign in through the AWS Command Line Interface](https://docs.aws.amazon.com/signin/latest/userguide/command-line-sign-in.html)
- [AWS IAM ユーザーガイド: ポリシーとアクセス許可](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/access_policies.html)
- [Google Cloud IAM ドキュメント: 事前定義ロールの理解](https://cloud.google.com/iam/docs/understanding-roles)
- [Cloud-init 公式ドキュメント](https://cloud-init.io/)
