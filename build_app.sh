#!/bin/bash
# swift build で作ったバイナリを .app バンドルに詰め直す。
# 使い方: ./build_app.sh   →  build/ポモドーロタイマー.app ができる
set -euo pipefail

TARGET_NAME="Pomodoro"
APP_NAME="Pomodoro"
DISPLAY_NAME="ポモドーロタイマー"
BUNDLE_ID="com.roll1226.pomodoro"
VERSION="1.0"

cd "$(dirname "$0")"

echo "==> ビルド中..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${TARGET_NAME}"
APP_DIR="build/${APP_NAME}.app"

echo "==> .app バンドルを作成中..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# アイコン。Resources/AppIcon.icns は Tools/MakeAppIcon.swift の生成物で、
# 再生成が必要なのはデザインを変えたときだけ（README 参照）。
cp Resources/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# 注意: アドホック署名は再ビルドのたびに cdhash が変わるため、macOS が別アプリと
# 見なして通知の許可がリセットされることがある。通知が出なくなったら
# システム設定 › 通知 でポモドーロタイマーの許可を確認する。
echo "==> 署名中（通知を有効にするためのアドホック署名）..."
codesign --force --deep --sign - "${APP_DIR}" \
    || echo "警告: 署名に失敗しました。通知が出ない場合がありますが、サウンドは鳴ります。"

echo ""
echo "完成: ${APP_DIR}"
echo "起動:   open ${APP_DIR}"
echo "配置:   cp -R ${APP_DIR} /Applications/"
