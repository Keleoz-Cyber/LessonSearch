# 考勤助手

> 面向课堂查课场景的 Flutter App，支持点名、记名、考勤文本生成、本地优先+服务器同步。

**当前版本：v0.5.1**（2026-04-12）

## v0.5.1 更新日志

### 响应式布局优化

- **公共组件提取** - StatusBadge、EmptyState、EntryCard 统一UI风格
- **实名页优化** - 移除固定占位，按钮固定底部
- **文字溢出修复** - 姓名/学号长文字自动截断
- **按钮溢出修复** - 发送验证码按钮自适应宽度
- **AlertDialog优化** - 移除固定宽度，自适应屏幕
- **Row布局优化** - 统计卡片使用Wrap防止溢出

## v0.5.0 更新日志

### 核心功能

- **实名制** - 登录后必须填写真实姓名，路由+首页双重检查
- **名单提交审核** - 成员提交记名任务（分开提交），管理员审核
- **周名单汇总** - 管理员审核、导出Excel（含请假/其他列）、发布汇总
- **数据隔离** - 登出时清空本地用户数据
- **实时公告** - 从服务端获取公告内容，Markdown渲染
- **审核历史** - 管理员查看已审核记录
- **成员提交详情** - 点击提交卡片查看详细名单

### 角色系统

| 角色 | 权限 |
|------|------|
| member | 查看自己的数据、提交记录、查看已发布汇总 |
| admin | 审核、导出、查看所有提交状态 |

### Bug修复

- 导出Excel使用share_plus（解决Android 11+权限问题）
- 历史周次统计显示实际人数（去重统计）
- 累计计算统一为迟到/2 + 缺勤
- 记名名单固定两列布局
- 提交卡片文字排版优化
- 实名页面响应式布局

### 技术改进

- 服务端目录结构重构
- Models/Schemas按领域拆分
- 周次系统统一使用服务端配置
- 学生名单更新（2022-2024级本科生，含性别）
- 新增 flutter_markdown、share_plus 依赖

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