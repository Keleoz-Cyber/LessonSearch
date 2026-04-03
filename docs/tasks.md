

# 查课 App — 重构后开发任务表

> 基于 P0/P1/P2 审计结果，优先打通客户端-服务器联动链路。
> 更新日期：2026-04-01

---

## 已完成

### P0：Excel 导入 + MySQL 初始化 ✅
- scripts/config.py, models.py, init_db.py, excel_analyzer.py, excel_importer.py
- MySQL 基础 4 表：grades, majors, classes, students
- 3036 名学生数据已入库

### P1：FastAPI 基础 API ✅
- server/ 目录结构，GET 接口：grades, majors, classes, students
- 支持筛选和搜索

### P2：Flutter 项目骨架 ✅
- Drift 本地 8 张表（含 AttendanceTasks, AttendanceRecords, SyncQueue）
- Riverpod + go_router + Dio 骨架
- 首页 3 入口

---

## 待实施

### P3：服务端任务系统接口
**目标：** 让服务端具备任务 CRUD 能力

| 序号 | 任务 | 文件 | 操作 |
|------|------|------|------|
| 3.1 | MySQL 新增任务系统表 | server/models.py | 追加 AttendanceTask / TaskClass / AttendanceRecord |
| 3.2 | 新增请求/响应 Schema | server/schemas.py | 追加 TaskCreate / TaskOut / RecordCreate / RecordUpdate / RecordOut |
| 3.3 | 新增任务 CRUD 路由 | server/routers/tasks.py | 新建：POST/GET/PUT |
| 3.4 | 新增记录 CRUD 路由 | server/routers/records.py | 新建：POST/PUT/GET |
| 3.5 | 注册新路由 | server/main.py | 追加 2 行 |
| 3.6 | Flutter ApiClient 增加写方法 | app/lib/core/network/api_client.dart | 追加 POST/PUT |
| 3.7 | Drift 表补 syncStatus | app/lib/core/database/tables.dart | 改 1 行 + 重新生成 |

**验收：**
- curl POST /api/tasks 创建任务 → MySQL 可见
- curl POST /api/tasks/{id}/records 创建记录 → MySQL 可见
- curl PUT /api/tasks/{id} 更新状态 → MySQL 更新
- Flutter ApiClient 方法可编译

---

### P4：Flutter Domain 模型 + Repository + DataSource
**目标：** 建立正确分层，数据访问通过 Repository

| 序号 | 任务 | 文件 |
|------|------|------|
| 4.1 | 创建 domain 模型（freezed） | features/attendance/domain/models.dart |
| 4.2 | 本地数据源 | features/attendance/data/local/attendance_local_ds.dart |
| 4.3 | 远程数据源 | features/attendance/data/remote/attendance_remote_ds.dart |
| 4.4 | AttendanceRepository | features/attendance/data/attendance_repository.dart |
| 4.5 | StudentRepository | features/student/data/student_repository.dart |
| 4.6 | Provider 注册 | shared/providers.dart 扩展 |

**验收：**
- Repository.createTask() → 写 Drift + 入队 SyncQueue
- Repository.updateRecordStatus() → 写 Drift + 入队 SyncQueue
- 页面层不直接操作 DB

---

### P5：SyncService 最小闭环
**目标：** SyncQueue 记录被消费并发送到服务端

| 序号 | 任务 | 文件 |
|------|------|------|
| 5.1 | SyncService 实现 | core/sync/sync_service.dart |
| 5.2 | 启动时自动扫描 pending 队列 | main.dart 或 Provider 初始化 |
| 5.3 | 失败重试逻辑（retryCount） | sync_service.dart |
| 5.4 | 联调测试页（临时） | features/debug/sync_test_page.dart |

**验收（最小联调闭环）：**
1. Flutter 创建 AttendanceTask → Drift 写入 → SyncQueue 入队
2. SyncService 消费 → POST /api/tasks → MySQL 出现记录
3. Flutter 更新学生状态 → Drift 写入 → SyncQueue 入队
4. SyncService 消费 → POST /api/tasks/{id}/records → MySQL 出现记录
5. 断网操作不报错，恢复后自动同步

---

### P6：首页 + 选择页 + 最小点名流程
**目标：** 第一个真实业务闭环

| 序号 | 任务 |
|------|------|
| 6.1 | 选择页（年级→专业→班级，数据来自 Repository） |
| 6.2 | 点名执行页（当前学生/拼音/班级，下一位，结束） |
| 6.3 | Controller/Notifier 管理任务状态 |
| 6.4 | 创建→点名→结束 全程同步服务端 |

**验收：** 从选择到结束，服务端能看到完整任务和记录

---

### P7：最小记名流程
**目标：** 记名流程联调闭环

| 序号 | 任务 |
|------|------|
| 7.1 | 记名选择页（班级多选） |
| 7.2 | 记名执行页（多班切换、状态标记） |
| 7.3 | 进度显示 |

**验收：** 多班记名全程同步到服务端

---

### P8：确认页 + 文本生成 + 中断恢复
**目标：** 补全流程尾部 + 基础恢复

| 序号 | 任务 |
|------|------|
| 8.1 | 记名确认页（异常名单按班分组） |
| 8.2 | 文本生成（可配置模板） |
| 8.3 | 启动时检查未完成任务 → 弹窗继续/放弃 |

---

### P9：记录系统 + 编辑 + 重同步

| 序号 | 任务 |
|------|------|
| 9.1 | 记录列表页 |
| 9.2 | 记录详情/编辑页 |
| 9.3 | 编辑后更新 updatedAt + 重新同步 |
| 9.4 | 文本重新生成 |

---

### P10：UI 优化 + 异常处理 + 恢复增强

| 序号 | 任务 |
|------|------|
| 10.1 | 主题/配色/动画优化 |
| 10.2 | 错误提示 UI |
| 10.3 | 完整恢复体验（恢复到精确页面和状态） |
| 10.4 | 边界情况处理 |
