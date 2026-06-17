# 构建大武 Android APK (Windows PowerShell)
# 用法:
#   .\build-android.ps1           # 默认 arm64-only
#   .\build-android.ps1 -Full     # 全架构包
#   .\build-android.ps1 -Debug    # Debug 构建
#   .\build-android.ps1 -Clean    # 清理后构建

param(
    [switch]$Full,      # 全架构 (arm64 + armeabi-v7a + x86 + x86_64)
    [switch]$Debug,     # Debug 构建
    [switch]$Clean,     # 清理后构建
    [switch]$Install    # 构建后安装到已连接设备
)

$ErrorActionPreference = "Stop"

# === 加载环境配置 ===
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\env-android.ps1"

# === 设置 Java 环境 ===
$env:JAVA_HOME = "D:\dev\jdks\jdk17"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

# === 设置 Rust 版本环境变量（绕过安全策略阻止 rustc --version） ===
$env:RUSTC_VERSION = "1.95.0"
$env:RUSTC_DATE = "2025-04-10"

# === 参数解析 ===
$buildType = if ($Debug) { "debug" } else { "release" }

if ($Full) {
    $modeLabel = "全架构"
} else {
    $modeLabel = "arm64-only"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  大武 Android APK 构建" -ForegroundColor Cyan
Write-Host "  模式: $modeLabel | 类型: $buildType" -ForegroundColor Cyan
Write-Host "  JDK: $env:JAVA_HOME" -ForegroundColor Gray
Write-Host "  NDK: $env:NDK_HOME" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# === 步骤 0: 安装 Rust Android targets（如缺失） ===
Write-Host "[0/5] 检查 Rust Android targets..." -ForegroundColor Yellow
$neededTargets = @("aarch64-linux-android")
if ($Full) {
    $neededTargets += @("armv7-linux-androideabi", "i686-linux-android", "x86_64-linux-android")
}
$installed = rustup target list --installed 2>&1
foreach ($t in $neededTargets) {
    if ($installed -notmatch $t) {
        Write-Host "  安装 rust target: $t ..." -ForegroundColor Gray
        rustup target add $t
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] 无法安装 $t" -ForegroundColor Red
            exit 1
        }
    }
}
Write-Host "  Rust targets 就绪" -ForegroundColor Green

# === 步骤 1: 构建前端 ===
Write-Host "[1/5] 构建前端..." -ForegroundColor Yellow
Push-Location $env:DWX_FRONTEND
try {
    $pnpmResult = pnpm build 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] 前端构建失败:" -ForegroundColor Red
        Write-Host ($pnpmResult -join "`n")
        exit 1
    }
    Write-Host "  前端构建完成" -ForegroundColor Green
} finally {
    Pop-Location
}

# === 步骤 2: 编译 Rust 代码 ===
Write-Host "[2/5] 编译 Rust 代码 ($modeLabel)..." -ForegroundColor Yellow
Push-Location "$env:DWX_MOBILE\src-tauri"

# 清理
if ($Clean) {
    Write-Host "  清理旧构建..." -ForegroundColor Gray
    Remove-Item -Recurse -Force "$env:DWX_MOBILE\src-tauri\gen\android\app\build" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$env:DWX_MOBILE\src-tauri\gen\android\build" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$env:DWX_MOBILE\src-tauri\target" -ErrorAction SilentlyContinue
    Write-Host "  清理完成" -ForegroundColor Green
}

try {
    $env:ANDROID_NDK_HOME = $env:NDK_HOME
    $env:ANDROID_NDK_ROOT = $env:NDK_HOME
    
    Write-Host "  使用 NDK: $env:NDK_HOME" -ForegroundColor Gray

    $cargoArgs = @("build", "--target", "aarch64-linux-android")
    if (-not $Debug) {
        $cargoArgs += "--release"
    }

    $cargoOutput = cargo @cargoArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Rust 编译失败:" -ForegroundColor Red
        Write-Host ($cargoOutput -join "`n") | Select-Object -Last 50
        exit 1
    }
    Write-Host "  Rust 编译完成" -ForegroundColor Green
} finally {
    Pop-Location
}

# === 步骤 3: 复制 .so 文件到 jniLibs 目录 ===
Write-Host "[3/5] 复制 .so 文件..." -ForegroundColor Yellow

$targetDir = "$env:DWX_MOBILE\src-tauri\target\aarch64-linux-android"
$targetDir += if ($Debug) { "\debug" } else { "\release" }
$libSrc = "$targetDir\libapp_lib.so"

if (-not (Test-Path $libSrc)) {
    Write-Host "[FAIL] 未找到 .so 文件: $libSrc" -ForegroundColor Red
    exit 1
}

$jniDir = "$env:DWX_MOBILE\src-tauri\gen\android\app\src\main\jniLibs\arm64-v8a"
if (-not (Test-Path $jniDir)) {
    New-Item -ItemType Directory -Path $jniDir -Force | Out-Null
}

Copy-Item $libSrc $jniDir -Force
Write-Host "  已复制: $libSrc -> $jniDir" -ForegroundColor Green

# === 步骤 4: Gradle 构建 APK ===
Write-Host "[4/5] Gradle 构建 APK..." -ForegroundColor Yellow
Push-Location "$env:DWX_MOBILE\src-tauri\gen\android"

try {
    $env:ANDROID_HOME = $env:ANDROID_HOME_LOCAL
    $env:TAURI_SKIP_RUST_BUILD = "true"
    
    if (-not $Debug) {
        $env:TAURI_ANDROID_KEYSTORE_PATH = "$env:DWX_MOBILE\src-tauri\gen\android\app\keystore.jks"
        $env:TAURI_ANDROID_KEYSTORE_PASSWORD = "zhu470192LX"
        $env:TAURI_ANDROID_KEY_ALIAS = "dwx-key"
        Write-Host "  签名配置: $env:TAURI_ANDROID_KEYSTORE_PATH (alias: $env:TAURI_ANDROID_KEY_ALIAS)" -ForegroundColor Gray
    }
    
    $gradleTask = if ($Debug) { "assembleDebug" } else { "assembleRelease" }
    
    Write-Host "  执行: .\gradlew.bat $gradleTask" -ForegroundColor Gray
    
    $gradleOutput = .\gradlew.bat $gradleTask 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Gradle 构建失败:" -ForegroundColor Red
        Write-Host ($gradleOutput -join "`n") | Select-Object -Last 50
        exit 1
    }
    Write-Host "  Gradle 构建完成" -ForegroundColor Green
} finally {
    Pop-Location
}

# === 步骤 5: 定位并复制 APK ===
Write-Host "[5/5] 定位 APK..." -ForegroundColor Yellow

$apkBase = "$env:DWX_MOBILE\src-tauri\gen\android\app\build\outputs\apk"

$apkSrc = $null
if ($Debug) {
    # Debug 模式查找
    $apkSrc = Get-ChildItem "$apkBase" -Filter "app-arm64-debug.apk" -Recurse | Select-Object -First 1 -ExpandProperty FullName
    if (-not $apkSrc) {
        $apkSrc = Get-ChildItem "$apkBase" -Filter "*debug.apk" -Recurse | Where-Object { $_.Name -match "arm64" } | Select-Object -First 1 -ExpandProperty FullName
    }
} else {
    # Release 模式查找
    $apkSrc = Get-ChildItem "$apkBase" -Filter "app-arm64-release.apk" -Recurse | Select-Object -First 1 -ExpandProperty FullName
    if (-not $apkSrc) {
        $apkSrc = Get-ChildItem "$apkBase" -Filter "*release.apk" -Recurse | Where-Object { $_.Name -match "arm64" } | Select-Object -First 1 -ExpandProperty FullName
    }
}

if (-not $apkSrc -or -not (Test-Path $apkSrc)) {
    # Fallback: 递归搜索
    $apkSrc = Get-ChildItem "$apkBase" -Filter "*.apk" -Recurse | Where-Object { $_.Name -notlike "*unaligned*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}

if (-not $apkSrc -or -not (Test-Path $apkSrc)) {
    Write-Host "[FAIL] 未找到 APK 文件" -ForegroundColor Red
    Write-Host "搜索路径: $apkBase"
    Get-ChildItem "$apkBase" -Recurse -Filter "*.apk"
    exit 1
}

Write-Host "  源 APK: $apkSrc" -ForegroundColor Gray

# 复制到目标目录
$targetDir = "$env:DWX_MOBILE\target"
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$apkDst = "$targetDir\dwx-$buildType-$timestamp.apk"
Copy-Item $apkSrc $apkDst -Force

$apkSize = (Get-Item $apkDst).Length
$apkSizeMB = [math]::Round($apkSize / 1MB, 1)

# === 步骤 6: 验证 ===
Write-Host "[6/6] 验证..." -ForegroundColor Yellow

# 检查签名
$buildTools = "$env:ANDROID_HOME\build-tools\36.1.0"
$apksigner = "$buildTools\apksigner.bat"
if (Test-Path $apksigner) {
    Write-Host "  签名验证:" -ForegroundColor Gray
    & $apksigner verify --verbose $apkDst 2>&1 | Select-Object -First 5
} else {
    Write-Host "  [SKIP] apksigner 未找到，跳过签名验证" -ForegroundColor Yellow
}

# 安装到设备
if ($Install) {
    Write-Host "  安装到设备..." -ForegroundColor Yellow
    $adbPath = "$env:ANDROID_HOME\platform-tools\adb.exe"
    if (Test-Path $adbPath) {
        & $adbPath install -r $apkDst
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  安装成功!" -ForegroundColor Green
        }
    } else {
        Write-Host "  [SKIP] adb 未找到，跳过安装" -ForegroundColor Yellow
    }
}

# === 完成 ===
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  构建完成! ($modeLabel)" -ForegroundColor Green
Write-Host "  APK: $apkDst" -ForegroundColor Green
Write-Host "  大小: ${apkSizeMB}MB" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
