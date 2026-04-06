# 清理 Flutter 构建产物

Write-Host "清理 Flutter 构建产物..."

cd app

# 清理 Flutter 缓存
flutter clean

Write-Host "清理完成！"
Write-Host "下次构建请运行: flutter build apk --release"