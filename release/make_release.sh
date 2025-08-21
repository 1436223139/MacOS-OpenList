#!/bin/bash

# =========================================================
# OpenList macOS 应用打包发布脚本（适用于 appdmg）
# 作者：Gemini AI Assistant
# 版本：2025-07-16
# =========================================================

# ===== 配置项 =====
APP_NAME="OpenList"                            # 应用名称
CERT_NAME="OpenList Developer"                # 签名证书名称（需在钥匙串中配置好）
ICON_FILE="openlist.icns"                     # 应用图标文件（必须是 .icns 格式）
BACKGROUND_FILE="background.png"              # DMG 背景图
RELEASE_DIR="release"                         # 输出目录

# ===== 获取版本号（从参数读取，否则默认为 v4.0.8）=====
VERSION="${1:-v4.0.8}"
DMG_NAME="${APP_NAME}_${VERSION}.dmg"
ZIP_NAME="${APP_NAME}_${VERSION}.zip"
APP_BUNDLE="${APP_NAME}.app"

echo "🔖 打包版本：$VERSION"

# =========================================================
# 阶段 0: 前置文件和工具检查
# =========================================================
echo "--- 正在进行前置文件和工具检查... ---"
[ ! -f openlist_launcher.sh ] && echo "❌ 缺少 openlist_launcher.sh" && exit 1
[ ! -f openlist ] && echo "❌ 缺少 openlist 可执行文件" && exit 1
[ ! -f "$ICON_FILE" ] && echo "❌ 缺少 $ICON_FILE" && exit 1
[ ! -x "$(command -v appdmg)" ] && echo "❌ 未安装 appdmg，请运行 'npm install -g appdmg'" && exit 1

if [ -f "$BACKGROUND_FILE" ]; then
    echo "✅ 找到背景图片: $BACKGROUND_FILE"
else
    echo "⚠️ 警告：未找到背景图文件 $BACKGROUND_FILE，DMG 将没有自定义背景"
fi
echo "--- 前置文件和工具检查完成。 ---"

# =========================================================
# 阶段 1: 构建 .app 应用程序包结构
# =========================================================
echo "--- 阶段 1: 构建 $APP_BUNDLE ---"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 拷贝启动脚本和可执行文件
cp openlist_launcher.sh "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp openlist "$APP_BUNDLE/Contents/Resources/openlist"
cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/$ICON_FILE"

# 生成 Info.plist 配置文件（描述应用信息）
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.mouren.openlist</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>$ICON_FILE</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ 应用构建完成：$APP_BUNDLE"

# =========================================================
# 阶段 2: 签名 .app 应用
# =========================================================
echo "--- 阶段 2: 签名 $APP_BUNDLE ---"
sudo codesign -s "$CERT_NAME" --deep --force --options runtime "$APP_BUNDLE"

if codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" &>/dev/null; then
    echo "✅ 签名成功"
else
    echo "❌ 签名失败，请检查证书名：$CERT_NAME"
    exit 1
fi

# =========================================================
# 阶段 3: 清理并创建 release 目录
# =========================================================
echo "--- 阶段 3: 清理旧的 $RELEASE_DIR 目录 ---"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
echo "✅ 创建完成：$RELEASE_DIR"

# =========================================================
# 阶段 4: 创建 .dmg 安装包
# =========================================================
echo "--- 阶段 4: 创建 DMG 文件 ---"
DMG_TEMP_DIR="dmg_temp"
rm -rf "$DMG_TEMP_DIR"
mkdir -p "$DMG_TEMP_DIR"
cp -R "$APP_BUNDLE" "$DMG_TEMP_DIR"
[ -f "$BACKGROUND_FILE" ] && cp "$BACKGROUND_FILE" "$DMG_TEMP_DIR"
[ -f "$ICON_FILE" ] && cp "$ICON_FILE" "$DMG_TEMP_DIR"

# 生成 appdmg 所需配置文件
cat > "$DMG_TEMP_DIR/dmg_config.json" <<EOF
{
  "title": "${APP_NAME} ${VERSION}",
  "icon": "$ICON_FILE",
  "background": "${BACKGROUND_FILE:-none}",
  "icon-size": 100,
  "contents": [
    { "x": 130, "y": 200, "type": "file", "path": "${APP_NAME}.app" },
    { "x": 380, "y": 200, "type": "link", "path": "/Applications" }
  ],
  "format": "UDZO"
}
EOF

cd "$DMG_TEMP_DIR"
appdmg dmg_config.json "../${RELEASE_DIR}/${DMG_NAME}"
cd ..
rm -rf "$DMG_TEMP_DIR"

if [ -f "${RELEASE_DIR}/${DMG_NAME}" ]; then
    echo "✅ DMG 创建完成：$RELEASE_DIR/$DMG_NAME"
else
    echo "❌ DMG 创建失败"
    exit 1
fi

# =========================================================
# 阶段 5: 生成 README 文档
# =========================================================
echo "--- 阶段 5: 生成说明文档 README.md ---"
cat > "$RELEASE_DIR/README.md" <<EOF
# OpenList ${VERSION}

OpenList 是一个轻量级服务列表管理工具，支持 Web 控制面板。

## 安装步骤

1. 双击 \`${DMG_NAME}\`
2. 拖动 OpenList.app 到“应用程序”文件夹图标
3. 若提示“无法验证开发者”，右键 → 打开一次即可

## 默认信息

- 默认地址：http://localhost:5244
- 管理员账户：admin
EOF
echo "✅ README.md 创建完成"

# =========================================================
# 阶段 6: 创建 ZIP 包（包含 DMG 和文档）
# =========================================================
echo "--- 阶段 6: 创建 ZIP 包 ---"
cp "$0" "$RELEASE_DIR"
cd "$RELEASE_DIR"
zip -r "$ZIP_NAME" "$DMG_NAME" "README.md" "$(basename "$0")"
cd ..
echo "✅ ZIP 包创建完成：$RELEASE_DIR/$ZIP_NAME"

# =========================================================
# 阶段 7: 生成 SHA256 校验码文件
# =========================================================
echo "--- 阶段 7: 生成 SHA256 校验码 ---"
cd "$RELEASE_DIR"
shasum -a 256 "$DMG_NAME" "$ZIP_NAME" > SHA256SUMS.txt
cd ..
echo "✅ 校验码生成完成：$RELEASE_DIR/SHA256SUMS.txt"

# =========================================================
# 阶段 8: 生成二维码下载页面（release_qr.html）
# =========================================================
echo "--- 阶段 8: 生成二维码 HTML 页面 ---"
cat > "$RELEASE_DIR/release_qr.html" <<EOF
<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="UTF-8">
  <title>OpenList ${VERSION} 下载</title>
  <style>
    body { font-family: sans-serif; text-align: center; margin-top: 50px; }
    img { margin: 20px 0; }
    pre { background-color: #f0f0f0; padding: 10px; border-radius: 5px; display: inline-block; }
  </style>
</head>
<body>
  <h1>OpenList ${VERSION}</h1>
  <p>点击或扫码下载 ZIP 包</p>
  <img src="https://api.qrserver.com/v1/create-qr-code/?data=YOUR_DOWNLOAD_LINK_HERE&size=220x220" alt="QR">
  <p><a href="YOUR_DOWNLOAD_LINK_HERE">${ZIP_NAME}</a></p>
  <h2>SHA256：</h2>
  <pre>$(shasum -a 256 "$RELEASE_DIR/$ZIP_NAME" | awk '{print $1}')</pre>
  <p>构建时间：$(date '+%Y-%m-%d %H:%M:%S')</p>
</body>
</html>
EOF
echo "✅ 二维码页面已生成：$RELEASE_DIR/release_qr.html"

# =========================================================
# 🎉 所有步骤完成
# =========================================================
echo "🎉 构建完成！输出目录：$(pwd)/$RELEASE_DIR"
ls -lh "$RELEASE_DIR"