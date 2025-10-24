# Systemd Unicorn セットアップスクリプト

複数のUnicornベースRailsアプリケーションのSystemdサービス設定を自動化するスクリプト集です。

## 概要

このリポジトリは、各プロジェクト用の`systemd_setup.sh`を生成するジェネレータースクリプトを提供します。生成されたセットアップスクリプトは、UnicornアプリケーションサーバーのSystemdサービスのデプロイと設定を自動化します。

## リポジトリ構造

```
systemd-unicorn-setup/
├── config/
│   └── projects.yml                 # プロジェクト設定ファイル (YAML)
├── scripts/
│   ├── generate_from_yaml.sh       # YAMLベースジェネレーター (推奨)
│   ├── generate_all.sh             # 従来版: インライン生成
│   ├── generate_setup_scripts.sh   # 従来版: テンプレート生成
│   └── lib/
│       ├── yaml_parser.sh          # YAML解析ライブラリ
│       └── ssh_parser.sh           # SSH config解析ライブラリ
└── README.md
```

## 管理対象プロジェクト

以下のプロジェクトがこのスクリプトで管理されています:

| プロジェクト | サービス名 | SSH Host | アプリパス |
|---------|-------------|----------|---------|
| medica | medica-unicorn | torcheees_medica_prod | /home/deploy/apps/medica |
| corp | corp-unicorn | torcheees_corp_prod | /home/deploy/apps/corp |
| ex_dance_stadium | dance-stadium-unicorn | ndp_dance_prod | /home/deploy/apps/dance_stadium |
| ndp-kabarai-lp-for-fujii | kabarai-for-fujii-unicorn | ndp_kabarai_fujii | /home/deploy/apps/kabarai_for_fujii |
| ndp_yamikin_lp | ndp-yamikin-lp-unicorn | ndp_yamikin_lp_prod | /home/deploy/apps/ndp_yamikin_lp |
| ndp-seramid | ndp-seramid-unicorn | ndp_seramid | /home/deploy/apps/ndp-seramid |
| ndp-king-gear | king-gear-unicorn | ndp_king_gear | /home/deploy/apps/king_gear |

全てのプロジェクト設定は `config/projects.yml` で一元管理されています。

## クイックスタート

### 1. プロジェクト一覧表示

```bash
./scripts/generate_from_yaml.sh --list
```

### 2. 設定検証 (SSH config連携テスト)

```bash
./scripts/generate_from_yaml.sh --validate
```

`~/.ssh/config` から自動的にHostNameとPortを取得し、全プロジェクトの設定を検証します。

### 3. セットアップスクリプト生成

```bash
# 全プロジェクト一括生成
./scripts/generate_from_yaml.sh

# 特定プロジェクトのみ生成
./scripts/generate_from_yaml.sh medica
```

## YAMLベースジェネレーター (推奨)

### 特徴

- **YAML設定ファイル**: `config/projects.yml` で全プロジェクトを一元管理
- **SSH config連携**: `~/.ssh/config` から自動的にHostName/Portを取得
- **ディレクトリマッピング**: ローカルとリモートのパス対応を明示的に定義
- **バリデーション機能**: 設定ファイルとSSH接続性を事前検証
- **選択的生成**: 全プロジェクトまたは特定プロジェクトのみ生成可能

### 使用方法

#### プロジェクト一覧表示

```bash
./scripts/generate_from_yaml.sh --list
```

出力例:
```
ID    プロジェクト名     SSH Host             ローカルパス
----------------------------------------------------------------------------------------
0     medica                    torcheees_medica_prod          /Users/.../medica
1     corp                      torcheees_corp_prod            /Users/.../corp
...
```

#### 設定検証

```bash
./scripts/generate_from_yaml.sh --validate
```

以下を検証:
- SSH Hostが `~/.ssh/config` に存在するか
- SSH接続情報 (HostName, Port, User) の取得
- ローカルディレクトリの存在確認

出力例:
```
[INFO] === YAML設定検証 ===

[INFO] [0] medica
  ✓ SSH Host: torcheees_medica_prod
    → deploy@45.77.21.63:11270
  ✓ ローカルパス: /Users/akimitsukoshikawa/workspace/torcheees/medica

...

[SUCCESS] 全ての検証に合格しました
```

#### スクリプト生成

```bash
# 全プロジェクト生成
./scripts/generate_from_yaml.sh

# 特定プロジェクトのみ生成
./scripts/generate_from_yaml.sh medica
./scripts/generate_from_yaml.sh corp
```

### YAML設定ファイル

`config/projects.yml` の構造:

```yaml
projects:
  - name: medica
    ssh_host: torcheees_medica_prod  # ~/.ssh/config のHost名
    service_name: medica-unicorn
    app_name: medica
    remote:
      app_path: /home/deploy/apps/medica
      user: deploy
    local:
      project_path: /Users/akimitsukoshikawa/workspace/torcheees/medica
      service_file: config/systemd/medica-unicorn.service
      output_script: script/systemd_setup.sh

  # 他のプロジェクト...

# SSH Config 設定
ssh_config:
  path: ~/.ssh/config
  auto_detect: true  # SSH Hostから自動的にHostName/Portを取得

# デフォルト設定
defaults:
  remote:
    user: deploy
    ruby_manager: rbenv
    rails_env: production
  local:
    service_file: config/systemd/{service_name}.service
    output_script: script/systemd_setup.sh
```

### 新規プロジェクト追加手順

1. `config/projects.yml` に新しいプロジェクトエントリを追加
2. `~/.ssh/config` にSSH Host設定があることを確認
3. 設定を検証: `./scripts/generate_from_yaml.sh --validate`
4. スクリプト生成: `./scripts/generate_from_yaml.sh <project_name>`

例:
```yaml
projects:
  - name: new_project
    ssh_host: new_project_prod
    service_name: new-project-unicorn
    app_name: new_project
    remote:
      app_path: /home/deploy/apps/new_project
      user: deploy
    local:
      project_path: /Users/user/workspace/new_project
      service_file: config/systemd/new-project-unicorn.service
      output_script: script/systemd_setup.sh
```

## 生成されるセットアップスクリプトの機能

各プロジェクトに生成される `systemd_setup.sh` の実行モード:

### 1. フルセットアップ (デフォルト)

```bash
./script/systemd_setup.sh
```

- サービスファイル転送
- 自動起動有効化
- systemd設定完了

### 2. 検証モード (ダウンタイムなし)

```bash
./script/systemd_setup.sh --validate
```

以下を検証:
1. 既存unicornプロセス確認
2. テスト用サービスで環境検証
3. 本番サービスファイルの構文チェック
4. パス・設定値検証
5. 依存サービス確認
6. 検証サマリー出力

**既存プロセスに影響なし**

### 3. テストモード

```bash
./script/systemd_setup.sh --test-only
```

- サービスファイル検証のみ
- 自動起動は**有効化しない**
- テスト環境で安全に使用可能

### 4. ドライランモード

```bash
./script/systemd_setup.sh --dry-run
```

- デプロイ内容を表示
- 実際の変更は行わない

## SSH設定要件

スクリプトは `~/.ssh/config` から自動的にホスト情報を取得します。

### 必要な設定例

```
Host torcheees_medica_prod
  HostName 45.77.21.63
  Port 11270
  User deploy
  IdentityFile ~/.ssh/id_rsa

Host ndp_dance_prod
  HostName 108.61.162.167
  Port 57777
  User deploy
  IdentityFile ~/.ssh/new_ssh/id_rsa
```

### 要件

- SSH config に Host エントリが存在すること
- SSH鍵認証が設定済みであること
- ユーザーがリモートサーバーでsudo権限を持つこと

## Systemdサービスファイル

各プロジェクトには以下の場所にサービスファイルが必要です:

```
<project_path>/config/systemd/<service-name>.service
```

### サービスファイル例

```ini
[Unit]
Description=Medica Unicorn Server
After=network.target mysql.service

[Service]
Type=forking
User=deploy
Group=deploy
WorkingDirectory=/home/deploy/apps/medica/current

Environment=RAILS_ENV=production
Environment=BUNDLE_GEMFILE=/home/deploy/apps/medica/current/Gemfile
Environment=RBENV_ROOT=/home/deploy/.rbenv
Environment=PATH=/home/deploy/.rbenv/shims:/home/deploy/.rbenv/bin:/usr/local/bin:/usr/bin:/bin

ExecStart=/bin/bash -lc 'bundle exec unicorn -c config/unicorn.rb -E production -D'
ExecReload=/bin/kill -USR2 $MAINPID
ExecStop=/bin/kill -QUIT $MAINPID

PIDFile=/home/deploy/apps/medica/shared/tmp/pids/unicorn.pid

Restart=on-failure
RestartSec=10
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
```

## ワークフロー例

### 完全デプロイ

```bash
# 1. 設定検証
./scripts/generate_from_yaml.sh --validate

# 2. スクリプト生成
./scripts/generate_from_yaml.sh medica

# 3. プロジェクトディレクトリへ移動
cd /Users/akimitsukoshikawa/workspace/torcheees/medica

# 4. 環境検証 (ダウンタイムなし)
./script/systemd_setup.sh --validate

# 5. サービス設定デプロイ
./script/systemd_setup.sh

# 6. デプロイ確認
ssh torcheees_medica_prod 'sudo systemctl status medica-unicorn'
```

### 安全なテストワークフロー

```bash
# 1. ドライランで確認
./script/systemd_setup.sh --dry-run

# 2. テストモードでデプロイ (自動起動なし)
./script/systemd_setup.sh --test-only

# 3. 手動検証
ssh server 'sudo systemctl cat service-name'

# 4. OK なら本番設定有効化
./script/systemd_setup.sh
```

## トラブルシューティング

### SSH接続失敗

**問題:** `SSH接続失敗: hostname`

**解決策:**
- `~/.ssh/config` に正しいHost設定があるか確認
- 手動でSSH接続テスト: `ssh hostname`
- SSH鍵認証の確認
- IPアドレスとポートがconfigと一致しているか確認

### サービスファイルが見つからない

**問題:** `サービスファイルが見つかりません`

**解決策:**
- `config/systemd/<service-name>.service` が存在するか確認
- スクリプト内のファイルパスが正しいか確認
- ファイルパーミッションを確認

### 検証失敗

**問題:** `--validate` モードでの環境テスト失敗

**解決策:**
- サーバー上のRuby環境を確認
- rbenvインストールを確認
- アプリケーションディレクトリにGemfileが存在するか確認
- bundleインストールを確認
- ログ確認: `sudo journalctl -u <service-name>-test -n 50`

### 権限エラー

**問題:** `/etc/systemd/system/` への書き込み権限なし

**解決策:**
- ユーザーがsudo権限を持っているか確認
- sudoers設定を確認
- SSHユーザーが適切なグループに所属しているか確認

## Systemdサービス管理

デプロイ後のサービス管理コマンド:

```bash
# ステータス確認
ssh server 'sudo systemctl status service-name'

# 起動
ssh server 'sudo systemctl start service-name'

# 停止
ssh server 'sudo systemctl stop service-name'

# 再起動
ssh server 'sudo systemctl restart service-name'

# 設定リロード
ssh server 'sudo systemctl reload service-name'

# ログ確認
ssh server 'sudo journalctl -u service-name -f'

# 自動起動有効化
ssh server 'sudo systemctl enable service-name'

# 自動起動無効化
ssh server 'sudo systemctl disable service-name'
```

## ベストプラクティス

1. **必ず検証を先に実行**
   - 本番デプロイ前に `--validate` を実行
   - 全てのチェックが通ることを確認

2. **新規設定はテストモードで**
   - 初回デプロイは `--test-only` を使用
   - 手動確認後に自動起動を有効化

3. **バックアップを保持**
   - 更新前に既存のサービスファイルをバックアップ
   - サービス設定のバージョン管理を維持

4. **ログの監視**
   - デプロイ後にjournalctlでログ確認
   - 起動時のエラーがないか検証

5. **段階的なロールアウト**
   - まず1台のサーバーにデプロイ
   - 安定性を確認後、全サーバーにロールアウト

## 従来版ジェネレーター

後方互換性のため、従来のジェネレータースクリプトも利用可能です:

### `generate_all.sh`

インラインでスクリプトを直接生成します。

```bash
./scripts/generate_all.sh
```

### `generate_setup_scripts.sh`

medicaプロジェクトをテンプレートとして使用します。

```bash
./scripts/generate_setup_scripts.sh
```

**注意:** 新規プロジェクトには **YAMLベースのジェネレーター** (`generate_from_yaml.sh`) の使用を推奨します。

## セキュリティ考慮事項

- サービスファイルには機密パスや設定が含まれる
- 適切なファイルパーミッション (644) を設定
- sudo アクセスを適切に制限
- SSH鍵認証のみを使用
- デプロイ前にサービスファイル内容をレビュー

## ライセンス

社内利用専用

## サポート

問題や質問がある場合:
- トラブルシューティングセクションを確認
- systemdログをレビュー: `journalctl -u service-name`
- SSH設定を検証
- サービスファイル構文を確認

## 関連ドキュメント

- [Systemd Service Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Unicorn Configuration](https://bogomips.org/unicorn/)
- [Rails Production Deployment](https://guides.rubyonrails.org/deployment.html)
