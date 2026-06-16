#!/bin/bash
# Android 构建环境配置
# 每次构建前 source 此文件

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH=$PATH:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# 重定向构建缓存到 /mnt/data，避免占系统盘
export GRADLE_USER_HOME=/mnt/data/.gradle
export CARGO_HOME=/mnt/data/.cargo

echo "JAVA_HOME=$JAVA_HOME"
echo "ANDROID_HOME=$ANDROID_HOME"
echo "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
echo "SDK manager: $(which sdkmanager 2>/dev/null)"
echo "Java: $(java -version 2>&1 | head -1)"
echo "ADB: $(which adb 2>/dev/null)"
echo "Cargo targets:"
rustup target list --installed 2>/dev/null | grep android || echo "  (using manually installed targets)"
