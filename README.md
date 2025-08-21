# OpenList macOS 应用打包发布完整方案

## 方案概览

本文提供了一个自动化、完整的流程，指导你如何将 **OpenList Go 语言可执行文件**打包成一个用户友好的 **macOS `.app` 应用程序包**，并最终生成一个带有自定义背景和图标的 **`.dmg` 安装文件**，同时附带发布所需的辅助文件（如 ZIP 包、README 和校验码）。

我们将涉及以下核心组件：

* **`openlist`**: 你的 Go 语言编译后的核心服务可执行文件。
* **`openlist_launcher.sh`**: 一个 Shell 脚本，作为 `.app` 包的启动入口，提供用户交互界面来控制 OpenList 服务（启动、停止、密码重置）。
* **`openlist.icns`**: 应用程序图标文件。
* **`background.png`**: DMG 安装界面的背景图片（可选）。
* **`make_release.sh`**: 主要的打包脚本，负责构建 `.app`、代码签名、生成 `.dmg` 和其他发布材料。

## 文件准备

在开始自动化打包流程之前，我们需要确保所有必需的文件都已准备就绪并放置在正确的目录结构中。这一步是整个流程的基础，包含了将你的核心可执行文件、启动脚本、应用程序图标等素材整理到位。

建议你创建一个专门的工作文件夹，例如 `~/OpenList_Packaging/`，并将所有相关文件集中存放于此。

以下是详细的文件准备步骤，包含如何从你的开发环境中获取和生成这些文件：

### 创建主工作文件夹

首先，在你的用户目录下创建一个用于打包项目的主文件夹。这个文件夹将包含你所有的源文件和打包脚本。

```bash
mkdir -p ~/OpenList_Packaging
cd ~/OpenList_Packaging/
```

### 准备 OpenList Go 可执行文件

确保你已经将 Go 语言编写的 `openlist` 服务编译成一个可在 macOS 上运行的二进制文件。
将这个编译好的可执行文件移动到你的工作文件夹中。

```bash
# 假设你的 Go 项目在 ~/go/src/your_project/
# 并且你已经编译生成了 openlist 可执行文件
mv /path/to/your/openlist_executable ~/OpenList_Packaging/openlist
# 请将 /path/to/your/openlist_executable 替换为你的实际可执行文件路径
```

### 准备 `openlist_launcher.sh` 启动脚本

这个 Shell 脚本将作为你的 `.app` 应用程序包的实际启动入口，负责启动 OpenList 服务并提供用户交互界面。请在 `~/OpenList_Packaging/` 目录下创建 `openlist_launcher.sh` 文件，并粘贴本文档 `3.1 openlist_launcher.sh` 部分提供的内容。

```bash
# 在 ~/OpenList_Packaging/ 目录下创建文件
touch openlist_launcher.sh
# 然后将本文档 3.1 节的内容复制粘贴到此文件中
# 例如使用 nano 或 vim 编辑器:
# nano openlist_launcher.sh
# (粘贴内容后按 Ctrl+X, Y, Enter 保存退出)
```

### 准备应用程序图标 (`openlist.icns`)

你的应用程序需要一个 `.icns` 格式的图标文件才能在 macOS 上正确显示。
如果是其他格式，则需要进行转换，如`openlist.png`，我们可以使用它来生成 `.icns` 文件。

**如果你已经有 `openlist.png` 文件：**

1.  **将 PNG 图像移动到工作文件夹：**

    ```bash
    mv /path/to/your/openlist.png ~/OpenList_Packaging/openlist.png
    # 请将 /path/to/your/openlist.png 替换为你的实际 PNG 文件路径
    ```

2.  **生成 `.icns` 文件：**
    macOS 提供了一个内置工具 `iconutil` 可以从一个包含不同尺寸 PNG 图片的 `.iconset` 文件夹中生成 `.icns` 文件。你需要先创建一个 `.iconset` 文件夹，并将不同尺寸的 `openlist.png` 复制进去。

      * **重要提示：** 为了最佳显示效果，你需要准备不同分辨率的 `openlist.png` 图片，并按照 Apple 的要求命名。如果没有，`iconutil` 可能会失败或生成效果不佳的图标。最简单的做法是准备一个高分辨率的 PNG（例如 1024x1024 像素），然后使用在线工具或图形编辑软件（如 Sketch, Affinity Designer, Photoshop）导出所有必需的尺寸。

      * 以下是一个示例，假设你已经有了一个高分辨率的 `openlist.png`，你可以使用 ImageMagick（`brew install imagemagick`）来快速生成一些尺寸：

        ```bash
        # 假设 openlist.png 已经存在于 ~/OpenList_Packaging/
        mkdir openlist.iconset

        # 生成不同尺寸的PNG并放入iconset文件夹
        sips -z 16 16 openlist.png --out openlist.iconset/icon_16x16.png
        sips -z 32 32 openlist.png --out openlist.iconset/icon_16x16@2x.png
        sips -z 32 32 openlist.png --out openlist.iconset/icon_32x32.png
        sips -z 64 64 openlist.png --out openlist.iconset/icon_32x32@2x.png
        sips -z 128 128 openlist.png --out openlist.iconset/icon_64x64@2x.png # icon_64x64.png is deprecated
        sips -z 128 128 openlist.png --out openlist.iconset/icon_128x128.png
        sips -z 256 256 openlist.png --out openlist.iconset/icon_128x128@2x.png
        sips -z 256 256 openlist.png --out openlist.iconset/icon_256x256.png
        sips -z 512 512 openlist.png --out openlist.iconset/icon_256x256@2x.png
        sips -z 512 512 openlist.png --out openlist.iconset/icon_512x512.png
        sips -z 1024 1024 openlist.png --out openlist.iconset/icon_512x512@2x.png

        # 使用 iconutil 生成 .icns 文件
        iconutil -c icns openlist.iconset -o openlist.icns

        # 清理临时文件 (可选)
        rm -rf openlist.iconset
        ```

### 准备 DMG 背景图片 (`background.png`) (可选)

为了让你的 `.dmg` 安装文件看起来更专业，你可以准备一张自定义的背景图片。这张图片通常是 `.png`、`.gif` 或 `.jpg` 格式，大小适中，能够作为 DMG 窗口的背景。将它放置在你的工作文件夹中。如果不需要自定义背景，可以跳过此步骤，`make_release.sh` 脚本会检测到文件不存在并跳过背景设置。

```bash
# 假设你的背景图片在 /path/to/your/background.png
mv /path/to/your/background.png ~/OpenList_Packaging/background.png
# 如果没有此文件，可跳过。
```

### 准备 `make_release.sh` 主打包脚本

在 `~/OpenList_Packaging/` 目录下创建 `make_release.sh` 文件，并粘贴本文档 `3.2 make_release.sh` 部分提供的内容。**请务必根据你的实际情况修改 `CERT_NAME` 变量！**

```bash
# 在 ~/OpenList_Packaging/ 目录下创建文件
touch make_release.sh
# 然后将本文档 3.2 节的内容复制粘贴到此文件中
# 尤其注意修改 CERT_NAME="OpenList Developer" 为你自己的证书名称
```

现在，你的 `~/OpenList_Packaging/` 文件夹应该包含了所有必需的文件，结构如下：

```
~/OpenList_Packaging/
├── openlist             # 你的 Go 程序可执行文件 (已编译)
├── openlist.icns        # 你的应用图标文件 (已生成)
├── background.png       # (可选) DMG 背景图片
├── openlist_launcher.sh # 启动脚本
└── make_release.sh      # 主打包脚本
```

文件准备工作完成，你可以继续进行下一步的脚本执行。

## 脚本内容

### `openlist_launcher.sh`

创建 `openlist_launcher.sh` 文件，并复制以下内容。这个脚本是 `OpenList.app` 实际运行时的核心逻辑，它通过 AppleScript 弹窗与用户交互。

```bash
#!/bin/bash

# 获取当前脚本所在应用程序包的Contents目录
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Resources目录
RES_DIR="$APP_DIR/Resources"

# 实际的OpenList可执行文件路径
BIN_PATH="$RES_DIR/openlist"

# 数据目录，通常放在 ~/Library/Application Support/OpenList
DATA_DIR="$HOME/Library/Application Support/OpenList"

# 图标路径，用于AppleScript对话框
ICON_PATH="$RES_DIR/openlist.icns"

# 服务访问URL
SERVICE_URL="http://localhost:5244"

# 检查服务是否运行
is_running() {
    pgrep -f "openlist server" >/dev/null
}

# 获取服务状态文本
get_status_text() {
    if is_running; then
        echo "✅ 服务正在运行"
    else
        echo "❌ 服务未运行"
    fi
}

# 启动服务核心逻辑
start_service_core() {
    if ! is_running; then
        mkdir -p "$DATA_DIR"
        nohup "$BIN_PATH" start --data "$DATA_DIR" --force-bin-dir > "$DATA_DIR/openlist_server.log" 2>&1 &
        echo $! > "$DATA_DIR/openlist_pid.txt"
        sleep 2
    fi
}

# 停止服务
stop_service() {
    if is_running; then
        if [ -f "$DATA_DIR/openlist_pid.txt" ]; then
            PID=$(cat "$DATA_DIR/openlist_pid.txt")
            if ps -p $PID > /dev/null; then
                kill $PID
                sleep 1
                if ! is_running; then
                    rm "$DATA_DIR/openlist_pid.txt"
                    return 0
                fi
            fi
        fi
        "$BIN_PATH" stop --data "$DATA_DIR"
        sleep 1
        if ! is_running; then
            return 0
        else
            pkill -f "openlist server"
            sleep 1
            if ! is_running; then
                return 0
            fi
        fi
        return 1
    else
        return 1
    fi
}

# 主菜单
main_menu() {
    while true; do
        local status_text=$(get_status_text)
        choice=$(osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "🌐 OpenList 服务控制面板\n\n'"$status_text"'" buttons {"启动服务", "更多操作", "退出"} default button "退出" with title "OpenList 控制台" with icon iconPath
            return button returned of result
        ')

        case "$choice" in
            "启动服务") handle_start_service_flow ;;
            "更多操作") handle_secondary_menu_flow ;;
            "退出")
                local confirm_exit=$(osascript -e '
                    set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
                    display dialog "您确定要退出 OpenList 控制台吗？服务将继续在后台运行。" buttons {"继续运行服务并退出", "停止服务并退出", "取消"} default button "继续运行服务并退出" with title "确认退出" with icon iconPath
                    return button returned of result
                ')
                case "$confirm_exit" in
                    "停止服务并退出") stop_service; exit 0 ;;
                    "继续运行服务并退出") exit 0 ;;
                    "取消") ;;
                esac
                ;;
        esac
    done
}

# 启动服务流程
handle_start_service_flow() {
    start_service_core
    local choice=$(osascript -e '
        set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
        display dialog "OpenList 服务已尝试启动！\n\n'"$(get_status_text)"'" buttons {"访问地址", "返回"} default button "返回" with title "服务状态" with icon iconPath
        return button returned of result
    ')
    case "$choice" in
        "访问地址") handle_access_url_action; exit 0 ;;
        "返回") ;;
    esac    
}

# 二级菜单流程
handle_secondary_menu_flow() {
    local action=$(osascript -e '
        set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
        display dialog "请选择要执行的操作：" buttons {"停止服务", "重置密码", "返回"} default button "返回" with title "服务操作" with icon iconPath
        return button returned of result
    ')
    case "$action" in
        "停止服务") handle_stop_service_action ;;
        "重置密码") handle_reset_password_flow ;;
        "返回") ;;
    esac
}

# 停止服务操作
handle_stop_service_action() {
    if stop_service; then
        osascript -e 'display notification "OpenList 服务已停止" with title "✅ 操作完成"'
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "OpenList 服务已停止！\n\n'"$(get_status_text)"'" buttons {"确定"} default button "确定" with title "操作完成" with icon iconPath
        '
        exit 0
    else
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "服务未运行，无法停止。\n\n'"$(get_status_text)"'" buttons {"确定"} default button "确定" with title "操作失败" with icon iconPath
        '
    fi
}

# 访问服务URL
handle_access_url_action() {
    if is_running; then
        open "$SERVICE_URL"
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "已在浏览器中打开服务地址。\n\n'"$(get_status_text)"'" buttons {"确定"} default button "确定" with title "操作完成" with icon iconPath
        '
    else
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "服务未启动，无法访问。\n\n'"$(get_status_text)"'" buttons {"确定"} default button "确定" with title "操作失败" with icon iconPath
        '
    fi
}

# 重置密码流程
handle_reset_password_flow() {
    local reset_action=$(osascript -e '
        set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
        display dialog "请选择重置密码方式：" buttons {"随机生成", "手动设置", "返回"} default button "返回" with title "重置密码" with icon iconPath
        return button returned of result
    ')
    case "$reset_action" in
        "随机生成") handle_random_password_reset ;;
        "手动设置") handle_manual_password_set ;;
        "返回") ;;
    esac
}

# 随机密码重置
handle_random_password_reset() {
    if is_running; then
        local confirm=$(osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "重置密码需要先停止 OpenList 服务，是否继续？" buttons {"继续", "取消"} default button "取消" with title "确认操作" with icon iconPath
            return button returned of result
        ')
        if [ "$confirm" == "取消" ]; then
            osascript -e '
                set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
                display dialog "已取消操作。" buttons {"确定"} default button "确定" with title "取消" with icon iconPath
            '
            return
        fi
        stop_service
        sleep 2
    fi

    rm -f "$DATA_DIR/openlist_server.log"
    "$BIN_PATH" admin random --data "$DATA_DIR" >> "$DATA_DIR/openlist_server.log" 2>&1

    local new_password=$(grep 'password:' "$DATA_DIR/openlist_server.log" | tail -n1 | awk -F 'password:' '{gsub(/^[ \t]+/, "", $2); print $2}')

    if [ -z "$new_password" ]; then
        new_password="（未能识别密码，请手动查看日志）"
    fi

    osascript <<EOF
set iconPathAlias to (POSIX file "$ICON_PATH" as alias)
display dialog "已生成新的随机密码：\n\n$new_password\n\n请复制并保存。您可以重新启动服务。" buttons {"确定"} default button "确定" with title "密码已重置" with icon iconPathAlias
EOF
}

# 手动设置密码
handle_manual_password_set() {
    if is_running; then
        local confirm=$(osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "重置密码需要先停止 OpenList 服务，是否继续？" buttons {"继续", "取消"} default button "取消" with title "确认操作" with icon iconPath
            return button returned of result
        ')
        if [ "$confirm" == "取消" ]; then
            osascript -e '
                set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
                display dialog "已取消操作。" buttons {"确定"} default button "确定" with title "取消" with icon iconPath
            '
            return
        fi
        stop_service
        sleep 2
    fi

    local user_input=$(osascript -e "
        set iconPathAlias to (POSIX file \"$ICON_PATH\" as alias)
        try
            display dialog \"请输入您想设置的新密码：\" default answer \"\" with icon iconPathAlias buttons {\"设置\", \"取消\"} default button \"设置\"
            if button returned of result is \"设置\" then
                return text returned of result
            else
                return \"CANCELLED\"
            end if
        on error
            return \"CANCELLED\"
        end try
    ")

    if [ "$user_input" == "CANCELLED" ]; then
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "已取消密码设置。" buttons {"确定"} default button "确定" with title "取消" with icon iconPath
        '
        return
    fi

    if [ -z "$user_input" ]; then
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "密码不能为空，已取消设置。" buttons {"确定"} default button "确定" with title "错误" with icon iconPath
        '
        return
    fi

    "$BIN_PATH" admin set "$user_input" --data "$DATA_DIR"

    osascript <<EOF
set iconPathAlias to (POSIX file "$ICON_PATH" as alias)
display dialog "密码已成功设置为：\n\n$user_input\n\n您可以重新启动服务。" buttons {"确定"} default button "确定" with title "密码已设置" with icon iconPathAlias
EOF
}

# 启动控制台
main_menu
```

### `make_release.sh`

创建 `make_release.sh` 文件，并复制以下内容。**注意：请务必将 `CERT_NAME="OpenList Developer"` 替换为你自己的代码签名证书名称！**

```bash
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
2. 拖动 OpenList.app 到"应用程序"文件夹图标
3. 若提示"无法验证开发者"，右键 → 打开一次即可

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
```

## 执行步骤

1.  **保存文件：**
    将 "文件准备" 中列出的所有文件放到同一个工作目录下 (例如 `~/OpenList_Packaging/`)。

2.  **设置脚本权限：**
    打开终端，进入你的工作目录，并为两个 Shell 脚本添加可执行权限：

    ```bash
    cd ~/OpenList_Packaging/
    chmod +x openlist_launcher.sh
    chmod +x make_release.sh
    ```

3.  **安装 `create-dmg` 和 `appdmg` 工具：**
    如果尚未安装 `create-dmg`，请通过 Homebrew 安装：

    ```bash
    brew install create-dmg
    ```
    如果尚未安装 `appdmg`，请通过 npm 安装：

    ```bash
    npm install -g appdmg
    ```

4.  **创建代码签名证书：**
    这是最关键的一步，确保你的应用在 macOS 上能够正常运行且不被安全机制阻止。

      * 打开 **"钥匙串访问" (Keychain Access)** 应用。
      * 在菜单栏选择 **"钥匙串访问" (Keychain Access)** \> **"证书助理" (Certificate Assistant)** \> **"创建证书" (Create a Certificate)**。
      * **填写信息：**
          * **名称：** 填写 `OpenList Developer` (这个名称**必须**与 `make_release.sh` 脚本中 `CERT_NAME` 变量的值完全一致)。
          * **身份类型：** 选择 `自签名根证书 (Self Signed Root)`。
          * **证书类型：** 选择 `代码签名 (Code Signing)`。
      * 点击 **"继续"**，一路默认设置，直到"指定位置"选择 **"系统"钥匙串 (System)**。
          * 💡 如果无法直接保存到"系统"钥匙串，你可以先保存到"登录"钥匙串。保存后，在"登录"钥匙串中找到新创建的证书，右键点击它，选择 **"导出" (Export)**，将其导出为一个 `.p12` 文件（设置一个密码）。然后，双击导出的 `.p12` 文件，在导入时选择导入到 **"系统"钥匙串**。
      * 点击 **"创建"** 并输入 macOS 用户密码以确认操作。
      * **设置信任策略：** 在"钥匙串访问"的**"系统"钥匙串**中找到你刚创建的 `OpenList Developer` 证书。
          * **双击**该证书。
          * 展开 **"信任" (Trust)** 部分。
          * 将 **"使用此证书时" (When using this certificate)** 设置为 **"始终信任" (Always Trust)**。
          * 关闭窗口，系统会提示你输入密码以保存更改。确保证书旁边显示绿色的勾 ✅。

5.  **运行打包脚本：**
    在终端中，回到你的工作目录 `~/OpenList_Packaging/`，然后执行打包脚本：

    ```bash
    ./make_release.sh
    ```

    或者，如果你想为发布指定一个特定的版本号（例如 `v1.2.3`）：

    ```bash
    ./make_release.sh v1.2.3
    ```

## 验证结果

脚本运行成功后，你会在 `~/OpenList_Packaging/` 目录下找到一个名为 `release` 的新文件夹。进入这个文件夹，你会看到：

  * `OpenList_vX.X.X.dmg`：你的应用程序安装包。双击它可以挂载 DMG，然后将 `OpenList.app` 拖到"应用程序"文件夹中。
  * `OpenList_vX.X.X.zip`：包含所有发布文件的压缩包。
  * `README.md`：详细的安装和使用说明。
  * `SHA256SUMS.txt`：用于验证文件完整性的校验码。
  * `release_qr.html`：一个简单的网页，用于分发下载链接（**请记得手动编辑此文件，将 `YOUR_DOWNLOAD_LINK_HERE` 替换为你的实际下载链接！**）。

现在，你的 OpenList macOS 应用程序已经准备好发布了！ 🎉