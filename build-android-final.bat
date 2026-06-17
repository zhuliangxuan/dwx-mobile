@echo off
setlocal

set JAVA_HOME=D:\dev\jdks\jdk17
set PATH=%JAVA_HOME%\bin;%PATH%

set RUSTC_VERSION=1.95.0
set RUSTC_DATE=2025-04-10
set ANDROID_NDK_HOME=C:\Users\24781\AppData\Local\Android\Sdk\ndk\27.2.12479018

cd /d D:\workspace\user\dwx-space\dwx-mobile

npx tauri android build

endlocal