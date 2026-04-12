# 考勤助手 开发文档

> 版本：0.5.0 | 更新日期：2026-04-12 | 仓库：https://github.com/Keleoz-Cyber/LessonSearch

---

## 一、项目概述

考勤助手是面向课堂查课场景的 Flutter 应用（Android 优先），用于学习部日常考勤工作。

### 核心功能

- 点名：按学号顺序逐人点名
- 记名：逐人标记考勤状态
- 名单提交：成员提交记名任务供审核
- 周名单汇总：管理员审核、导出、发布
- 实名制：登录后必须填写真实姓名
- 数据隔离：登出清空本地用户数据

### 技术栈

| 端 | 技术 |
|----|------|
| 客户端 | Flutter 3.43、Riverpod、go_router、Dio、Drift |
| 服务端 | FastAPI、SQLAlchemy、MySQL 8 |
| 部署 | 1Panel、Nginx、systemd、HTTPS |

---

## 二、仓库结构

```
LessonSearch/
├── app/                    # Flutter 客户端
│   └── lib/
│       ├── core/           # 数据库、网络、路由、同步
│       ├── features/       # 功能模块
│       └── shared/         # 共享组件
│
├── server/                 # FastAPI 服务端
│   ├── app/
│   │   ├── core/           # config, database, security
│   │   ├── models/         # 数据模型
│   │   ├── schemas/        # Pydantic模型
│   │   ├── routers/        # API路由
│   │   └── services/       # 业务逻辑
│   └── migrations/         # SQL迁移脚本
│
├── scripts/                # 数据导入脚本
│   ├── excel_importer.py   # 旧版导入
│   └── import_students_2022plus.py  # 新版导入（含性别）
│
├── docs/                   # 文档
├── AGENT.md                # AI Agent协作指南
└── CLAUDE.md               # 项目规范
```

---

## 三、架构设计

### 分层职责

| 层 | 职责 |
|----|------|
| UI页面 | 展示、事件分发 |
| Notifier | 业务逻辑、状态管理 |
| Repository | 统一数据访问 |
| DataSource | 封装Drift/API调用 |

### 数据流

- **写操作**：写本地 → 入队SyncQueue → 异步同步服务端
- **读操作**：读本地Drift，首次使用时从服务端拉取缓存

---

## 四、数据库设计

### 本地 SQLite（Drift）

| 表 | 说明 |
|----|------|
| grades | 年级 |
| majors | 专业 |
| classes | 班级 |
| students | 学生（含gender字段） |
| attendance_tasks | 考勤任务 |
| task_classes | 任务-班级关联 |
| attendance_records | 考勤记录 |
| sync_queue | 同步队列 |

### 服务端 MySQL

| 表 | 说明 |
|----|------|
| users | 用户（role, real_name） |
| verification_codes | 验证码 |
| invitation_codes | 邀请码 |
| week_config | 周次配置 |
| submissions | 提交记录 |
| submission_records | 提交-记录关联 |
| week_exports | 周导出记录 |
| duty_assignments | 职务分配 |
| announcements | 公告 |

---

## 五、API接口

服务端地址：https://api.keleoz.cn
Swagger文档：https://api.keleoz.cn/docs

### 主要接口

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/auth/send-code | 发送验证码 |
| POST | /api/auth/login | 登录 |
| POST | /api/auth/register | 注册 |
| PUT | /api/user/real-name | 更新实名 |
| GET | /api/week/current | 获取当前周次 |
| GET | /api/submissions | 提交相关API |
| GET | /api/duties | 职务相关API |
| GET | /api/announcement | 获取公告 |

---

## 六、开发环境搭建

### Flutter客户端

```bash
cd app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run -d emulator-5554
```

### 服务端

```bash
cd server
pip install -r requirements.txt
cp .env.example .env
uvicorn main:app --reload --port 8000
```

### 数据导入

```bash
cd scripts
pip install pandas pypinyin openpyxl
python import_students_2022plus.py  # 预览
python import_students_2022plus.py --commit --clear  # 正式导入
```

---

## 七、服务器部署

### 服务管理

```bash
systemctl restart lesson-search.service
journalctl -u lesson-search.service -f
```

### 数据库操作

```bash
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "SQL语句"
```

### 更新部署

```bash
cd /opt/lesson-search
git pull origin feature/v0.5.0
systemctl restart lesson-search.service
```

---

## 八、版本发布流程

1. 更新 `app/pubspec.yaml` 版本号
2. 更新 `app/lib/core/announcement/announcement_config.dart` 公告版本
3. 构建 APK：`flutter build apk --release`
4. 发布到 GitHub Release

---

## 九、服务端维护操作

### 分配管理员

```bash
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "UPDATE users SET role='admin' WHERE id=用户ID;"
```

### 设置新学期

```bash
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "UPDATE week_config SET is_active=FALSE; INSERT INTO week_config (start_date, semester_name, is_active) VALUES ('2026-09-07', '新学期', TRUE);"
```

### 分配职务

```bash
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "INSERT INTO duty_assignments (user_id, assigned_by) VALUES (用户ID, 管理员ID);"
```

---

## 十、相关文档

| 文档 | 说明 |
|------|------|
| AGENT.md | AI Agent协作指南 |
| CLAUDE.md | 项目规范 |
| docs/tasks.md | 任务表 |
| docs/invitation-codes.md | 邀请码管理 |