# Android 构建环境一键配置 (Windows PowerShell)
# 安装所有缺失的依赖: Rust targets, NDK, cmake, keystore
# 用法: .\setup-android.ps1

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  大武 Android 构建环境配置" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"

# === 1. Rust Android targets ===
Write-Host "[1/4] 安装 Rust Android targets..." -ForegroundColor Yellow
$targets = @(
    "aarch64-linux-android",
    "armv7-linux-androideabi", 
    "i686-linux-android",
    "x86_64-linux-android"
)
foreach ($t in $targets) {
    Write-Host "  安装 $t ..." -ForegroundColor Gray
    rustup target add $t
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] $t 安装失败" -ForegroundColor Yellow
    }
}
Write-Host "  Rust targets 完成" -ForegroundColor Green

# === 2. Android NDK ===
Write-Host "[2/4] 安装 Android NDK..." -ForegroundColor Yellow
$ndkVersion = "27.2.12479018"
$ndkPath = "$ANDROID_HOME\ndk\$ndkVersion"

if (Test-Path $ndkPath) {
    Write-Host "  NDK 已安装: $ndkPath" -ForegroundColor Green
} else {
    # 尝试通过 sdkmanager 安装
    $sdkmanager = "$ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat"
    if (Test-Path $sdkmanager) {
        Write-Host "  通过 sdkmanager 安装 NDK $ndkVersion ..." -ForegroundColor Gray
        & $sdkmanager "ndk;$ndkVersion"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  NDK 安装完成" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] sdkmanager 安装失败" -ForegroundColor Red
            Write-Host "  请手动安装: 打开 Android Studio -> SDK Manager -> SDK Tools -> NDK (Side by side)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [MISS] cmdline-tools 未安装，无法自动安装 NDK" -ForegroundColor Yellow
        Write-Host "  手动安装方式:" -ForegroundColor Yellow
        Write-Host "    1. 打开 Android Studio -> Settings -> Languages & Frameworks -> Android SDK" -ForegroundColor Gray
        Write-Host "    2. SDK Tools 标签 -> 勾选 'NDK (Side by side)' -> Apply" -ForegroundColor Gray
        Write-Host "    3. 或下载: https://developer.android.com/ndk/downloads" -ForegroundColor Gray
    }
}

# === 3. 生成签名密钥 ===
Write-Host "[3/4] 检查签名密钥..." -ForegroundColor Yellow
$keystorePath = "D:\workspace\user\dwx-space\dwx-mobile\src-tauri\gen\android\app\keystore.jks"
$keystoreDir = Split-Path $keystorePath -Parent

if (-not (Test-Path $keystoreDir)) {
    New-Item -ItemType Directory -Path $keystoreDir -Force | Out-Null
}

if (Test-Path $keystorePath) {
    Write-Host "  密钥已存在: $keystorePath" -ForegroundColor Green
} else {
    Write-Host "  生成新密钥..." -ForegroundColor Gray
    $keytool = "$env:JAVA_HOME\bin\keytool.exe"
    if (-not (Test-Path $keytool)) {
        # 尝试默认 Java
        $keytool = "keytool"
    }
    
    & $keytool -genkey -v `
        -keystore $keystorePath `
        -alias dwx-key `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -storepass zhu470192LX `
        -keypass zhu470192LX `
        -dname "CN=dwx, OU=dev, O=dwx, L=Shanghai, ST=Shanghai, C=CN" `
        2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  密钥生成成功: $keystorePath" -ForegroundColor Green
        Write-Host "  alias: dwx-key, 密码: zhu470192LX" -ForegroundColor Gray
    } else {
        Write-Host "  [FAIL] 密钥生成失败，请手动创建" -ForegroundColor Red
    }
}

# === 4. 验证 Java 17 ===
Write-Host "[4/4] 验证 Java 17..." -ForegroundColor Yellow
$JAVA_HOME = "D:\dev\jdks\jdk17"
if (Test-Path "$JAVA_HOME\bin\java.exe") {
    & "$JAVA_HOME\bin\java.exe" -version 2>&1 | Select-Object -First 1
    Write-Host "  Java 17 就绪" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Java 17 未找到: $JAVA_HOME" -ForegroundColor Red
    Write-Host "  请安装 Java 17+ 或修改 env-android.ps1 中的 JAVA_HOME" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  环境配置完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "下一步: .\build-android.ps1" -ForegroundColor Cyan
