# クラウド (AWS) での過去問演習環境構築ガイド (07_cloud_practice_env.md)

ISUCON公式およびコミュニティが公開している AWS CloudFormation / AMI を使って、本番同等の複数台環境を構築する手順です。

---

## 🏆 おすすめの過去問（初参加者向け）

| 過去問 | 特徴・学べること | 推奨度 |
| :--- | :--- | :---: |
| **ISUCON11 予選** (ISUCONDITION) | N+1解消、Drop/バルク処理、SQLiteからMySQL/インメモリへのデータ移行、複数台分散 | ⭐️⭐️⭐️⭐️⭐️ (最初におすすめ) |
| **ISUCON12 予選** (ISUPORTER) | SQLite/MySQL混在、SQLiteのWALモード、キャッシュ無効化設計、地理情報計算 | ⭐️⭐️⭐️⭐️ |
| **ISUCON13** (ISUPipe) | ライブ配信サービス、DNS/HTTP3、Websocket、画像配信、SingleFlight | ⭐️⭐️⭐️⭐️ |

---

## 🚀 AWS CloudFormation を使った構築手順 (例: ISUCON11 予選)

ISUCON公式リポジトリ: [matsuu/aws-isucon (GitHub)](https://github.com/matsuu/aws-isucon)

### 1. 事前準備
- AWS アカウント
- SSHキーペアの作成（AWSマネジメントコンソール → EC2 → キーペア で `isucon-key` を作成して `.pem` を手元に保存）

### 2. CloudFormation スタックの作成
1. [matsuu/aws-isucon](https://github.com/matsuu/aws-isucon) にアクセス
2. 対象のコンテスト（例: `isucon11-qualify`）の **「Launch Stack」** ボタンをクリック（東京リージョン `ap-northeast-1`）
3. パラメータ設定:
   - **Stack name**: `isucon11-practice`
   - **KeyName**: 作成したSSHキーペア名 (`isucon-key`)
   - **AllowedIP**: 自宅やオフィスのグローバルIP（`XXX.XXX.XXX.XXX/32` または `0.0.0.0/0`）
   - **InstanceType**: デフォルト（例: `c5.large` または `t3.medium` 等）
4. スタック作成を実行（完了まで約5〜10分）

### 3. 出力値の確認
CloudFormation の **「出力 (Outputs)」** タブを確認します:
- `TargetIPAddress1`, `TargetIPAddress2`, `TargetIPAddress3` (競技用サーバー1〜3のIP)
- `BenchIPAddress` (ベンチマーカーサーバーのIP)

---

## 💻 接続と初期ベンチマーク実行

### 1. 競技サーバーへのSSH接続
```bash
ssh -i ~/.ssh/isucon-key.pem ubuntu@<TargetIPAddress1>
# または isucon ユーザー
ssh -i ~/.ssh/isucon-key.pem isucon@<TargetIPAddress1>
```

### 2. ベンチマーカーサーバーへの接続とベンチ実行
```bash
ssh -i ~/.ssh/isucon-key.pem ubuntu@<BenchIPAddress>

# ベンチマーク実行コマンド（問題のマニュアルに従う）
# 例:
./bench -target-url http://<TargetIPAddress1>
```

---

## 💰 費用と利用後の注意（課金爆死の防止）

- **費用目安**:
  - EC2インスタンス 4台（競技サーバー3台 + ベンチマーカー1台）
  - 合計で **1時間あたり 約50円〜150円程度**
- **練習終了時のアクション**:
  - 練習が終わったら、AWSマネジメントコンソールの CloudFormation で **「スタックを削除 (Delete Stack)」** を必ず実行してください。
  - インスタンスを停止（Stop）するだけだとEBSボリューム等の課金が継続します。スタック削除が最も安全です。
