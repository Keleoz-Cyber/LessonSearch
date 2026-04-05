# 查课 App — 开发任务表

> 更新日期：2026-04-04
> 当前版本：0.3.6

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

### P11：邮箱验证码登录 ✅ (v0.3.0)
- 服务端：users + verification_codes + invitation_codes 表
- 服务端：/api/auth/send-code、/api/auth/login、/api/auth/register、/api/auth/me 接口
- 服务端：SMTP 发送验证码（QQ邮箱）
- 服务端：JWT token 认证（7天过期）
- 客户端：登录页面、注册页面、AuthService、token 管理
- 客户端：ApiClient 自动携带 token
- 一人一码邀请机制（仅注册时需要邀请码）
- 数据隔离：登录后创建的任务绑定 user_id

### P12：暗色模式 ✅ (v0.3.0)
- 设置页主题切换：跟随系统/亮色/暗色
- 主题持久化到 SharedPreferences
- 记名名单暗色适配

### P13：暗色模式 ✅ (v0.3.0)
- 设置页主题切换：跟随系统/亮色/暗色
- 主题持久化到 SharedPreferences
- 记名名单暗色适配

### P14：扩展功能入口 ✅ (v0.3.0)
- 首页扩展功能入口
- 扩展功能页：导入查课信息、名单提交、周名单汇总、排行榜（暂未实现）

### P15：登录注册分离 ✅ (v0.3.1)
- 登录页：只需邮箱+验证码
- 注册页：邮箱+验证码+邀请码
- 老用户登录无需邀请码

### P16：性能优化 ✅ (v0.3.1)
- NameCheckState 缓存计算字段
- GridView 添加 key 减少 Widget 重建
- SyncService 增加同步间隔和批量限制

### P17：数据库迁移 ✅ (v0.3.2)
- 添加 Drift migration 策略
- 支持从 v1 平滑升级到 v2
- 无需卸载重装

### P18：检查更新功能 ✅ (v0.3.3)
- 服务端 `/api/version` 接口
- 客户端检查更新并显示下载链接
- GitHub Releases API 中转缓存

### P19：性能优化与体验改进 ✅ (v0.3.5)
- 数据加载优化：并行加载、增量更新、版本检查
- Toast 提示：悬浮弹幕替代 SnackBar
- 请假颜色：从橙色改为蓝色，区分迟到
- 登录限制：未登录无法使用功能，保护隐私数据
- 注册错误提示：区分验证码错误/邮箱已注册/邀请码无效/邀请码已使用

### P20：Bug修复与体验优化 ✅ (v0.3.6)
- 手势返回：修复与返回按钮行为不一致问题
- 确认页恢复：修复手势返回导致无限加载问题
- 任务恢复：未登录时不提示恢复任务
- 响应式布局：优化所有页面适配不同屏幕
- 振动反馈：新增设置开关，操作时振动提示
- 登录状态：登录/退出后界面立即刷新
- 班级选择：优化布局，选中不移动其他按钮

---

## 待实施

| 项目 | 说明 | 优先级 |
|------|------|--------|
| 文本模板配置化 | 目前是代码常量，应支持用户自定义 | 中 |
| 数据导出 | Excel/PDF 导出考勤数据 | 中 |
| 统计分析 | 缺勤趋势、班级对比图表 | 低 |
| 跨设备同步 | 登录后从服务端拉取数据 | 低 |
| iOS 适配 | 已有指南 docs/ios-guide.md，待执行 | 进行中 |

---

## 已知问题

- SyncService 在主 isolate，大量同步时可能微卡
- 记名恢复后 remark 字段可能丢失（fromString 映射）
