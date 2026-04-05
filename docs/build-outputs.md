# Flutter 构建输出目录说明

`app/build/app/outputs/` 目录结构：

```
outputs/
├── flutter-apk/              # Flutter APK 输出（主要）
│   └── app-release.apk       # Release APK（57MB）
│
├── logs/                     # 构建日志
│   ├── manifest-merger-debug-report.txt
│   └── manifest-merger-release-report.txt
│
├── mapping/                  # 代码混淆映射（用于 Crash 分析）
│   └── release/
│       └── mapping.txt
│
├── native-debug-symbols/     # 原生调试符号
│   └── release/
│
└── sdk-dependencies/         # SDK 依赖信息
```

## 目录用途

| 目录 | 说明 | 是否需要提交 |
|------|------|-------------|
| `flutter-apk/` | Flutter 构建的 APK | ❌ 已在 .gitignore |
| `logs/` | 构建日志，用于排查问题 | ❌ 已在 .gitignore |
| `mapping/` | 代码混淆映射，用于反混淆 Crash 日志 | ❌ 已在 .gitignore |
| `native-debug-symbols/` | 原生代码调试符号 | ❌ 已在 .gitignore |
| `sdk-dependencies/` | SDK 依赖信息 | ❌ 已在 .gitignore |

## 清理构建产物

运行 `flutter clean` 会清空整个 `build/` 目录。

或者使用项目根目录的清理脚本：
```powershell
.\clean_build.ps1
```

## 发布 APK

使用构建脚本自动重命名并复制：
```powershell
.\build_release.ps1
```

APK 会在 `app/build/app/outputs/flutter-apk/` 目录下生成重命名后的文件：
`kaoqin-helper-vX.X.X.apk`