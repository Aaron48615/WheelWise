#!/bin/bash
# 构建 WheelWise.app 并 ad-hoc 签名，输出 zip。
# 用法:
#   bash scripts/build-app.sh              # 本机架构
#   UNIVERSAL=1 bash scripts/build-app.sh  # arm64 + x86_64 通用二进制
# 环境变量:
#   APP_VERSION   版本号（默认 0.1.0）
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${APP_VERSION:-0.1.1}"
BUILD="$(date +%Y%m%d)"
APP="build/WheelWise.app"

if [ "${UNIVERSAL:-0}" = "1" ]; then
    echo "==> swift build -c release --arch arm64 --arch x86_64"
    swift build -c release --arch arm64 --arch x86_64
    BIN=".build/apple/Products/Release/WheelWise"
else
    echo "==> swift build -c release"
    swift build -c release
    BIN=".build/release/WheelWise"
fi

if [ ! -f "$BIN" ]; then
    echo "错误: 找不到可执行文件 $BIN" >&2
    exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
    <key>CFBundleExecutable</key><string>WheelWise</string>
    <key>CFBundleIdentifier</key><string>com.wheelwise.WheelWise</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>WheelWise</string>
    <key>CFBundleDisplayName</key><string>WheelWise</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>Released under the MIT License.</string>
</dict>
</plist>
PLIST

cp "$BIN" "$APP/Contents/MacOS/WheelWise"

# ad-hoc 签名：无开发者账号也能本机运行；正式分发公证见 scripts/notarize.sh
codesign --force -s - "$APP"

ditto -c -k --keepParent "$APP" "build/WheelWise-$VERSION.zip"
echo "==> 完成: $APP (build/WheelWise-$VERSION.zip)"
