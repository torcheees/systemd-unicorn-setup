#!/bin/bash
# 全プロジェクトのsystemd_setup.shを生成するスクリプト

set -e

# プロジェクト設定
declare -a PROJECTS=(
  "medica|medica|medica-unicorn|/home/deploy/apps/medica|45.77.21.63:11270|/Users/akimitsukoshikawa/workspace/torcheees/medica"
  "corp|corp|corp-unicorn|/home/deploy/apps/corp|45.77.178.149:11270|/Users/akimitsukoshikawa/workspace/torcheees/corp"
  "ex_dance_stadium|dance_stadium|dance-stadium-unicorn|/home/deploy/apps/dance_stadium|108.61.162.167:57777|/Users/akimitsukoshikawa/workspace/torcheees/ex_dance_stadium"
  "ndp-kabarai-lp-for-fujii|kabarai_for_fujii|kabarai-for-fujii-unicorn|/home/deploy/apps/kabarai_for_fujii|202.182.99.237:11270|/Users/akimitsukoshikawa/workspace/ndp/ndp-kabarai-lp-for-fujii"
  "ndp_yamikin_lp|ndp_yamikin_lp|ndp-yamikin-lp-unicorn|/home/deploy/apps/ndp_yamikin_lp|104.156.239.46:11270|/Users/akimitsukoshikawa/workspace/torcheees/ndp_yamikin_lp"
  "ndp-seramid|ndp-seramid|ndp-seramid-unicorn|/home/deploy/apps/ndp-seramid|104.238.151.79:11270|/Users/akimitsukoshikawa/workspace/ndp/ndp-seramid"
  "ndp-king-gear|king_gear|king-gear-unicorn|/home/deploy/apps/king_gear|45.32.28.159:57777|/Users/akimitsukoshikawa/workspace/torcheees/ndp-king-gear"
)

# medicaのスクリプトをテンプレートとして読み込む
TEMPLATE_FILE="/Users/akimitsukoshikawa/workspace/torcheees/medica/script/systemd_setup.sh"

for project_info in "${PROJECTS[@]}"; do
  IFS='|' read -r project_name app_name service_name app_path server_ip_port project_path <<< "$project_info"

  echo "生成中: $project_name"

  OUTPUT_FILE="$project_path/script/systemd_setup.sh"

  # テンプレートをコピーして置換
  sed -e "s|SERVICE_NAME=\"medica-unicorn\"|SERVICE_NAME=\"${service_name}\"|" \
      -e "s|APP_NAME=\"medica\"|APP_NAME=\"${app_name}\"|" \
      -e "s|APP_PATH=\"/home/deploy/apps/medica\"|APP_PATH=\"${app_path}\"|" \
      -e "s|SERVER_IP_PORT=\"45.77.21.63:11270\"|SERVER_IP_PORT=\"${server_ip_port}\"|" \
      -e "s|SERVICE_FILE=\"\$PROJECT_ROOT/config/systemd/medica-unicorn.service\"|SERVICE_FILE=\"\$PROJECT_ROOT/config/systemd/${service_name}.service\"|" \
      -e "s|/tmp/medica-unicorn.service|/tmp/${service_name}.service|g" \
      -e "s|sudo systemctl cat medica-unicorn|sudo systemctl cat ${service_name}|" \
      -e "s|sudo systemctl enable medica-unicorn|sudo systemctl enable ${service_name}|" \
      -e "s|sudo systemctl status medica-unicorn|sudo systemctl status ${service_name}|" \
      "$TEMPLATE_FILE" > "$OUTPUT_FILE"

  chmod +x "$OUTPUT_FILE"
  echo "  ✓ $OUTPUT_FILE"
done

echo ""
echo "完了！全プロジェクトのスクリプトを生成しました。"
