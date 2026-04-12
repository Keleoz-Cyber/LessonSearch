# 考勤助手

> 面向课堂查课场景的 Flutter App，支持点名、记名、考勤文本生成、本地优先+服务器同步。

**当前版本：v0.5.0**（2026-04-12）

## v0.5.0 更新日志

### 核心功能

- **实名制** - 登录后必须填写真实姓名
- **名单提交审核** - 成员提交记名任务，管理员审核
- **周名单汇总** - 管理员审核、导出Excel、发布汇总
- **数据隔离** - 登出时清空本地用户数据
- **实时公告** - 从服务端获取公告内容
- **审核历史** - 管理员查看已审核记录

### 角色系统

| 角色 | 权限 |
|------|------|
| member | 查看自己的数据、提交记录、查看已发布汇总 |
| admin | 审核、导出、查看所有提交状态 |

### 技术改进

- 服务端目录结构重构
- Models/Schemas按领域拆分
- 周次系统统一使用服务端配置
- 学生名单更新（2022-2024级本科生，含性别）

---

## 功能

- **点名** — 按学号顺序逐人点名，多班级，支持中途保存和继续，可撤销上一位
- **记名** — 逐人标记状态（到课/缺勤/迟到/请假/其他），多班切换，自定义备注
- **确认名单** — 异常记录按班分组，支持重新编辑
- **文本生成** — 一键生成总群汇报和学委汇报，学委汇报按班级分开复制
- **查课记录** — 查看、编辑历史记录，继续未完成任务
- **中断恢复** — 记名任务异常退出后恢复进度
- **数据同步** — 本地优先离线可用，后台异步同步服务器
- **名单提交** — 提交本周记名任务供管理员审核
- **周名单汇总** — 管理员审核导出，成员查看已发布汇总
- **邮箱登录** — 邮箱验证码登录注册，一人一码邀请机制
- **暗色模式** — 支持跟随系统/亮色/暗色三种主题
- **检查更新** — App 内检查新版本并跳转下载
- **公告系统** — 版本更新自动弹出

---

## 技术栈

| 端 | 技术 |
|----|------|
| 客户端 | Flutter · Riverpod · go_router · Dio · Drift (SQLite) |
| 服务端 | FastAPI · SQLAlchemy · PyJWT · MySQL 8 |
| 数据导入 | Python · openpyxl · pypinyin |
| 部署 | 1Panel · Nginx · systemd · HTTPS |

---

## 项目结构

```
LessonSearch/
├── app/            Flutter 客户端
├── server/         FastAPI 服务端
│   └── app/
│       ├── core/   配置、数据库、安全
│       ├── models/ 数据模型
│       ├── schemas/ Pydantic模型
│       ├── routers/ API路由
│       └── services/ 业务逻辑
├── scripts/        Excel导入脚本
├── docs/           文档
└── AGENT.md        AI Agent协作指南
```

---

## 快速开始

```bash
# Flutter
cd app && flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run

# 服务端
cd server && pip install -r requirements.txt
cp .env.example .env
uvicorn main:app --reload --port 8000

# 数据导入
cd scripts && pip install -r requirements.txt
python import_students_2022plus.py --commit --clear
```

---

## 文档

| 文档 | 说明 |
|------|------|
| AGENT.md | AI Agent协作指南（接手必读） |
| CLAUDE.md | 项目规范与约束 |
| docs/dev-guide.md | 开发文档 |
| docs/tasks.md | 任务表 |

---

## API

Swagger 文档：https://api.keleoz.cn/docs

---

## 许可

本项目仅供学习使用，未经作者允许禁止分发。