# AGENT.md — AI Agent 协作指南

> 本文档面向接手此项目的 AI Agent。请在开始任何工作前完整阅读此文件。
> 最后更新：2026-05-01 · 当前版本：v0.6.0
> 
> 项目：考勤助手（查课 App）· 课堂考勤 Flutter 应用（Android 优先）
> 仓库：https://github.com/Keleoz-Cyber/LessonSearch
> 服务端：https://api.keleoz.cn（FastAPI + MySQL）
> API 文档：https://api.keleoz.cn/docs

---

## 一、项目概述

考勤助手是面向课堂查课场景的 Flutter App，采用**本地优先 + 服务器异步同步**架构。

### 核心功能

| 功能 | 说明 |
|------|------|
| 点名 | 按学号顺序逐人点名，支持多班级、撤销上一位 |
| 记名 | 逐人标记考勤状态（到课/缺勤/迟到/请假/其他），固定两列布局 |
| 查课记录 | 展示每次查课记录，支持查看和编辑，保留修改时间 |
| 名单提交 | 成员提交记名任务（分开提交），管理员审核 |
| 周名单汇总 | 管理员审核、导出Excel（含请假/其他列）、发布汇总 |
| 实名制 | 登录后必须填写真实姓名，路由+首页双重检查 |
| 数据隔离 | 登出清空本地用户数据 |
| 实时公告 | 从服务端获取公告内容，Markdown渲染 |
| 排行榜 | 支持近7天/近30天/总榜，多榜单统计与规则说明 |
| 同步保护 | 启动自动同步、失败重试、提交前确认、后台静默同步 |
| 隐私政策 | 应用内查看完整的隐私政策和用户协议 |

### 技术栈

| 端 | 技术 |
|----|------|
| 客户端 | Flutter 3.43、Riverpod 2.6、go_router 14、Dio、Drift 2.28、flutter_markdown、share_plus |
| 服务端 | FastAPI、SQLAlchemy、PyJWT、MySQL 8、openpyxl |
| 部署 | 1Panel、Nginx反向代理、systemd、Let's Encrypt HTTPS |

---

## 二、工作方式要求（必读）

### 总原则
- **先规划，后实现**
- **先做可运行骨架，再逐步补功能**
- **先保证架构正确，再优化 UI**
- 不要一上来生成巨型 demo 文件
- 不要把复杂业务逻辑堆在页面层
- 每完成一个阶段都必须能运行、能验证

### 写代码流程
当我要求"开始写代码"时：
1. 先说明本次只做哪个子模块
2. 先给目录树和文件清单
3. 再分文件生成代码
4. **不要一次性生成整个项目所有文件**
5. 每完成一批文件，要说明用途和运行方式

### 实施顺序

当前项目已完成 v0.6.0，后续如需新增功能，优先顺序：
1. 项目规划与数据设计
2. Excel 名单导入数据库脚本
3. MySQL 基础表设计
4. GitHub 仓库结构与规则
5. Flutter 本地数据库与任务系统骨架
6. 首页和路由
7. 点名流程
8. 记名流程
9. 确认页与文本生成
10. 记录系统
11. 同步与恢复
12. UI 与异常处理优化

---

## 三、架构

### 分层架构

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

### 架构原则

1. **统一任务系统**：点名和记名必须统一抽象为"查课任务系统"，不能做成两套完全割裂的逻辑
2. **本地优先**：所有查课操作都必须先写本地数据库，再异步同步服务器
3. **离线可用**：无网状态下必须能正常使用点名、记名、记录查看和任务恢复
4. **中断恢复**：应用启动时必须检查是否存在未完成任务，若有则提示继续或放弃
5. **模板可配置**：总群汇报和学委文本模板必须配置化，不允许硬编码在页面中

---

## 四、目录结构

```
app/lib/
├── main.dart
├── app.dart
├── core/
│   ├── database/      # Drift表定义（tables.dart）
│   ├── network/       # ApiClient
│   ├── router/        # go_router
│   ├── sync/          # SyncService
│   ├── resume/        # 任务恢复检查
│   ├── announcement/  # 公告系统
│   └── feedback/      # 振动/音效反馈
├── features/
│   ├── attendance/    # 点名、记名、文本生成
│   ├── extension/     # 名单提交、周名单汇总
│   ├── auth/          # 登录、实名制
│   ├── records/       # 查课记录
│   ├── ranking/       # 排行榜
│   ├── settings/      # 设置、致谢、隐私政策
│   └── debug/         # 调试工具
└── shared/
    └── providers.dart

server/
├── main.py
├── app/
│   ├── core/          # config, database, security
│   ├── models/        # user, student, task, submission
│   ├── schemas/       # Pydantic模型
│   ├── routers/       # API路由
│   └── services/     # 业务逻辑
└── migrations/       # SQL迁移脚本

scripts/
├── config.py
├── models.py
├── excel_importer.py
└── import_students_2022plus.py  # 新版导入脚本
```

---

## 五、代码规则

### 页面层规则
- 页面层禁止直接操作数据库
- 页面层禁止直接写复杂业务逻辑
- 页面层只负责展示、事件分发、简单交互

### 业务层规则
- 核心逻辑进入 controller / notifier / service / usecase 层
- 点名与记名共用统一任务模型
- 同步逻辑必须集中管理

### 数据层规则
- Repository 统一管理数据访问
- 本地数据库与远程接口访问必须解耦
- 同步队列必须独立建模
- 记录编辑后必须更新修改时间

### 输出要求
- 不要把所有内容塞进单个文件
- 必须按模块拆分
- 每阶段都应可运行、可验证
- 优先保证架构正确，再优化 UI

---

## 六、数据库

### 本地 SQLite（Drift）— 8张表

| 表 | 说明 |
|----|------|
| grades | 年级 |
| majors | 专业 |
| classes | 班级 |
| students | 学生（含gender字段） |
| attendance_tasks | 考勤任务 |
| attendance_records | 考勤记录 |
| task_classes | 任务-班级关联 |
| sync_queue | 同步队列 |

### 服务端 MySQL — 14张表

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
| ranking_cache | 排行榜缓存 |
| ranking_summary | 排行榜汇总 |

详细表结构见 `docs/dev-guide.md` 第四章。

---

## 七、关键业务流程

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
    │   └── 导出Excel → 分享文件
    └── 历史周次Tab：查看历史已发布汇总
```

### 周次系统

- 所有周次相关功能使用服务端 `week_config.start_date` 计算
- 周一零点为新的一周开始
- 计算公式：`week_number = (current_date - start_date).days // 7 + 1`
- 提交、汇总、审核全部按周次维度

---

## 八、同步保护机制（v0.6.0 核心优化）

### 机制说明

- **后台静默同步**：同步在后台进行，不显示进度条，不干扰用户操作
- **启动自动同步**：打开App自动检测待同步/失败记录，自动重试
- **失败重试**：同步失败记录自动重置并重试，最多5次
- **提交前强制同步**：提交前自动同步，失败则阻止提交并提示
- **同步完成提示**：启动同步完成后显示 SnackBar（2秒自动消失）

### 代码位置

- `app/lib/core/sync/sync_service.dart` — 同步服务
- `app/lib/app.dart` — 启动同步检查
- `app/lib/features/home/presentation/home_page.dart` — 未同步警告卡片
- `app/lib/features/extension/presentation/submission_page.dart` — 提交前同步

---

## 九、服务端维护操作

以下操作由程序员/运维通过SSH操作：

```bash
# 分配管理员角色
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "UPDATE users SET role='admin' WHERE id=用户ID;"

# 设置新学期周次（start_date必须是周一）
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "UPDATE week_config SET is_active=FALSE; INSERT INTO week_config (start_date, semester_name, is_active) VALUES ('2026-09-07', '新学期', TRUE);"

# 分配查课职务
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "INSERT INTO duty_assignments (user_id, assigned_by) VALUES (用户ID, 管理员ID);"

# 取消职务
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "UPDATE duty_assignments SET is_active=FALSE, deactivated_at=NOW() WHERE user_id=用户ID;"

# 发布公告
docker exec -i 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search -e "INSERT INTO announcements (version, title, content, is_active, created_by) VALUES (版本号+1, '标题', '内容', TRUE, 管理员ID);"

# 生成邀请码
cd /opt/lesson-search/scripts
source ../venv/bin/activate
python generate_invitation_codes.py 10
```

### 服务管理

```bash
# 重启服务
systemctl restart lesson-search.service

# 查看日志
journalctl -u lesson-search.service -f

# 查看状态
systemctl status lesson-search.service
```

---

## 十、开发环境

```bash
# Flutter 客户端
cd app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run

# 服务端
cd server
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000

# 数据导入
cd scripts
pip install pandas pypinyin openpyxl sqlalchemy pymysql
python import_students_2022plus.py --commit --clear
```

### 版本发布流程

1. **更新版本号**
   - `app/pubspec.yaml`: `version: X.X.X+Y`
   - `app/lib/features/settings/presentation/settings_page.dart`: 版本显示

2. **更新公告**
   - `app/lib/core/announcement/announcement_config.dart`
   - `announcementVersion` +1
   - 更新 `announcementContent` 和 `updateNotes`

3. **更新文档**
   - `AGENT.md` 版本号
   - `docs/dev-guide.md` 版本号
   - `docs/tasks.md` 版本历史

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

6. **打 Tag 触发 GitHub Actions 自动构建**
   ```bash
   git tag vX.X.X
   git push origin vX.X.X
   ```

---

## 十一、GitHub 规则

### 分支建议
- `main`：稳定版本
- `dev`：开发集成
- `feature/*`：功能开发
- `fix/*`：问题修复
- `docs/*`：文档更新

### 提交规范
采用 Conventional Commits 风格：
- `feat:` 新功能
- `fix:` 修复
- `refactor:` 重构
- `docs:` 文档
- `chore:` 杂项

### 禁止提交
- 原始学生 Excel 数据
- `.env`
- 本地数据库文件
- 构建产物
- 日志文件
- 临时测试数据
- IDE 私有配置

---

## 十二、常见陷阱

1. **周次计算必须用服务端API** — 不能用本地时间
2. **DioException用 `e.response?.data['detail']` 提取错误**
3. **Drift查询 `select(table).get()` 返回列表**
4. **FastAPI路由顺序** — 动态路径要在静态路径之后
5. **服务器仅 2GB 内存** — 注意内存使用，精简监控 agent
6. **server/app 目录被 .gitignore** — 提交需 `git add -f`

---

## 十三、相关文档

| 文档 | 说明 |
|------|------|
| `docs/dev-guide.md` | 完整开发文档（API接口、数据库设计、部署指南） |
| `docs/tasks.md` | 开发任务表与版本历史 |
| `docs/invitation-codes.md` | 邀请码管理指南 |
| `docs/incident-2026-04-20-server-overload.md` | 服务器故障报告 |

---

## 十四、Excel 数据导入规则

### 当前已知情况
当前 Excel 数据并不规范，通常只有：
- 学生姓名
- 学号

而以下信息可能出现在：
- 文件名
- sheet 名称
- 表头
- 前几行说明文字
- 其他位置

### 导入脚本必须满足
1. 扫描指定目录下所有 Excel 文件
2. 支持 xlsx / xls
3. 自动分析每个 Excel 文件和 sheet 的结构
4. 自动尝试从文件名、sheet 名、表头、前几行文本中提取年级、专业、班级
5. 自动识别学生数据区域
6. 自动识别"姓名"列和"学号"列
7. 若无拼音字段，自动生成姓名拼音
8. 做字段清洗
9. 做重复校验和学号唯一性检查
10. 支持 dry-run
11. 支持重复执行避免重复插入和脏数据
12. 生成导入日志和异常报告
13. 对无法确定的信息输出"待人工确认"结果，不允许静默跳过

### 导入脚本设计要求
- 先分析 Excel 结构
- 再提出推荐模板规范
- 再设计导入流程
- 优先保证稳健性和可追踪性
