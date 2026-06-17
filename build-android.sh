#!/bin/bash
# 构建大武侠 Android APK (已集成签名)
# 用法:
#   ./build-android.sh          # 默认 arm64-only (~6MB)
#   ./build-android.sh full     # 全架构包 (~33MB)
set -euo pipefail

# 解析参数
BUILD_MODE="${1:-arm}"
if [ "$BUILD_MODE" = "full" ] || [ "$BUILD_MODE" = "--full" ] || [ "$BUILD_MODE" = "universal" ]; then
    TARGET_ARG=""
    MODE_LABEL="全架构"
else
    TARGET_ARG="--target aarch64"
    MODE_LABEL="arm64-only"
fi

# 加载环境配置（含缓存重定向）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/env-android.sh"

echo "=== 1. 构建前端 ==="
cd /mnt/data/dwx-server/frontend
pnpm build 2>&1 | tail -5

echo "=== 2. 构建 Android APK（${MODE_LABEL}） ==="
cd /mnt/data/dwx-mobile-android

if [ -n "$TARGET_ARG" ]; then
    pnpm tauri android build ${TARGET_ARG} 2>&1
else
    # 全架构：临时设 targets=all
    pnpm tauri android build 2>&1
fi

APK_SRC="/mnt/data/dwx-mobile-android/src-tauri/gen/android/app/build/outputs/apk/universal/release/app-universal-release.apk"
APK_DST="/mnt/data/dwx-mobile-android/target/dwx.apk"

echo "=== 3. 复制已签名 APK ==="
mkdir -p /mnt/data/dwx-mobile-android/target
cp "$APK_SRC" "$APK_DST"

echo "=== 4. 验证签名 ==="
$ANDROID_HOME/build-tools/35.0.0/apksigner verify --print-certs "$APK_DST" 2>&1 | head -3

echo ""
echo "✅ 构建完成（${MODE_LABEL}）: $APK_DST"
ls -lh "$APK_DST"
