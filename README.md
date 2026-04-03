# 查课 App

> 面向课堂查课场景的 Flutter App，支持点名、记名、考勤文本生成、本地优先+服务器同步。

---

## 功能特性

- **点名** — 按学号顺序逐人点名，支持多班级选择
- **记名** — 逐人标记考勤状态（到课/缺勤/请假/其他），支持多班级切换，自定义备注
- **确认名单** — 异常记录按班级分组展示，支持重新编辑
- **文本生成** — 一键生成总群汇报和学委汇报文本，复制即用
- **查课记录** — 查看、编辑历史记录，支持重新生成文本
- **中断恢复** — 记名任务异常退出后，再次打开可恢复进度
- **数据同步** — 本地优先离线可用，后台异步同步到服务器
- **公告系统** — 首次进入弹出公告，支持版本更新后重新弹出

## 技术栈

| 端 | 技术 |
|----|------|
| 客户端 | Flutter · Riverpod · go_router · Dio · Drift (SQLite) |
| 服务端 | FastAPI · SQLAlchemy · PyMySQL · MySQL 8 |
| 数据导入 | Python · openpyxl · pypinyin（带声调） |
| 部署 | 1Panel · Nginx 反向代理 · systemd · Let's Encrypt |

## 项目结构

```
LessonSearch/
├── app/            Flutter 客户端
├── server/         FastAPI 服务端
├── scripts/        Excel 导入脚本
├── docs/           文档
│   ├── dev-guide.md       开发文档
│   ├── deploy-guide.md    部署指南
│   └── tasks.md           任务表
├── data/           考勤表 Excel（.gitignore 排除）
└── CLAUDE.md       项目规范
```

## 快速开始

### 1. 克隆

```bash
git clone https://github.com/Keleoz-Cyber/LessonSearch.git
cd LessonSearch
```

### 2. Flutter 客户端

```bash
cd app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

### 3. 服务端

```bash
cd server
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env    # 编辑数据库配置
python -c "from models import Base; from database import engine; Base.metadata.create_all(engine)"
uvicorn main:app --reload --port 8000
```

### 4. 数据导入

```bash
cd scripts
pip install -r requirements.txt
cp ../server/.env .env
python excel_analyzer.py           # 分析 Excel 结构
python excel_importer.py           # 预览
python excel_importer.py --commit  # 正式导入
```

## 架构

```
Flutter App
  ├── UI 页面层
  ├── Notifier (业务逻辑)
  ├── Repository (统一数据访问)
  │     ├── LocalDataSource → Drift (SQLite)
  │     └── RemoteDataSource → Dio → HTTPS
  └── SyncService: SyncQueue → 异步同步
                                  ↓
                          FastAPI → MySQL
```

**本地优先**：所有操作先写入本地 SQLite，再通过 SyncQueue 异步同步到服务端。离线状态下完全可用，恢复网络后自动同步。

## API 文档

服务端运行后访问 Swagger UI：

```
http://localhost:8000/docs
```

主要接口：

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/grades` | 年级列表 |
| GET | `/api/majors` | 专业列表 |
| GET | `/api/classes` | 班级列表 |
| GET | `/api/students/by-class/{id}` | 按班级查学生 |
| POST | `/api/tasks` | 创建任务 |
| PUT | `/api/tasks/{id}` | 更新任务 |
| POST | `/api/tasks/{id}/records` | 创建考勤记录 |
| PUT | `/api/records/{id}` | 更新记录 |

## 数据库

**8 张本地表（SQLite）：** grades、majors、classes、students、attendance_tasks、task_classes、attendance_records、sync_queue

**7 张服务端表（MySQL）：** 同上（无 sync_queue）

支持两种 Excel 格式自动识别导入：考勤表格式（22级）和名单格式（23/24级），姓名拼音自动生成（带声调）。

## 文档

- [开发文档](docs/dev-guide.md) — 架构设计、数据库、API、开发环境搭建
- [部署指南](docs/deploy-guide.md) — 1Panel + 子域名 + HTTPS 部署
- [任务表](docs/tasks.md) — 开发阶段规划与进度

## 许可

本项目仅供学习使用，未经作者允许禁止分发。
