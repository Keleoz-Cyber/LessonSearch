# 查课 App iOS 适配指南

> 本文档面向负责 iOS 适配的开发者，基于当前 Android 版本的代码进行适配。
> 仓库地址：https://github.com/Keleoz-Cyber/LessonSearch
> 当前版本：0.3.8

---

## 一、项目现状

### 已完成（跨平台，无需重写）

所有业务逻辑、UI 页面、数据层代码均使用 Dart/Flutter 编写，天然跨平台：

- 首页、选择页、点名页、记名页、确认页、文本生成页、查课记录页、设置页
- 登录页、注册页、扩展功能页
- Drift (SQLite) 本地数据库（9 张表）
- Dio 网络请求（已使用 HTTPS）
- Riverpod 状态管理
- go_router 路由
- SyncService 同步服务
- shared_preferences 本地存储
- 暗色模式（自动适配 iOS 外观）

### 需要做的 iOS 适配工作

| 项目 | 说明 | 难度 |
|------|------|------|
| 创建 iOS 平台目录 | 项目创建时只指定了 Android | 简单 |
| Xcode 工程配置 | Bundle ID、签名、权限 | 简单 |
| CocoaPods 依赖 | sqlite3_flutter_libs 等需要 pod install | 简单 |
| 网络权限 | 已使用 HTTPS，符合 iOS ATS 要求 | 无需改 |
| 真机测试 | 需要 Apple Developer 账号或免费签名 | 中等 |
| App Store 发布 | 需要付费开发者账号 | 后续 |

---

## 二、开发环境要求

- **macOS**（iOS 开发必须在 Mac 上）
- **Xcode 15+**（从 App Store 安装）
- **Flutter SDK 3.x**（建议 3.19+）
- **CocoaPods**（`sudo gem install cocoapods`）
- **Apple ID**（免费签名调试用）或 Apple Developer 账号（发布用）

### 验证环境

```bash
flutter doctor
```

确保以下项目打勾：
- [✓] Flutter
- [✓] Android toolchain（可选）
- [✓] Xcode
- [✓] CocoaPods

---

## 三、操作步骤

### 步骤 1：克隆仓库

```bash
git clone https://github.com/Keleoz-Cyber/LessonSearch.git
cd LessonSearch/app
```

### 步骤 2：创建 iOS 平台目录

项目创建时只指定了 Android，需要补充 iOS：

```bash
flutter create --platforms ios .
```

这会在 `app/` 下生成 `ios/` 目录，包含 Xcode 工程文件。

> 注意：这个命令不会覆盖已有的 Dart 代码，只会生成 iOS 平台文件。

### 步骤 3：安装依赖

```bash
flutter pub get
cd ios
pod install
cd ..
```

如果 `pod install` 报错，尝试：
```bash
cd ios
pod deintegrate
pod install --repo-update
cd ..
```

### 步骤 4：生成 Drift 代码

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 步骤 5：配置 Xcode 项目

用 Xcode 打开 iOS 工程：

```bash
open ios/Runner.xcworkspace
```

在 Xcode 中配置：

1. **选择 Runner target** → General
2. **Bundle Identifier**: 改为 `com.lessonsearch.lessonSearch`（或你自己的）
3. **Display Name**: `查课`（会显示在手机桌面）
4. **Deployment Target**: 建议 iOS 15.0+
5. **Signing & Capabilities**:
   - Team: 选择你的 Apple ID 或开发者账号
   - 勾选 Automatically manage signing

### 步骤 6：运行到模拟器

```bash
# 查看可用模拟器
flutter devices

# 运行到 iOS 模拟器
flutter run -d "iPhone 15"
```

或在 Xcode 中直接 Run（Cmd+R）。

### 步骤 7：运行到真机

1. 用 USB 线连接 iPhone 到 Mac
2. 在 iPhone 上信任此电脑
3. Xcode → Runner → Signing → 选择 Team
4. 首次运行需要在 iPhone 上：设置 → 通用 → VPN与设备管理 → 信任开发者

```bash
flutter run -d <你的设备ID>
```

---

## 四、可能遇到的问题及解决

### 4.1 CocoaPods 版本问题

```
[!] CocoaPods could not find compatible versions for pod "sqlite3_flutter_libs"
```

解决：
```bash
cd ios
pod repo update
pod install
```

### 4.2 最低 iOS 版本

如果报错 `The platform of the target 'Runner' is compatible with ...`：

编辑 `ios/Podfile`，确保最低版本：
```ruby
platform :ios, '15.0'
```

同时在 Xcode → Runner → General → Minimum Deployments 设为 15.0。

### 4.3 网络请求问题

项目已使用 HTTPS（`https://api.keleoz.cn/api`），符合 iOS App Transport Security (ATS) 要求，**无需额外配置**。

如果调试时需要访问 HTTP（如本地开发服务器），需要在 `ios/Runner/Info.plist` 中添加：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

> 注意：发布时不要允许任意 HTTP，只用 HTTPS。

### 4.4 sqlite3 编译问题

`sqlite3_flutter_libs` 在 iOS 上使用系统自带的 SQLite，通常不会有问题。如果遇到编译错误，确保：
- Xcode Command Line Tools 已安装：`xcode-select --install`
- CocoaPods 是最新版：`sudo gem install cocoapods`

### 4.5 签名问题

**免费签名限制：**
- App 在设备上 7 天后过期，需要重新安装
- 同时只能签名 3 个 App
- 不能使用推送通知等高级功能

**解决：** 使用付费 Apple Developer 账号（￥688/年）可以消除这些限制。

---

## 五、iOS 特有的适配点

### 5.1 状态栏和安全区域

代码中已经使用了 `SafeArea`，iPhone 的刘海屏/灵动岛应该已经适配。但需要在真机上验证：
- 刘海屏区域是否正常
- 底部 Home Indicator 区域是否被遮挡
- 横屏时是否正常（如果需要支持）

### 5.2 滚动行为

iOS 的滚动弹性效果（bouncing）和 Android 不同，Flutter 默认会根据平台自动适配。如果发现滚动体验异常，无需特殊处理。

### 5.3 返回手势

iOS 支持从屏幕左边缘向右滑动返回，go_router 默认支持。确认所有页面的返回行为正常。

### 5.4 键盘处理

iOS 键盘弹出时可能遮挡底部输入框。检查以下页面：
- 记名"其他"状态的文本输入弹窗
- 记录详情编辑"其他"状态弹窗

如果被遮挡，可以用 `SingleChildScrollView` 包裹弹窗内容。

### 5.5 字体

iOS 默认使用 San Francisco 字体，拼音中的声调符号（如 zhāng）需要验证是否正常显示。

---

## 六、打包发布

### 6.1 测试版（TestFlight）

```bash
flutter build ipa
```

产物在 `build/ios/ipa/` 目录下，使用 Xcode → Product → Archive 上传到 App Store Connect，然后通过 TestFlight 分发。

### 6.2 正式版

需要在 App Store Connect 中：
1. 创建 App
2. 填写应用信息、截图、描述
3. 提交审核

---

## 七、项目架构概览（快速了解代码）

```
app/lib/
├── main.dart                    # 入口
├── app.dart                     # MaterialApp + 主题 + 暗色模式
├── core/
│   ├── database/tables.dart     # 9 张本地表定义
│   ├── network/api_client.dart  # 所有 API 调用（含 token）
│   ├── sync/sync_service.dart   # 后台同步
│   ├── resume/                  # 中断恢复
│   └── announcement/            # 公告系统
├── features/
│   ├── home/                    # 首页
│   ├── attendance/              # 点名+记名核心逻辑
│   │   ├── domain/models.dart   # 枚举和领域模型
│   │   ├── data/                # Repository + DataSource
│   │   ├── application/         # Notifier (状态管理)
│   │   └── presentation/        # 页面 UI
│   ├── student/                 # 学生数据
│   ├── records/                 # 查课记录
│   ├── auth/                    # 用户认证（登录、token）
│   ├── extension/               # 扩展功能
│   └── settings/                # 设置页 + 主题切换
└── shared/
    ├── providers.dart           # 全局 Provider
    └── widgets/                 # 通用组件
```

**关键文件：**
- API 地址：`core/network/api_client.dart` → `defaultBaseUrl`
- 数据库表：`core/database/tables.dart`
- 公告内容：`core/announcement/announcement_config.dart`
- 文本模板：`features/attendance/domain/text_template.dart`
- 认证服务：`features/auth/data/auth_service.dart`

---

## 八、联系方式

- 仓库：https://github.com/Keleoz-Cyber/LessonSearch
- 开发文档：`docs/dev-guide.md`
- 任务表：`docs/tasks.md`
- 邀请码管理：`docs/invitation-codes.md`
- 服务端 API 文档：https://api.keleoz.cn/docs

有问题直接在仓库提 Issue 或联系项目负责人。
