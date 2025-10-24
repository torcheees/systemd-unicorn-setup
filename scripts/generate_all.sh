#!/bin/bash
# 全プロジェクトのスクリプトを直接生成

generate_script() {
  local service_name="$1"
  local app_name="$2"
  local app_path="$3"
  local server_ip_port="$4"
  local output_file="$5"

  cat > "$output_file" << EOFSCRIPT
#!/bin/bash
# Unicorn Systemd自動セットアップスクリプト
#
# 使用方法:
#   ./script/systemd_setup.sh [--validate] [--test-only] [--dry-run]

set -e

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "\${BLUE}[INFO]\${NC} \$1"; }
print_success() { echo -e "\${GREEN}[SUCCESS]\${NC} \$1"; }
print_warning() { echo -e "\${YELLOW}[WARNING]\${NC} \$1"; }
print_error() { echo -e "\${RED}[ERROR]\${NC} \$1"; }

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/.." && pwd)"

TEST_ONLY=false
DRY_RUN=false
VALIDATE_ONLY=false

while [ \$# -gt 0 ]; do
  case "\$1" in
    --validate) VALIDATE_ONLY=true ;;
    --test-only) TEST_ONLY=true ;;
    --dry-run) DRY_RUN=true ;;
    *) print_error "不明なオプション: \$1"; exit 1 ;;
  esac
  shift
done

# プロジェクト設定
SERVICE_NAME="${service_name}"
APP_NAME="${app_name}"
APP_PATH="${app_path}"
SERVER_IP_PORT="${server_ip_port}"
SERVICE_FILE="\$PROJECT_ROOT/config/systemd/${service_name}.service"

# SSH Hostを ~/.ssh/config から検索
find_ssh_host() {
  local ip_port="\$1"
  local ip="\${ip_port%:*}"
  local port="\${ip_port#*:}"

  # SSH configからIPアドレスでHost名を検索
  local ssh_host=\$(awk -v ip="\$ip" -v port="\$port" '
    /^Host / {host=\$2}
    /HostName/ && \$2 == ip {found_host=host}
    /Port/ && \$2 == port && found_host {print found_host; found_host=""; exit}
    /port/ && \$2 == port && found_host {print found_host; found_host=""; exit}
  ' ~/.ssh/config)

  if [ -z "\$ssh_host" ]; then
    # Portが見つからない場合、HostNameだけで検索
    ssh_host=\$(awk -v ip="\$ip" '
      /^Host / {host=\$2}
      /HostName/ && \$2 == ip {print host; exit}
    ' ~/.ssh/config)
  fi

  echo "\$ssh_host"
}

SSH_HOST=\$(find_ssh_host "\$SERVER_IP_PORT")

if [ -z "\$SSH_HOST" ]; then
  print_error "SSH Hostが見つかりません: \$SERVER_IP_PORT"
  print_error "~/.ssh/config に設定を追加してください"
  exit 1
fi

if [ ! -f "\$SERVICE_FILE" ]; then
  print_error "サービスファイルが見つかりません: \$SERVICE_FILE"
  exit 1
fi

print_info "=== 設定情報 ==="
print_info "SSH: \$SSH_HOST (\$SERVER_IP_PORT)"
print_info "サービス: \$SERVICE_NAME"
print_info "アプリパス: \$APP_PATH"
echo ""

if [ "\$DRY_RUN" = true ]; then
  print_warning "ドライランモード"
  cat "\$SERVICE_FILE"
  exit 0
fi

# SSH接続テスト
print_info "SSH接続テスト..."
if ! ssh "\$SSH_HOST" "echo 'OK'" > /dev/null 2>&1; then
  print_error "SSH接続失敗: \$SSH_HOST"
  exit 1
fi
print_success "SSH接続OK"

# --validate オプション: 完全な検証（ダウンタイムなし）
if [ "\$VALIDATE_ONLY" = true ]; then
  print_info "=== 検証モード（既存プロセスに影響なし） ==="
  echo ""

  # 1. 既存unicornプロセス確認
  print_info "[1/6] 既存unicornプロセス確認..."
  ssh "\$SSH_HOST" "ps aux | grep unicorn | grep -v grep" || print_warning "  Unicornプロセスが見つかりません"
  echo ""

  # 2. テスト用サービスで環境検証
  print_info "[2/6] 環境テスト実行（テスト用サービス）..."

  # テスト用サービスファイル生成
  TEST_SERVICE=\$(mktemp)
  cat > "\$TEST_SERVICE" << EOFTEST
[Unit]
Description=\${APP_NAME} Unicorn Server (VALIDATION TEST)
After=network.target

[Service]
Type=oneshot
User=deploy
Group=deploy
WorkingDirectory=\${APP_PATH}/current

Environment=RAILS_ENV=production
Environment=BUNDLE_GEMFILE=\${APP_PATH}/current/Gemfile
Environment=RBENV_ROOT=/home/deploy/.rbenv
Environment=PATH=/home/deploy/.rbenv/shims:/home/deploy/.rbenv/bin:/usr/local/bin:/usr/bin:/bin

ExecStart=/bin/bash -lc 'echo "=== Environment Test ===" && which ruby && which bundle && ruby -v && bundle -v && echo "=== Unicorn Check ===" && bundle show unicorn && echo "=== Test Passed ==="'

[Install]
WantedBy=multi-user.target
EOFTEST

  scp "\$TEST_SERVICE" "\${SSH_HOST}:/tmp/\${SERVICE_NAME}-test.service"
  rm "\$TEST_SERVICE"

  ssh "\$SSH_HOST" << EOFVALIDATE
set -e
sudo mv /tmp/\${SERVICE_NAME}-test.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start \${SERVICE_NAME}-test
sleep 2
echo ""
echo "=== テスト結果 ==="
sudo journalctl -u \${SERVICE_NAME}-test -n 50 --no-pager | grep -E "(Environment Test|ruby|bundle|Unicorn Check|Test Passed)" || true
sudo rm /etc/systemd/system/\${SERVICE_NAME}-test.service
sudo systemctl daemon-reload
EOFVALIDATE

  print_success "  環境テスト完了"
  echo ""

  # 3. 本番サービスファイルの構文チェック
  print_info "[3/6] サービスファイル構文チェック..."
  scp "\$SERVICE_FILE" "\${SSH_HOST}:/tmp/\${SERVICE_NAME}.service.test"

  ssh "\$SSH_HOST" << EOFSYNTAX
sudo mv /tmp/\${SERVICE_NAME}.service.test /etc/systemd/system/\${SERVICE_NAME}.service.test
sudo systemctl daemon-reload
if sudo systemd-analyze verify \${SERVICE_NAME}.service.test 2>&1 | grep -q "Failed"; then
  echo "構文エラーあり"
  sudo systemd-analyze verify \${SERVICE_NAME}.service.test
  sudo rm /etc/systemd/system/\${SERVICE_NAME}.service.test
  exit 1
else
  echo "構文チェックOK"
  sudo rm /etc/systemd/system/\${SERVICE_NAME}.service.test
fi
EOFSYNTAX

  print_success "  構文チェック完了"
  echo ""

  # 4. パス・設定値検証
  print_info "[4/6] パス・設定値検証..."
  ssh "\$SSH_HOST" << EOFPATH
if [ ! -d "\${APP_PATH}/current" ]; then
  echo "✗ アプリパスが存在しません: \${APP_PATH}/current"
  exit 1
else
  echo "✓ アプリパス存在"
fi

if [ ! -f "\${APP_PATH}/current/Gemfile" ]; then
  echo "✗ Gemfileが存在しません"
  exit 1
else
  echo "✓ Gemfile存在"
fi

if [ ! -f "\${APP_PATH}/current/config/unicorn.rb" ]; then
  echo "✗ unicorn.rbが存在しません"
  exit 1
else
  echo "✓ unicorn.rb存在"
fi
EOFPATH

  print_success "  パス検証完了"
  echo ""

  # 5. 依存サービス確認
  print_info "[5/6] 依存サービス確認..."
  ssh "\$SSH_HOST" << EOFDEP
# MySQL確認
if sudo systemctl is-active mysql > /dev/null 2>&1; then
  echo "✓ MySQL稼働中"
elif sudo systemctl is-active mariadb > /dev/null 2>&1; then
  echo "✓ MariaDB稼働中"
else
  echo "✗ MySQL/MariaDB停止中"
fi

# Nginx確認
if sudo systemctl is-active nginx > /dev/null 2>&1; then
  echo "✓ Nginx稼働中"
else
  echo "✗ Nginx停止中"
fi
EOFDEP

  print_success "  依存サービス確認完了"
  echo ""

  # 6. 最終レポート
  print_info "[6/6] 検証サマリー"
  echo ""
  print_success "=== 検証完了 ==="
  echo ""
  echo "✅ 全ての検証が完了しました"
  echo "✅ 既存のunicornプロセスに影響はありません"
  echo ""
  echo "次のステップ:"
  echo "  ./script/systemd_setup.sh        # 本番設定（自動起動有効化）"
  echo "  ./script/systemd_setup.sh --test-only  # 設定のみ（自動起動なし）"

  exit 0
fi

# サービスファイル転送
print_info "サービスファイルを転送..."
scp "\$SERVICE_FILE" "\${SSH_HOST}:/tmp/\${SERVICE_NAME}.service"

# リモートでセットアップ
ssh "\$SSH_HOST" << EOFSSH
set -e
sudo mv /tmp/\${SERVICE_NAME}.service /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/\${SERVICE_NAME}.service
sudo systemctl daemon-reload
EOFSSH

if [ "\$TEST_ONLY" = true ]; then
  print_info "テストのみモード"
  ssh "\$SSH_HOST" "sudo systemctl cat \${SERVICE_NAME}"
  exit 0
fi

# 自動起動有効化
print_info "自動起動を有効化..."
ssh "\$SSH_HOST" "sudo systemctl enable \${SERVICE_NAME}"

print_success "設定完了！"
echo ""
echo "=== 次のステップ ==="
echo "1. 状態確認: ssh \$SSH_HOST 'sudo systemctl status \${SERVICE_NAME}'"
echo "2. 動作確認: ssh \$SSH_HOST 'ps aux | grep unicorn'"
echo "3. (オプション) 今すぐ起動: ssh \$SSH_HOST 'sudo systemctl start \${SERVICE_NAME}'"
EOFSCRIPT

  chmod +x "$output_file"
}

# 各プロジェクトのスクリプト生成
echo "生成中: medica"
generate_script "medica-unicorn" "medica" "/home/deploy/apps/medica" "45.77.21.63:11270" "/Users/akimitsukoshikawa/workspace/torcheees/medica/script/systemd_setup.sh"

echo "生成中: corp"
generate_script "corp-unicorn" "corp" "/home/deploy/apps/corp" "167.179.89.96:11270" "/Users/akimitsukoshikawa/workspace/torcheees/corp/script/systemd_setup.sh"

echo "生成中: ex_dance_stadium"
generate_script "dance-stadium-unicorn" "dance_stadium" "/home/deploy/apps/dance_stadium" "108.61.162.167:57777" "/Users/akimitsukoshikawa/workspace/torcheees/ex_dance_stadium/script/systemd_setup.sh"

echo "生成中: ndp-kabarai-lp-for-fujii"
generate_script "kabarai-for-fujii-unicorn" "kabarai_for_fujii" "/home/deploy/apps/kabarai_for_fujii" "202.182.99.237:11270" "/Users/akimitsukoshikawa/workspace/ndp/ndp-kabarai-lp-for-fujii/script/systemd_setup.sh"

echo "生成中: ndp_yamikin_lp"
generate_script "ndp-yamikin-lp-unicorn" "ndp_yamikin_lp" "/home/deploy/apps/ndp_yamikin_lp" "104.156.239.46:11270" "/Users/akimitsukoshikawa/workspace/torcheees/ndp_yamikin_lp/script/systemd_setup.sh"

echo "生成中: ndp-seramid"
generate_script "ndp-seramid-unicorn" "ndp-seramid" "/home/deploy/apps/ndp-seramid" "104.238.151.79:11270" "/Users/akimitsukoshikawa/workspace/ndp/ndp-seramid/script/systemd_setup.sh"

echo "生成中: ndp-king-gear"
generate_script "king-gear-unicorn" "king_gear" "/home/deploy/apps/king_gear" "45.32.28.159:57777" "/Users/akimitsukoshikawa/workspace/torcheees/ndp-king-gear/script/systemd_setup.sh"

echo ""
echo "完了！全プロジェクトのスクリプトを生成しました。"
