#!/usr/bin/env bash
#
# Android 设备/模拟器一键截图脚本
#
# 用法：
#   ./scripts/screenshot.sh                   # 默认文件名 screenshot_时间戳.png
#   ./scripts/screenshot.sh music_glass_tab   # 自定义文件名（不带扩展名）
#   ./scripts/screenshot.sh -l                # 列出当前在线设备
#   ./scripts/screenshot.sh -d emulator-5554 my_shot  # 指定设备截图
#
# 截图保存到项目根目录的 screenshots/ 目录（已在 .gitignore 中忽略）
# 依赖：adb（Android SDK platform-tools 自带）

set -euo pipefail

# 解析项目根目录（脚本可能在 worktree 或主仓库）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$PROJECT_ROOT/screenshots"
mkdir -p "$OUT_DIR"

# ─────────── 参数解析 ───────────
DEVICE_FLAG=""
LIST_ONLY=false
CUSTOM_NAME=""

print_usage() {
  cat <<EOF
用法:
  scripts/screenshot.sh [选项] [文件名]

选项:
  -d <serial>   指定 adb 设备 serial（多设备时用）
  -l, --list    列出当前在线设备后退出
  -h, --help    显示帮助

示例:
  scripts/screenshot.sh                       # 保存为 screenshot_YYYYMMDD_HHMMSS.png
  scripts/screenshot.sh music_glass_tab       # 保存为 music_glass_tab_YYYYMMDD_HHMMSS.png
  scripts/screenshot.sh -d emulator-5554 x    # 指定设备截名为 x_时间戳.png
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device)
      DEVICE_FLAG="$2"
      shift 2
      ;;
    -l|--list)
      LIST_ONLY=true
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    -*)
      echo "未知选项: $1"
      print_usage
      exit 1
      ;;
    *)
      CUSTOM_NAME="$1"
      shift
      ;;
  esac
done

# ─────────── adb 命令构造 ───────────
ADB="adb"
if [[ -n "$DEVICE_FLAG" ]]; then
  ADB="adb -s $DEVICE_FLAG"
fi

# 检查 adb 是否可用
if ! command -v adb &>/dev/null; then
  echo "❌ 未找到 adb，请确认 Android SDK platform-tools 已安装并加入 PATH"
  echo "   常见路径："
  echo "   - Windows: C:\\Users\\<user>\\AppData\\Local\\Android\\Sdk\\platform-tools"
  echo "   - macOS:   ~/Library/Android/sdk/platform-tools"
  exit 1
fi

# ─────────── 列出设备 ───────────
if $LIST_ONLY; then
  echo "📱 当前在线设备："
  $ADB devices -l
  exit 0
fi

# 检查设备是否在线
DEVICES_OUTPUT="$($ADB devices | tail -n +2 | grep -v '^$' || true)"
if [[ -z "$DEVICES_OUTPUT" ]]; then
  echo "❌ 没有在线的 Android 设备/模拟器"
  echo ""
  echo "排查："
  echo "  1. 模拟器是否启动？  flutter emulators --launch <id>"
  echo "  2. 真机是否开启 USB 调试并已授权？"
  echo "  3. adb 是否识别到？  $ADB devices"
  exit 1
fi

# ─────────── 文件名构造 ───────────
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
if [[ -n "$CUSTOM_NAME" ]]; then
  FILENAME="${CUSTOM_NAME}_${TIMESTAMP}.png"
else
  FILENAME="screenshot_${TIMESTAMP}.png"
fi
OUT_PATH="$OUT_DIR/$FILENAME"

# ─────────── 截图 ───────────
echo "📸 正在截图..."
# 注意：必须用 exec-out 而不是 shell，否则 LF/CRLF 换行会污染 PNG 二进制流
$ADB exec-out screencap -p > "$OUT_PATH"

# 验证文件
if [[ ! -s "$OUT_PATH" ]]; then
  echo "❌ 截图失败：输出文件为空"
  exit 1
fi

# 验证 PNG 头（前 8 字节应为 \x89PNG\r\n\x1a\n）
FILE_SIZE="$(wc -c < "$OUT_PATH" | tr -d ' ')"
echo "✅ 截图已保存：$OUT_PATH"
echo "   文件大小：${FILE_SIZE} bytes"
echo ""
echo "💡 提示：screenshots/ 已在 .gitignore 中忽略，不会污染仓库"
