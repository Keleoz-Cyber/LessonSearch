#!/bin/bash
# 构建并重命名 APK

cd app

# 从 pubspec.yaml 获取版本号
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)

echo "构建版本: $VERSION"

# 构建 APK
flutter build apk --release

# 重命名 APK
cp build/app/outputs/flutter-apk/app-release.apk "build/app/outputs/flutter-apk/kaoqin-helper-v${VERSION}.apk"

echo "APK 已生成: build/app/outputs/flutter-apk/kaoqin-helper-v${VERSION}.apk"
ls -la "build/app/outputs/flutter-apk/kaoqin-helper-v${VERSION}.apk"