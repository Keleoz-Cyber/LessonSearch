# 构建并重命名 APK

cd app

# 从 pubspec.yaml 获取版本号
$version = (Select-String -Path pubspec.yaml -Pattern "^version:" | ForEach-Object { $_.Line }) -replace "version: ", "" -replace "\+.*", ""

Write-Host "构建版本: $version"

# 构建 APK
flutter build apk --release

# 重命名 APK（英文文件名，GitHub 不支持中文）
$source = "build\app\outputs\flutter-apk\app-release.apk"
$dest = "build\app\outputs\flutter-apk\kaoqin-helper-v$version.apk"

Copy-Item $source $dest -Force

Write-Host "APK 已生成: $dest"
Write-Host "建议下载后重命名为: 考勤助手v$version.apk"
Get-Item $dest