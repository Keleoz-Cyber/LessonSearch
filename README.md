# 考勤助手

<div align="center">

![Logo](app/assets/icon.png)

**面向学校查课场景的 Flutter + FastAPI 全栈应用**

[![Version](https://img.shields.io/badge/version-v0.6.0-blue)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android-lightgrey)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.43-02569B?logo=flutter)]()
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110-009688?logo=fastapi)]()

**已在高校查课工作中正式投入使用**

点名 · 记名 · 名单提交 · 管理员审核 · 周汇总 · Excel 导出

</div>

---

## 为什么需要这个项目？

在高校查课工作中，通常需要两人配合：一人点名，一人用**纸质名单或 Excel** 记录。传统方式存在以下问题：

- ❌ **手动统计**：每次查课后需要人工汇总迟到、缺勤、请假数据
- ❌ **容易出错**：纸质记录字迹潦草、Excel 手动输入容易遗漏
- ❌ **难以追溯**：谁提交的、谁审核的、拒绝原因是什么，没有记录
- ❌ **数据分散**：名单在微信群、统计在 Excel、审核在口头，无法集中管理
- ❌ **弱网/断网**：如果用普通 App，教室网络不稳定时无法使用

**考勤助手** 通过本地优先架构 + SyncQueue 同步队列，完美解决了这些问题：

| 传统方式 | 考勤助手 |
|----------|----------|
| 纸质名单/Excel 手动记录 | App 逐人标记，自动统计 |
| 手动汇总迟到/缺勤/请假 | 一键生成汇报文本 |
| 名单在微信群，统计在 Excel | 数据集中管理，全程可追溯 |
| 审核靠口头，无记录 | 提交→审核→拒绝原因，全程留痕 |
| 教室断网 = 无法使用 | 本地优先，断网正常使用 |

---

## 功能展示

### 现场查课

| 首页 | 记名页面 | 名单提交 |
|:----:|:--------:|:--------:|
| ![首页](docs/screenshots/首页.png) | ![记名](docs/screenshots/记名.png) | ![提交](docs/screenshots/名单提交.png) |
| 功能入口，一目了然 | 逐人标记考勤状态 | 选择任务提交审核 |

### 审核与汇总

| 管理员审核 | 周汇总 | 同步问题详情 |
|:----------:|:------:|:------------:|
| ![审核](docs/screenshots/管理员审核.png) | ![汇总](docs/screenshots/周汇总.png) | ![同步](docs/screenshots/同步问题详情.png) |
| 通过/拒绝，全程可追溯 | 按周次汇总统计 | 查看待同步/失败记录 |

---

## 业务流程

```mermaid
flowchart LR
    A[现场记名] --> B[修改记录]
    B --> C[生成汇报]
    C --> D[名单提交]
    D --> E[管理员审核]
    E -->|通过| F[周汇总 / Excel导出]
    E -->|拒绝| B
```

**详细流程：**

1. **现场记名** → 选择年级、专业、班级，逐人标记考勤状态
2. **修改记录** → 在查课记录中反复修改，直到确认无误
3. **生成汇报** → 自动生成文本，发送给学委确认 / 发送到总群
4. **名单提交** → 选择本周已完成的记名任务，提交管理员审核
5. **管理员审核** → 查看异常名单，通过或拒绝（填写原因）
6. **周汇总 / Excel 导出** → 审核通过后，生成周汇总并导出 Excel

---

## 技术架构

```mermaid
graph TB
    subgraph "Flutter 客户端"
        A[UI 层] --> B[Notifier]
        B --> C[Repository]
        C --> D[LocalDS<br>Drift SQLite]
        C --> E[RemoteDS<br>Dio]
        D --> F[SyncQueue]
    end
    
    subgraph "FastAPI 服务端"
        E -->|HTTPS| G[API Gateway]
        G --> H[Auth<br>JWT]
        G --> I[Business Logic]
        I --> J[MySQL 8]
    end
    
    F -->|10s 轮询| E
```

**技术栈：**

| 端 | 技术 | 用途 |
|----|------|------|
| 客户端 | Flutter 3.43 | 跨平台 UI 框架 |
| 状态管理 | Riverpod 2.6 | 响应式状态管理 |
| 本地数据库 | Drift 2.28 | SQLite ORM |
| 网络请求 | Dio | HTTP 客户端 |
| 服务端 | FastAPI | Python Web 框架 |
| 数据库 | MySQL 8 | 主数据库 |
| 认证 | PyJWT + bcrypt | JWT 认证 + 密码哈希 |

---

## 项目亮点

### 1. 本地优先，弱网可用

| 传统方式 | 本项目 |
|----------|--------|
| 网络断开 = 无法使用 | 网络断开 = 正常使用 |
| 数据丢失风险 | 数据安全保留 |
| 手动重试 | 自动补齐同步 |

**实现方式：** 所有操作先写本地 Drift 数据库，再异步同步到服务端。

### 2. SyncQueue 同步队列

```mermaid
stateDiagram-v2
    [*] --> pending: 修改入队
    pending --> syncing: 10s 轮询
    syncing --> synced: 成功
    syncing --> failed: 失败
    failed --> pending: 自动重试
    failed --> abandoned: 超过 5 次
```

**特性：**
- 每次修改自动入队（`pending` 状态）
- SyncService 每 10 秒消费队列，批量提交（2~50 条合并为一次请求）
- 失败自动分类：网络错误重试、401 认证过期保留数据、其他错误最多重试 5 次

### 3. 提交前强制同步

**问题：** 用户修改了记录，但提交时服务端还是旧数据

**解决方案：** 名单提交前必须完成同步，如果有失败项会阻止提交并提示具体原因

```dart
// submission_page.dart
final result = await syncService.syncNow();
if (result.failed > 0) {
  Toast.show(context, '同步失败 ${result.failed} 项，请检查网络后重试');
  return; // 阻止提交
}
```

### 4. Token 过期保护

**传统方式：** Token 过期 → 清空所有数据 → 重新登录 → 数据丢失

**本项目：** Token 过期 → 只清除 token → 保留本地数据 → 重新登录 → 继续同步

```dart
// api_client.dart
if (statusCode == 401) {
  _token = null;
  onAuthExpired?.call(); // 只清除 token，不清数据
}
```

### 5. 记录锁定与权限

**状态流转：**
- `pending` → `approved`：记录锁定，禁止修改
- `pending` → `rejected`：记录解锁，可以修改后重新提交
- 任何状态 → `abandoned`：任务放弃，保留数据但不再参与提交

**实现：** 服务端检查记录是否已关联 pending/approved submission，已提交则返回 403

### 6. 异常状态完整追溯

**追溯链：**
- 谁提交的？ → `submission.user_id`
- 谁审核的？ → `submission.reviewer_id`
- 什么时候？ → `submission.review_time`
- 拒绝原因？ → `submission.review_note`
- 历史记录？ → `my_submissions_provider`

---

## 快速开始

### 前端

```bash
# 克隆仓库
git clone https://github.com/Keleoz-Cyber/LessonSearch.git
cd LessonSearch/app

# 安装依赖
flutter pub get

# 生成图标
flutter pub run flutter_launcher_icons:main

# 运行
flutter run
```

### 后端

```bash
cd server

# 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt

# 配置环境变量
cp .env.example .env
# 编辑 .env 填入数据库密码、JWT 密钥、SMTP 配置

# 启动开发服务器
uvicorn main:app --reload --port 8000
```

### 数据库迁移

```bash
# 添加 password_hash 字段（如未执行）
cd server
python migrations/add_password_hash.py
```

---

## 目录结构

```
├── app/                          # Flutter 前端
│   ├── lib/
│   │   ├── core/                 # 核心模块
│   │   │   ├── database/         # Drift 表定义
│   │   │   ├── network/          # Dio 封装
│   │   │   ├── sync/             # SyncService
│   │   │   └── router/           # go_router 路由
│   │   ├── features/             # 功能模块
│   │   │   ├── attendance/       # 点名、记名
│   │   │   ├── auth/             # 登录、实名
│   │   │   ├── extension/        # 名单提交、周汇总
│   │   │   ├── records/          # 查课记录
│   │   │   ├── ranking/          # 排行榜
│   │   │   └── settings/         # 设置、FAQ
│   │   └── shared/               # 全局 Provider
│   └── assets/                   # 图标、隐私政策、用户协议
│
├── server/                       # FastAPI 后端
│   ├── app/
│   │   ├── core/                 # 配置、数据库连接
│   │   ├── models/               # SQLAlchemy 模型
│   │   ├── schemas/              # Pydantic 模型
│   │   ├── routers/              # API 路由
│   │   └── services/             # 业务逻辑
│   └── migrations/               # 数据库迁移脚本
│
├── docs/                         # 开发文档
│   ├── dev-guide.md              # 完整开发文档
│   ├── business-flow.md          # 业务流程文档
│   └── screenshots/              # 应用截图
│
└── scripts/                      # 数据导入脚本
```

---

## 配置说明

### 前端

无需额外配置，默认连接 `https://api.keleoz.cn/api`。如需修改 API 地址：

```dart
// app/lib/core/network/api_client.dart
static const String defaultBaseUrl = 'https://your-domain.com/api';
```

### 后端

创建 `server/.env` 文件，配置以下项：

```env
# 数据库
DATABASE_URL=mysql+pymysql://user:password@localhost/lesson_search

# JWT
JWT_SECRET=your-secret-key
JWT_EXPIRE_HOURS=720

# SMTP（发送验证码）
SMTP_HOST=smtp.example.com
SMTP_PORT=465
SMTP_USER=your-email@example.com
SMTP_PASSWORD=your-password
```

**注意**：不要将真实的 `.env` 文件提交到仓库。

---

## 贡献指南

欢迎贡献代码、报告问题或提出建议！

### 如何参与

1. **Fork** 本仓库
2. **创建** 你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. **提交** 你的修改 (`git commit -m 'Add some AmazingFeature'`)
4. **推送到** 分支 (`git push origin feature/AmazingFeature`)
5. **打开** Pull Request

### 代码规范

- **Flutter**：遵循 [Flutter 官方风格指南](https://flutter.dev/docs/development/tools/formatting)
- **Python**：遵循 [PEP 8](https://peps.python.org/pep-0008/)
- **提交信息**：使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式

### Issue 模板

报告问题时，请包含：
- 问题描述
- 复现步骤
- 预期行为
- 实际行为
- 环境信息（Flutter 版本、Python 版本、操作系统）

### Pull Request 流程

1. 确保代码通过 `flutter analyze` 和 `ruff check`
2. 更新相关文档
3. 添加测试（如适用）
4. 等待 Review

---

## 更新日志

完整版本更新日志请查看 [CHANGELOG.md](CHANGELOG.md)。

**当前版本亮点：**
- v0.6.0：密码登录、批量同步优化、同步保护机制、设置页增强、全新图标

---

## License

本项目采用 MIT License - 详见 [LICENSE](LICENSE) 文件
