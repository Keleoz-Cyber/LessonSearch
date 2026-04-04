# 查课 App

> 面向课堂查课场景的 Flutter App，支持点名、记名、考勤文本生成、本地优先+服务器同步。

## 功能

- **点名** — 按学号顺序逐人点名，多班级，支持中途保存和继续
- **记名** — 逐人标记状态（到课/缺勤/迟到/请假/其他），多班切换，自定义备注
- **确认名单** — 异常记录按班分组，支持重新编辑
- **文本生成** — 一键生成总群汇报和学委汇报，复制即用
- **查课记录** — 查看、编辑历史记录，继续未完成任务
- **中断恢复** — 记名任务异常退出后恢复进度
- **数据同步** — 本地优先离线可用，后台异步同步服务器
- **公告系统** — 版本更新自动弹出

## 技术栈

| 端 | 技术 |
|----|------|
| 客户端 | Flutter · Riverpod · go_router · Dio · Drift (SQLite) |
| 服务端 | FastAPI · SQLAlchemy · PyMySQL · MySQL 8 |
| 数据导入 | Python · openpyxl · pypinyin |
| 部署 | 1Panel · Nginx · systemd · HTTPS |

## 项目结构

```
LessonSearch/
├── app/            Flutter 客户端（31 个 Dart 源文件）
├── server/         FastAPI 服务端（12 个 Python 文件）
├── scripts/        Excel 导入脚本
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
- [docs/dev-guide.md](docs/dev-guide.md) — 开发文档
- [docs/ios-guide.md](docs/ios-guide.md) — iOS 适配指南
- [docs/tasks.md](docs/tasks.md) — 任务表

## API

Swagger 文档：https://api.keleoz.cn/docs

## 许可

本项目仅供学习使用，未经作者允许禁止分发。
