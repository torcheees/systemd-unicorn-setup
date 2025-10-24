#!/bin/bash
# 単一プロジェクト用YAML解析ライブラリ
# .systemd-setup.yml を解析

parse_single_project_yaml() {
  local yaml_file="$1"
  local project_dir="$2"  # プロジェクトディレクトリ（絶対パス）

  if [ ! -f "$yaml_file" ]; then
    echo "ERROR: YAML file not found: $yaml_file" >&2
    return 1
  fi

  # シンプルなYAMLパーサー (単一プロジェクト用)
  awk -v project_dir="$project_dir" '
    BEGIN {
      current_section = ""
    }

    # コメントと空行をスキップ
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }

    # セクション判定
    /^project:/ {
      current_section = "project"
      next
    }

    /^remote:/ {
      current_section = "remote"
      next
    }

    /^local:/ {
      current_section = "local"
      next
    }

    /^ssh_config:/ {
      current_section = "ssh_config"
      next
    }

    # キー:値のペア
    /^[[:space:]]*[a-z_]+:[[:space:]]*.+$/ {
      line = $0
      sub(/^[[:space:]]*/, "", line)

      # コロンで分割
      colon_pos = index(line, ":")
      if (colon_pos > 0) {
        key = substr(line, 1, colon_pos - 1)
        value = substr(line, colon_pos + 1)
        sub(/^[[:space:]]*/, "", value)  # 値の先頭空白除去

        # セクションプレフィックス
        if (current_section == "project") {
          print "PROJECT_" key "=" value
        } else if (current_section == "remote") {
          print "REMOTE_" key "=" value
        } else if (current_section == "local") {
          # ローカルパスは絶対パスに変換
          if (key == "service_file" || key == "output_script") {
            # 相対パスの場合、project_dirを基準に絶対パスに変換
            if (value !~ /^\//) {
              value = project_dir "/" value
            }
          }
          print "LOCAL_" key "=" value
        } else if (current_section == "ssh_config") {
          print "SSH_CONFIG_" key "=" value
        }
      }
    }
  ' "$yaml_file"
}

# プロジェクト情報を環境変数として読み込む
load_single_project() {
  local config_file="$1"
  local project_dir="$2"

  eval "$(parse_single_project_yaml "$config_file" "$project_dir")"
}

# 使用例:
# load_single_project "/path/to/project/.systemd-setup.yml" "/path/to/project"
# echo "Project name: $PROJECT_name"
# echo "SSH host: $PROJECT_ssh_host"
# echo "Service file: $LOCAL_service_file"
