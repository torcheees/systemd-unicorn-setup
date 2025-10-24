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
