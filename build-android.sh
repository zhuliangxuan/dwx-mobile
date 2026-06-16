#!/bin/bash
# 构建大武侠 Android APK (已集成签名)
# 用法: ./build-android.sh
set -euo pipefail

# 加载环境配置（含缓存重定向）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/env-android.sh"

echo "=== 1. 构建前端 ==="
cd /mnt/data/dwx-server/frontend
pnpm build 2>&1 | tail -5

echo "=== 2. 构建 Android APK ==="
cd /mnt/data/dwx-mobile-android
pnpm tauri android build --target aarch64 2>&1

APK_SRC="/mnt/data/dwx-mobile-android/src-tauri/gen/android/app/build/outputs/apk/universal/release/app-universal-release.apk"
APK_DST="/mnt/data/dwx-mobile-android/target/dwx.apk"

echo "=== 3. 复制已签名 APK ==="
mkdir -p /mnt/data/dwx-mobile-android/target
cp "$APK_SRC" "$APK_DST"

echo "=== 4. 验证签名 ==="
$ANDROID_HOME/build-tools/35.0.0/apksigner verify --print-certs "$APK_DST" 2>&1 | head -3

echo ""
echo "✅ 构建完成: $APK_DST"
ls -lh "$APK_DST"
