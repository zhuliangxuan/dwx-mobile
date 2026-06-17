@echo off
chcp 65001 >nul
cd /d D:\workspace\user\dwx-space\dwx-mobile
powershell -ExecutionPolicy Bypass -Command ". .\env-android.ps1; $env:ANDROID_NDK_HOME = $env:NDK_HOME; $env:ANDROID_NDK_ROOT = $env:NDK_HOME; pnpm tauri android build --target aarch64 --debug"
echo Build completed with exit code: %errorlevel%
pause