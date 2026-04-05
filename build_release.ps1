# 构建并重命名 APK

cd app

# 从 pubspec.yaml 获取版本号
$version = (Select-String -Path pubspec.yaml -Pattern "^version:" | ForEach-Object { $_.Line }) -replace "version: ", "" -replace "\+.*", ""

Write-Host "构建版本: $version"

# 构建 APK
flutter build apk --release

# 重命名 APK
$source = "build\app\outputs\flutter-apk\app-release.apk"
$dest = "build\app\outputs\flutter-apk\kaoqin-helper-v$version.apk"

Copy-Item $source $dest -Force

Write-Host "APK 已生成: $dest"
Get-Item $dest