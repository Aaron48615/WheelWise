#!/bin/bash
# 预留：取得 Apple Developer 账号后，对发布产物做 Developer ID 签名 + 公证。
#
# 前置条件（当前未启用，仅占位）：
#   1. 用 "Developer ID Application" 证书替换 build-app.sh 中的 ad-hoc 签名:
#      codesign --force --options runtime -s "Developer ID Application: <NAME> (<TEAMID>)" build/WheelWise.app
#   2. 配置以下环境变量（建议放 GitHub Actions secrets）:
#      APPLE_ID / APPLE_TEAM_ID / APPLE_APP_SPECIFIC_PASSWORD
#
# 用法: APPLE_ID=... APPLE_TEAM_ID=... APPLE_APP_SPECIFIC_PASSWORD=... bash scripts/notarize.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ZIP=$(ls build/WheelWise-*.zip | head -n1)

echo "==> notarytool submit $ZIP"
xcrun notarytool submit "$ZIP" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait

echo "==> stapler staple"
xcrun stapler staple build/WheelWise.app

ditto -c -k --keepParent build/WheelWise.app "$ZIP"
echo "==> 公证完成: $ZIP"
