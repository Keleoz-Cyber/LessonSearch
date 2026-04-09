# 考勤助手 开发文档

> **⚠️ 此文档待更新至 v0.5.0**
> 
> 当前内容基于 v0.4.0，v0.5.0 新功能（角色系统、提交审核、周名单汇总、实时公告等）尚未更新。
> 
> v0.5.0 新功能详见：
> - `docs/v0.5.0功能开发计划.md` - 功能开发详细规划
> - `docs/v0.5.0重构方案.md` - 代码重构方案
> 
> 本文档将在所有功能开发完成后统一更新。

> 版本：0.4.0 | 更新日期：2026-04-06 | 仓库：https://github.com/Keleoz-Cyber/LessonSearch

---

## 一、项目概述

### 1.1 项目简介

考勤助手（原查课 App）是一个面向课堂查课场景的 Flutter 应用（Android 优先），用于学习部日常考勤工作。支持点名、记名、查课记录查看与编辑、考勤文本生成、邮箱登录等功能。

### 1.2 核心功能

| 功能 | 说明 |
|------|------|
| 点名 | 按学号顺序逐人点名，支持多班级选择 |
| 记名 | 逐人标记考勤状态（到课/缺勤/迟到/请假/其他），支持多班级切换 |
| 确认名单 | 记名完成后展示异常名单（缺勤/请假/其他），按班级分组 |
| 文本生成 | 一键生成总群汇报和学委汇报文本，支持复制 |
| 查课记录 | 查看、编辑历史考勤记录，支持重新生成文本 |
| 中断恢复 | 记名任务异常退出后，再次打开 App 可恢复上次进度 |
| 数据同步 | 本地优先，异步同步到服务端 MySQL |
| 邮箱登录 | 邮箱验证码登录，一人一码邀请机制，数据隔离 |
| 暗色模式 | 支持跟随系统/亮色/暗色三种主题 |
| 公告系统 | 首次打开显示公告，支持版本更新后重新弹出 |

### 1.3 技术栈

| 端 | 技术 |
|----|------|
| 客户端 | Flutter 3.43、Riverpod、go_router、Dio、Drift (SQLite) |
| 服务端 | FastAPI、SQLAlchemy、PyJWT、MySQL 8 |
| 数据导入 | Python、openpyxl、pypinyin |
| 部署 | 1Panel、Nginx 反向代理、systemd、Let's Encrypt HTTPS |

---

## 二、仓库结构

```
LessonSearch/
├── app/                            # Flutter 客户端
│   ├── lib/
│   │   ├── main.dart               # 入口：Riverpod + App
│   │   ├── app.dart                # MaterialApp.router + Material3 主题
│   │   ├── core/
│   │   │   ├── database/
│   │   │   │   ├── tables.dart     # Drift 表定义（9 张表）
│   │   │   │   ├── app_database.dart
│   │   │   │   └── app_database.g.dart  # 生成代码（勿手动修改）
│   │   │   ├── network/
│   │   │   │   └── api_client.dart # Dio HTTP 客户端（所有 API 调用）
│   │   │   ├── router/
│   │   │   │   └── app_router.dart # go_router 路由定义
│   │   │   ├── sync/
│   │   │   │   └── sync_service.dart  # SyncQueue 消费 + 远程同步
│   │   │   ├── resume/
│   │   │   │   └── task_resume_checker.dart  # 中断恢复检查
│   │   │   └── announcement/
│   │   │       ├── announcement_config.dart  # 公告内容配置
│   │   │       └── announcement_service.dart # 公告弹窗逻辑
│   │   ├── features/
│   │   │   ├── home/
│   │   │   │   └── presentation/
│   │   │   │       └── home_page.dart     # 首页（4 入口 + 设置）
│   │   │   ├── attendance/
│   │   │   │   ├── domain/
│   │   │   │   │   ├── models.dart        # 领域模型 + 枚举
│   │   │   │   │   └── text_template.dart  # 文本生成模板
│   │   │   │   ├── data/
│   │   │   │   │   ├── local/
│   │   │   │   │   │   └── attendance_local_ds.dart   # Drift 操作封装
│   │   │   │   │   ├── remote/
│   │   │   │   │   │   └── attendance_remote_ds.dart  # API 调用封装
│   │   │   │   │   └── attendance_repository.dart     # 统一仓库
│   │   │   │   ├── application/
│   │   │   │   │   ├── roll_call_notifier.dart  # 点名状态管理
│   │   │   │   │   └── name_check_notifier.dart # 记名状态管理
│   │   │   │   └── presentation/
│   │   │   │       ├── selection/
│   │   │   │       │   └── selection_page.dart  # 选择页（年级/专业/班级）
│   │   │   │       ├── roll_call/
│   │   │   │       │   └── roll_call_page.dart  # 点名执行页
│   │   │   │       ├── name_check/
│   │   │   │       │   └── name_check_page.dart # 记名执行页
│   │   │   │       ├── confirmation/
│   │   │   │       │   └── confirmation_page.dart # 确认名单页
│   │   │   │       └── text_generation/
│   │   │   │           └── text_gen_page.dart   # 文本生成页
│   │   │   ├── student/
│   │   │   │   └── data/
│   │   │   │       └── student_repository.dart  # 学生数据（含远程拉取）
│   │   │   ├── records/
│   │   │   │   ├── data/
│   │   │   │   │   └── records_repository.dart  # 查课记录数据
│   │   │   │   └── presentation/
│   │   │   │       ├── records_list_page.dart    # 记录列表
│   │   │   │       └── record_detail_page.dart   # 记录详情/编辑
│   │   │   ├── auth/                      # 用户认证（v0.3.0 新增）
│   │   │   │   ├── data/
│   │   │   │   │   └── auth_service.dart    # token 管理
│   │   │   │   └── presentation/
│   │   │   │       ├── login_page.dart      # 登录页
│   │   │   │       └── register_page.dart   # 注册页
│   │   │   ├── extension/                 # 扩展功能（v0.3.0 新增）
│   │   │   │   └── presentation/
│   │   │   │       └── extension_page.dart  # 扩展功能页
│   │   │   ├── settings/
│   │   │   │   └── presentation/
│   │   │   │       └── settings_page.dart       # 设置 + 关于页 + 主题切换
│   │   │   └── debug/
│   │   │       └── sync_test_page.dart          # 联调测试页（长按标题进入）
│   │   └── shared/
│   │       └── providers.dart                   # 全局 Provider 注册
│   ├── android/                    # Android 工程配置
│   ├── test/
│   │   └── widget_test.dart
│   └── pubspec.yaml
│
├── server/                         # FastAPI 服务端
│   ├── main.py                     # FastAPI 入口
│   ├── config.py                   # 数据库配置 + JWT/SMTP 配置
│   ├── database.py                 # SQLAlchemy Session
│   ├── models.py                   # 10 张表的 ORM 模型
│   ├── schemas.py                  # Pydantic 请求/响应模型
│   ├── requirements.txt            # Python 依赖
│   ├── .env.example                # 环境变量模板
│   ├── routers/
│   │   ├── auth.py                 # 认证接口（登录/验证码）
│   │   ├── grades.py               # GET /api/grades
│   │   ├── majors.py               # GET /api/majors
│   │   ├── classes.py              # GET /api/classes
│   │   ├── students.py             # GET /api/students
│   │   ├── tasks.py                # POST/GET/PUT /api/tasks
│   │   └── records.py              # POST/GET/PUT /api/tasks/{id}/records
│   └── deploy/
│       ├── lesson-search.service   # systemd 服务文件
│       └── nginx-lesson-search.conf # Nginx 配置（参考用）
│
├── scripts/                        # 数据脚本
│   ├── config.py                   # 数据库配置
│   ├── models.py                   # SQLAlchemy 模型
│   ├── init_db.py                  # 建表脚本
│   ├── excel_analyzer.py           # Excel 结构分析器
│   ├── excel_importer.py           # Excel 导入器
│   ├── generate_invitation_codes.py # 邀请码生成脚本
│   └── requirements.txt
│
├── docs/
│   ├── dev-guide.md                # 本文档
│   ├── invitation-codes.md         # 邀请码管理指南
│   └── tasks.md                    # 开发任务表
│
├── data/                           # Excel 考勤数据（.gitignore 排除）
├── .env.example
├── .gitignore
├── AGENT.md                        # AI Agent 协作指南
├── CLAUDE.md                       # 项目规范与约束
└── README.md
```

---

## 三、架构设计

### 3.1 整体架构

```
Flutter App (Android)
    │
    ├── UI 页面层 (presentation/)
    │     ↓ 事件分发
    ├── 业务层 (application/ — Notifier/Controller)
    │     ↓ 调用
    ├── 仓库层 (data/ — Repository)
    │     ├── LocalDataSource → Drift (SQLite)
    │     └── RemoteDataSource → ApiClient → Dio
    │                                 ↓ HTTPS
    │                        FastAPI (api.keleoz.cn)
    │                                 ↓
    │                             MySQL
    │
    ├── AuthService: token 管理、登录状态（SharedPreferences）
    ├── SyncService: SyncQueue → 异步发送到服务端
    └── ThemeModeNotifier: 暗色模式切换
```

### 3.2 分层职责

| 层 | 职责 | 禁止 |
|----|------|------|
| UI 页面 | 展示、事件分发、简单交互 | 直接操作数据库、复杂业务逻辑 |
| Notifier | 核心业务逻辑、状态管理 | 直接操作 UI Widget |
| Repository | 统一数据访问、写本地→入队同步 | 业务逻辑 |
| DataSource | 封装 Drift / API 调用、数据映射 | 业务逻辑 |
| SyncService | 消费 SyncQueue、调用远程 API | UI 操作 |
| AuthService | token 存储、登录状态管理 | 业务逻辑 |

### 3.3 数据流

**写操作（本地优先）：**
```
用户操作 → Notifier → Repository
    → LocalDS.insert() → Drift (SQLite)
    → LocalDS.enqueueSync() → SyncQueue 表
    → SyncService 定期消费 → RemoteDS → API → MySQL
```

**读操作：**
```
用户打开页面 → Notifier → Repository → LocalDS.query() → Drift
首次使用时 → StudentRepository.ensureBaseData() → API 拉取 → 存入 Drift
```

**登录流程：**
```
设置页 → 登录页 → 输入邮箱 → 发送验证码（SMTP）
→ 输入验证码 + 邀请码 → 验证成功 → 返回 JWT token
→ AuthService 保存到 SharedPreferences
→ ApiClient 自动携带 Authorization: Bearer <token>
→ 后续请求按 user_id 过滤数据
```

### 3.4 同步机制

- **SyncQueue 表**：记录所有待同步操作（entityType、entityId、action、payload）
- **SyncService**：每 10 秒扫描一次 pending 队列，逐条发送到服务端
- **失败重试**：retryCount 自动递增，超过 5 次标记 failed
- **网络异常**：检测到网络不通时跳过剩余队列，等下次扫描
- **幂等设计**：服务端 API 支持重复创建（已存在则返回现有记录）
- **数据隔离**：登录后任务带 userId，userId=NULL 的本地历史数据不同步

---

## 四、数据库设计

### 4.1 本地 SQLite（Drift）— 9 张表

| 表 | 说明 |
|----|------|
| `users` | 用户（id, email, nickname, createdAt） |
| `grades` | 年级（id, name, year） |
| `majors` | 专业（id, name, shortName） |
| `classes` | 班级（id, gradeId, majorId, classCode, displayName） |
| `students` | 学生（id, name, studentNo, pinyin, pinyinAbbr, classId） |
| `attendance_tasks` | 考勤任务（id UUID, userId, type, status, phase, syncStatus, ...） |
| `task_classes` | 任务-班级关联（taskId, classId, sortOrder） |
| `attendance_records` | 考勤记录（taskId, studentId, classId, status, remark） |
| `sync_queue` | 同步队列（entityType, entityId, action, payload, syncStatus, retryCount） |

### 4.2 服务端 MySQL — 10 张表

| 表 | 说明 |
|----|------|
| `users` | 用户账户 |
| `verification_codes` | 邮箱验证码（5分钟过期） |
| `invitation_codes` | 邀请码（一人一码） |
| `grades` | 年级 |
| `majors` | 专业 |
| `classes` | 班级 |
| `students` | 学生 |
| `attendance_tasks` | 考勤任务（含 user_id） |
| `task_classes` | 任务-班级关联 |
| `attendance_records` | 考勤记录 |

区别：
- 无 `sync_queue` 表（同步队列仅客户端使用）
- `attendance_tasks.id` 为 VARCHAR(36)，由客户端生成 UUID
- `attendance_tasks.user_id` 关联用户，实现数据隔离
- `classes` 的唯一约束为 (grade_id, major_id, class_code) 组合唯一

### 4.3 班级编号规则

`class_code` 格式为 4 位数字（如 "2301"），前两位为年级缩写（23=2023），后两位为班级序号。同一年级内不同专业可以有相同的 class_code，通过 (grade_id, major_id, class_code) 联合唯一约束区分。

---

## 五、API 接口

服务端地址：`https://api.keleoz.cn`
Swagger 文档：`https://api.keleoz.cn/docs`

### 5.1 认证接口

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/send-code` | 发送邮箱验证码 |
| POST | `/api/auth/login` | 登录（邮箱+验证码） |
| POST | `/api/auth/register` | 注册（邮箱+验证码+邀请码） |
| GET | `/api/auth/me` | 获取当前用户信息（需 token） |

**发送验证码：**
```json
POST /api/auth/send-code
{ "email": "user@example.com" }
```

**登录：**
```json
POST /api/auth/login
{
  "email": "user@example.com",
  "code": "123456"
}

// 响应
{
  "token": "eyJ...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "nickname": null,
    "is_new_user": false
  }
}
```

**注册：**
```json
POST /api/auth/register
{
  "email": "user@example.com",
  "code": "123456",
  "invitation_code": "keleoz"
}

// 响应
{
  "token": "eyJ...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "nickname": null,
    "is_new_user": true
  }
}
```

### 5.2 基础数据（只读）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/grades` | 年级列表 |
| GET | `/api/grades/{id}` | 年级详情 |
| GET | `/api/majors` | 专业列表 |
| GET | `/api/majors/{id}` | 专业详情 |
| GET | `/api/classes?grade_id=&major_id=` | 班级列表（支持筛选） |
| GET | `/api/classes/{id}` | 班级详情（含学生数） |
| GET | `/api/students?class_id=&keyword=` | 学生搜索 |
| GET | `/api/students/by-class/{class_id}` | 按班级查学生 |
| GET | `/api/students/{id}` | 学生详情 |

### 5.3 任务系统

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/tasks` | 创建任务（携带 user_id） |
| GET | `/api/tasks` | 任务列表（按 user_id 过滤） |
| GET | `/api/tasks/{id}` | 任务详情 |
| PUT | `/api/tasks/{id}` | 更新任务状态 |
| POST | `/api/tasks/{id}/records` | 批量创建考勤记录 |
| GET | `/api/tasks/{id}/records` | 查询任务的考勤记录 |
| PUT | `/api/records/{id}` | 更新单条记录状态 |

### 5.4 请求/响应示例

**创建任务：**
```json
POST /api/tasks
Authorization: Bearer <token>
{
  "id": "uuid-string",
  "user_id": 1,
  "type": "roll_call",
  "class_ids": [1, 2, 3],
  "selected_grade_id": 1,
  "selected_major_id": 2
}
```

**创建考勤记录：**
```json
POST /api/tasks/{task_id}/records
[
  {"student_id": 1, "class_id": 1, "status": "present"},
  {"student_id": 2, "class_id": 1, "status": "absent", "remark": "生病"}
]
```

---

## 六、页面流程

### 6.1 点名流程

```
首页 → 选择页（年级→专业→班级多选）→ 点名执行页
                                         ├── 显示当前学生姓名/拼音/学号/班级
                                         ├── "下一位" → 标记为到课
                                         ├── "结束查课" → 确认弹窗
                                         └── 完成页
```

### 6.2 记名流程

```
首页 → 选择页（年级→专业→班级多选）→ 记名执行页
                                         ├── 多班级标签切换
                                         ├── 学生网格（一排两人，颜色区分状态）
                                         ├── 点击学生选中 → 底部按钮标记状态
                                         ├── "确认名单" → 确认页
                                         │                  ├── 异常名单按班分组
                                         │                  ├── "重新编辑" → 返回
                                         │                  └── "确认" → 文本生成页
                                         │                                 ├── 总群汇报 Tab
                                         │                                 ├── 学委汇报 Tab
                                         │                                 ├── 复制按钮
                                         │                                 └── 完成 → 首页
                                         └── 退出弹窗：继续/放弃/保存退出
```

### 6.3 查课记录

```
首页 → 记录列表（按时间倒序）→ 记录详情
                                  ├── 默认显示异常记录
                                  ├── "编辑" → 显示全部，可修改状态
                                  ├── 右上角生成文本 → 底部弹窗
                                  └── 删除记录
```

---

## 七、开发环境搭建

### 7.1 前置条件

- Flutter SDK 3.x（建议 3.43+）
- Android Studio（含 Android SDK、模拟器）
- Python 3.10+（用于导入脚本和服务端）
- MySQL 8.x
- Git

### 7.2 克隆项目

```bash
git clone https://github.com/Keleoz-Cyber/LessonSearch.git
cd LessonSearch
```

### 7.3 Flutter 客户端

```bash
cd app
flutter pub get

# 生成 Drift 代码（修改 tables.dart 后必须执行）
flutter pub run build_runner build --delete-conflicting-outputs

# 运行
flutter run -d emulator-5554

# 打包 APK
flutter build apk --debug
# 产物：app/build/app/outputs/flutter-apk/app-debug.apk
```

### 7.4 服务端

```bash
cd server
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# 配置数据库
cp .env.example .env
# 编辑 .env 填入 MySQL 密码

# 建表
python -c "from models import Base; from database import engine; Base.metadata.create_all(engine)"

# 启动
uvicorn main:app --reload --port 8000
# 访问 http://localhost:8000/docs
```

### 7.5 数据导入

```bash
cd scripts
pip install -r requirements.txt
cp ../server/.env .env  # 或创建独立的 .env

# 分析 Excel
python excel_analyzer.py --verbose

# 导入（dry-run）
python excel_importer.py

# 正式导入
python excel_importer.py --commit

# 强制更新
python excel_importer.py --commit --force
```

---

## 八、关键配置文件

### 8.1 数据库连接 (.env)

```
DB_HOST=localhost          # 或 127.0.0.1
DB_PORT=3306
DB_USER=lesson_search
DB_PASSWORD=your_password
DB_NAME=lesson_search
```

### 8.2 JWT 和 SMTP 配置 (.env)

```
# JWT
JWT_SECRET=your_random_secret_key
JWT_EXPIRE_HOURS=168       # 7 天

# SMTP（以 QQ 邮箱为例）
SMTP_HOST=smtp.qq.com
SMTP_PORT=465
SMTP_USER=your_email@qq.com
SMTP_PASSWORD=your_smtp_auth_code  # 不是 QQ 密码
SMTP_FROM_NAME=查课 App
```

### 8.3 API 地址

文件：`app/lib/core/network/api_client.dart`
```dart
static const String defaultBaseUrl = 'https://api.keleoz.cn/api';
```
本地开发时改为 `http://10.0.2.2:8000/api`（模拟器访问宿主机）。

### 8.4 公告内容

文件：`app/lib/core/announcement/announcement_config.dart`
```dart
const int announcementVersion = 8;       // 改公告后 +1
const String announcementTitle = '...';
const String announcementContent = '''...''';
const String updateNotes = '''...''';
```

### 8.5 文本生成模板

文件：`app/lib/features/attendance/domain/text_template.dart`

模板使用占位符替换，如 `{date}`、`{class_names}`、`{absent_list}` 等。修改 `defaultGroupReportTemplate` 和 `defaultCommitteeReportTemplate` 常量即可自定义格式。

### 8.6 Gradle 镜像

文件：`app/android/settings.gradle.kts` 和 `app/android/build.gradle.kts`

已配置阿里云 Maven 镜像，解决国内网络下载依赖失败的问题。

---

## 九、常用开发命令

```bash
# Flutter
flutter analyze              # 静态分析
flutter test                  # 运行测试
flutter run -d emulator-5554  # 运行到模拟器
flutter build apk --debug     # 打包调试 APK
flutter build apk --release   # 打包发布 APK
flutter pub run build_runner build --delete-conflicting-outputs  # Drift 代码生成

# 服务端
uvicorn main:app --reload --port 8000    # 开发模式
uvicorn main:app --host 0.0.0.0 --port 8000  # 生产模式

# 数据导入
python excel_analyzer.py                  # 分析 Excel
python excel_importer.py                  # 预览
python excel_importer.py --commit         # 导入
python excel_importer.py --commit --force # 强制更新

# Git
git status
git add .
git commit -m "feat: ..."
git push origin main
```

---

## 十一、版本发布流程

### 11.1 版本号管理

版本号定义在 `app/pubspec.yaml` 中：
```yaml
version: 0.4.0+17
```

格式：`主版本.次版本.修订版+构建号`

### 11.2 发布前检查清单

1. **更新版本号**
   - 编辑 `app/pubspec.yaml` 中的 `version`
   - 编辑 `app/lib/features/settings/presentation/settings_page.dart` 中的 `currentVersion`

2. **更新公告**
   - 编辑 `app/lib/core/announcement/announcement_config.dart`
   - `announcementVersion` +1
   - 更新 `announcementContent` 和 `updateNotes`

3. **更新文档**
   - `docs/dev-guide.md` 版本号
   - `docs/ios-guide.md` 版本号
   - `docs/tasks.md` 版本号和更新日志

### 11.3 构建 APK

**使用自动化脚本（推荐）：**
```powershell
.\build_release.ps1
```

**手动构建：**
```powershell
cd app
flutter build apk --release
# APK 位置：app/build/app/outputs/flutter-apk/app-release.apk
```

**APK 命名规范：**
- 格式：`kaoqin-helper-vX.X.X.apk`
- 示例：`kaoqin-helper-v0.4.0.apk`

### 11.4 发布到 GitHub

1. **提交代码：**
   ```powershell
   git add .
   git commit -m "release: vX.X.X"
   git push origin main
   ```

2. **创建 Release：**
   ```powershell
   gh release create vX.X.X --title "vX.X.X 版本标题" --prerelease
   gh release upload vX.X.X 考勤助手vX.X.X.apk
   ```

3. **更新服务端版本信息：**
   ```bash
   # SSH 到服务器
   ssh root@47.94.142.242
   
   # 更新版本缓存
   cd /opt/lesson-search
   source venv/bin/activate
   # 服务端会自动从 GitHub 获取最新版本信息
   ```

### 11.5 版本类型

- **Pre-release（预发布）**：内测版本，不会通过 `/releases/latest` API 返回
- **Latest（正式版）**：稳定版本，用户检查更新时会收到通知

设置预发布：
```powershell
gh release edit vX.X.X --prerelease
```

取消预发布（设为正式版）：
```powershell
gh release edit vX.X.X --prerelease=false
```

---

## 十二、部署

详见 `docs/deploy-guide.md`，关键点：

- 服务端部署在 `https://api.keleoz.cn`
- 通过 1Panel 反向代理 + Let's Encrypt HTTPS
- FastAPI 监听 `127.0.0.1:8000`，不暴露到公网
- systemd 管理进程，1 worker + 256MB 内存限制
- MySQL 通过 1Panel 管理

---

## 十三、数据流示例

### 记名完整链路

```
1. 用户选择 2023级/电信/2301班+2302班
2. SelectionPage → context.push('/name-check/execute', extra: {classIds, ...})
3. NameCheckNotifier.startNameCheck()
   → StudentRepository.ensureStudentsForClass()  // 确保本地有学生数据
   → AttendanceRepository.createTask()
     → LocalDS.insertTask() → Drift
     → LocalDS.enqueueSync() → SyncQueue
   → 更新 Notifier 状态

4. 用户标记学生状态（缺勤/请假/其他/到课）
   → NameCheckNotifier.markStudent()
   → AttendanceRepository.createRecord()
     → LocalDS.insertRecord() → Drift
     → LocalDS.enqueueSync() → SyncQueue

5. SyncService（后台每 10 秒）
   → getPendingSyncItems() → 读取 SyncQueue
   → RemoteDS.createTask() → POST /api/tasks
   → RemoteDS.createRecords() → POST /api/tasks/{id}/records
   → LocalDS.markSynced()

6. 用户确认名单 → ConfirmationPage → TextGenPage
   → 生成文本 → 复制到剪贴板

7. 数据已在服务端 MySQL 中
```

---

## 十四、已知限制与后续计划

### 已知限制

1. 文本模板目前是代码常量，未做数据库配置化
2. 同步失败的记录没有 UI 提示详情
3. 暂不支持跨设备同步（登录后不会从服务端拉取数据）

### 后续可做

- 文本模板从数据库加载，支持用户自定义
- 检查更新功能（GitHub Release 已实现）
- 数据导出（Excel/PDF）
- 跨设备同步（登录后从服务端拉取数据）
- 统计分析（缺勤趋势、班级对比）
- 扩展功能实现（导入、提交、汇总、排行）
