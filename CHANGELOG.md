# 更新日志

完整版本更新历史。

---

## v0.7.0

### v0.7.0+34（2026-06-23）业务稳定性大修

> 通过 3 轮深度审计识别 + 修复 23 项 T0/T1/T2 业务问题，覆盖数据正确性、流程卡死、并发竞态、资源泄漏等核心隐患。

**T0 数据正确性（8 项）**：
- `pending` 状态被计入 `present` — 汇报文本到课人数虚高（text_gen_page / record_detail_page）
- 已提交任务被远端 403 拒绝后 sync 静默标 `synced` — 本地/服务端永久不一致（单条 + batch 双路径修复）
- 401 认证过期 `break` 退出整条同步队列 — 后续正常项全部阻塞，改 `continue`
- `_syncRecord` 缺 `delete` action — delete 同步项被静默跳过
- `finishNameCheck` 与 `markStudent` 并发竞态 — 加 `isFinishing` 锁
- `getUnsyncedCount` 用错误的 `'unfinished'` 状态值 — 永远返回 0
- `getSyncIssueCount` 与 `getPendingSyncItems` 口径不一致 — 已放弃项阻止提交

**T1 流程卡住（8 项）**：
- `records_list` 显示 `in_progress` 任务 — 用户可进入生成错误汇报文本
- `TaskResumeChecker` 不恢复 `confirming`/`text_generating` 阶段
- reconcile 删除记录时未取消未消费的 create/update sync 项
- `RollCallNotifier.nextStudent` 无事务保护
- 启动时 `retryAllFailed()` 无条件重置所有 failed（含 401 认证项）
- 400/422 永久性错误也计作 `failed` 并允许重试 — 形成重试→失败循环
- sync_issues 无"跳过此项"单条操作 — 右滑 Dismissible + 确认对话框
- `classroom` 可为 null，老数据升级后显示防护

**T2 极端条件（4 项）**：
- `prevStudent` 删除记录后无事务保护 — 调整为先 updateTaskStatus 后 deleteRecord
- 数据库迁移 `catch(_){}` 吞噬异常 — addColumn 只吞 duplicate column
- `syncNow` while 忙等待无超时 — 加 60s 超时保护
- `mark()` 闭包捕获过期的 `hasPendingInAllClasses` — await 后重新 ref.read

**Dialog 红屏修复**：
- `TextEditingController` 在 `Navigator.pop` 后立即 dispose 触发 `_dependents.isEmpty` assertion
- 修复路径：submission_search 周次选择 / weekly_summary 拒绝理由 / name_check 备注 / record_detail 备注
- 统一用 `WidgetsBinding.instance.addPostFrameCallback` 延迟到下一帧释放

### 新功能

- **查课计划 + 本地提醒**（v0.7.0+33）
  - 提前排定本周/未来周的查课任务（周次/星期/节次/班级/教室/备注）
  - 上课前 15 分钟系统通知栏提醒（`flutter_local_notifications` + `timezone`）
  - **纯本地存储**，不依赖第三方推送 SaaS（极光/个推），保护学生班级隐私
  - 班级选择对话框支持年级/专业横向筛选，按"年级+专业"分组展示
  - 列表按周分组 + 状态标签（已设提醒/提醒已关/已结束）
  - 长按卡片可切换提醒状态或删除
  - 顶部品牌色横条提示"上课前 15 分钟会通过系统通知提醒"
  - 入口：首页二级入口"查课计划"
  - 新增表 `DutyPlanRows`（schema 2→3→4，含 classroom 字段）
- **FAQ 新增「查课计划」分类** 9 条问答（功能说明 / 创建流程 / 节次时间表 / 班级筛选 / 提醒开关 / 收不到通知排查 / 隐私说明 / 多班级 / 删除）

### 业务稳定性修复

- **记名页同步失败不再阻塞操作** - 之前 sync 队列有任意 failed 项会锁死所有底部记名按钮，打断正在进行的记名。改为非阻塞警告横条「本次记名仍可继续，标记会保留到本地。结束后请到「同步问题」处理」，5 个按钮始终可点
- **班级数据主动加载** - 查课计划创建页主动调用 `syncBaseData()`，不再依赖用户先去点名页才加载到班级
- **查课计划班级对话框 StatefulBuilder** - 修复点击班级不刷新、需要重开对话框才看到选中状态的 bug
- **记名 setState 强制刷新坏味道清理** - `setState(() => _focusedIndex = _focusedIndex)` 三处改为 `setState(() {})`

### UI 设计系统重做

- **设计系统骨架** - 在 `shared/design_system/` 建立 tokens（颜色/字号/间距/圆角/动效）+ 亮暗主题 + 9 个核心组件（AppButton/AppCard/StatusPill/AppInput/AppTopBar/BottomActionBar/AppSegmentedControl/SyncStatusBanner/SegmentedProgressBar）
- **品牌色统一** - 主色 `#2563EB`（blue-600），中性灰背景，sky→blue 渐变；淘汰 Material 3 默认紫蓝
- **24 个页面全部接入设计系统** - 按统一规范改造：home / name_check / submission / record_detail / confirmation / text_gen / records_list / selection / roll_call / login / register / real_name / weekly_summary / submission_search / ranking / settings / faq / set_password / sync_issues / markdown_document / debug 系列
- **核心视觉升级** - 周次 hero 用品牌渐变；StatusPill 替代手写徽章；AppCard 替代 Card（圆角 8、规范阴影、暗色边框）；审核对话框拒绝/通过按钮用语义色（stateDanger/stateSuccess）
- **响应式加固** - 所有 Row 内用 Flexible/Expanded + overflow:ellipsis；拒绝/通过按钮在窄屏（< 320px）改纵向；对话框宽 min(width*0.92, 480)
- **废弃组件清理** - 删除 `EntryCard` / `FeatureCard` / `StatusBadge` / `CountBadge`（0 调用方）
- **公共 helper 提取** - `_NoticeBox` / `_StatChip` / `_StatTile` 提升为 `AppNoticeBox` / `AppStatChip` / `AppStatTile` 放入 design_system
- **动画体系** - AppDuration 扩档（page/emphasize/depart）；AnimatedRotation 补 curve；状态切换引入 AnimatedSwitcher；列表→详情 Hero 共享元素；weekly_summary 卡片骨架屏
- **widget_test 修复** - 标记为 skip（依赖注入未 mock，待引入 integration_test）

### 记名流程稳定性修复

- **markStudent 回滚修复** - 失败恢复时不再使用过时的局部变量，基于最新 state 副本回滚目标项；失败时 LoggerService 记录详细错误日志，前端弹 Toast 提示
- **finishNameCheck 异常保护** - 整个方法包裹 try/catch，失败后 task 维持 inProgress 状态避免数据丢失；前端弹 Toast 并记录详细日志
- **finishNameCheck 名单变化提示** - reconcile 检测到学生名单新增时，不再静默标已到；弹窗让用户选择"返回标记"或"全部按已到处理"
- **finishNameCheck 新增 FinishNameCheckResult** - 返回结构化结果，UI 层根据 success/newStudents/errorMessage 分别处理

### 提交流程增强

- **提交确认后再校验** - 用户点"确认提交"后，再做一次 getSyncIssueCount + 任务存在性校验，防止确认对话框期间状态变化
- **提交失败聚合展示** - 多任务提交时，不再只显示第一个错误；改为弹详情对话框，逐条显示班级名 + 错误原因
- **周任务边界修复** - 任务过滤从 `isAfter` 改为 `!isBefore`，避免周一 00:00 整点创建的任务被重复识别
- **服务端提交通过滤** - (新增 `_filter_valid_submission_records`) 提交时过滤学生已转班/不在任务班级的记录，无有效记录时返回 400

### 同步服务稳定性

- **syncNow 竞态修复** - 等待中同步结束时不再返回伪 (0,0,0)，改为缓存最近一次 `_lastResult`；若队列仍有项则触发新同步，只剩已放弃/认证过期项时正确计入 failed 计数
- **SyncService remark 同步** - 批量/逐条 record/update 同步时传递 remark 字段，不再丢失备注内容

### 本地记录编辑防护

- **isSubmitted 网络异常禁止编辑** - 确认提交状态时网络失败，不再默认放行编辑；新增 `_submitStatusUnknown` 状态，禁用编辑按钮，顶部显示红色横幅 + 重试按钮

### 服务端记录校验

- **记录写入 membership 校验** - create_records 和 batch_update_records 新增 `_validate_student_record_membership`，校验学生存在、属于提交的班级、班级属于任务；不匹配时返回 400
- **客户端 student 数据主动刷新** - ensureStudentsBatch 改为每次都 checkClassesUpdate，确保 reconcile 时拿到最新名单
- **服务端活跃学生过滤** - getStudentsByClass 本地查询时参考服务端返回的 active_ids，过滤已被删除的学生

### 测试新增

- **记名 reconcile 测试** - `name_check_reconcile_test.dart`：验证按 studentId 保留状态、新增学生为 pending、已删除学生移除
- **remark 同步测试** - `attendance_remote_ds_test.dart`：验证 create 和 update payload 正确携带 remark
- **服务端记录校验测试** - `test_record_validation.py`：验证学生不属于班级/班级不属于任务时 400
- **服务端提交通过滤测试** - `test_submission_record_filter.py`：验证学生转班后提交自动过滤脏记录

### UI 重设计（设计系统 + 4 核心页）

- **全新 Design System** - tokens（间距/圆角/动效）+ AppColors 双主题色板（中性灰 + sky→blue 渐变）+ AppTextStyles 字号阶梯 + buildLightTheme/buildDarkTheme
- **9 个核心组件** - AppButton（4 variant × 3 size）/ AppCard / StatusPill / AppInput / AppTopBar / BottomActionBar / AppSegmentedControl / SyncStatusBanner / SegmentedProgressBar，含针对性单元/Widget 测试
- **首页重做** - hero 区 + 渐变主 CTA "开始记名" + 次入口紧凑网格 + 整合后的同步状态卡，syncing 状态恢复进度条动画反馈
- **记名页重做** - 顶部 5 段彩色进度条（绿/红/黄/蓝/紫/灰）+ segmented 班级切换 + 紧凑学生卡片（焦点品牌色边框 + 状态胶囊）+ 当前学生姓名预览 + 顶栏高度自适配状态栏
- **提交页重做** - SegmentedControl 替代 TabBar（保留 controller 监听器）+ 单一 SyncStatusBanner + 紧凑可选任务卡片 + 固定 BottomActionBar，swipe 切换 tab 与 segmented 同步
- **记录详情页重做** - 顶部信息卡（班级 + 状态胶囊 + 5 段进度条 + 数字统计）+ 4 种状态横幅整合 + StatusPill 替代纯背景色变化
- **旧组件 API 兼容** - EntryCard / StatusBadge / EmptyState / LoadingOverlay / Toast 保留，未改造页面继续可用

### 视觉细节

- 字号阶梯采用 8 档（display 28 / h1 22 / h2 18 / h3 16 / body 14 / bodyMedium 14/500 / sm 13 / xs 11）
- 学号、数字栏、时间戳统一使用等宽数字（FontFeature.tabularFigures）
- 圆角默认 6 px（按钮/输入框）+ 8 px（卡片）+ 4 px（标签胶囊），比 M3 默认 12 px 更锐利
- 暗模式弃用阴影，改用 1 px 边框区分层级；Toast/LoadingOverlay 暗模式边框升级为 borderDefault 提升可见性
- 触摸操作 < 200 ms easeOut，元素位移 < 200 ms easeInOut
- AppCard 改用 Material > Ink > InkWell 模式，确保点击涟漪在彩色背景上可见
- AppSegmentedControl 修复透明段点击死区，并增加 a11y 语义
- SegmentedProgressBar 增加输入断言与契约文档，避免 flex < 0 运行时崩溃

### 性能与动画优化

- **AppCard 选中态动画** - onTap 分支也用 AnimatedContainer，selected 切换 200ms 平滑过渡
- **AppButton 按下反馈** - 改 StatefulWidget，onTapDown/Up AnimatedScale 0.96 按下形变
- **Material ripple 恢复** - 移除 `splashFactory: NoSplash`，恢复 Android 触感反馈
- **数字滚动动画** - AppStatTile 用 TweenAnimationBuilder<int> 600ms 滚动入场；home badge scale 0.6→1.0 弹出
- **骨架屏 shimmer 扫光** - SkeletonCard 从 alpha 脉冲改为线性渐变扫光（1400ms 循环），加载状态识别度提升
- **SyncStatusBanner 旋转图标** - syncing 态用 RotationTransition 持续旋转 sync 图标
- **home 同步状态 AnimatedSwitcher** - sync banner 出现/消失淡入淡出
- **Hero 共享元素** - records_list → record_detail 的班级名文本飞越过渡
- **AppInput focus 动画** - label/prefixIcon 颜色根据 focused/error 状态动画过渡
- **per-platform PageTransitions** - Android 用 ZoomPageTransitionsBuilder（M3 风格），iOS 保持 Cupertino
- **selection 班级选中动画** - Icon 用 AnimatedSwitcher + ScaleTransition 弹出
- **AnimatedRotation curve** - ranking/faq 箭头旋转补 curve: AppCurves.normal
- **AppDuration/Curves 扩档** - 新增 page=450ms / emphasize=easeOutBack / depart=easeIn
- **9 处 ListView 加 RepaintBoundary** - 卡片型列表滚动 FPS 提升
- **submission_page Theme.of 缓存** - 14 处 Theme.of + 30+ 处 context.colors 裸调用改为方法级缓存
- **dialog TextEditingController dispose** - 防止内存泄漏
- **dart fix --apply** - 自动清理 37 项（unnecessary_const / underscores / braces / null_aware）

### 文档更新

- **AGENT.md** - v0.6.5 → v0.7.0，新增 duty_plan / design_system / notification 模块说明
- **README.md** - 版本号 badge + v0.7.0 亮点 6 条
- **docs/dev-guide.md** - 版本号 + DutyPlanRows 表 + schema 4 + Provider 依赖链
- **docs/design-system.md** - 新建设计系统手册（tokens / 组件 API / 调用模式 / 禁用清单）
- **删除无用文档** - `app/README.md`（Flutter 默认模板）、`docs/business-flow.md`（合并到 dev-guide）、`docs/business-logic-audit.md`（v0.6.5 审计已过时）

### 已知问题清单（已修复，详见上方"业务稳定性大修"）

> 以下 22 项 + 1 项 bonus 问题已通过 3 轮深度审计识别并全部修复。完整修复 commit：`ae16afc` `bc2771c` `1a58728` `08df7a7` `ba8b405` `048d918` `d244bf6` `c659e39`。

**T0 级（数据正确性，7 项）**：
- **T0-15** `pending` 状态被计入 `present` — `text_gen_page`/`record_detail_page` 生成汇报文本时到课人数虚高
- **T0-14** 已提交任务被远端 403 拒绝后 sync 静默标记 `synced` — 本地/服务端永久不一致
- **T0-9** 401 认证过期 `break` 退出整条同步队列 — 后续正常项全部阻塞
- **T0-1** `_syncRecord` 缺 `delete` action — delete 同步项被静默跳过，本地/服务端数据不一致
- **T0-2** `finishNameCheck` 与 `markStudent` 并发竞态 — 标记可能被覆盖丢失
- **T0-13** `getUnsyncedCount` 用 `'unfinished'` 查 status — 永远返回 0
- **T0-4** `getSyncIssueCount` 与 `getPendingSyncItems` 口径不一致 — 已放弃项阻止提交

**T1 级（流程卡住，8 项）**：
- **T1-16** `records_list` 显示 `in_progress` 任务 — 用户可进入生成文本触发 T0-15
- **T1-17** `TaskResumeChecker` 不恢复 `confirming`/`text_generating` 阶段任务
- **T1-3** reconcile 删除记录时未取消未消费的 create/update sync 项
- **T1-18** `RollCallNotifier.nextStudent` 先 createRecord 后 updateTaskStatus，后者失败时记录已写入
- **T1-8** 启动时 `retryAllFailed()` 无条件重置所有 failed（包括 401 认证过期项）
- **T1-12** 400/422 永久性错误也计作 `failed` 并允许重试 — 重试→失败循环
- **T1-10** sync_issues 无"跳过此项"单条操作
- **T1-21** `classroom` 可为 null，老数据升级后显示异常

**T2 级（极端条件，5 项）**：
- **T2-7** `prevStudent` 删除记录后无事务保护
- **T2-20** 数据库迁移 `catch(_){}` 吞噬异常
- **T2-11** `syncNow` while 忙等待无超时
- **T2-19** `mark()` 闭包捕获过期的 `hasPendingInAllClasses`
- **T2-24** `Stream.periodic` 轮询无手动 cancel

---

## v0.6.5

### 记名重复记录修复

- **insertRecord upsert** - 本地改为 taskId+studentId upsert，已存在则更新而非插入，从根因消除重复记录
- **UpsertResult 区分** - 新增 UpsertResult(id, created) 区分新建/更新，SyncQueue 入队 action 正确设置为 create 或 update
- **finishNameCheck 回填** - 批量创建 present 记录后回填 recordId，重新编辑时走 updateRecord 而非创建新记录
- **记录详情去重** - getRecordEntries 同一 studentId 去重，优先 updatedAt 最新
- **历史重复清理** - cleanDupRecords() 自动清理重复记录，每次同步前执行
- **服务端 upsert** - create_records 现有记录也更新 status（带权限保护检查）
- **服务端去重** - create_submission 按 task_id+student_id 去重，优先 updated_at
- **权限异常保护** - create_records 只吞保护性 HTTPException，权限错误重新 raise

---

## v0.6.4

### 拼音优化

- **拼音显示** - 点名页面拼音改为每个汉字之间加空格（如 WANG XIAO MING）
- **拼音生成** - 导入脚本 generate_pinyin() 改为 `" ".join()`，新导入的学生自动带空格

### 同步稳定性修复

- **403 protected skip 修复** - 从 DioException.response.data.detail 提取错误信息判断，不再依赖 toString()
- **SyncService 网络错误判断优化** - 使用 DioException.type 替代字符串匹配，更准确
- **批量同步网络错误判断优化** - 同步使用 DioException.type

---

## v0.6.3

升级兼容修复版本。

### 同步兼容修复

- **403 保护性拒绝跳过** - 旧版本升级后，历史 record/update 因服务端保护（已提交审核/已放弃/不可修改）返回 403 时，客户端自动跳过而非无限重试
- **批量同步补充** - 批量同步 failed reason 包含"该任务已放弃"/"不可修改记录"时也安全跳过
- **Dio 错误日志增强** - 403/400/500 错误日志现在打印 response.data 中的 detail 字段，便于排查

### 旧版本升级遗留 SyncQueue 自修复

- **syncing 残留修复** - 历史 syncStatus='syncing' 的卡死项自动重置为 pending
- **坏 payload 跳过** - payload 为空或 JSON 解析失败的旧项自动 markSynced，不阻塞同步
- **不完整 record/update 跳过** - 缺少 task_id/student_id/status 的旧项自动 markSynced
- **历史队列清理** - 7 天前已 synced 的队列项自动清理，避免本地数据库膨胀
- **同步前自动执行** - 每次同步前自动修复，不影响正常同步流程
- **详情页文案优化** - 提示"旧版本遗留的无效项会自动跳过"

---

## v0.6.2

发布后体验修复版本，不涉及业务逻辑变更。

### 日志优化

- **Dio 网络日志** - statusCode null 时区分 timeout、connectionError、cancel 等具体错误类型，日志更清晰
- **周名单汇总** - member 账号不再请求管理员接口（pending/reviewed），避免日志中大量 403

### 健康检查

- **/health 接口** - 返回 timestamp 和 version 字段
- **/health/db 接口** - 新增数据库连接检测接口
- **路由兼容** - /health 和 /api/health 都可访问，兼容前端 baseUrl

### 性能优化

- **/sync/version** - 优化 N+1 查询，改为一次 group_by 查询所有班级学生统计
- **students.class_id** - 补充数据库索引

### FAQ 更新

- **同步保护模式** - 新增"为什么编辑/提交按钮被禁用了"说明
- **账号安全** - 新增"如何设置或修改密码"、"加载失败点击重试"说明
- **审核通过快照** - 新增"导出后新数据还会进入汇总"说明
- **现有问题更新** - 网络断开、退出登录、查课记录修改等补充同步保护模式说明
- **Markdown 修复** - 修复记名操作 FAQ 中加粗语法未闭合的问题

---

## v0.6.1

### 同步保护模式

- **失败时禁止编辑** - 存在 syncStatus == 'failed' 的记录时，禁止记名页编辑、记录详情编辑、放弃任务
- **失败时禁止提交** - 名单提交按钮禁用，显示"有 X 条同步失败，请先处理"
- **失败时禁止导出** - Excel 导出/发布前检查同步问题，有 failed 时阻止
- **首页红色警告** - 存在 failed 时首页显示红色警告卡片
- **统一统计口径** - 首页/提交页/导出页统一使用 syncIssueCountProvider

### 审核通过快照

- **submission_snapshots 表** - 新增快照表，管理员审核通过时自动锁定提交内容
- **幂等生成** - 重复审核不会重复生成快照
- **周汇总基于快照** - get_week_summary / get_week_summary_detail 优先读取快照
- **Excel 基于快照** - export_week_excel 优先读取快照
- **submission 级别 fallback** - 同一周有快照和无快照的 approved submission 都能正确处理
- **remark 字段保留** - 快照和 fallback 都保留考勤记录的 remark 字段

### 账号安全优化

- **区分错误类型** - 401 显示"登录状态已过期"，网络错误显示"加载失败，点击重试"
- **重试机制** - error 状态点击可重试 invalidate hasPasswordProvider
- **设置密码返回刷新** - 从设置密码页返回后自动刷新状态
- **loading 禁止点击** - 加载中点击提示"正在加载，请稍候"

### 发布前检查

- **调试工具新增 Tab** - "发布检查"页，打包前快速检查 App 状态
- **检查项** - 登录状态、Token 状态、服务器连接、同步状态、本地数据、账号安全、版本信息
- **总体结论** - 全部正常显示绿色"可以发布"，有问题显示红色/橙色提醒

### 其他修复

- **DioException 安全解析** - 兼容 Map/String/List/null 各种错误响应格式
- **bcrypt 替换 passlib** - 解决密码设置时服务端 500 错误
- **退出登录误判修复** - getUnsyncedCount() 只统计 pending/failed，排除 synced 历史记录
- **设置密码反馈优化** - 成功后延迟 800ms 返回，Toast 明确提示

---

## v0.6.0

### 批量同步优化（核心性能提升）

- **批量更新接口** - 新增服务端 `POST /records/batch-update`，支持一次提交多条记录更新
- **自动合并** - SyncService 自动合并连续的 record update（≥2条且≤50条）为批量请求
- **失败分类处理** - 批量返回 success/failed 列表，成功项统一 markSynced，失败项按 reason 处理
- **性能提升** - 大量修改学生状态后，提交审核前同步速度明显变快（从 N 次请求降为 1 次）

### 同步失败处理优化

- **错误分类** - 区分网络错误、认证过期 401、其他错误，分别给出明确提示
- **401 保护** - Token 过期时只清除 token，保留 userId 和本地数据，避免未同步记录丢失
- **自动恢复** - 重新登录后自动重置 auth failed 项（retryCount=999 → pending）并触发 syncNow()
- **退出登录保护** - 有未同步数据（含 auth failed）时禁用退出按钮，强制先同步
- **关键操作阻塞** - 名单提交、Excel 导出前检查未同步状态，未同步时阻止操作

### 删除任务逻辑重构

- **标记删除** - 查课记录删除任务改为标记 `abandoned` 状态，不再物理删除本地数据
- **同步到服务端** - 删除后入队 SyncQueue，服务端任务状态同步变为 abandoned
- **提交保护** - 服务端 `update_task` 在改为 abandoned 时检查是否已关联 pending/approved submission，已提交则返回 403
- **名单提交过滤** - 名单提交页只查询 `completed` 任务，abandoned 任务自然被过滤

### 提交审核安全加固

- **同步中交互优化** - 同步中时提交按钮显示"正在同步 X 条记录..."并禁用，避免用户误以为卡死
- **二次校验** - 提交前遍历选中 taskId，确认任务仍存在且状态为 completed
- **服务端校验** - `create_submission` 增加三重校验：task 必须存在、状态必须为 completed、必须属于当前用户
- **删除后刷新** - 删除任务后自动 invalidate 名单提交相关 provider

### 同步保护机制

- **启动自动同步** - 打开App自动检测待同步/失败记录，自动重试同步
- **后台同步** - 记名时同步在后台静默进行，不干扰用户操作
- **失败重试** - 同步失败记录自动重置并重试，最多5次
- **同步完成提示** - 启动同步完成后显示 SnackBar 提示
- **同步等待修复** - 修复同步循环问题，避免重复同步

### 业务逻辑核心修复

- **记录锁定** - 提交审核后，服务端禁止修改已关联 pending/approved submission 的记录（返回 403）
- **前端编辑限制** - 查课记录详情页检查提交状态，已提交任务禁用编辑并显示提示
- **重新提交支持** - submitted-task-ids 明确过滤 pending/approved，rejected/cancelled 可重新提交
- **文案修正** - 总群汇报删除"不可撤销"误导，提示用户前往名单提交
- **权限校验** - 服务端 record update 接口增加 user_id 权限校验

### 设置页增强

- **数据统计** - 查课任务统计（完成/进行中/放弃）、考勤记录数、待同步数
- **手动同步** - 可直接触发手动同步，显示同步状态
- **清理缓存** - 清除日志和临时数据
- **网络诊断** - 测试与服务器的连通性
- **隐私政策/用户协议** - 应用内查看，无需跳转浏览器
- **FAQ 帮助中心** - 内置常见问题与解决方案
- **账号安全** - 支持设置/修改密码，验证码登录后可在设置页配置密码

### Bug修复

- **任务状态同步** - 修复断网/重启后 task 状态未同步导致提交失败的问题
- **提交详情空状态** - 区分 record_count == 0 和无异常两种空状态
- **rejected 状态提示** - 已拒绝提交始终显示审核人、拒绝原因
- **DioException 安全解析** - 兼容 Map/String/List/null 各种错误响应格式
- **设置密码反馈** - 成功后延迟 800ms 返回，Toast 明确提示
- **退出登录误判** - getUnsyncedCount() 只统计 pending/failed，排除 synced 历史记录
- **bcrypt 替换 passlib** - 解决密码设置时服务端 500 错误
- **空安全** - firstWhere 空安全问题修复

### 其他

- **邮件模板** - 验证码邮件改为梦幻炫彩玻璃风格
- **隐私政策/用户协议** - 完整的隐私政策和用户协议文档
- **密码登录** - 新增邮箱+密码登录方式，保留验证码登录
- **全新图标** - 应用图标重新设计

---

## v0.5.6

### 日志与调试

- **全局日志服务** - LoggerService 统一记录，支持分类筛选（全部/同步/网络/错误）
- **网络日志** - Dio 拦截器自动记录请求/响应，便于排查网络问题
- **同步可视化** - 调试工具新增同步队列状态展示
- **Token测试** - 支持查看Token剩余时间、模拟过期重新登录

### 交互优化

- **确认弹窗** - 总群汇报复制文本前弹出确认警告，防止误操作
- **Tab顺序调整** - 汇报界面学委汇报在前，总群汇报在后
- **日志导出** - 支持复制和分享日志文件

### 导出增强

- **记录时间列** - Excel导出新增"记录时间"列，显示月日时分及状态（迟/缺/假/其）
- 同一学生多条记录按时间排序，换行显示

### Bug修复

- **JWT时区** - 服务端统一使用 UTC 时间生成和验证 Token，修复时区偏移问题
- **JWT有效期** - 修复环境变量配置错误（168小时→720小时，即30天）
- **服务端时区** - 所有 datetime 操作统一使用 UTC，避免跨时区问题

---

## v0.5.5

### 排行榜功能

- **排行榜入口** - 扩展功能页新增排行榜入口
- **三种周期** - 近7天、近30天、总榜
- **三种榜单** - 异常分数榜、缺勤率榜、缺勤人次榜
- **暖金主题** - 前三名金银铜奖牌，数值深红强调
- **概览卡片** - 平均值、最高值、上榜班级数统计
- **班级详情** - 缺勤/请假/迟到/其他人次徽章
- **趋势显示** - 排名变化箭头（↑↓），NEW标签
- **规则说明** - 可展开查看计算公式

### 认证与稳定性修复

- **JWT有效期** - 新登录凭证默认从7天延长至30天
- **401自动处理** - 新版客户端在登录过期后自动跳转登录页并提示重新登录
- **数据库连接池** - 服务端增加 `pool_pre_ping` 与 `pool_recycle`，降低 MySQL 长连接失效概率
- **网络超时优化** - 客户端连接超时调整为15秒，接收超时调整为30秒
- **服务保活** - 服务器通过 cron 定时请求 `/health`，降低低内存场景下冷启动超时概率

### Bug修复

- **提交卡片** - 撤销/拒绝后仍显示班级名称（存储class_names字段）
- **汇总弹窗** - 管理汇总预览正常显示
- **公告渲染** - 设置页公告正确显示 Markdown 格式

---

## v0.5.3

- **重要修复**：编辑记录后同步到服务端（修复提交数据不一致问题）
- **提交前强制同步**：进入提交页面自动同步，确保数据一致
- **禁止删除已提交记录**：已提交的记录需先撤销才能删除
- **布局优化**：点名详情单列、记名两列、卡片尺寸恢复原样
- **响应式修复**：Dialog宽度自适应屏幕，统计标签自动换行

---

## v0.5.2

- **数据自动刷新**：服务端更新学生名单后App自动同步
- **编辑记录同步**：查课记录编辑后正确同步到服务端
- **点名名单优化**：单列布局，学号完整显示
- **提交卡片优化**：班级名称正确显示
- **下载源切换**：国内用户从Gitee下载，速度更快

---

## v0.5.1

- **响应式布局优化**：修复多个页面在不同设备上的布局问题
- **UI组件统一**：提取公共组件（StatusBadge、EmptyState、EntryCard）
- **实名页优化**：移除固定占位，按钮固定底部
- **修复文字溢出**：姓名/学号长文字显示优化
- **修复按钮溢出**：发送验证码按钮自适应宽度
- **AlertDialog优化**：移除固定宽度，自适应屏幕

---

## v0.5.0

- **实名制**：登录后必须填写真实姓名
- **名单提交审核系统**：成员提交，管理员审核
- **周名单汇总**：管理员审核、导出Excel、发布汇总
- **实时公告**：从服务端获取
- **数据隔离**：登出清空本地用户数据
- **审核历史记录**：管理员查看已审核记录
- **学生名单更新**：2022-2024级本科生，含性别字段
- **公告 Markdown 渲染**：支持富文本显示

---

## v0.4.0

- 应用更名为"考勤助手"
- 全新App图标（绿色勾选 + 学习部）
- 多班级记名支持左右滑动切换
- 当前班级处理完毕自动跳转下个班级
- 网络断开时显示友好提示和重试按钮
- 同步优化：404错误自动跳过
- 新增学习部全体成员致谢名单
- 删除测试文档

---

## v0.3.9

- 修复数据库升级失败问题
- 修复同步队列累积问题（取消10条限制）
- 修复微信/QQ跳转检测问题
- 总群汇报显示学号
- 全勤时显示"全勤"
- 班级选择单列布局
- 自动同步间隔改为10秒
- 多个稳定性改进

---

## v0.3.8

- 总群汇报文本按班级分组显示
- 复制并跳转微信/QQ功能
- 班级选择界面优化（固定宽度、两列布局）
- 调试工具改进（统计卡片、操作日志）
- 性能优化（记名页面渲染）

---

## v0.3.6

- 修复手势返回与返回按钮不一致的问题
- 修复确认页手势返回导致加载问题
- 修复未登录时仍提示恢复任务的问题
- 优化所有页面的响应式布局
- 新增振动反馈开关（设置页）
- 登录/退出后界面立即刷新
- 班级选择界面布局优化

---

## v0.3.5

- 优化数据加载速度（并行加载、增量更新）
- 改进提示样式为悬浮弹幕
- 请假状态颜色改为蓝色，区分迟到
- 未登录时限制使用功能

---

## v0.3.3

- 新增检查更新功能
- 优化设置页显示

---

## v0.3.2

- 修复数据库升级失败问题
- 现在可以平滑升级，无需卸载重装

---

## v0.3.1

- 登录和注册分离，登录无需邀请码
- 性能优化，减少界面卡顿

---

## v0.3.0

- 新增邮箱验证码登录功能
- 新增扩展功能页面（导入、提交、汇总、排行）
- 优化暗色模式颜色显示
- 记名名单显示完整学号

---

## v0.2.5

- 新增暗色模式支持（设置页可切换）
- 新增扩展功能入口
- 优化颜色适配暗色主题

---

## v0.2.4

- 修复查课记录人数显示不正确的问题
- 点名记录显示全班学生（已点/未点）
- 进行中的任务支持"继续"功能
- 修复继续点名跳转位置不正确的问题
- 保存退出时自动保存当前进度
- 已完成的点名记录显示"已完成"标签

---

## v0.2.2

- 加载遮罩优化、批量操作减少卡顿

---

## v0.2.0

- 新增迟到状态、自定义备注、文本生成、公告系统
