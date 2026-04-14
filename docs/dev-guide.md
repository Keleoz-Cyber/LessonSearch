# 考勤助手 开发文档

> 版本：0.5.3 | 更新日期：2026-04-13 | 仓库：https://github.com/Keleoz-Cyber/LessonSearch

---

## 一、项目概述

考勤助手是面向课堂查课场景的 Flutter 应用（Android 优先），用于学习部日常考勤工作。采用本地优先 + 服务端异步同步架构。

### 核心功能

| 功能 | 说明 |
|------|------|
| 点名 | 按学号顺序逐人点名，支持多班级、撤销上一位 |
| 记名 | 逐人标记考勤状态（到课/缺勤/迟到/请假/其他），固定两列布局 |
| 名单提交 | 成员提交记名任务（分开提交），管理员审核 |
| 周名单汇总 | 管理员审核、导出Excel（含请假/其他列）、发布汇总 |
| 实名制 | 登录后必须填写真实姓名，路由+首页双重检查 |
| 数据隔离 | 登出清空本地用户数据 |
| 实时公告 | 从服务端获取公告内容，Markdown渲染 |

### 技术栈

| 端 | 技术 |
|----|------|
| 客户端 | Flutter 3.43、Riverpod 2.6、go_router 14、Dio、Drift 2.28、flutter_markdown、share_plus |
| 服务端 | FastAPI、SQLAlchemy、PyJWT、MySQL 8、openpyxl |
| 部署 | 1Panel、Nginx反向代理、systemd、Let's Encrypt HTTPS |

---

## 二、完整目录结构

### 客户端 (app/lib/)

```
app/lib/
├── main.dart                      # 入口：初始化SharedPreferences + ProviderScope
├── app.dart                       # MaterialApp.router + Material3主题
│
├── core/                          # 核心模块
│   ├── database/
│   │   ├── tables.dart            # Drift表定义（8张表）
│   │   ├── app_database.dart      # Drift数据库类 + clearUserData()
│   │   └── app_database.g.dart    # 生成代码（勿手动修改）
│   │
│   ├── network/
│   │   └── api_client.dart        # Dio封装 + 自动携带token + 错误处理
│   │
│   ├── router/
│   │   └── app_router.dart        # go_router路由定义（首页、登录、点名、记名等）
│   │
│   ├── sync/
│   │   └── sync_service.dart      # SyncQueue消费者（每10秒轮询）
│   │
│   ├── resume/
│   │   └── task_resume_checker.dart  # 启动时检查未完成任务
│   │
│   ├── announcement/
│   │   ├── announcement_config.dart  # 公告内容（版本号、标题、内容）
│   │   └── announcement_service.dart # 从服务端获取公告 + 缓存
│   │
│   └── feedback/
│       └ feedback_service.dart    # 振动/音效反馈
│
├── features/                      # 功能模块（feature-first）
│   │
│   ├── home/
│   │   └── presentation/
│   │       └── home_page.dart     # 首页（点名、记名、记录、扩展入口）
│   │
│   ├── attendance/                # 核心考勤模块
│   │   ├── domain/
│   │   │   ├── models.dart        # 枚举 + 领域模型
│   │   │   └── text_template.dart # 文本生成模板
│   │   │
│   │   ├── data/
│   │   │   ├── local/
│   │   │   │   └── attendance_local_ds.dart  # Drift操作封装
│   │   │   ├── remote/
│   │   │   │   └ attendance_remote_ds.dart  # API调用封装
│   │   │   └── attendance_repository.dart   # 统一仓库（写本地→入队同步）
│   │   │
│   │   ├── application/
│   │   │   ├── roll_call_notifier.dart  # 点名状态管理
│   │   │   └ name_check_notifier.dart   # 记名状态管理
│   │   │
│   │   └── presentation/
│   │       ├── selection/
│   │       │   └── selection_page.dart  # 选择页（年级→专业→班级）
│   │       ├── roll_call/
│   │       │   └ roll_call_page.dart    # 点名执行页
│   │       ├── name_check/
│   │       │   └── name_check_page.dart # 记名执行页
│   │       ├── confirmation/
│   │       │   └ confirmation_page.dart # 确认名单页
│   │       └── text_generation/
│   │           └── text_gen_page.dart   # 文本生成页
│   │
│   ├── student/
│   │   └── data/
│   │       └── student_repository.dart  # 学生数据（远程拉取+本地缓存）
│   │
│   ├── records/                   # 查课记录
│   │   ├── data/
│   │   │   └ records_repository.dart
│   │   └── presentation/
│   │       ├── records_list_page.dart   # 记录列表
│   │       └── record_detail_page.dart  # 记录详情/编辑
│   │
│   ├── auth/                      # 用户认证
│   │   ├── data/
│   │   │   └── auth_service.dart  # token管理、登录状态
│   │   └── presentation/
│   │       ├── login_page.dart    # 登录页（邮箱+验证码）
│   │       ├── register_page.dart # 注册页（邮箱+验证码+邀请码）
│   │       └── real_name_page.dart # 实名填写页
│   │
│   ├── extension/                 # 扩展功能
│   │   ├── data/
│   │   │   └ submission_service.dart  # 提交相关API调用
│   │   └ presentation/
│   │       ├── extension_page.dart     # 扩展功能入口（4个按钮）
│   │       ├── submission_page.dart    # 名单提交页
│   │       └── weekly_summary_page.dart # 周名单汇总页
│   │
│   ├── settings/
│   │   └ presentation/
│   │       └── settings_page.dart  # 设置页 + 关于页 + 主题切换 + 登出
│   │
│   └── debug/
│       └ sync_test_page.dart      # 联调测试页（长按首页标题进入）
│
├── shared/
│   ├── providers.dart             # 全局Provider注册
│   └── widgets/
│       └── toast.dart             # Toast组件
```

### 服务端 (server/)

```
server/
├── main.py                        # FastAPI入口 + 路由注册 + CORS
│
├── app/
│   ├── core/
│   │   ├── config.py              # 数据库配置 + JWT/SMTP配置
│   │   ├── database.py            # SQLAlchemy SessionLocal + Base
│   │   ├── security.py            # JWT生成/验证 + 密码处理
│   │   └── exceptions.py          # 自定义异常
│   │
│   ├── models/                    # 数据模型（按领域拆分）
│   │   ├── __init__.py            # 统一导出
│   │   ├── user.py                # User, VerificationCode, InvitationCode
│   │   ├── student.py             # Grade, Major, Class, Student
│   │   ├── task.py                # AttendanceTask, TaskClass
│   │   ├── record.py              # AttendanceRecord
│   │   ├── week.py                # WeekConfig, WeekExport
│   │   ├── submission.py          # Submission, SubmissionRecord
│   │   ├── duty.py                # DutyAssignment
│   │   └── announcement.py        # Announcement
│   │
│   ├── schemas/                   # Pydantic请求/响应模型
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── student.py
│   │   ├── task.py
│   │   └── record.py
│   │
│   ├── routers/                   # API路由
│   │   ├── auth.py                # POST /api/auth/send-code, login, register
│   │   ├── user.py                # PUT /api/user/real-name, GET /api/user/me
│   │   ├── grades.py              # GET /api/grades
│   │   ├── majors.py              # GET /api/majors
│   │   ├── classes.py             # GET /api/classes
│   │   ├── students.py            # GET /api/students
│   │   ├── tasks.py               # POST/GET/PUT /api/tasks
│   │   ├── records.py             # POST/GET/PUT /api/records
│   │   ├── week.py                # GET /api/week/current
│   │   ├── submission.py          # 提交审核API
│   │   ├── duty.py                # 职务相关API
│   │   └ announcement.py          # GET /api/announcement
│   │
│   └── services/                  # 业务逻辑（可选）
│
├── migrations/                    # SQL迁移脚本
│   ├── add_announcements.sql
│   └── add_gender.sql
│
├── requirements.txt
├── .env.example
└── deploy/
    ├── lesson-search.service      # systemd服务文件
    └── nginx-lesson-search.conf   # Nginx配置
```

### 数据脚本 (scripts/)

```
scripts/
├── config.py                      # 数据库配置
├── models.py                      # SQLAlchemy模型（同步scripts用）
├── excel_importer.py              # 旧版Excel导入
├── import_students_2022plus.py    # 新版导入（含性别、过滤研究生）
├── generate_invitation_codes.py   # 生成邀请码
└ └── requirements.txt
```

---

## 三、架构设计

### 分层职责

| 层 | 职责 | 禁止 |
|----|------|------|
| UI页面 (presentation/) | 展示、事件分发、简单交互 | 直接操作数据库、复杂业务逻辑 |
| Notifier (application/) | 核心业务逻辑、状态管理 | 直接操作UI Widget |
| Repository (data/) | 统一数据访问、写本地→入队同步 | 业务逻辑 |
| DataSource | 封装Drift/API调用、数据映射 | 业务逻辑 |
| SyncService | 消费SyncQueue、调用远程API | UI操作 |
| AuthService | token存储、登录状态管理 | 业务逻辑 |

### 数据流

**写操作：**
```
用户操作 → Notifier → Repository
    → LocalDS.insert() → Drift (SQLite)
    → LocalDS.enqueueSync() → SyncQueue表
    → SyncService定期消费 → RemoteDS → API → MySQL
```

**读操作：**
```
用户打开页面 → Notifier → Repository → LocalDS.query() → Drift
首次使用时 → StudentRepository.ensureStudentsForClass() → API拉取 → 存入Drift
```

### Provider依赖图

```
sharedPreferencesProvider
    ↓
authServiceProvider → apiClientProvider（自动携带token）
    ↓
databaseProvider
    ↓
attendanceLocalDSProvider
attendanceRemoteDSProvider
    ↓
attendanceRepositoryProvider
studentRepositoryProvider
recordsRepositoryProvider
    ↓
syncServiceProvider（自动启动）
rollCallProvider
nameCheckProvider
```

---

## 四、数据库设计

### 本地 SQLite（Drift）— 8张表

#### 用户表 (Users)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| email | VARCHAR(100) | 邮箱 |
| nickname | VARCHAR(50) | 昵称（可空） |
| createdAt | DATETIME | 创建时间 |
| lastLoginAt | DATETIME | 最后登录时间 |

#### 年级表 (Grades)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| name | VARCHAR(20) | 年级名称（如"2022级"） |
| year | INT | 年份（唯一） |

#### 专业表 (Majors)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| name | VARCHAR(50) | 专业全称 |
| shortName | VARCHAR(20) | 专业简称（唯一，如"电信"） |

#### 班级表 (Classes)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| gradeId | INT | 关联年级 |
| majorId | INT | 关联专业 |
| classCode | VARCHAR(20) | 班级编号（如"01"） |
| displayName | VARCHAR(50) | 显示名称（如"电信2201"） |

#### 学生表 (Students)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| name | VARCHAR(50) | 姓名 |
| studentNo | VARCHAR(20) | 学号（唯一） |
| pinyin | VARCHAR(100) | 姓名拼音（带声调） |
| pinyinAbbr | VARCHAR(20) | 拼音首字母 |
| classId | INT | 关联班级 |

#### 考勤任务表 (AttendanceTasks)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) | UUID主键 |
| userId | INT | 用户ID（可空，登录后绑定） |
| type | VARCHAR(20) | 任务类型：roll_call / name_check |
| status | VARCHAR(20) | 状态：in_progress / completed / abandoned |
| phase | VARCHAR(20) | 当前阶段：selecting / executing / confirming |
| selectedGradeId | INT | 选中的年级ID |
| selectedMajorId | INT | 选中的专业ID |
| currentClassIndex | INT | 当前班级索引 |
| currentStudentIndex | INT | 当前学生索引 |
| createdAt | DATETIME | 创建时间 |
| updatedAt | DATETIME | 更新时间 |
| syncStatus | VARCHAR(20) | 同步状态：pending / synced / failed |

#### 任务-班级关联表 (TaskClasses)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| taskId | VARCHAR(36) | 关联任务 |
| classId | INT | 关联班级 |
| sortOrder | INT | 排序顺序 |

#### 考勤记录表 (AttendanceRecords)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| taskId | VARCHAR(36) | 关联任务 |
| studentId | INT | 关联学生 |
| classId | INT | 关联班级 |
| status | VARCHAR(20) | 状态：pending / present / absent / late / leave / other |
| remark | VARCHAR(200) | 备注（"其他"状态的自定义说明） |
| createdAt | DATETIME | 创建时间 |
| updatedAt | DATETIME | 更新时间 |

#### 同步队列表 (SyncQueue)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| entityType | VARCHAR(50) | 实体类型：task / record |
| entityId | VARCHAR(36) | 实体ID |
| action | VARCHAR(20) | 操作：create / update |
| payload | TEXT | JSON数据（可空） |
| syncStatus | VARCHAR(20) | 同步状态：pending / syncing / synced / failed |
| retryCount | INT | 重试次数（超过5次放弃） |
| createdAt | DATETIME | 创建时间 |
| syncedAt | DATETIME | 同步完成时间 |

### 服务端 MySQL — 14张表

#### 用户表 (users)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| email | VARCHAR(100) | 邮箱（唯一） |
| nickname | VARCHAR(50) | 昵称 |
| role | VARCHAR(20) | 角色：member / admin |
| real_name | VARCHAR(50) | 真实姓名（实名制） |
| created_at | DATETIME | 创建时间 |
| last_login_at | DATETIME | 最后登录 |

#### 验证码表 (verification_codes)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| email | VARCHAR(100) | 邮箱 |
| code | VARCHAR(6) | 6位验证码 |
| expires_at | DATETIME | 过期时间（5分钟） |
| used | BOOLEAN | 是否已使用 |
| created_at | DATETIME | 创建时间 |

#### 邀请码表 (invitation_codes)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| code | VARCHAR(20) | 邀请码（唯一） |
| used | BOOLEAN | 是否已使用 |
| used_by | INT | 使用者ID |
| used_at | DATETIME | 使用时间 |

#### 学生表 (students) — 新增gender字段
| 字段 | 类型 | 说明 |
|------|------|------|
| ... | ... | 同本地Drift |
| gender | VARCHAR(10) | 性别：男 / 女 |

#### 周次配置表 (week_config)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| start_date | DATE | 第1周起始日期（必须是周一） |
| semester_name | VARCHAR(50) | 学期名称 |
| is_active | BOOLEAN | 是否当前学期 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

#### 提交记录表 (submissions)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| user_id | INT | 提交人ID |
| week_number | INT | 周次 |
| status | VARCHAR(20) | 状态：pending / approved / rejected / cancelled |
| reviewer_id | INT | 审核人ID |
| review_time | DATETIME | 审核时间 |
| review_note | TEXT | 审核备注 |
| submitted_at | DATETIME | 提交时间 |
| updated_at | DATETIME | 更新时间 |

#### 提交-记录关联表 (submission_records)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| submission_id | INT | 关联提交 |
| record_id | INT | 关联考勤记录（唯一约束） |

#### 周导出记录表 (week_exports)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| week_number | INT | 周次 |
| exported_by | INT | 导出人ID |
| exported_at | DATETIME | 导出时间 |

#### 职务分配表 (duty_assignments)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| user_id | INT | 成员ID（唯一约束） |
| assigned_by | INT | 分配人ID |
| assigned_at | DATETIME | 分配时间 |
| is_active | BOOLEAN | 是否在职 |
| deactivated_at | DATETIME | 离职时间 |

#### 公告表 (announcements)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 自增主键 |
| version | INT | 版本号（改公告后+1） |
| title | VARCHAR(100) | 公告标题 |
| content | TEXT | 公告内容 |
| is_active | BOOLEAN | 是否启用 |
| created_by | INT | 创建人ID |
| created_at | DATETIME | 创建时间 |

---

## 五、API接口详细

服务端地址：https://api.keleoz.cn
Swagger文档：https://api.keleoz.cn/docs

### 认证接口 (/api/auth)

| 方法 | 路径 | 说明 | 请求体 | 响应 |
|------|------|------|--------|------|
| POST | /send-code | 发送验证码 | `{email}` | `{message}` |
| POST | /login | 登录 | `{email, code}` | `{token, user}` |
| POST | /register | 注册 | `{email, code, invitation_code}` | `{token, user}` |

### 用户接口 (/api/user)

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | /me | 获取当前用户信息 | 登录 |
| PUT | /real-name | 更新实名 | 登录 |
| GET | /admins | 获取管理员列表 | 登录 |

### 基础数据接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/grades | 年级列表 |
| GET | /api/majors | 专业列表 |
| GET | /api/classes?grade_id=&major_id= | 班级列表 |
| GET | /api/students?class_id=&keyword= | 学生搜索 |
| GET | /api/students/by-class/{class_id} | 按班级查学生 |

### 任务接口 (/api/tasks)

| 方法 | 路径 | 说明 | 请求体 |
|------|------|------|--------|
| POST | / | 创建任务 | `{id, type, class_ids, ...}` |
| GET | / | 任务列表（按user_id过滤） | - |
| GET | /{id} | 任务详情 | - |
| PUT | /{id} | 更新任务状态 | `{status, ...}` |
| POST | /{id}/records | 批量创建记录 | `[{student_id, status, ...}]` |
| GET | /{id}/records | 查询任务记录 | - |

### 周次接口 (/api/week)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /current | 获取当前周次信息（含start_date, end_date） |

### 提交接口 (/api/submissions)

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | / | 创建提交 | member |
| GET | /my | 我的提交列表 | member |
| DELETE | /{id} | 撤回提交（待审核） | member |
| GET | /pending | 待审核列表 | admin |
| GET | /reviewed | 已审核列表 | admin |
| POST | /{id}/approve | 审核通过 | admin |
| POST | /{id}/reject | 审核拒绝 | admin |
| GET | /week-summary/{week} | 周汇总统计 | admin |
| GET | /week-summary-detail/{week} | 周汇总详情 | admin/member（已发布） |
| GET | /export-status/{week} | 导出状态 | 登录 |
| POST | /export/{week} | 导出Excel | admin |

### 职务接口 (/api/duties)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /my | 我的职务状态 |
| GET | /week-submissions | 本周提交状态（admin） |

### 公告接口 (/api/announcement)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | / | 获取最新公告 |

---

## 六、关键业务流程

### 点名流程

```
首页 → 选择页（年级→专业→班级多选）→ 点名执行页
    ├── startRollCall(): 创建任务 → 加载学生(按学号排序)
    ├── nextStudent(): 标记present → 创建record → index++
    ├── prevStudent(): 撤销上一位 → 删除record → index--
    ├── saveProgress(): 保存退出时持久化currentStudentIndex
    ├── finishRollCall(): 标记completed
    └── resumeTask(): 从currentStudentIndex继续
→ 完成页（已点N/未点M）
```

### 记名流程

```
首页 → 选择页（年级→专业→班级多选）→ 记名执行页
    ├── startNameCheck(): 创建任务 → 加载学生网格
    ├── markStudent(): 标记状态 → 创建/更新record
    ├── switchClass(): 切换班级（左右滑动）
    ├── finishNameCheck(): 未处理的批量标为present → 确认页
    ├── 确认页：异常名单按班分组 → 重新编辑 / 确认 → 文本生成页
    └── 文本生成页：总群汇报Tab + 学委汇报Tab → 复制 → 完成
→ 首页
```

### 名单提交审核流程

```
成员创建记名任务 → 扩展功能 → 名单提交
    ├── 选择本周记名任务（多选）
    ├── 提交审核 → 创建submission → 关联records
    └── 我的提交Tab：查看状态（待审核/已通过/已拒绝）
    
管理员 → 扩展功能 → 周名单汇总
    ├── 本周汇总Tab
    │   ├── 查看提交状态（已提交/未提交成员）
    │   ├── 查看提交详情 → 审核通过/拒绝
    │   ├── 汇总预览（迟到/缺勤/请假/其他统计）
    │   │   └── 异常人数：所有异常学生去重后的总人数
    │   │   └── 累计计算：迟到/2 + 缺勤（请假/其他不计入）
    │   └── 导出Excel → 分享文件（share_plus）
    │       └── 文件名：第X周考勤表.xlsx
    │       └── 列：序号、姓名、班级、学号、迟到、缺勤、请假、其他、累计
    └── 历史周次Tab：查看历史已发布汇总

成员 → 名单提交 → 我的提交
    ├── 点击提交卡片 → 查看详细名单
    │   └── 显示迟到/缺勤/请假/其他统计和名单
    └── 撤回待审核提交
```

### 周次系统

- 所有周次相关功能使用服务端 `week_config.start_date` 计算
- 周一零点为新的一周开始
- 计算公式：`week_number = (current_date - start_date).days // 7 + 1`
- 提交、汇总、审核全部按周次维度

### 数据隔离

```
登出流程：
1. 检查未同步数据数量
2. 弹窗提示（同步并登出 / 直接登出）
3. 清除token和用户信息
4. 清空本地数据库（tasks, records, submissions, sync_queue）
5. 返回登录页
```

---

## 七、开发环境搭建

### 前置条件

- Flutter SDK 3.43+（建议 master channel）
- Android Studio（含 Android SDK、模拟器）
- Python 3.10+
- MySQL 8.x
- Git

### Flutter客户端

```bash
cd app
flutter pub get

# 生成Drift代码（修改tables.dart后必须执行）
flutter pub run build_runner build --delete-conflicting-outputs

# 运行到模拟器
flutter run -d emulator-5554

# 打包APK
flutter build apk --release
# 产物：app/build/app/outputs/flutter-apk/app-release.apk
```

### 服务端本地开发

```bash
cd server
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# 配置数据库
cp .env.example .env
# 编辑.env填入MySQL密码、JWT密钥、SMTP配置

# 启动开发服务器
uvicorn main:app --reload --port 8000
# 访问 http://localhost:8000/docs
```

### 数据导入

```bash
cd scripts
pip install pandas pypinyin openpyxl sqlalchemy pymysql
cp ../server/.env .env

# 预览数据
python import_students_2022plus.py

# 正式导入（清空旧数据）
python import_students_2022plus.py --commit --clear
```

---

## 八、服务器部署

### 服务管理

```bash
# 重启服务
systemctl restart lesson-search.service

# 查看日志
journalctl -u lesson-search.service -f

# 查看状态
systemctl status lesson-search.service
```

### 数据库操作

```bash
# 执行SQL
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "SQL语句"

# 查看用户
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "SELECT id, email, role, real_name FROM users;"

# 查看周次配置
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "SELECT * FROM week_config WHERE is_active=TRUE;"
```

### 更新部署

```bash
cd /opt/lesson-search
git pull origin feature/v0.5.0
systemctl restart lesson-search.service

# 检查日志确认启动成功
journalctl -u lesson-search.service -n 20
```

### SQL迁移

```bash
# 执行迁移脚本
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search < server/migrations/add_gender.sql
```

---

## 九、服务端维护操作

### 分配管理员角色

```bash
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "UPDATE users SET role='admin' WHERE id=用户ID;"
```

### 设置新学期周次

```bash
# 禁用旧学期
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "UPDATE week_config SET is_active=FALSE;"

# 创建新学期（start_date必须是周一）
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "INSERT INTO week_config (start_date, semester_name, is_active) VALUES ('2026-09-07', '2026-2027学年第一学期', TRUE);"
```

### 分配查课职务

```bash
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "INSERT INTO duty_assignments (user_id, assigned_by) VALUES (成员ID, 管理员ID);"
```

### 取消职务

```bash
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "UPDATE duty_assignments SET is_active=FALSE, deactivated_at=NOW() WHERE user_id=成员ID;"
```

### 发布公告

```bash
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "INSERT INTO announcements (version, title, content, is_active, created_by) VALUES (版本号+1, '标题', '内容', TRUE, 管理员ID);"
```

### 创建邀请码

```bash
cd /opt/lesson-search/scripts
source ../venv/bin/activate
python generate_invitation_codes.py 10  # 生成10个随机邀请码
```

---

## 十、版本发布流程

### 发布前检查清单

1. **更新版本号**
   - `app/pubspec.yaml`: `version: X.X.X+Y`
   - `app/lib/features/settings/presentation/settings_page.dart`: 版本显示

2. **更新公告**
   - `app/lib/core/announcement/announcement_config.dart`
   - `announcementVersion` +1
   - 更新 `announcementContent` 和 `updateNotes`

3. **更新文档**
   - `docs/dev-guide.md` 版本号
   - `docs/tasks.md` 版本历史
   - `AGENT.md` 版本号

4. **本地测试**
   ```bash
   cd app && flutter analyze
   flutter run -d emulator-5554
   ```

5. **提交并推送**
   ```bash
   git add .
   git commit -m "release: vX.X.X"
   git push origin main
   ```

### GitHub Actions 自动构建

推送 tag 触发自动构建发布：

```bash
git tag vX.X.X
git push origin vX.X.X
```

构建产物自动上传到 GitHub Release，包含：
- `kaoqin-helper-vX.X.X.apk` - Android APK（release keystore签名）
- `kaoqin-helper-unsigned.ipa` - iOS IPA（未签名）

### 本地构建APK

本地构建需要 `key.properties` 文件：

```bash
cd app
flutter build apk --release
# APK位置：app/build/app/outputs/flutter-apk/考勤助手vX.X.X.apk
```

### Release Keystore 签名

APK 使用 release keystore 签名，确保后续版本可正常覆盖安装：

- **Keystore文件**: `app/android/app/release-keystore.jks`（不提交到仓库）
- **配置文件**: `app/android/key.properties`（不提交到仓库）
- **GitHub Secrets**: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`

⚠️ keystore 文件丢失会导致签名不一致，用户需卸载重装

---

## 十一、常见问题

### Q: Drift修改表结构后怎么办？

修改 `tables.dart` 后：
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

⚠️ 用户需要卸载重装App（Drift不支持migration）

### Q: 服务端API返回403？

检查：
1. 用户是否登录（token是否有效）
2. 用户角色是否有权限（admin接口需要admin角色）
3. 路由顺序（动态路径要在静态路径之后）

### Q: 周次计算不准确？

所有周次计算必须用服务端 `GET /api/week/current` 返回的 `start_date` 和 `end_date`，不能用本地时间。

### Q: DioException如何提取错误信息？

```dart
try {
  await api.dio.post('/api/xxx');
} on DioException catch (e) {
  final message = e.response?.data['detail'] ?? '操作失败';
  Toast.show(context, message);
}
```

### Q: 如何在服务器查看实时日志？

```bash
journalctl -u lesson-search.service -f
```

---

## 十二、相关文档

| 文档 | 说明 |
|------|------|
| AGENT.md | AI Agent协作指南（接手必读） |
| CLAUDE.md | 项目规范与约束 |
| docs/tasks.md | 开发任务表 |
| docs/invitation-codes.md | 邀请码管理指南 |