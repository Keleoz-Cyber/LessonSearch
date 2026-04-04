# 查课 App — 开发任务表

> 更新日期：2026-04-04
> 当前版本：0.2.4

---

## 已完成

### P0：Excel 导入 + MySQL 初始化 ✅
- scripts/ 目录：config.py, models.py, init_db.py, excel_analyzer.py, excel_importer.py
- MySQL 基础 4 表：grades, majors, classes, students
- 支持两种 Excel 格式自动识别（考勤表格式 + 名单格式）
- 拼音带声调生成（pypinyin TONE）
- 班级唯一约束：(grade_id, major_id, class_code)
- 3036 名学生数据已入库

### P1：FastAPI 基础 API ✅
- server/ 目录，GET 接口：grades, majors, classes, students
- 支持按年级/专业筛选班级，支持学生搜索

### P2：Flutter 项目骨架 ✅
- Drift 本地 8 张表（含 AttendanceTasks, AttendanceRecords, SyncQueue）
- Riverpod + go_router + Dio
- 首页 3 入口 + 设置入口

### P3：服务端任务系统接口 ✅
- AttendanceTask / TaskClass / AttendanceRecord 模型 + CRUD 路由
- Flutter ApiClient 全部写方法

### P4：Flutter 分层架构 ✅
- Domain 模型：6 枚举（TaskType, TaskStatus, TaskPhase, AttendanceStatus, SyncStatus）+ 领域类
- LocalDataSource：Drift 操作封装 + 批量事务操作
- RemoteDataSource：API 调用封装
- AttendanceRepository：写本地 → 入队 SyncQueue
- StudentRepository：远程拉取 + 本地缓存 + 按需加载

### P5：SyncService ✅
- 消费 SyncQueue，10 秒轮询
- 自动重试（retryCount < 5），网络异常跳过
- 端到端链路验证通过

### P6：选择页 + 点名 ✅
- 选择页：年级→专业→班级多选，全选/取消全选
- 点名：按学号顺序，多班级，班级信息实时切换
- 退出弹窗：继续/放弃/保存退出（保存时持久化进度）
- 恢复点名：从查课记录"继续"按钮跳回上次位置

### P7：记名 ✅
- 记名选择页：班级多选 FilterChip
- 记名执行页：多班切换，状态网格（自适应列数），底部操作栏
- 状态：到课/缺勤/迟到/请假/其他（自定义备注）
- 确认弹窗：未处理自动标记为已到

### P8：确认页 + 文本生成 + 中断恢复 ✅
- 确认页：异常名单按班分组，重新编辑/确认
- 文本生成：总群汇报 + 学委汇报，可配置模板，含查课时间
- 中断恢复：仅记名 executing 阶段，恢复到执行页含已标记状态

### P9：查课记录 ✅
- 记录列表：卡片显示类型/班级/统计/日期/状态标签
- 点名记录：只读查看（已点/未点，全班学生），"已完成"/"进行中"标签
- 记名记录：可编辑状态，重新生成文本
- 进行中任务："继续"按钮恢复到上次位置

### P10：UI 优化 + 其他 ✅
- 加载遮罩、响应式布局、SafeArea、FittedBox
- 批量 DB 事务操作（减少掉帧）
- 设置页、关于页、公告系统（版本号控制）
- Gradle 阿里云镜像

---

## 待实施

| 项目 | 说明 | 优先级 |
|------|------|--------|
| Drift schema migration | 避免表结构变更需要卸载重装 | 高 |
| 检查更新功能 | 设置页占位，未实现 | 中 |
| 文本模板配置化 | 目前是代码常量，应支持用户自定义 | 中 |
| 数据导出 | Excel/PDF 导出考勤数据 | 中 |
| 统计分析 | 缺勤趋势、班级对比图表 | 低 |
| 多用户 + 登录 | 权限控制 | 低 |
| iOS 适配 | 已有指南 docs/ios-guide.md，待执行 | 进行中 |

---

## 已知问题

- 本地 SQLite 无 migration，表结构变更需卸载 App 重装
- SyncService 在主 isolate，大量同步时可能微卡
- 记名恢复后 remark 字段可能丢失（fromString 映射）
