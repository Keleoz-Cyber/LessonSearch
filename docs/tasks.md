# 查课 App — 开发任务表

> 更新日期：2026-04-04
> 当前版本：0.2.3

---

## 已完成

### P0：Excel 导入 + MySQL 初始化 ✅
- scripts/ 目录：config.py, models.py, init_db.py, excel_analyzer.py, excel_importer.py
- MySQL 基础 4 表：grades, majors, classes, students
- 支持两种 Excel 格式自动识别（考勤表 + 名单格式）
- 拼音带声调生成（pypinyin TONE）
- 3036 名学生数据已入库

### P1：FastAPI 基础 API ✅
- server/ 目录：GET 接口（grades, majors, classes, students）
- 支持筛选和搜索

### P2：Flutter 项目骨架 ✅
- Drift 本地 8 张表（含 AttendanceTasks, AttendanceRecords, SyncQueue）
- Riverpod + go_router + Dio 骨架
- 首页 3 入口

### P3：服务端任务系统接口 ✅
- server/models.py：AttendanceTask / TaskClass / AttendanceRecord
- server/routers/tasks.py：POST/GET/PUT 任务
- server/routers/records.py：POST/GET/PUT 记录
- Flutter ApiClient：createTask/getTask/updateTask/createRecords/updateRecord
- Drift AttendanceTasks 加 syncStatus 字段

### P4：Flutter Domain 模型 + Repository + DataSource ✅
- attendance/domain/models.dart：5 枚举 + 领域模型
- attendance/data/local/attendance_local_ds.dart：Drift 操作封装 + 批量操作
- attendance/data/remote/attendance_remote_ds.dart：API 调用封装
- attendance/data/attendance_repository.dart：统一仓库（写本地→入队同步）
- student/data/student_repository.dart：学生数据（含远程拉取+批量事务）
- shared/providers.dart：全局 Provider 注册

### P5：SyncService 最小闭环 ✅
- core/sync/sync_service.dart：消费 SyncQueue + 自动重试 + 网络异常检测
- features/debug/sync_test_page.dart：联调测试页
- 端到端联调验证通过（Flutter → Drift → SyncQueue → HTTPS → FastAPI → MySQL）

### P6：选择页 + 最小点名流程 ✅
- 选择页（年级→专业→班级多选，全选/取消全选）
- 点名执行页（按学号顺序，多班级支持，班级信息实时切换）
- 退出弹窗：继续/放弃/保存退出

### P7：最小记名流程 ✅
- 记名选择页（班级多选 FilterChip）
- 记名执行页（多班切换、状态网格、自适应列数）
- 底部栏：缺勤/迟到/请假/其他/到课
- "其他"状态自定义备注输入
- 确认弹窗：未处理的自动标记为已到

### P8：确认页 + 文本生成 + 中断恢复 ✅
- 确认页：异常名单按班级分组（缺勤/迟到/请假/其他）
- 文本生成：总群汇报 + 学委汇报，可配置模板，复制到剪贴板
- 汇报文本包含查课时间（精确到分钟）
- 学委汇报附带到场证明和假条提醒
- 中断恢复：仅记名任务 executing 阶段，恢复到执行页（含已标记状态）
- 退出弹窗：继续/放弃/保存退出

### P9：查课记录系统 ✅
- 记录列表：按时间倒序，卡片显示类型/班级/统计/日期/状态标签
- 点名记录：只读查看（已点/未点），标题"点名记录"
- 记名记录：可编辑状态，生成文本，标题"记名详情"
- 保存退出的任务显示"进行中"标签
- 删除记录确认

### P10：UI 优化 + 异常处理 ✅
- 首页：同步状态指示器，调试入口隐藏（长按标题）
- 加载遮罩：半透明背景 + 转圈 + 提示文字
- 响应式布局：自适应列数、FittedBox、SafeArea、ScrollView
- 批量 DB 操作优化（事务写入，减少掉帧）
- 网络异常友好处理（跳过剩余队列）
- 学生卡片文字溢出保护

### 其他已完成功能
- 设置页：应用信息、版本号、查看公告、检查更新（占位）、开发者与致谢
- 公告系统：首次进入弹出，版本号控制重新弹出，含更新内容栏
- iOS 适配指南：docs/ios-guide.md
- 开发文档：docs/dev-guide.md
- 服务端部署完成：https://api.keleoz.cn（1Panel + HTTPS）
- Gradle 阿里云镜像配置

---

## 待实施 / 后续可做

| 项目 | 说明 | 优先级 |
|------|------|--------|
| Drift schema migration | 避免每次表结构变更需要卸载重装 | 高 |
| 检查更新功能 | 目前为占位 | 中 |
| 文本模板数据库配置化 | 目前是代码常量 | 中 |
| 数据导出 | Excel/PDF 导出 | 中 |
| 统计分析 | 缺勤趋势、班级对比 | 低 |
| 多用户 + 登录系统 | 权限控制 | 低 |
| iOS 适配 | 已有指南，待执行 | 进行中 |
| UI 主题美化 | 配色/动画/图标 | 低 |
