# Systemd Unicorn Setup Generator (汎用版)

どんなUnicorn Railsプロジェクトでも使えるSystemdセットアップスクリプト自動生成ツール

## 概要

このツールは、Unicorn Railsアプリケーション用のSystemdサービスセットアップスクリプトを自動生成します。
**完全に汎用的**で、どのプロジェクトでも使用できます。

## 特徴

✨ **完全に汎用的** - どんなプロジェクトでも使用可能
📝 **複数の使用モード** - プロジェクトに合わせて選択可能
🔧 **SSH Config連携** - ~/.ssh/configから自動的にホスト情報取得
✅ **検証機能** - ゼロダウンタイムでの環境検証
🎯 **テンプレートベース** - カスタマイズが簡単

## インストール

```bash
git clone https://github.com/torcheees/systemd-unicorn-setup.git
cd systemd-unicorn-setup
```

## 使用方法

### 1. 対話モード（推奨 - 初めての方向け）

```bash
./scripts/generate_setup.sh --interactive
```

対話形式で必要な情報を入力して、セットアップスクリプトを生成します。

### 2. コマンドライン引数モード（簡単）

```bash
./scripts/generate_setup.sh \
  --service-name my-app-unicorn \
  --app-name my_app \
  --app-path /home/deploy/apps/my_app \
  --ssh-host my_app_prod \
  --output /path/to/your/project/script/systemd_setup.sh
```

全ての設定をコマンドライン引数で指定します。

### 3. プロジェクト設定ファイルモード（プロジェクト用）

#### 3-1. 設定ファイルを作成

プロジェクトのルートディレクトリに `.systemd-setup.yml` を配置:

```bash
cd /path/to/your/project
cp /path/to/systemd-unicorn-setup/config/.systemd-setup.example.yml .systemd-setup.yml
```

#### 3-2. 設定を編集

`.systemd-setup.yml`:
```yaml
project:
  name: my_app
  ssh_host: my_app_prod
  service_name: my-app-unicorn
  app_name: my_app

remote:
  app_path: /home/deploy/apps/my_app
  user: deploy

local:
  service_file: config/systemd/my-app-unicorn.service
  output_script: script/systemd_setup.sh
```

#### 3-3. スクリプト生成

```bash
/path/to/systemd-unicorn-setup/scripts/generate_setup.sh --project /path/to/your/project
```

### 4. 複数プロジェクト管理モード（複数プロジェクト向け）

複数のプロジェクトを一元管理する場合:

#### 4-1. 設定ファイルを作成

```bash
cp config/projects.example.yml config/projects.yml
```

#### 4-2. プロジェクトを追加

`config/projects.yml`:
```yaml
projects:
  - name: project1
    ssh_host: project1_prod
    service_name: project1-unicorn
    app_name: project1
    remote:
      app_path: /home/deploy/apps/project1
    local:
      project_path: /Users/you/workspace/project1

  - name: project2
    ssh_host: project2_prod
    service_name: project2-unicorn
    app_name: project2
    remote:
      app_path: /home/deploy/apps/project2
    local:
      project_path: /Users/you/workspace/project2
```

#### 4-3. 生成

```bash
# 全プロジェクト生成
./scripts/generate_from_yaml.sh

# 特定プロジェクトのみ
./scripts/generate_from_yaml.sh project1

# プロジェクト一覧表示
./scripts/generate_from_yaml.sh --list

# 設定検証
./scripts/generate_from_yaml.sh --validate
```

## 生成されるスクリプトの使い方

生成された `systemd_setup.sh` の使用方法:

### 検証モード（ダウンタイムなし）

```bash
cd /path/to/your/project
./script/systemd_setup.sh --validate
```

以下を検証:
1. 既存unicornプロセス確認
2. 環境テスト（Ruby, Bundle, Unicorn）
3. サービスファイル構文チェック
4. パス・設定値検証
5. 依存サービス確認

### テストモード

```bash
./script/systemd_setup.sh --test-only
```

サービスファイルを転送して検証のみ（自動起動は有効化しない）

### 本番デプロイ

```bash
./script/systemd_setup.sh
```

サービスファイルを転送し、自動起動を有効化

### ドライラン

```bash
./script/systemd_setup.sh --dry-run
```

何が行われるか確認のみ

## SSH設定

`~/.ssh/config` に接続先を設定してください:

```
Host my_app_prod
  HostName 192.168.1.100
  Port 22
  User deploy
  IdentityFile ~/.ssh/id_rsa
```

ツールは自動的にこの設定を読み取ります。

## ファイル構成

### 生成に必要なファイル

プロジェクトには以下のファイルが必要です:

```
your_project/
├── config/
│   └── systemd/
│       └── your-app-unicorn.service    # systemdサービスファイル
└── script/
    └── systemd_setup.sh                # 生成されるセットアップスクリプト（自動生成）
```

### systemdサービスファイル例

`config/systemd/my-app-unicorn.service`:
```ini
[Unit]
Description=My App Unicorn Server
After=network.target mysql.service

[Service]
Type=forking
User=deploy
Group=deploy
WorkingDirectory=/home/deploy/apps/my_app/current

Environment=RAILS_ENV=production
Environment=BUNDLE_GEMFILE=/home/deploy/apps/my_app/current/Gemfile
Environment=RBENV_ROOT=/home/deploy/.rbenv
Environment=PATH=/home/deploy/.rbenv/shims:/home/deploy/.rbenv/bin:/usr/local/bin:/usr/bin:/bin

ExecStart=/bin/bash -lc 'bundle exec unicorn -c config/unicorn.rb -E production -D'
ExecReload=/bin/kill -USR2 $MAINPID
ExecStop=/bin/kill -QUIT $MAINPID

PIDFile=/home/deploy/apps/my_app/shared/tmp/pids/unicorn.pid

Restart=on-failure
RestartSec=10
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
```

## テンプレートのカスタマイズ

生成されるスクリプトをカスタマイズしたい場合:

1. `templates/systemd_setup.sh.template` を編集
2. スクリプトを再生成

テンプレート内で使用できるプレースホルダー:
- `{{SERVICE_NAME}}` - サービス名
- `{{APP_NAME}}` - アプリ名
- `{{APP_PATH}}` - リモートアプリパス
- `{{SSH_HOST}}` - SSH Host名

## ワークフロー例

### 新規プロジェクトへの導入

```bash
# 1. systemdサービスファイル作成
mkdir -p /path/to/project/config/systemd
vim /path/to/project/config/systemd/my-app-unicorn.service

# 2. SSH設定
vim ~/.ssh/config  # Host my_app_prod を追加

# 3. セットアップスクリプト生成
./scripts/generate_setup.sh \
  --service-name my-app-unicorn \
  --app-name my_app \
  --app-path /home/deploy/apps/my_app \
  --ssh-host my_app_prod \
  --output /path/to/project/script/systemd_setup.sh

# 4. 検証
cd /path/to/project
./script/systemd_setup.sh --validate

# 5. デプロイ
./script/systemd_setup.sh
```

### 既存プロジェクトへの導入

```bash
# 1. プロジェクトに設定ファイルを配置
cd /path/to/existing/project
cp /path/to/systemd-unicorn-setup/config/.systemd-setup.example.yml .systemd-setup.yml

# 2. 設定を編集
vim .systemd-setup.yml

# 3. スクリプト生成
/path/to/systemd-unicorn-setup/scripts/generate_setup.sh --project .

# 4. 検証とデプロイ
./script/systemd_setup.sh --validate
./script/systemd_setup.sh
```

## トラブルシューティング

### SSH接続失敗

**問題:** `SSH接続失敗`

**解決策:**
- `~/.ssh/config` の設定を確認
- 手動でSSH接続テスト: `ssh your_host`
- SSH鍵認証が設定されているか確認

### サービスファイルが見つからない

**問題:** `サービスファイルが見つかりません`

**解決策:**
- `config/systemd/` ディレクトリにサービスファイルを配置
- パスが正しいか確認

### テンプレートファイルが見つからない

**問題:** `テンプレートファイルが見つかりません`

**解決策:**
- このリポジトリのディレクトリ構造を確認
- `templates/systemd_setup.sh.template` が存在するか確認

## よくある質問

### Q: 既存のプロジェクトで使えますか？

A: はい、どんなUnicorn Railsプロジェクトでも使えます。

### Q: systemdサービスファイルは自動生成されますか？

A: いいえ、サービスファイルは手動で作成する必要があります。このツールは**セットアップスクリプト**を生成します。

### Q: 複数のプロジェクトで同じツールを使えますか？

A: はい、プロジェクトごとに設定ファイルを配置するか、`config/projects.yml` で一元管理できます。

### Q: Capistrano等のデプロイツールと併用できますか？

A: はい、生成されたスクリプトは独立して動作するため、どんなデプロイフローにも統合できます。

## ライセンス

社内利用専用

## サポート

問題や質問がある場合:
- トラブルシューティングセクションを確認
- GitHub Issuesで報告

## 関連ドキュメント

- [Systemd Service Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Unicorn Configuration](https://bogomips.org/unicorn/)
- [Rails Production Deployment](https://guides.rubyonrails.org/deployment.html)
