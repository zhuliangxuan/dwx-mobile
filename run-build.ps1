cd D:\workspace\user\dwx-space\dwx-mobile
. .\env-android.ps1
$env:ANDROID_NDK_HOME = $env:NDK_HOME
$env:ANDROID_NDK_ROOT = $env:NDK_HOME
pnpm tauri android build --target aarch64 --debug 2>&1 | Tee-Object -FilePath D:\workspace\user\dwx-space\dwx-mobile\build-log.txt
