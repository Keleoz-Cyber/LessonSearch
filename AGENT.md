# AGENT.md — AI Agent 协作指南

> 本文档面向接手此项目的 AI Agent。请在开始任何工作前完整阅读此文件。
> 最后更新：2026-04-04 · 当前版本：0.3.8

---

## 一、项目概述

这是一个课堂考勤查课 Flutter App（Android 优先），采用本地优先 + 服务器异步同步架构。

- **仓库**：https://github.com/Keleoz-Cyber/LessonSearch
- **服务端**：https://api.keleoz.cn（FastAPI + MySQL，1Panel 部署）
- **API 文档**：https://api.keleoz.cn/docs

---

## 二、架构（务必理解再动手）

```
Flutter App
  UI 页面 (presentation/)
    ↓ 事件
  Notifier (application/)         ← 业务逻辑在这里
    ↓ 调用
  Repository (data/)              ← 统一数据访问
    ├── LocalDataSource → Drift (SQLite)   ← 所有读写先走这里
    └── RemoteDataSource → ApiClient → Dio
                                     ↓ HTTPS
                            FastAPI → MySQL
  SyncService (core/sync/)
    ↓ 定期消费 SyncQueue 表
    → RemoteDataSource → 服务端

AuthService (features/auth/)
  → SharedPreferences (token, userId, email)
  → ApiClient 自动携带 Authorization: Bearer <token>
```

### 核心规则

1. **页面层禁止直接操作数据库或写业务逻辑** — 只通过 Notifier
2. **Notifier 通过 Repository 访问数据** — 不直接用 LocalDS/RemoteDS
3. **写操作 = 写本地 + 入队 SyncQueue** — Repository 自动处理
4. **读操作 = 读本地 Drift** — 首次使用时从服务器拉取缓存
5. **SyncService 是独立的后台消费者** — 不被页面直接调用（除了 syncNow）
6. **登录后任务绑定 user_id** — 数据隔离，每用户只看自己的记录

### Drift 和 Domain 模型名称冲突

Drift 生成的数据类和 Domain 模型同名（如 `AttendanceTask`）。在 LocalDataSource 中用 `import '...models.dart' as domain;` 区分：
- `AttendanceTask` = Drift 生成的数据类
- `domain.AttendanceTask` = 领域模型

**修改 tables.dart 后必须运行：**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 三、目录结构与文件职责

```
app/lib/
├── main.dart                          # 入口：ProviderScope + App
├── app.dart                           # MaterialApp.router + Material3 主题
├── core/
│   ├── database/
│   │   ├── tables.dart                # ★ 8 张 Drift 表定义（改这里要重新生成）
│   │   ├── app_database.dart          # Drift 数据库类
│   │   └── app_database.g.dart        # 生成代码（勿手动改）
│   ├── network/
│   │   └── api_client.dart            # ★ 所有 HTTP 调用（GET/POST/PUT）
│   ├── router/
│   │   └── app_router.dart            # ★ 所有路由定义
│   ├── sync/
│   │   └── sync_service.dart          # SyncQueue 消费者（10秒轮询）
│   ├── resume/
│   │   └── task_resume_checker.dart   # 启动时检查未完成记名任务
│   └── announcement/
│       ├── announcement_config.dart   # ★ 公告内容（用户编辑）
│       └── announcement_service.dart  # 公告弹窗逻辑
│
├── features/
│   ├── home/presentation/
│   │   └── home_page.dart             # 首页（4入口 + 设置 + 同步状态）
│   │
│   ├── attendance/                    # ★ 核心模块
│   │   ├── domain/
│   │   │   ├── models.dart            # ★ 枚举 + 领域模型（TaskType, AttendanceStatus 等）
│   │   │   └── text_template.dart     # ★ 文本生成模板（可配置）
│   │   ├── data/
│   │   │   ├── local/attendance_local_ds.dart   # Drift 操作（含批量方法）
│   │   │   ├── remote/attendance_remote_ds.dart # API 调用
│   │   │   └── attendance_repository.dart       # ★ 统一仓库（写本地→入队同步）
│   │   ├── application/
│   │   │   ├── roll_call_notifier.dart  # ★ 点名状态管理（含 resume）
│   │   │   └── name_check_notifier.dart # ★ 记名状态管理（含 resume）
│   │   └── presentation/
│   │       ├── selection/selection_page.dart       # 选择页（年级/专业/班级）
│   │       ├── roll_call/roll_call_page.dart       # 点名执行页
│   │       ├── name_check/name_check_page.dart     # 记名执行页
│   │       ├── confirmation/confirmation_page.dart # 确认名单页
│   │       └── text_generation/text_gen_page.dart  # 文本生成页
│   │
│   ├── student/data/
│   │   └── student_repository.dart    # 学生/班级数据（含远程拉取+本地缓存）
│   │
│   ├── records/                       # 查课记录
│   │   ├── data/records_repository.dart
│   │   └── presentation/
│   │       ├── records_list_page.dart
│   │       └── record_detail_page.dart
│   │
│   ├── auth/                          # ★ 用户认证（v0.3.0 新增）
│   │   ├── data/auth_service.dart     # token 管理、登录状态
│   │   └── presentation/
│   │       ├── login_page.dart        # 登录页
│   │       └── register_page.dart     # 注册页
│   │
│   ├── extension/                     # ★ 扩展功能（v0.3.0 新增）
│   │   └── presentation/extension_page.dart
│   │
│   ├── settings/presentation/
│   │   └── settings_page.dart         # 设置页 + 关于页 + 主题切换
│   │
│   └── debug/
│       └── sync_test_page.dart        # 联调测试页（长按首页标题进入）
│
└── shared/
    ├── providers.dart                 # ★ 所有 Riverpod Provider 注册
    └── widgets/loading_overlay.dart   # 通用加载遮罩
```

```
server/
├── main.py           # FastAPI 入口 + 路由注册
├── config.py         # 数据库配置 + JWT/SMTP 配置（读 .env）
├── database.py       # SQLAlchemy Session
├── models.py         # ★ 10 张表的 ORM 模型（含 users, verification_codes, invitation_codes）
├── schemas.py        # ★ Pydantic 请求/响应模型
├── requirements.txt
├── .env.example
└── routers/
    ├── auth.py       # ★ POST /api/auth/send-code, /api/auth/login, GET /api/auth/me
    ├── grades.py     # GET /api/grades
    ├── majors.py     # GET /api/majors
    ├── classes.py    # GET /api/classes
    ├── students.py   # GET /api/students
    ├── tasks.py      # ★ POST/GET/PUT /api/tasks（支持 user_id 过滤）
    └── records.py    # ★ POST/GET/PUT 考勤记录
```

```
scripts/
├── init_db.py                        # 初始化数据库
├── excel_analyzer.py                 # Excel 结构分析
├── excel_importer.py                 # Excel 导入 MySQL
└── generate_invitation_codes.py      # 生成邀请码（v0.3.0 新增）
```

---

## 四、数据库

### 本地 SQLite (Drift) — 9 张表

| 表 | 说明 | 关键字段 |
|----|------|---------|
| users | 用户 | id, email, nickname, createdAt |
| grades | 年级 | id, name, year |
| majors | 专业 | id, name, shortName |
| classes | 班级 | id, gradeId, majorId, classCode, displayName |
| students | 学生 | id, name, studentNo, pinyin(带声调), pinyinAbbr, classId |
| attendance_tasks | 任务 | id(UUID), **userId**, type, status, phase, syncStatus, currentStudentIndex |
| task_classes | 任务-班级关联 | taskId, classId, sortOrder |
| attendance_records | 考勤记录 | taskId, studentId, classId, status, remark |
| sync_queue | 同步队列 | entityType, entityId, action, payload, syncStatus, retryCount |

### 服务端 MySQL — 10 张表

| 表 | 说明 |
|----|------|
| users | 用户账户 |
| verification_codes | 邮箱验证码（5分钟过期） |
| invitation_codes | 邀请码（一人一码） |
| grades, majors, classes, students | 基础数据 |
| attendance_tasks | 任务（含 user_id） |
| task_classes, attendance_records | 关联数据 |

### ⚠️ 当前无 Drift migration

修改 `tables.dart` 后，用户需要**卸载 App 重装**才能生效。这是最高优先级的技术债。

---

## 五、枚举值（跨端共享）

```
TaskType:        roll_call | name_check
TaskStatus:      in_progress | confirming | text_gen | completed | abandoned
TaskPhase:       selecting | executing | confirming | text_generating
AttendanceStatus: pending | present | absent | late | leave | other
SyncStatus:      pending | synced | failed
```

`AttendanceStatus.late_`（Dart 中 `late` 是关键字，用 `late_`，值为 `"late"`）

---

## 六、关键业务流程

### 点名流程
```
首页 → 选择页(多选班级) → 点名执行页
  startRollCall(): 创建任务 → 加载全部学生(按学号排序)
  nextStudent(): 标记当前为 present → 创建 record → index++
  finishRollCall(): 标记 completed
  saveProgress(): 保存退出时持久化 currentStudentIndex
  resumeTask(): 从 currentStudentIndex 继续
→ 完成页(已点N/未点M)
```

### 记名流程
```
首页 → 选择页(多选班级) → 记名执行页
  startNameCheck(): 创建任务 → 加载学生网格
  markStudent(): 标记状态 → 创建/更新 record
  finishNameCheck(): 未处理的批量标为 present(事务)
  resumeTask(): 恢复已标记状态
→ 确认页(异常名单) → 文本生成页(总群/学委汇报) → 完成
```

### 数据同步流程
```
Repository.createRecord()
  → LocalDS.insertRecord() → Drift
  → LocalDS.enqueueSync() → SyncQueue 表
SyncService(每10秒)
  → getPendingSyncItems() → 含 failed+retryCount<5 的
  → _processItem() → RemoteDS → POST/PUT 服务端
  → markSynced() 或 markSyncFailed(retryCount++)
```

### 登录流程（v0.3.0）
```
设置页 → 登录页 → 输入邮箱 → 发送验证码（SMTP）
→ 输入验证码 → 验证成功 → 返回 JWT token
→ AuthService 保存到 SharedPreferences
→ ApiClient 自动携带 Authorization: Bearer <token>
→ 后续请求按 user_id 过滤数据

注册页 → 输入邮箱 → 发送验证码
→ 输入验证码 + 邀请码 → 验证成功 → 创建账户 → 返回 JWT token
```

### 邀请码机制
- **一人一码**：每个邀请码只能注册一个新用户
- **注册时需要**：新用户注册必须提供有效邀请码
- **登录时不需要**：老用户登录只需邮箱+验证码
- **管理**：`docs/invitation-codes.md`

---

## 七、修改代码的注意事项

### 添加新页面
1. 在 `features/` 下创建目录
2. 在 `app_router.dart` 添加路由
3. 如需数据访问，通过 Repository，不直接操作 DB
4. 如需状态管理，创建 Notifier，注册到 `providers.dart`

### 添加新的考勤状态
1. `domain/models.dart` — AttendanceStatus 枚举加值
2. `name_check_page.dart` — 底部按钮 + _StudentCard 颜色/标签
3. `confirmation_page.dart` — statusLabel + statusColor
4. `record_detail_page.dart` — _RecordRow 颜色/标签 + PopupMenu
5. `text_template.dart` — 模板占位符 + Stats/ClassStats 字段
6. `text_gen_page.dart` — 收集统计逻辑
7. `record_detail_page.dart` — _generateText 收集逻辑
8. `records_repository.dart` — getTaskSummaries 统计
9. `records_list_page.dart` — 卡片统计文字

### 修改 Drift 表结构
1. 修改 `tables.dart`
2. 运行 `flutter pub run build_runner build --delete-conflicting-outputs`
3. 如果加了新字段，检查 LocalDataSource 的映射方法
4. ⚠️ 用户需要卸载重装 App

### 修改服务端
1. 修改 `server/models.py` + `schemas.py` + 对应 router
2. 服务器上需要 `git pull` + 可能需要 ALTER TABLE + `systemctl restart lesson-search`
3. 如果是新增字段，Flutter 的 ApiClient/RemoteDS 也需要同步更新

### 打包 APK
```bash
cd app
# 更新版本号：pubspec.yaml (version)、settings_page.dart (两处)
# 更新公告：announcement_config.dart (announcementVersion+1, updateNotes)
flutter build apk --debug --target-platform android-arm,android-arm64,android-x64
# 产物：app/build/app/outputs/flutter-apk/app-debug.apk
```

---

## 八、环境信息

| 项目 | 信息 |
|------|------|
| Flutter SDK | 3.43 (master channel) |
| Dart SDK | 3.11.3 |
| Android SDK | API 36 |
| 服务端地址 | https://api.keleoz.cn |
| API baseUrl | `app/lib/core/network/api_client.dart` → `defaultBaseUrl` |
| 服务器 | 2C/2G/40G，1Panel + MySQL(Docker) + OpenResty |
| systemd 服务 | lesson-search（/opt/lesson-search/server/） |
| MySQL 数据库 | lesson_search，用户 lesson_search |
| 数据源 | Excel 考勤表 → Python 脚本导入 MySQL |
| Gradle 镜像 | 阿里云（已配置 settings.gradle.kts + build.gradle.kts） |

---

## 九、Provider 依赖关系

```
sharedPreferencesProvider (SharedPreferences)
  ↓
authServiceProvider (AuthService) — token/userId 管理
themeModeProvider (ThemeModeNotifier) — 暗色模式
  ↓
databaseProvider (AppDatabase)
apiClientProvider (ApiClient) — 自动携带 token
  ↓
attendanceLocalDSProvider (AttendanceLocalDataSource)
attendanceRemoteDSProvider (AttendanceRemoteDataSource)
  ↓
attendanceRepositoryProvider (AttendanceRepository)
studentRepositoryProvider (StudentRepository)
recordsRepositoryProvider (RecordsRepository)
  ↓
syncServiceProvider (SyncService) — 自动 start()
rollCallProvider (RollCallNotifier)
nameCheckProvider (NameCheckNotifier)
  ↓
syncStateProvider (SyncState) — 供 UI 监听同步状态
```

---

## 十、常见陷阱

1. **`AttendanceStatus.late_` 不是 `late`** — Dart 关键字冲突，枚举值用 `late_`，但字符串值是 `"late"`
2. **Drift 生成类和 Domain 模型同名** — LocalDataSource 必须用 `as domain` 导入
3. **`classes` 表 class_code 不是全局唯一** — 唯一约束是 `(grade_id, major_id, class_code)`
4. **点名只创建 present 记录** — 未点的学生没有 attendance_records 记录，显示时需要从班级花名册对比
5. **记名确认后 isFinished=true** — 如果从确认页返回，必须调用 `resumeEditing()` 重置
6. **公告版本号 announcementVersion** — 每次改公告内容必须 +1，否则已点"不再显示"的用户看不到
7. **本地数据首次加载** — `StudentRepository.ensureBaseData()` 和 `ensureStudentsForClass()` 会从服务器拉取并缓存
8. **服务器 MySQL 在 Docker 里** — 命令行访问需要 `docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql ...`
9. **Windows 终端 python -c 多行命令** — 会有缩进问题，用 `cat > /tmp/script.py << 'EOF'` 写文件再执行
10. **服务端时间用 datetime.now()** — 不用 utcnow()，否则时区不一致导致验证码验证失败
11. **登录后任务带 userId** — 创建任务时传入 `authService.userId`，否则数据不会隔离
12. **userId=NULL 的任务不同步** — 本地历史数据（登录前）不会被同步到服务端
13. **登录和注册分离** — 登录只需邮箱+验证码，注册需要额外提供邀请码

---

## 十一、测试方法

### Flutter 分析
```bash
cd app && flutter analyze
```

### 单元测试
```bash
cd app && flutter test
```

### 联调测试
长按首页标题 → 进入联调测试页 → 创建任务/标记学生/查看同步队列

### 服务端验证
```bash
curl https://api.keleoz.cn/health
curl https://api.keleoz.cn/api/grades
curl -X POST https://api.keleoz.cn/api/tasks -H 'Content-Type: application/json' -d '{"id":"test","type":"roll_call","class_ids":[1]}'
```

### 服务端 MySQL 查看
```bash
# 在服务器上
docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql -u lesson_search -p lesson_search
SELECT id, type, status FROM attendance_tasks ORDER BY created_at DESC LIMIT 10;
```

---

## 十二、Git 规范

- 提交格式：`feat:` / `fix:` / `perf:` / `docs:` / `chore:`
- 每次打包前：更新 version、settings 版本号、公告 version+1 和 updateNotes
- 禁止提交：.env、data/、构建产物、IDE 配置

---

## 十三、相关文档

| 文档 | 说明 |
|------|------|
| `CLAUDE.md` | 项目规范与约束 |
| `docs/tasks.md` | 开发任务表 |
| `docs/dev-guide.md` | 完整开发文档 |
| `docs/invitation-codes.md` | 邀请码管理指南 |
| `docs/ios-guide.md` | iOS 适配指南 |
