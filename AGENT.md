# AGENT.md — AI Agent 协作指南

> 本文档面向接手此项目的 AI Agent。请在开始任何工作前完整阅读此文件。
> 最后更新：2026-04-13 · 当前版本：0.5.2

---

## 一、项目概述

考勤助手是一个课堂考勤 Flutter App（Android 优先），采用本地优先 + 服务器异步同步架构。

- **仓库**：https://github.com/Keleoz-Cyber/LessonSearch
- **服务端**：https://api.keleoz.cn（FastAPI + MySQL，1Panel 部署）
- **API 文档**：https://api.keleoz.cn/docs

### 核心功能

| 功能 | 说明 |
|------|------|
| 点名 | 按学号顺序逐人点名 |
| 记名 | 逐人标记考勤状态 |
| 名单提交 | 成员提交记名任务供审核 |
| 周名单汇总 | 管理员审核、导出、发布 |
| 实名制 | 登录后必须填写真实姓名 |
| 数据隔离 | 登出清空本地用户数据 |

---

## 二、架构

```
Flutter App
  UI 页面 (presentation/)
    ↓ 事件
  Notifier (application/)
    ↓ 调用
  Repository (data/)
    ├── LocalDataSource → Drift (SQLite)
    └── RemoteDataSource → ApiClient → Dio
                              ↓ HTTPS
                         FastAPI → MySQL
```

### 核心规则

1. **页面层禁止直接操作数据库** — 只通过 Notifier
2. **Notifier 通过 Repository 访问数据**
3. **写操作 = 写本地 + 入队 SyncQueue**
4. **读操作 = 读本地 Drift**
5. **登录后任务绑定 user_id** — 数据隔离

---

## 三、目录结构

```
app/lib/
├── main.dart
├── app.dart
├── core/
│   ├── database/     # Drift表定义（tables.dart）
│   ├── network/      # ApiClient
│   ├── router/       # go_router
│   ├── sync/         # SyncService
│   └── announcement/ # 公告系统
├── features/
│   ├── attendance/   # 点名、记名、文本生成
│   ├── extension/    # 名单提交、周名单汇总
│   ├── auth/         # 登录、实名制
│   ├── records/      # 查课记录
│   └── settings/     # 设置、致谢
└── shared/
    └── providers.dart

server/
├── main.py
├── app/
│   ├── core/         # config, database, security
│   ├── models/       # user, student, task, submission
│   ├── schemas/      # Pydantic模型
│   ├── routers/      # API路由
│   └── services/     # 业务逻辑
└── migrations/       # SQL迁移脚本

scripts/
├── config.py
├── models.py
├── excel_importer.py
└── import_students_2022plus.py  # 新版导入脚本
```

---

## 四、数据库

### 本地 SQLite（Drift）

| 表 | 说明 |
|----|------|
| grades | 年级 |
| majors | 专业 |
| classes | 班级 |
| students | 学生（含gender字段） |
| attendance_tasks | 考勤任务 |
| attendance_records | 考勤记录 |
| sync_queue | 同步队列 |

### 服务端 MySQL

| 表 | 说明 |
|----|------|
| users | 用户（role, real_name） |
| week_config | 周次配置 |
| submissions | 提交记录 |
| week_exports | 周导出记录 |
| duty_assignments | 职务分配 |
| announcements | 公告 |

---

## 五、关键业务流程

### 名单提交审核流程

```
成员创建记名任务 → 提交审核 → 管理员审核 → 通过/拒绝
                                     ↓
                               名单汇总 → 导出Excel → 发布
```

### 周次系统

- 所有周次相关功能使用服务端 `week_config.start_date` 计算
- 周一零点为新的一周开始
- 提交、汇总、审核全部按周次维度

---

## 六、服务端维护操作

以下操作由程序员/运维通过SSH操作：

```bash
# 分配管理员角色
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "UPDATE users SET role='admin' WHERE id=5;"

# 设置新学期周次
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "UPDATE week_config SET is_active=FALSE; INSERT INTO week_config (start_date, semester_name, is_active) VALUES ('2026-09-07', '新学期', TRUE);"

# 分配查课职务
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "INSERT INTO duty_assignments (user_id, assigned_by) VALUES (用户ID, 管理员ID);"

# 发布公告
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "INSERT INTO announcements (version, title, content, created_by) VALUES (版本号, '标题', '内容', 管理员ID);"
```

---

## 七、开发环境

```bash
# Flutter
cd app && flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run

# 服务端
cd server && pip install -r requirements.txt
uvicorn main:app --reload --port 8000

# 数据导入
cd scripts && pip install pandas pypinyin openpyxl
python import_students_2022plus.py --commit --clear
```

---

## 八、常见陷阱

1. **周次计算必须用服务端API** — 不能用本地时间
2. **DioException用 `e.response?.data['detail']` 提取错误**
3. **Drift查询 `select(table).get()` 返回列表**
4. **FastAPI路由顺序** — 动态路径要在静态路径之后

---

## 九、相关文档

| 文档 | 说明 |
|------|------|
| CLAUDE.md | 项目规范 |
| docs/dev-guide.md | 开发文档 |
| docs/tasks.md | 任务表 |
| docs/invitation-codes.md | 邀请码管理 |