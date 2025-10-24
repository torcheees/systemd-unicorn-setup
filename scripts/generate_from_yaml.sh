#!/bin/bash
# YAMLベース systemd_setup.sh ジェネレーター
#
# 使用方法:
#   ./scripts/generate_from_yaml.sh                    # 全プロジェクト生成
#   ./scripts/generate_from_yaml.sh medica             # 特定プロジェクトのみ
#   ./scripts/generate_from_yaml.sh --list             # プロジェクト一覧表示
#   ./scripts/generate_from_yaml.sh --validate         # YAML検証のみ

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/projects.yml"

# ライブラリ読み込み
source "$SCRIPT_DIR/lib/yaml_parser.sh"
source "$SCRIPT_DIR/lib/ssh_parser.sh"

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# YAML設定ファイル確認
if [ ! -f "$CONFIG_FILE" ]; then
  print_error "設定ファイルが見つかりません: $CONFIG_FILE"
  exit 1
fi

# プロジェクト一覧表示
list_projects() {
  print_info "=== プロジェクト一覧 ==="
  echo ""

  eval "$(parse_yaml "$CONFIG_FILE")"

  printf "%-5s %-25s %-20s %-30s\n" "ID" "プロジェクト名" "SSH Host" "ローカルパス"
  printf "%s\n" "----------------------------------------------------------------------------------------"

  for ((i=0; i<PROJECT_COUNT; i++)); do
    eval "name=\$PROJECT_${i}_name"
    eval "ssh_host=\$PROJECT_${i}_ssh_host"
    eval "local_path=\$PROJECT_${i}_local_project_path"

    printf "%-5s %-25s %-20s %-30s\n" "$i" "$name" "$ssh_host" "$local_path"
  done
  echo ""
}

# YAML検証
validate_config() {
  print_info "=== YAML設定検証 ==="
  echo ""

  eval "$(parse_yaml "$CONFIG_FILE")"

  local errors=0

  for ((i=0; i<PROJECT_COUNT; i++)); do
    eval "name=\$PROJECT_${i}_name"
    eval "ssh_host=\$PROJECT_${i}_ssh_host"
    eval "service_name=\$PROJECT_${i}_service_name"
    eval "local_path=\$PROJECT_${i}_local_project_path"

    print_info "[$i] $name"

    # SSH Host存在確認
    if ssh_host_exists "$ssh_host"; then
      echo "  ✓ SSH Host: $ssh_host"

      # SSH情報取得
      if ssh_info=$(get_ssh_info "$ssh_host" 2>/dev/null); then
        hostname=$(echo "$ssh_info" | sed -n '1p')
        port=$(echo "$ssh_info" | sed -n '2p')
        user=$(echo "$ssh_info" | sed -n '3p')
        echo "    → ${user}@${hostname}:${port}"
      else
        print_warning "  SSH情報の取得に失敗: $ssh_host"
      fi
    else
      print_error "  ✗ SSH Hostが見つかりません: $ssh_host"
      errors=$((errors + 1))
    fi

    # ローカルディレクトリ確認
    if [ -d "$local_path" ]; then
      echo "  ✓ ローカルパス: $local_path"
    else
      print_warning "  ⚠ ローカルパスが存在しません: $local_path"
    fi

    echo ""
  done

  if [ $errors -gt 0 ]; then
    print_error "検証エラー: $errors 件"
    return 1
  else
    print_success "全ての検証に合格しました"
    return 0
  fi
}

# systemd_setup.sh 生成関数
generate_setup_script() {
  local service_name="$1"
  local app_name="$2"
  local app_path="$3"
  local ssh_host="$4"
  local output_file="$5"

  # 出力ディレクトリ作成
  mkdir -p "$(dirname "$output_file")"

  cat > "$output_file" << 'EOFSCRIPT'
#!/bin/bash
# Unicorn Systemd自動セットアップスクリプト
#
# このスクリプトは自動生成されています
# 編集する場合は config/projects.yml を更新して再生成してください
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

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_ONLY=false
DRY_RUN=false
VALIDATE_ONLY=false

while [ $# -gt 0 ]; do
  case "$1" in
    --validate) VALIDATE_ONLY=true ;;
    --test-only) TEST_ONLY=true ;;
    --dry-run) DRY_RUN=true ;;
    *) print_error "不明なオプション: $1"; exit 1 ;;
  esac
  shift
done

# プロジェクト設定 (YAML から自動生成)
EOFSCRIPT

  # YAML設定を埋め込み
  cat >> "$output_file" << EOFCONFIG
SERVICE_NAME="${service_name}"
APP_NAME="${app_name}"
APP_PATH="${app_path}"
SSH_HOST="${ssh_host}"
SERVICE_FILE="\$PROJECT_ROOT/config/systemd/${service_name}.service"
EOFCONFIG

  # 残りのスクリプト本体
  cat >> "$output_file" << 'EOFSCRIPT'

if [ ! -f "$SERVICE_FILE" ]; then
  print_error "サービスファイルが見つかりません: $SERVICE_FILE"
  exit 1
fi

print_info "=== 設定情報 ==="
print_info "SSH: $SSH_HOST"
print_info "サービス: $SERVICE_NAME"
print_info "アプリパス: $APP_PATH"
echo ""

if [ "$DRY_RUN" = true ]; then
  print_warning "ドライランモード"
  cat "$SERVICE_FILE"
  exit 0
fi

# SSH接続テスト
print_info "SSH接続テスト..."
if ! ssh "$SSH_HOST" "echo 'OK'" > /dev/null 2>&1; then
  print_error "SSH接続失敗: $SSH_HOST"
  exit 1
fi
print_success "SSH接続OK"

# --validate オプション: 完全な検証（ダウンタイムなし）
if [ "$VALIDATE_ONLY" = true ]; then
  print_info "=== 検証モード（既存プロセスに影響なし） ==="
  echo ""

  # 1. 既存unicornプロセス確認
  print_info "[1/6] 既存unicornプロセス確認..."
  ssh "$SSH_HOST" "ps aux | grep unicorn | grep -v grep" || print_warning "  Unicornプロセスが見つかりません"
  echo ""

  # 2. テスト用サービスで環境検証
  print_info "[2/6] 環境テスト実行（テスト用サービス）..."

  # テスト用サービスファイル生成
  TEST_SERVICE=$(mktemp)
  cat > "$TEST_SERVICE" << EOFTEST
[Unit]
Description=${APP_NAME} Unicorn Server (VALIDATION TEST)
After=network.target

[Service]
Type=oneshot
User=deploy
Group=deploy
WorkingDirectory=${APP_PATH}/current

Environment=RAILS_ENV=production
Environment=BUNDLE_GEMFILE=${APP_PATH}/current/Gemfile
Environment=RBENV_ROOT=/home/deploy/.rbenv
Environment=PATH=/home/deploy/.rbenv/shims:/home/deploy/.rbenv/bin:/usr/local/bin:/usr/bin:/bin

ExecStart=/bin/bash -lc 'echo "=== Environment Test ===" && which ruby && which bundle && ruby -v && bundle -v && echo "=== Unicorn Check ===" && bundle show unicorn && echo "=== Test Passed ==="'

[Install]
WantedBy=multi-user.target
EOFTEST

  scp "$TEST_SERVICE" "${SSH_HOST}:/tmp/${SERVICE_NAME}-test.service"
  rm "$TEST_SERVICE"

  ssh "$SSH_HOST" << EOFVALIDATE
set -e
sudo mv /tmp/${SERVICE_NAME}-test.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start ${SERVICE_NAME}-test
sleep 2
echo ""
echo "=== テスト結果 ==="
sudo journalctl -u ${SERVICE_NAME}-test -n 50 --no-pager | grep -E "(Environment Test|ruby|bundle|Unicorn Check|Test Passed)" || true
sudo rm /etc/systemd/system/${SERVICE_NAME}-test.service
sudo systemctl daemon-reload
EOFVALIDATE

  print_success "  環境テスト完了"
  echo ""

  # 3. 本番サービスファイルの構文チェック
  print_info "[3/6] サービスファイル構文チェック..."
  scp "$SERVICE_FILE" "${SSH_HOST}:/tmp/${SERVICE_NAME}.service.test"

  ssh "$SSH_HOST" << EOFSYNTAX
sudo mv /tmp/${SERVICE_NAME}.service.test /etc/systemd/system/${SERVICE_NAME}.service.test
sudo systemctl daemon-reload
if sudo systemd-analyze verify ${SERVICE_NAME}.service.test 2>&1 | grep -q "Failed"; then
  echo "構文エラーあり"
  sudo systemd-analyze verify ${SERVICE_NAME}.service.test
  sudo rm /etc/systemd/system/${SERVICE_NAME}.service.test
  exit 1
else
  echo "構文チェックOK"
  sudo rm /etc/systemd/system/${SERVICE_NAME}.service.test
fi
EOFSYNTAX

  print_success "  構文チェック完了"
  echo ""

  # 4. パス・設定値検証
  print_info "[4/6] パス・設定値検証..."
  ssh "$SSH_HOST" << EOFPATH
if [ ! -d "${APP_PATH}/current" ]; then
  echo "✗ アプリパスが存在しません: ${APP_PATH}/current"
  exit 1
else
  echo "✓ アプリパス存在"
fi

if [ ! -f "${APP_PATH}/current/Gemfile" ]; then
  echo "✗ Gemfileが存在しません"
  exit 1
else
  echo "✓ Gemfile存在"
fi

if [ ! -f "${APP_PATH}/current/config/unicorn.rb" ]; then
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
  ssh "$SSH_HOST" << EOFDEP
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
scp "$SERVICE_FILE" "${SSH_HOST}:/tmp/${SERVICE_NAME}.service"

# リモートでセットアップ
ssh "$SSH_HOST" << EOFSSH
set -e
sudo mv /tmp/${SERVICE_NAME}.service /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/${SERVICE_NAME}.service
sudo systemctl daemon-reload
EOFSSH

if [ "$TEST_ONLY" = true ]; then
  print_info "テストのみモード"
  ssh "$SSH_HOST" "sudo systemctl cat ${SERVICE_NAME}"
  exit 0
fi

# 自動起動有効化
print_info "自動起動を有効化..."
ssh "$SSH_HOST" "sudo systemctl enable ${SERVICE_NAME}"

print_success "設定完了！"
echo ""
echo "=== 次のステップ ==="
echo "1. 状態確認: ssh $SSH_HOST 'sudo systemctl status ${SERVICE_NAME}'"
echo "2. 動作確認: ssh $SSH_HOST 'ps aux | grep unicorn'"
echo "3. (オプション) 今すぐ起動: ssh $SSH_HOST 'sudo systemctl start ${SERVICE_NAME}'"
EOFSCRIPT

  chmod +x "$output_file"
}

# メイン処理
main() {
  local target_project=""

  # 引数解析
  case "${1:-}" in
    --list)
      list_projects
      exit 0
      ;;
    --validate)
      validate_config
      exit $?
      ;;
    "")
      # 全プロジェクト生成
      ;;
    *)
      target_project="$1"
      ;;
  esac

  # YAML読み込み
  eval "$(parse_yaml "$CONFIG_FILE")"

  if [ -n "$target_project" ]; then
    # 特定プロジェクトのみ生成
    project_idx=$(find_project_by_name "$CONFIG_FILE" "$target_project")

    if [ -z "$project_idx" ]; then
      print_error "プロジェクトが見つかりません: $target_project"
      echo ""
      list_projects
      exit 1
    fi

    eval "name=\$PROJECT_${project_idx}_name"
    eval "ssh_host=\$PROJECT_${project_idx}_ssh_host"
    eval "service_name=\$PROJECT_${project_idx}_service_name"
    eval "app_name=\$PROJECT_${project_idx}_app_name"
    eval "app_path=\$PROJECT_${project_idx}_remote_app_path"
    eval "output_file=\$PROJECT_${project_idx}_local_project_path/\$PROJECT_${project_idx}_local_output_script"

    print_info "生成中: $name"
    generate_setup_script "$service_name" "$app_name" "$app_path" "$ssh_host" "$output_file"
    print_success "生成完了: $output_file"

  else
    # 全プロジェクト生成
    print_info "=== 全プロジェクトのスクリプト生成 ==="
    echo ""

    for ((i=0; i<PROJECT_COUNT; i++)); do
      eval "name=\$PROJECT_${i}_name"
      eval "ssh_host=\$PROJECT_${i}_ssh_host"
      eval "service_name=\$PROJECT_${i}_service_name"
      eval "app_name=\$PROJECT_${i}_app_name"
      eval "app_path=\$PROJECT_${i}_remote_app_path"
      eval "local_path=\$PROJECT_${i}_local_project_path"
      eval "output_script=\$PROJECT_${i}_local_output_script"

      output_file="$local_path/$output_script"

      print_info "[$i] 生成中: $name"
      echo "  → $output_file"

      if generate_setup_script "$service_name" "$app_name" "$app_path" "$ssh_host" "$output_file"; then
        print_success "  ✓ 完了"
      else
        print_error "  ✗ 失敗"
      fi
      echo ""
    done

    print_success "=== 全プロジェクトの生成完了 ==="
  fi
}

main "$@"
