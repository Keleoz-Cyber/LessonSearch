# 考勤助手 — 开发任务表

> 更新日期：2026-05-03
> 当前版本：0.6.0 (开发中)
> 分支：main

---

## 版本目标

本次版本实现：
1. 设置页增强（数据统计、手动同步、清理缓存、网络诊断）
2. Bug修复（提交权限、职务加载、统计一致性）
3. 邮件模板焕新（梦幻炫彩玻璃风格）
4. CI/CD增强（自动发布到Gitee）

---

## 已完成

### v0.6.0 同步保护与业务逻辑修复 ✅

- **批量同步优化**
  - 新增服务端 `POST /records/batch-update` 接口，支持批量更新考勤记录
  - SyncService 自动合并连续的 record update（≥2条且≤50条）为批量请求
  - 批量成功后统一 markSynced，失败按 reason 分类处理
  - 网络错误时整批标记 failed 并中断同步，单条或不足2条时回退到逐条处理
  - 目标：大量修改学生状态后，提交审核前同步速度明显变快
- **同步失败处理优化**
  - 区分三种错误：网络错误（提示检查网络）、认证过期 401（提示重新登录）、其他错误（正常重试）
  - 401 时只清除 token，保留 userId 和本地数据（避免未同步记录丢失）
  - 新增 `authExpiredProvider` 供 UI 监听认证过期状态
  - 登录成功后自动重置 auth failed 项（retryCount=999 → pending）并触发 syncNow()
  - `pendingSyncCountProvider` 统计包含 auth_failed（retryCount=999）项，确保关键操作前能检查到
- **删除任务逻辑重构**
  - 查课记录删除任务改为标记 `abandoned` 状态，不再物理删除本地数据
  - 删除后入队 SyncQueue 同步到服务端
  - 名单提交页只查询 `completed` 任务，`abandoned` 任务自然被过滤
  - 服务端 `update_task` 在改为 `abandoned` 时检查是否已关联 pending/approved submission，已提交则返回 403
- **提交审核安全加固**
  - 名单提交页同步中交互优化：按钮显示同步状态文案并禁用，避免用户误以为卡死
  - 提交前二次校验：遍历选中 taskId，确认任务仍存在且状态为 completed
  - 服务端 `create_submission` 增加三重校验：task 必须存在、状态必须为 completed、必须属于当前用户
  - 删除任务后自动 invalidate `weekNameCheckTasksProvider`、`submittedTaskIdsProvider`、`mySubmissionsProvider`
- **退出登录保护**
  - 有未同步数据（含 auth_failed）时，退出登录弹窗禁用"退出"按钮
  - 提示"无法退出登录"，只提供"立即同步"按钮
  - 避免用户误操作导致未同步数据永久丢失
- **同步保护机制**
  - 启动自动同步（检测待同步/失败记录，自动重试）
  - 失败重试（最多5次，失败后标记并自动恢复）
  - 提交前强制同步（失败则阻止提交并提示）
  - 同步完成 SnackBar 提示
  - 同步等待逻辑修复（避免循环同步）
- **业务逻辑核心修复**
  - 服务端 record update 接口增加校验：已关联 pending/approved submission 的记录禁止修改（返回 403）
  - 前端查课记录详情页检查提交状态，已提交任务禁用编辑并显示提示
  - submitted-task-ids 明确过滤 pending/approved，排除 rejected/cancelled（允许重新提交）
  - 总群汇报文案修正：删除"不可撤销"误导，提示用户前往名单提交
  - 服务端 record update 接口增加 user_id 权限校验
- **设置页增强**
  - 数据统计（查课任务、考勤记录、待同步数）
  - 手动同步按钮
  - 清理缓存功能
  - 网络诊断入口
  - 隐私政策/用户协议（应用内查看）
- **Bug修复**
  - 旧版任务提交权限修复（user_id=null时不403）
  - 职务加载逻辑优化（网络错误显示重试）
  - 待同步统计逻辑统一
  - `firstWhere` 空安全问题修复（添加安全查找方法）
- **FAQ 帮助页面**
  - 新增【常见问题与解决方案】页面（设置页入口）
  - 19个常见问题，涵盖同步、提交、审核、记录、账户、密码等场景
  - 基于实际业务逻辑整理，面向普通用户的口语化说明
  - 折叠卡片交互，按类别分组显示
- **Task 状态同步修复**
  - 修复断网/重启后 task 状态未同步为 completed，导致提交审核失败的 bug
  - 前端 createTask 同步时携带完整状态字段（status/phase/current_*）
  - 服务端 create_task 幂等更新：已存在任务时更新状态字段
  - 提交前增加服务端 task status 校验，不一致时主动修复
- **提交详情空状态优化**
  - 区分两种空状态：record_count == 0（无关联记录）和 record_count > 0 但无异常（全部到齐）
  - rejected 状态提示独立于空状态，始终显示审核人、拒绝原因
  - 各页面（我的提交、周名单汇总、提交查询）展示保持一致
- **密码登录功能**
  - 新增邮箱+密码登录方式，保留验证码登录
  - 登录页支持验证码/密码切换
  - 设置页新增"账号安全"入口，支持设置/修改密码
  - 密码使用 bcrypt 安全哈希存储
- **设置密码体验优化**
  - 设置密码成功后显示 Toast "密码设置成功"，延迟 800ms 再返回设置页
  - 延迟期间保持按钮加载状态，防止重复点击
  - 失败时明确显示错误信息，按钮立即恢复可点击状态
- **DioException 错误解析安全修复**
  - `set_password_page.dart` 新增 `_parseDioError()` 方法，安全解析 error response
  - 兼容 data 为 Map/String/List/null 等各种类型
  - 使用 finally 确保无论成功/失败/解析错误，loading 状态一定恢复
- **退出登录未同步数据误判修复**
  - `getUnsyncedCount()` 只统计 syncStatus == 'pending' 或 'failed' 的记录
  - 不再统计已同步成功的历史队列记录（synced），避免显示"数千条未同步"
  - 与 pendingSyncCountProvider 统计口径保持一致
- **bcrypt 替换 passlib**
  - 服务端移除 passlib 依赖，改用原生 bcrypt API（bcrypt.hashpw / bcrypt.checkpw）
  - 解决 bcrypt 5.0+ 与 passlib 1.7.4 不兼容导致的 500 错误
  - _verify_password 增加异常保护，避免 hash 格式错误时崩溃
- **其他**
  - 邮件模板改为梦幻炫彩玻璃风格
  - 隐私政策与用户协议文档
  - GitHub Actions自动发布到Gitee Release
  - 统一错误详情解析方法，兼容 String/List/Map

### v0.5.6 日志重构与导出增强 ✅

- 全局日志服务（LoggerService），支持持久化与分类筛选
- 网络请求自动记录（Dio拦截器）
- 同步队列日志可视化
- 调试工具3 Tab布局（概览/同步/日志）
- Token剩余时间显示与测试功能
- 总群汇报复制前确认弹窗（防止误操作）
- 汇报界面Tab顺序调整（学委汇报在前）
- Excel导出新增"记录时间"列（显示月日时分及状态）
- JWT时区修复（使用UTC时间）
- JWT有效期配置修正（168小时→720小时，即30天）
- 服务端所有datetime统一使用UTC

### v0.5.5 排行榜与稳定性修复 ✅

- 排行榜功能（近7天 / 近30天 / 总榜）
- 三种榜单（异常分数榜、缺勤率榜、缺勤人次榜）
- 排行榜规则说明与概览卡片
- 提交卡片撤销/拒绝后仍显示班级名称
- 汇总弹窗布局修复
- 公告 Markdown 渲染修复
- 服务端 data_version 路由注册
- JWT 默认有效期延长至 30 天
- 401 自动清理登录态并跳转登录页（新客户端）
- SQLAlchemy 连接池配置（pool_pre_ping / pool_recycle）
- App 超时时间优化（15s / 30s）
- 服务器低内存故障排查与保活方案落地

### v0.5.2 数据同步与布局优化 ✅

- 登出清空基础数据（Grades/Majors/Classes/Students）
- 编辑record入队同步修复
- 数据版本号刷新机制（服务端触发App自动同步）
- 点名名单单列布局优化
- 提交卡片班级名显示修复（服务端display_name字段）
- Gitee下载源切换（国内加速）

### v0.5.1 响应式布局优化 ✅

- 发送验证码按钮固定宽度改为Flexible
- AlertDialog固定宽度改为自适应
- 文字溢出添加overflow处理
- Row溢出改用Wrap
- 提取公共组件（StatusBadge、EmptyState、EntryCard）
- 实名页布局优化（移除SizedBox占位）

### v0.5.0 正式版 ✅

- 实名制系统
- 名单提交审核
- 周名单汇总导出
- 用户角色分级制度
- 数据隔离
- 实时公告

### v0.4.0 正式版 ✅

基础功能全部完成（点名、记名、记录、同步、登录）
- 实名制强制检查（路由redirect + 首页双重检查 + PopScope阻止返回）
- 公告Markdown渲染
- 导出Excel增加请假/其他列
- 导出文件名改为"第X周考勤表.xlsx"
- 多选任务分开提交（每个任务单独一条记录）
- 提交卡片显示班级名称
- 成员查看提交详情（点击卡片弹窗）
- 导出按钮位置调整（移到顶部）
- 响应式布局检查修复

### 阶段一：数据库设计 ✅

新增表：week_config, submissions, submission_records, week_exports, duty_assignments, announcements
修改表：users添加role, real_name字段

### 阶段二：后端API开发 ✅

新增API：user/real-name, week/current, submissions, duties, announcement

### 阶段三：前端页面开发 ✅

- 实名制页面
- 名单提交页面
- 周名单汇总页面
- 历史周次详情
- 审核历史记录
- 扩展页面（任务导入、排行榜占位）

### 阶段四：数据隔离 ✅

- 登出清空本地数据
- 登出前检查未同步数据

### 阶段五：审核流程 ✅

- 审核通过/拒绝
- 撤回提交
- 审核历史记录

### 阶段六：Excel导出 ✅

- 汇总逻辑
- Excel生成
- 文件下载

### 阶段七：实时公告 ✅

- 公告API
- 公告缓存

### 学生名单更新 ✅

- 2022-2024级本科生（3034人）
- 新增性别字段
- 过滤研究生和博士

---

## Bug修复记录

### v0.5.3 Record同步修复 ✅

- **核心问题**：编辑record后提交，服务端显示旧数据
- **原因**：本地ID和服务端ID不一致，同步使用本地ID导致404
- **修复**：新增 `/records/by-task-student` API，使用 task_id + student_id 更新
- **提交前强制同步**：进入提交页面自动同步
- **禁止删除已提交记录**：需先撤销提交
- **布局修复**：点名详情单列、记名两列、卡片高度恢复56px
- **响应式修复**：Dialog宽度自适应、统计标签Wrap换行

---

## 页面结构

```
扩展功能:
├── 名单提交
│   ├── 提交任务Tab
│   └── 我的提交Tab
└── 周名单汇总
    ├── 本周汇总Tab
    └── 历史周次Tab
```

---

## 服务端操作（不在客户端实现）

- 周次配置
- 职务分配
- 管理员角色
- 公告管理
- 邀请码管理

详见 AGENT.md

---

## 版本历史

| 版本 | 发布日期 | 主要内容 |
|------|----------|----------|
| v0.6.0 | 2026-05-03 | 密码登录、Task状态同步修复、提交详情空状态优化、同步保护机制、FAQ更新、设置页增强 |
| v0.5.6 | 2026-04-30 | 日志重构、导出增强、确认弹窗、JWT时区修复 |
| v0.5.5 | 2026-04-20 | 排行榜、稳定性修复、30天JWT、401跳登录、连接池优化 |