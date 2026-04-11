# 考勤助手

> 面向课堂查课场景的 Flutter App，支持点名、记名、考勤文本生成、本地优先+服务器同步。

**当前版本：v0.5.0**（2026-04-11）

## v0.5.0 更新日志

### 🎯 代码重构

- 服务端目录结构重构：`server/app/` 结构（core/models/schemas/routers/services）
- Models/Schemas 按领域拆分（user/student/task/record）
- Core 模块独立（config/database/security/exceptions）
- 构建脚本统一移至 `scripts/`
- 文档整合优化

### 🐛 Bug 修复

1. **记名重新编辑不自动跳转**
   - 从确认名单页返回编辑时，修改状态不再自动切换班级
   - 新增 `isEditing` 状态标记区分正常流程和编辑模式

2. **iOS 微信/QQ 检测修复**
   - 添加 `LSApplicationQueriesSchemes` 声明
   - iOS 9+ 可正常检测微信/QQ是否安装

3. **查课记录编辑滚动位置**
   - 修改状态后保持滚动位置，不再刷新到列表开头
   - 使用 `recordId` 直接更新条目，避免全量刷新

4. **查课记录编辑索引错误**
   - 修复过滤列表中索引错位导致修改错误条目的问题
   - 用 `recordId` 查找正确条目，不依赖列表索引

### ✨ 功能改进

5. **点名记录两列布局**
   - 点名详情改为两列网格显示，更紧凑
   - 使用 Wrap + LayoutBuilder 实现响应式布局

6. **学委汇报按班级分开复制**
   - 文本生成页：每个班级独立卡片，单独复制按钮
   - 查课记录详情页：同样支持按班级分开复制
   - 便于逐个发送给各班学委

7. **状态标签统一**
   - 记名详情"到"改为"到课"，与其他两字状态统一

8. **点名上一个+预览界面**
   - 新增"上一个"按钮，撤销上一位点名记录
   - 预览区显示"已点"上三位和"下一位"学生
   - 防止误操作，让用户清楚看到附近学生

---

## 功能

- **点名** — 按学号顺序逐人点名，多班级，支持中途保存和继续，可撤销上一位
- **记名** — 逐人标记状态（到课/缺勤/迟到/请假/其他），多班切换，自定义备注
- **确认名单** — 异常记录按班分组，支持重新编辑
- **文本生成** — 一键生成总群汇报和学委汇报，学委汇报按班级分开复制
- **查课记录** — 查看、编辑历史记录，继续未完成任务
- **中断恢复** — 记名任务异常退出后恢复进度
- **数据同步** — 本地优先离线可用，后台异步同步服务器
- **邮箱登录** — 邮箱验证码登录注册，登录注册分离，一人一码邀请机制
- **暗色模式** — 支持跟随系统/亮色/暗色三种主题
- **检查更新** — App 内检查新版本并跳转下载
- **公告系统** — 版本更新自动弹出

## 技术栈

| 端 | 技术 |
|----|------|
| 客户端 | Flutter · Riverpod · go_router · Dio · Drift (SQLite) |
| 服务端 | FastAPI · SQLAlchemy · PyJWT · MySQL 8 |
| 数据导入 | Python · openpyxl · pypinyin |
| 部署 | 1Panel · Nginx · systemd · HTTPS |

## 项目结构

```
LessonSearch/
├── app/            Flutter 客户端
├── server/         FastAPI 服务端
├── scripts/        Excel 导入脚本 + 邀请码生成
├── docs/           文档
└── AGENT.md        AI Agent 协作指南
```

## 快速开始

```bash
# Flutter
cd app && flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run

# 服务端
cd server && pip install -r requirements.txt
cp .env.example .env  # 编辑数据库配置
uvicorn main:app --reload --port 8000

# 数据导入
cd scripts && pip install -r requirements.txt
python excel_importer.py --commit
```

## 文档

- [AGENT.md](AGENT.md) — AI Agent 协作指南（接手必读）
- [CLAUDE.md](CLAUDE.md) — 项目规范与约束
- [docs/dev-guide.md](docs/dev-guide.md) — 开发文档
- [docs/tasks.md](docs/tasks.md) — 任务表
- [docs/invitation-codes.md](docs/invitation-codes.md) — 邀请码管理指南

## API

Swagger 文档：https://api.keleoz.cn/docs

## 许可

本项目仅供学习使用，未经作者允许禁止分发。
