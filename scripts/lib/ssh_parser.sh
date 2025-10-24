#!/bin/bash
# SSH Config パーサー
# ~/.ssh/config からHost情報を抽出

# SSH Hostから情報を取得
get_ssh_info() {
  local ssh_host="$1"
  local ssh_config="${2:-$HOME/.ssh/config}"

  if [ ! -f "$ssh_config" ]; then
    echo "ERROR: SSH config not found: $ssh_config" >&2
    return 1
  fi

  # awk で SSH config を解析
  awk -v host="$ssh_host" '
    BEGIN {
      found = 0
      hostname = ""
      port = "22"
      user = ""
      identity_file = ""
    }

    /^Host / {
      if (found) exit
      if ($2 == host) {
        found = 1
      }
    }

    found && /^[[:space:]]*HostName/ {
      hostname = $2
    }

    found && /^[[:space:]]*[Pp]ort/ {
      port = $2
    }

    found && /^[[:space:]]*User/ {
      user = $2
    }

    found && /^[[:space:]]*IdentityFile/ {
      identity_file = $2
      gsub(/~/, ENVIRON["HOME"], identity_file)
    }

    /^Host / && found && $2 != host {
      exit
    }

    END {
      if (found && hostname != "") {
        print hostname
        print port
        print user
        print identity_file
      } else {
        exit 1
      }
    }
  ' "$ssh_config"
}

# SSH Hostが存在するか確認
ssh_host_exists() {
  local ssh_host="$1"
  local ssh_config="${2:-$HOME/.ssh/config}"

  grep -q "^Host $ssh_host$" "$ssh_config"
}

# SSH接続文字列を生成
get_ssh_connection_string() {
  local ssh_host="$1"
  echo "$ssh_host"
}

# 使用例:
# if ssh_host_exists "medica_prod"; then
#   read -r hostname port user identity_file < <(get_ssh_info "medica_prod")
#   echo "Hostname: $hostname"
#   echo "Port: $port"
#   echo "User: $user"
# fi
