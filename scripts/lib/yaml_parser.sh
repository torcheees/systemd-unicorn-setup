#!/bin/bash
# YAML パーサー (yq不要のシンプル実装)
# projects.yml を解析してプロジェクト情報を抽出

parse_yaml() {
  local yaml_file="$1"
  local prefix="${2:-}"

  if [ ! -f "$yaml_file" ]; then
    echo "ERROR: YAML file not found: $yaml_file" >&2
    return 1
  fi

  # シンプルなYAMLパーサー (projects配列専用)
  awk -v prefix="$prefix" '
    BEGIN {
      in_projects = 0
      project_index = -1
      indent_level = 0
      current_section = ""
    }

    # コメントと空行をスキップ
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }

    # projects: セクション開始
    /^projects:/ {
      in_projects = 1
      next
    }

    # プロジェクトエントリ開始 (- name:)
    in_projects && /^[[:space:]]*-[[:space:]]*name:/ {
      project_index++
      name = $0
      sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", name)
      print prefix "PROJECT_" project_index "_name=" name
      current_section = ""
      next
    }

    # フィールド解析
    in_projects && project_index >= 0 {
      line = $0

      # インデントレベル判定
      match(line, /^[[:space:]]*/)
      indent = RLENGTH

      # セクション判定 (remote:, local:)
      if (line ~ /^[[:space:]]*remote:/) {
        current_section = "remote"
        next
      } else if (line ~ /^[[:space:]]*local:/) {
        current_section = "local"
        next
      }

      # キー:値のペア
      if (match(line, /^[[:space:]]*[a-z_]+:[[:space:]]*.+$/)) {
        key_value = line
        sub(/^[[:space:]]*/, "", key_value)

        # コロンで分割
        colon_pos = index(key_value, ":")
        if (colon_pos > 0) {
          key = substr(key_value, 1, colon_pos - 1)
          value = substr(key_value, colon_pos + 1)
          sub(/^[[:space:]]*/, "", value)  # 値の先頭空白除去

          # セクションプレフィックス
          if (current_section != "") {
            full_key = current_section "_" key
          } else {
            full_key = key
          }

          print prefix "PROJECT_" project_index "_" full_key "=" value
        }
      }
    }

    # projects以外のセクション (defaults, ssh_config等)
    !in_projects && /^[a-z_]+:/ {
      in_projects = 0
    }

    END {
      print prefix "PROJECT_COUNT=" (project_index + 1)
    }
  ' "$yaml_file"
}

# プロジェクト数を取得
get_project_count() {
  local yaml_file="$1"
  parse_yaml "$yaml_file" | grep "^PROJECT_COUNT=" | cut -d= -f2
}

# 特定プロジェクトの情報を取得
get_project_info() {
  local yaml_file="$1"
  local project_index="$2"

  parse_yaml "$yaml_file" | grep "^PROJECT_${project_index}_"
}

# プロジェクト名でインデックスを検索
find_project_by_name() {
  local yaml_file="$1"
  local project_name="$2"

  local count=$(get_project_count "$yaml_file")

  for ((i=0; i<count; i++)); do
    local name=$(get_project_info "$yaml_file" "$i" | grep "^PROJECT_${i}_name=" | cut -d= -f2)
    if [ "$name" = "$project_name" ]; then
      echo "$i"
      return 0
    fi
  done

  return 1
}

# 使用例:
# eval "$(parse_yaml config/projects.yml)"
# echo "Project 0 name: $PROJECT_0_name"
# echo "Project 0 SSH host: $PROJECT_0_ssh_host"
# echo "Project 0 local path: $PROJECT_0_local_project_path"
