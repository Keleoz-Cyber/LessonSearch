# 考勤助手

> 面向学校课堂查课场景的 Flutter + FastAPI 全栈应用。
> 
> 支持点名、记名、查课记录管理、名单提交审核、周汇总与 Excel 导出。
> 
> **本项目已在学校查课工作中正式投入使用**，覆盖从现场记名到管理员审核的完整闭环。

---

## 项目简介

考勤助手是为高校学生会/学习部查课工作开发的一套完整应用。

在日常查课中，通常需要两人在教室配合：一人负责点名，另一人使用 App 记录每位学生的出勤状态（到课、缺勤、迟到、请假、其他）。查课完成后，成员将名单提交审核，管理员审核通过后生成周汇总并导出 Excel。

**这不是一个 Demo，而是围绕真实校园查课流程持续迭代的功能完整应用。** 项目重点解决了以下问题：

- **弱网/断网场景**：教室网络不稳定时，App 必须能正常使用
- **数据一致性**：本地修改与服务端状态不一致时如何检测与修复
- **审核追溯**：提交后谁审核、是否通过、拒绝原因是什么，全程可追溯
- **异常保护**：Token 过期、同步失败、重复提交等边界情况的兜底处理

---

## 核心功能

### 现场查课
- **点名**：按学号顺序逐人点名，支持多班级、撤销上一位
- **记名**：逐人标记考勤状态，支持左右滑动切换班级，未处理自动标为"到课"
- **汇报文本生成**：自动生成学委汇报和总群汇报文本，一键复制跳转微信/QQ

### 记录管理
- **查课记录**：查看历史查课记录，支持编辑修改考勤状态
- **记录锁定**：已提交审核的任务禁止修改，防止数据被篡改
- **放弃任务**：标记为 abandoned，保留数据但不再参与提交

### 名单提交与审核
- **名单提交**：成员选择本周已完成的记名任务提交审核
- **提交前强制同步**：确保本地数据已全部同步到服务端后再提交
- **管理员审核**：管理员查看提交详情，通过或拒绝并填写原因
- **审核状态**：pending / approved / rejected / cancelled，全程可追溯

### 周汇总与导出
- **周名单汇总**：按周次查看所有已审核提交的汇总统计
- **Excel 导出**：导出含迟到、缺勤、请假、其他列的考勤表
- **排行榜**：近7天/近30天/总榜，异常分数、缺勤率、缺勤人次多维度统计

### 同步与帮助
- **同步队列**：本地优先 + 后台静默同步，失败自动重试
- **同步问题详情**：查看待同步、失败、认证过期的具体记录
- **密码登录 / 验证码登录**：两种登录方式共存，支持设置/修改密码
- **FAQ 帮助中心**：内置 19 个常见问题，涵盖同步、提交、审核、记录等场景

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

### 详细流程

1. **现场记名** → 选择年级、专业、班级，逐人标记考勤状态
2. **修改记录** → 在查课记录中反复修改，直到确认无误
3. **生成汇报** → 自动生成文本，发送给学委确认 / 发送到总群
4. **名单提交** → 选择本周已完成的记名任务，提交管理员审核
5. **管理员审核** → 查看异常名单，通过或拒绝（填写原因）
6. **周汇总 / Excel 导出** → 审核通过后，生成周汇总并导出 Excel

---

## 技术架构

```
Flutter App (Android)
  ├── Drift (SQLite) 本地数据库
  ├── SyncQueue 同步队列
  └── Dio + JWT 认证
          ↓ HTTPS
    FastAPI 服务端
      └── MySQL 8
```

### 前端
- **Flutter 3.43** + **Material 3**
- **Riverpod** 状态管理
- **Drift** 本地 SQLite 数据库
- **go_router** 路由管理
- **Dio** 网络请求 + 拦截器

### 后端
- **FastAPI** + **SQLAlchemy**
- **PyJWT** 认证
- **bcrypt** 密码哈希
- **MySQL 8** 主数据库
- **OpenResty** 反向代理

### 数据流

**写操作（本地优先）：**
```
用户操作 → Notifier → Repository
    → LocalDS (Drift) → SyncQueue 入队
    → SyncService 定期消费 → RemoteDS → API → MySQL
```

**读操作：**
```
用户打开页面 → Notifier → Repository → LocalDS.query() → Drift
```

---

## 项目亮点

### 1. 本地优先，弱网可用
所有查课操作先写本地数据库，再异步同步到服务端。**教室网络不稳定时，App 完全可用**，网络恢复后自动补齐同步。

### 2. SyncQueue 同步队列
- 每次修改自动入队（`pending` 状态）
- SyncService 每 10 秒消费队列，批量提交（2~50 条合并为一次请求）
- 失败自动分类：网络错误重试、401 认证过期保留数据、其他错误最多重试 5 次
- 支持手动触发同步和同步问题详情查看

### 3. 提交前强制同步
名单提交前必须完成同步，如果有失败项会阻止提交并提示具体原因，**避免"我明明修改了但提交的还是旧数据"的问题**。

### 4. Token 过期保护
Token 过期返回 401 时，**只清除 token，保留本地所有数据和用户信息**。重新登录后自动恢复认证失败项并继续同步，**数据不丢失**。

### 5. 记录锁定与权限
- 已提交审核（pending / approved）的任务，服务端禁止修改记录（返回 403）
- 前端同步检测，已提交任务禁用编辑并显示橙色提示
- 删除任务改为标记 abandoned，已提交的任务不允许删除

### 6. 异常状态完整追溯
- 审核拒绝始终显示审核人和拒绝原因
- rejected / cancelled 的提交可以重新提交
- 历史提交记录管理员可随时查询

---

## 页面预览

| 首页 | 记名页面 | 名单提交 |
|------|----------|----------|
| ![首页](docs/screenshots/首页.png) | ![记名](docs/screenshots/记名.png) | ![提交](docs/screenshots/名单提交.png) |

| 管理员审核 | 周汇总 | 同步问题详情 |
|------------|--------|--------------|
| ![审核](docs/screenshots/管理员审核.png) | ![汇总](docs/screenshots/周汇总.png) | ![同步](docs/screenshots/同步问题详情.png) |

---

## 快速开始

### 前端

```bash
cd app
flutter pub get
flutter pub run flutter_launcher_icons:main  # 生成图标
flutter run
```

### 后端

```bash
cd server
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
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
│   │   ├── core/                 # 数据库、网络、同步、路由
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
│   └── tasks.md                  # 开发任务表
│
└── scripts/                      # 数据导入脚本
    └── import_students_2022plus.py
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

## 更新日志

完整版本更新日志请查看 [CHANGELOG.md](CHANGELOG.md)。

当前版本亮点：
- v0.6.0：密码登录、批量同步优化、同步保护机制、设置页增强、全新图标

---

## License

待补充
