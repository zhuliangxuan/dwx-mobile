# Android 构建环境配置 (Windows PowerShell)
# 用法: . .\env-android.ps1

$ErrorActionPreference = "Stop"

# === 路径配置 ===
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# 项目路径
$env:DWX_ROOT = "D:\workspace\user\dwx-space"
$env:DWX_FRONTEND = "$env:DWX_ROOT\dwx\frontend"
$env:DWX_MOBILE = "$env:DWX_ROOT\dwx-mobile"

# Java 17+ (Android Gradle Plugin 需要 Java 17+)
$env:JAVA_HOME = "D:\dev\jdks\jdk17"

# Android SDK (使用用户提供的路径)
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:NDK_HOME = "D:\dev\android-ndk-r27d"

# 添加工具到 PATH (使用用户提供的 cmdline-tools)
$env:PATH = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;D:\dev\cmdline-tools\latest\bin;$env:PATH"

# Gradle 缓存重定向（避免占用系统盘）
$env:GRADLE_USER_HOME = "$env:DWX_ROOT\.gradle"
if (-not (Test-Path $env:GRADLE_USER_HOME)) {
    New-Item -ItemType Directory -Path $env:GRADLE_USER_HOME -Force | Out-Null
}

# === 输出当前配置 ===
Write-Host "=== Android 构建环境 ===" -ForegroundColor Cyan
Write-Host "DWX_ROOT     = $env:DWX_ROOT"
Write-Host "DWX_FRONTEND = $env:DWX_FRONTEND"
Write-Host "DWX_MOBILE   = $env:DWX_MOBILE"
Write-Host ""
Write-Host "JAVA_HOME    = $env:JAVA_HOME"
& java -version 2>&1 | Select-Object -First 1
Write-Host "ANDROID_HOME = $env:ANDROID_HOME"
Write-Host "NDK_HOME     = $env:NDK_HOME"
Write-Host "GRADLE_USER_HOME = $env:GRADLE_USER_HOME"

# === 检查关键组件 ===
Write-Host ""
Write-Host "--- 组件检查 ---" -ForegroundColor Cyan

$ok = $true

# Java 版本检查
$javaVer = & java -version 2>&1 | Select-String "version"
if ($javaVer -match '"17\.|"18\.|"19\.|"20\.|"21\.|"22\.|"23\.') {
    Write-Host "[OK] Java 17+" -ForegroundColor Green
} else {
    Write-Host "[FAIL] 需要 Java 17+, 当前: $javaVer" -ForegroundColor Red
    $ok = $false
}

# Android SDK 组件
$checks = @{
    "build-tools 36.1.0" = "$env:ANDROID_HOME\build-tools\36.1.0"
    "platform android-36" = "$env:ANDROID_HOME\platforms\android-36.1"
    "NDK r27d" = $env:NDK_HOME
}

foreach ($item in $checks.GetEnumerator()) {
    if (Test-Path $item.Value) {
        Write-Host "[OK] $($item.Key)" -ForegroundColor Green
    } else {
        Write-Host "[MISS] $($item.Key) -> $($item.Value)" -ForegroundColor Yellow
    }
}

# Rust Android targets
Write-Host ""
Write-Host "Rust targets:" -ForegroundColor Cyan
$targets = rustup target list --installed 2>&1
$androidTargets = @("aarch64-linux-android", "armv7-linux-androideabi", "i686-linux-android", "x86_64-linux-android")
foreach ($t in $androidTargets) {
    if ($targets -match $t) {
        Write-Host "  [OK] $t" -ForegroundColor Green
    } else {
        Write-Host "  [MISS] $t (运行 'rustup target add $t' 安装)" -ForegroundColor Yellow
    }
}

Write-Host ""
if ($ok) {
    Write-Host "环境就绪" -ForegroundColor Green
} else {
    Write-Host "存在关键缺失，请先修复后再构建" -ForegroundColor Red
}
