# Safe Command Patterns Reference

本リファレンスは、Antigravityエージェントがコマンドの自動許可（Allowlist登録）を判断・提案する際の安全基準です。

## 1. 自動許可を推奨する安全なコマンド（Allowlist対象）

### A. 参照・情報取得系（Read-Only）
- **ファイル・ディレクトリ一覧・探索**: `ls`, `pwd`, `tree`, `find`, `which`
- **ファイル閲覧・検索**: `cat`, `head`, `tail`, `grep`, `wc`, `diff`
- **環境情報**: `echo`, `env`, `printenv`, `uname`, `whoami`

### B. Git関連（状態確認・ローカル操作）
- **状態確認**: `git status`, `git diff`, `git log`, `git show`, `git branch`, `git rev-parse`
- **ローカル安全操作**: `git checkout`, `git switch`, `git add`, `git commit`
- **リモート情報参照**: `git remote`, `git remote -v`, `git fetch`

### C. ビルド・テスト・リント（Node.js / Python / Go / Rustなど）
- **Node.js**: `npm test`, `npm run lint`, `npm run build`, `npm run format`, `npm list`, `npx <tool>`
- **Python**: `pytest`, `python -m unittest`, `flake8`, `black --check`, `mypy`
- **Go**: `go test`, `go vet`, `go build`
- **Rust**: `cargo check`, `cargo test`, `cargo build`

### D. GitHub CLI（情報参照・PR作成）
- `gh auth status`
- `gh pr list`, `gh pr view`, `gh pr diff`, `gh pr status`, `gh pr create`
- `gh issue list`, `gh issue view`

### E. ワークスペース内スクリプト
- `./scripts/*`, `bash ./scripts/*`

---

## 2. 常に拒否または確認を必須とする危険なコマンド（Denylist / Ask対象）

- **システム・ルート削除**: `rm -rf /`, `rm -rf ~`, `rm -rf *`
- **強制プッシュ / 履歴改変**: `git push --force`, `git push -f`, `git reset --hard`
- **ディスクフォーマット / 低レイヤ操作**: `mkfs`, `dd`, `fdisk`
- **権限昇格 / パスワード入力**: `sudo`, `su`, `passwd`
- **機密情報の平文出力**: `cat ~/.ssh/*`, `cat ~/.aws/*`, `env` でのトークン露出
