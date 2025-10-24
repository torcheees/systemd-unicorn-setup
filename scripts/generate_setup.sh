#!/bin/bash
# 汎用 systemd_setup.sh ジェネレーター
#
# 使用方法:
#   # 単一プロジェクトモード
#   ./scripts/generate_setup.sh --project /path/to/project
#
#   # 設定ファイル指定モード
#   ./scripts/generate_setup.sh --config /path/to/config.yml --output /path/to/output.sh
#
#   # 対話モード
#   ./scripts/generate_setup.sh --interactive

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ライブラリ読み込み
source "$SCRIPT_DIR/lib/ssh_parser.sh"
source "$SCRIPT_DIR/lib/single_project_parser.sh"

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

# ヘルプ表示
show_help() {
  cat << EOF
使用方法: $0 [OPTIONS]

OPTIONS:
  --project DIR         プロジェクトディレクトリを指定
                        (DIR/.systemd-setup.yml を読み込む)

  --config FILE         設定YAMLファイルを指定
  --output FILE         出力スクリプトファイルを指定
                        (--config と併用)

  --interactive         対話モードで設定入力

  --service-name NAME   サービス名を指定 (対話モード省略用)
  --app-name NAME       アプリ名を指定
  --app-path PATH       リモートアプリパスを指定
  --ssh-host HOST       SSH Host名を指定

  --help                このヘルプを表示

例:
  # プロジェクトディレクトリから生成
  $0 --project /Users/user/workspace/my_app

  # 設定ファイルから生成
  $0 --config config.yml --output /path/to/systemd_setup.sh

  # 対話モード
  $0 --interactive

  # コマンドライン引数で全指定
  $0 --service-name my-app-unicorn \\
     --app-name my_app \\
     --app-path /home/deploy/apps/my_app \\
     --ssh-host my_app_prod \\
     --output /Users/user/workspace/my_app/script/systemd_setup.sh
EOF
}

# スクリプト生成関数
generate_setup_script() {
  local service_name="$1"
  local app_name="$2"
  local app_path="$3"
  local ssh_host="$4"
  local output_file="$5"

  # テンプレートファイル
  local template_file="$PROJECT_ROOT/templates/systemd_setup.sh.template"

  if [ ! -f "$template_file" ]; then
    print_error "テンプレートファイルが見つかりません: $template_file"
    return 1
  fi

  # 出力ディレクトリ作成
  mkdir -p "$(dirname "$output_file")"

  # テンプレートを読み込んでプレースホルダーを置換
  sed -e "s|{{SERVICE_NAME}}|${service_name}|g" \
      -e "s|{{APP_NAME}}|${app_name}|g" \
      -e "s|{{APP_PATH}}|${app_path}|g" \
      -e "s|{{SSH_HOST}}|${ssh_host}|g" \
      "$template_file" > "$output_file"

  chmod +x "$output_file"
}

# プロジェクトディレクトリモード
generate_from_project() {
  local project_dir="$1"

  if [ ! -d "$project_dir" ]; then
    print_error "プロジェクトディレクトリが存在しません: $project_dir"
    return 1
  fi

  # 絶対パスに変換
  project_dir="$(cd "$project_dir" && pwd)"

  local config_file="$project_dir/.systemd-setup.yml"

  if [ ! -f "$config_file" ]; then
    print_error "設定ファイルが見つかりません: $config_file"
    print_info "テンプレートファイルを作成してください:"
    print_info "  cp $PROJECT_ROOT/config/.systemd-setup.example.yml $config_file"
    return 1
  fi

  print_info "設定ファイル読み込み: $config_file"

  # 設定読み込み
  load_single_project "$config_file" "$project_dir"

  # 必須項目チェック
  if [ -z "$PROJECT_service_name" ] || [ -z "$PROJECT_app_name" ] || \
     [ -z "$REMOTE_app_path" ] || [ -z "$PROJECT_ssh_host" ]; then
    print_error "必須設定項目が不足しています"
    print_error "  service_name: $PROJECT_service_name"
    print_error "  app_name: $PROJECT_app_name"
    print_error "  app_path: $REMOTE_app_path"
    print_error "  ssh_host: $PROJECT_ssh_host"
    return 1
  fi

  # 出力ファイルパス
  local output_file="$LOCAL_output_script"
  if [ -z "$output_file" ]; then
    output_file="$project_dir/script/systemd_setup.sh"
  fi

  print_info "=== 設定情報 ==="
  print_info "プロジェクト: $PROJECT_name"
  print_info "サービス名: $PROJECT_service_name"
  print_info "SSH Host: $PROJECT_ssh_host"
  print_info "リモートパス: $REMOTE_app_path"
  print_info "出力先: $output_file"
  echo ""

  # SSH Host検証
  if ssh_host_exists "$PROJECT_ssh_host"; then
    ssh_info=$(get_ssh_info "$PROJECT_ssh_host" 2>/dev/null || true)
    if [ -n "$ssh_info" ]; then
      hostname=$(echo "$ssh_info" | sed -n '1p')
      port=$(echo "$ssh_info" | sed -n '2p')
      user=$(echo "$ssh_info" | sed -n '3p')
      print_success "SSH Host検証OK: ${user}@${hostname}:${port}"
    fi
  else
    print_warning "SSH Hostが ~/.ssh/config に見つかりません: $PROJECT_ssh_host"
  fi

  # スクリプト生成
  print_info "スクリプト生成中..."
  if generate_setup_script "$PROJECT_service_name" "$PROJECT_app_name" \
                           "$REMOTE_app_path" "$PROJECT_ssh_host" \
                           "$output_file"; then
    print_success "生成完了: $output_file"
    echo ""
    echo "次のステップ:"
    echo "  cd $project_dir"
    echo "  $output_file --validate"
    return 0
  else
    print_error "生成に失敗しました"
    return 1
  fi
}

# 対話モード
interactive_mode() {
  print_info "=== 対話モード ==="
  echo ""

  # プロジェクト名
  read -p "プロジェクト名: " project_name
  [ -z "$project_name" ] && { print_error "プロジェクト名は必須です"; return 1; }

  # サービス名
  read -p "サービス名 (例: ${project_name}-unicorn): " service_name
  [ -z "$service_name" ] && service_name="${project_name}-unicorn"

  # アプリ名
  read -p "アプリ名 (例: $project_name): " app_name
  [ -z "$app_name" ] && app_name="$project_name"

  # SSH Host
  read -p "SSH Host名 (例: ${project_name}_prod): " ssh_host
  [ -z "$ssh_host" ] && { print_error "SSH Hostは必須です"; return 1; }

  # リモートアプリパス
  read -p "リモートアプリパス (例: /home/deploy/apps/$project_name): " app_path
  [ -z "$app_path" ] && app_path="/home/deploy/apps/$project_name"

  # 出力ファイル
  read -p "出力ファイルパス (例: ./script/systemd_setup.sh): " output_file
  [ -z "$output_file" ] && output_file="./script/systemd_setup.sh"

  # 絶対パスに変換
  output_file="$(cd "$(dirname "$output_file")" 2>/dev/null && pwd)/$(basename "$output_file")" || output_file="$PWD/$output_file"

  echo ""
  print_info "=== 設定確認 ==="
  echo "プロジェクト名: $project_name"
  echo "サービス名: $service_name"
  echo "アプリ名: $app_name"
  echo "SSH Host: $ssh_host"
  echo "リモートパス: $app_path"
  echo "出力先: $output_file"
  echo ""

  read -p "この設定で生成しますか? (y/N): " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    print_warning "キャンセルしました"
    return 1
  fi

  # 生成
  print_info "スクリプト生成中..."
  if generate_setup_script "$service_name" "$app_name" "$app_path" "$ssh_host" "$output_file"; then
    print_success "生成完了: $output_file"
    return 0
  else
    print_error "生成に失敗しました"
    return 1
  fi
}

# メイン処理
main() {
  local project_dir=""
  local config_file=""
  local output_file=""
  local service_name=""
  local app_name=""
  local app_path=""
  local ssh_host=""
  local interactive=false

  # 引数解析
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        project_dir="$2"
        shift 2
        ;;
      --config)
        config_file="$2"
        shift 2
        ;;
      --output)
        output_file="$2"
        shift 2
        ;;
      --service-name)
        service_name="$2"
        shift 2
        ;;
      --app-name)
        app_name="$2"
        shift 2
        ;;
      --app-path)
        app_path="$2"
        shift 2
        ;;
      --ssh-host)
        ssh_host="$2"
        shift 2
        ;;
      --interactive)
        interactive=true
        shift
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        print_error "不明なオプション: $1"
        show_help
        exit 1
        ;;
    esac
  done

  # モード判定と実行
  if [ -n "$project_dir" ]; then
    # プロジェクトディレクトリモード
    generate_from_project "$project_dir"

  elif [ -n "$config_file" ]; then
    # 設定ファイルモード
    if [ -z "$output_file" ]; then
      print_error "--config を使用する場合、--output も必須です"
      exit 1
    fi

    print_info "設定ファイル読み込み: $config_file"
    load_single_project "$config_file" "$(dirname "$config_file")"

    generate_setup_script "$PROJECT_service_name" "$PROJECT_app_name" \
                         "$REMOTE_app_path" "$PROJECT_ssh_host" \
                         "$output_file"

  elif [ "$interactive" = true ]; then
    # 対話モード
    interactive_mode

  elif [ -n "$service_name" ] && [ -n "$app_name" ] && \
       [ -n "$app_path" ] && [ -n "$ssh_host" ] && \
       [ -n "$output_file" ]; then
    # コマンドライン引数モード
    print_info "コマンドライン引数から生成"
    generate_setup_script "$service_name" "$app_name" "$app_path" "$ssh_host" "$output_file"

  else
    print_error "使用方法が正しくありません"
    echo ""
    show_help
    exit 1
  fi
}

main "$@"
