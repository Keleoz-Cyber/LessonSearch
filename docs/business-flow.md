# 考勤助手 App 业务流程文档

> 基于代码实际实现整理
> 整理日期：2026-05-03
> 版本：v0.6.0

---

## 一、整体业务背景

### 1.1 用户群体

考勤助手面向**高校学习部/学生会查课人员**，用于课堂考勤工作。

### 1.2 使用场景

实际查课通常是**两个人配合**：
- **用户 A**：负责站在教室前面**点名**（按学号顺序念名字）
- **用户 B**：负责在 App 上**记名**（标记每个学生的出勤状态）

目前点名功能较简单，不是本次分析重点。

### 1.3 核心业务闭环

查课不是一次简单提交，而是一个**多轮反复**的过程：

```
现场记名 → 反复修改 → 发给学委确认 → 再次修改 → 
发送最终名单到微信群 → 提交审核 → 管理员审核 → 周汇总
```

### 1.4 系统架构

- **客户端**：Flutter App，本地 SQLite（Drift）优先
- **服务端**：FastAPI + MySQL，1Panel 部署
- **同步机制**：本地优先 + 异步同步（SyncQueue）

---

## 二、核心用户流程：记名

### 2.1 流程总览

```
首页 → 选择页 → 记名执行页 → 确认名单页 → 汇报文本页 → 首页
```

### 2.2 详细步骤

#### 步骤 1：进入记名功能

- **入口**：首页 → 点击"记名"按钮
- **代码**：`home_page.dart` → `SelectionPage`

#### 步骤 2：选择年级、专业、班级

- **页面**：`selection_page.dart`
- **逻辑**：
  1. 选择年级（如 2022 级）
  2. 选择专业（如计算机科学与技术）
  3. **多选班级**（支持一次查多个班，如计科 2201 + 2202）
  4. 点击"开始记名"

#### 步骤 3：创建记名任务

- **代码**：`name_check_notifier.dart::startNameCheck()`
- **操作**：
  1. 生成 UUID 作为 taskId
  2. 创建 `AttendanceTask`（status=in_progress, phase=executing）
  3. 写入本地 Drift 数据库
  4. **入队 SyncQueue**（action=create, entityType=task）
  5. 异步同步到服务端

#### 步骤 4：加载学生列表

- **代码**：`name_check_notifier.dart::startNameCheck()`
- **操作**：
  1. 从本地数据库加载选中班级的学生
  2. 按班级分组，每个班显示为独立 Tab
  3. 学生初始状态为 `pending`（待查）

#### 步骤 5：用户逐个标记学生状态

- **页面**：`name_check_page.dart`
- **状态选项**：
  - `present`：到课（绿色）
  - `absent`：缺勤（红色）
  - `late_`：迟到（黄色）
  - `leave`：请假（蓝色）
  - `other`：其他（紫色，需输入备注）

- **操作方式**：
  1. 点击学生卡片选中（蓝色边框）
  2. 点击底部按钮标记状态
  3. 自动跳转到下一个 `pending` 学生

- **数据写入**：
  ```dart
  // name_check_notifier.dart::markStudent()
  1. 乐观更新 UI
  2. 写入本地 Drift（attendance_records 表）
  3. 入队 SyncQueue（action=create 或 update, entityType=record）
  4. 异步同步到服务端
  ```

#### 步骤 6：点击右上角 ✓ 完成记名

- **代码**：`name_check_page.dart::_showFinishDialog()`
- **操作**：
  1. 弹出确认对话框
  2. 提示："还有 X 人未处理，未处理的将标记为'已到'"
  3. 用户点击"确认"

#### 步骤 7：未处理学生自动标记为到课

- **代码**：`name_check_notifier.dart::finishNameCheck()`
- **操作**：
  1. 遍历所有 `pending` 状态的学生
  2. 批量创建 `present` 记录
  3. 更新任务状态：`status=completed`, `phase=confirming`
  4. 写入本地 Drift + 入队 SyncQueue

#### 步骤 8：进入确认名单页

- **页面**：`confirmation_page.dart`
- **显示内容**：
  - 只展示**异常名单**（非 present 的学生）
  - 按班级分组
  - 显示：姓名、学号、状态（缺勤/迟到/请假/其他）
  - 统计：共 X 人，异常 Y 人

#### 步骤 9：重新编辑或确认

- **选项 1**：点击"重新编辑"
  - 返回记名执行页
  - 代码：`resumeEditing()` → `isFinished=false`
  - 可以修改任何学生的状态

- **选项 2**：点击"确认名单"
  - 跳转到汇报文本页
  - 代码：`context.push('/text-gen')`

#### 步骤 10：进入汇报文本页面

- **页面**：`text_gen_page.dart`
- **两个 Tab**：
  - **学委汇报**：按班级生成，可直接复制
  - **总群汇报**：汇总所有班级的异常统计

---

## 三、核心用户流程：第一次汇报给学委

### 3.1 场景描述

用户完成记名后，在汇报文本页：
1. 切换到"学委汇报"Tab
2. 按班级查看汇报文本
3. 点击"复制"按钮
4. 自动跳转 QQ
5. 把第一次名单发给学委

### 3.2 代码实现

- **页面**：`text_gen_page.dart::_buildCommitteeReportView()`
- **操作**：
  1. 点击"复制" → `Clipboard.setData()`
  2. 延迟 300ms → `launchUrl(Uri.parse('mqq://'))`
  3. **无需确认警告**

### 3.3 关键问题：此时是否算"最终完成"？

**答案：不算**

- 任务状态：`completed`
- 记录状态：可随时修改
- 数据同步：后台静默同步
- **代码没有锁定任何记录**
- **代码没有标记"已最终确认"**

### 3.4 用户点击"完成"返回首页

- **代码**：`_finish()` → `context.go('/')`
- **操作**：
  1. 刷新本周任务列表
  2. 刷新已提交任务列表
  3. 返回首页

---

## 四、核心用户流程：查课记录中反复修改

### 4.1 进入历史记名记录

- **入口**：首页 → 查课记录
- **页面**：`records_list_page.dart`
- **显示**：所有任务列表（in_progress / completed / abandoned）
- **卡片信息**：班级、总人数、各状态人数、创建时间

### 4.2 进入记名详情页

- **点击**：任务卡片
- **页面**：`record_detail_page.dart`
- **功能**：
  - 查看所有学生的考勤状态
  - 默认只显示**异常记录**（非 present）
  - 点击"编辑"按钮进入编辑模式

### 4.3 编辑记录

- **代码**：`_buildNameCheckView()` + `_RecordRow`
- **操作**：
  1. 点击"编辑"按钮 → `_editing = true`
  2. 点击状态标签 → 弹出下拉菜单
  3. 选择新状态（到课/缺勤/迟到/请假/其他）
  4. 代码调用：`_updateStatus(recordId, newStatus)`

### 4.4 修改后的数据写入

- **代码**：`records_repository.dart::updateRecord()`
- **操作**：
  1. 更新本地 Drift 数据库（`attendance_records` 表）
  2. 更新 `updated_at` 字段
  3. **入队 SyncQueue**（action=update, entityType=record）
  4. **立即触发同步**：`syncService.syncNow()`

### 4.5 同步检查

- **代码**：`record_detail_page.dart::_updateStatus()`
- **检查**：如果正在同步中，弹出提示"数据正在自动同步中，请稍候再编辑"
- **同步完成后**：
  - 成功：`LoggerService.sync('记录编辑已同步')`
  - 失败：`LoggerService.sync('记录编辑同步失败', isError: true)`

### 4.6 多次修改

- **支持**：可以无限次修改
- **限制**：每次修改都会入队 SyncQueue
- **合并**：如果同一记录有未同步的 create，update 会合并到 create 的 payload 中（`attendance_local_ds.dart::enqueueSync()`）

### 4.7 删除任务（v0.6.0+ 逻辑变更）

- **入口**：查课记录页 → 任务卡片 → 删除按钮
- **代码**：`records_repository.dart::deleteTask()`
- **操作**：
  1. **不再物理删除数据**（旧逻辑）
  2. 更新任务状态为 `abandoned`（新逻辑）
  3. 保留所有 records 和 task_classes 数据
  4. **入队 SyncQueue**（action=update, entityType=task, payload={status: 'abandoned'}）
  5. 异步同步到服务端
- **刷新**：删除后 invalidate 以下 provider：
  - `weekNameCheckTasksProvider`
  - `submittedTaskIdsProvider`
  - `mySubmissionsProvider`
- **服务端保护**：`update_task` 在改为 abandoned 时检查是否已关联 pending/approved submission，已提交则返回 403

### 4.8 重新生成汇报文本

- **入口**：记名详情页 → 点击右上角"生成文本"图标
- **代码**：`_generateText()`
- **操作**：
  1. 从本地数据库读取当前所有记录
  2. 按班级统计
  3. 生成学委汇报 + 总群汇报
  4. 弹出 BottomSheet 显示

---

## 五、核心用户流程：最终总群汇报

### 5.1 场景描述

当所有状态修改完成后，用户在查课记录详情中：
1. 点击"生成文本"
2. 切换到"总群汇报"Tab
3. 点击"复制并打开微信"

### 5.2 代码实现

- **页面**：`record_detail_page.dart::_TextSheet::_buildGroupReportView()`
- **操作**：
  1. 弹出**确认警告对话框**：
     - 标题："重要警告"
     - 内容："确认该记录为最终记录吗？确认后将复制文本并跳转微信，此操作不可撤销。"
     - 按钮："取消" / "确认最终记录"（橙色）
  2. 用户确认后：
     - `Clipboard.setData()`
     - 延迟 300ms
     - `launchUrl(Uri.parse('weixin://'))`

### 5.3 关键问题

**Q1：总群汇报使用的是当前本地记录，还是服务端记录？**
- **答案**：当前**本地记录**
- 代码从本地 Drift 读取，不查询服务端

**Q2：点击复制并打开微信后，代码是否认为这是最终记录？**
- **答案**：**没有**
- 代码只是弹出一个警告对话框，**没有修改任何状态**
- 没有锁定记录、没有标记"已最终确认"

**Q3：这一步是否会改变任务状态？**
- **答案**：**不会**
- 任务状态保持 `completed`

**Q4：这一步和后面的"名单提交"是什么关系？**
- **答案**：**完全独立**
- 总群汇报只是复制文本，**不触发任何提交逻辑**
- 提交审核需要用户手动去"扩展功能 → 名单提交"

---

## 六、最重要流程：扩展功能 - 名单提交

### 6.1 入口和前提

- **入口**：首页 → 扩展功能 → 名单提交
- **前提**：
  1. 用户必须已登录
  2. 用户必须被分配查课职务（`duty_assignments` 表）
  3. 必须有本周已完成的记名任务

### 6.2 提交任务列表

- **代码**：`submission_page.dart::_SubmitTaskTab`
- **过滤条件**：
  1. **只显示本周任务**：`createdAt` 在本周范围内（根据服务端 `week_config` 计算）
  2. **只显示 completed 的 name_check 任务**
  3. **过滤掉已提交的任务**：通过 `submittedTaskIdsProvider` 查询

- **显示信息**：
  - 班级名称
  - 记录数量
  - 创建时间

### 6.3 多选任务

- **操作**：Checkbox 多选
- **限制**：可以选择多个任务一起提交

### 6.4 提交前强制同步

- **代码**：`_submit()` 方法
- **操作**：
  1. 调用 `syncService.syncNow()`
  2. 如果 `result.failed > 0`：
     - 阻止提交
     - 弹出 Toast："同步失败 X 项，请检查网络后重试"
     - **返回，不继续**
  3. 再次检查待同步项（同步过程中可能有新修改）
  4. 最终检查仍有未同步项 → 阻止提交

### 6.5 提交前二次校验

- **代码**：`_submit()` 方法
- **校验内容**：
  1. 遍历选中 taskId，确认任务仍存在且状态为 `completed`
  2. 调用 `remoteDS.getTask()` 获取服务端状态
  3. 如果本地 `completed` 但服务端不是 → 主动调用 `updateTask(status: completed)` 修复
  4. 修复失败 → 阻止提交，提示"任务状态尚未同步完成，请先同步后再提交"

### 6.6 确认对话框

- **代码**：`_SubmissionConfirmDialog`
- **显示内容**：
  - 每个任务的统计信息：
    - 班级名称
    - 总人数
    - 到课人数
    - 缺勤人数（如有则显示红色）
    - 迟到人数（如有则显示黄色）
    - 请假人数（如有则显示蓝色）
    - 其他人数（如有则显示紫色）
  - **异常警告**：如果有异常记录，显示橙色警告卡片

- **用户操作**：
  - 点击"取消" → 返回
  - 点击"确认提交" → 继续

### 6.6 调用提交接口

- **代码**：`submissionService.createSubmission()`
- **请求**：`POST /api/submissions`
- **参数**：
  ```json
  {
    "week_number": 12,
    "task_ids": ["uuid-1", "uuid-2"]
  }
  ```

### 6.7 服务端创建 Submission

- **代码**：`server/app/routers/submission.py::create_submission()`
- **操作**：
  1. 验证任务属于当前用户
  2. 查询所有关联的 `attendance_records`
  3. **检查重复提交**：
     - 查询 `submission_records` 表
     - 如果任何 record 已关联其他 submission → 返回 400
  4. 创建 `Submission` 对象：
     - `user_id = current_user.id`
     - `week_number = body.week_number`
     - `status = "pending"`
     - `class_names = 班级名称拼接`
  5. 创建 `SubmissionRecord` 关联：
     - 每个 `attendance_record` 对应一条 `submission_record`
  6. 返回 `SubmissionResponse`

### 6.8 提交成功后状态

| 对象 | 状态 |
|------|------|
| AttendanceTask | `completed`（不变） |
| AttendanceRecord | 保持原状态（不变） |
| Submission | `pending`（待审核） |
| SyncQueue | 之前的同步队列继续消费 |

---

## 七、管理员审核流程

### 7.1 查看待审核名单

- **入口**：首页 → 扩展功能 → 周名单汇总
- **页面**：`weekly_summary_page.dart`
- **权限**：只有 `role=admin` 的用户能看到待审核列表

### 7.2 看到的是 Submission 还是 Task？

- **答案**：看到的是 **Submission**
- 管理员不直接操作 Task，而是操作 Submission

### 7.3 查看详情

- **代码**：`submission_page.dart::_SubmissionCard::_showDetailDialog()`
- **读取的表**：
  1. `submissions` 表
  2. `submission_records` 表
  3. `attendance_records` 表（通过 record_id 关联）
  4. `students` 表（通过 student_id 关联）
  5. `classes` 表（通过 class_id 关联）

### 7.4 审核通过

- **接口**：`PUT /api/submissions/{id}/approve`
- **代码**：`server/app/routers/submission.py::approve_submission()`
- **操作**：
  1. 检查权限（admin）
  2. 检查状态（必须为 pending）
  3. 更新 Submission：
     - `status = "approved"`
     - `reviewer_id = current_user.id`
     - `review_time = now()`
  4. 返回成功消息

### 7.5 审核拒绝

- **接口**：`PUT /api/submissions/{id}/reject`
- **代码**：`server/app/routers/submission.py::reject_submission()`
- **操作**：
  1. 检查权限（admin）
  2. 检查状态（必须为 pending）
  3. 更新 Submission：
     - `status = "rejected"`
     - `reviewer_id = current_user.id`
     - `review_time = now()`
     - `review_note = body.note`
  4. **删除所有 SubmissionRecord 关联**
  5. 返回成功消息

### 7.6 审核拒绝后能否重新提交？

- **答案**：**可以**
- Submission 状态变为 `rejected`
- 原来的 Task 和 Record 没有变化
- 用户可以重新去"名单提交"页面再次提交

### 7.7 成员撤回待审核提交

- **接口**：`DELETE /api/submissions/{id}`
- **代码**：`server/app/routers/submission.py::cancel_submission()`
- **操作**：
  1. 检查权限（只能撤回自己的）
  2. 检查状态（必须为 pending）
  3. **删除所有 SubmissionRecord 关联**
  4. 更新 Submission：`status = "cancelled"`
  5. 返回成功消息

### 7.8 审核通过后记录是否仍可修改？

- **客户端**：**可以修改**
  - 查课记录详情页没有检查 Submission 状态
  - 用户可以继续修改记录
  - 修改后入队 SyncQueue，同步到服务端

- **服务端**：**可以修改**
  - `attendance_records` 表没有锁定机制
  - 更新接口不检查是否已提交

---

## 八、周名单汇总和 Excel 导出

### 8.1 周次计算

- **来源**：服务端 `week_config` 表
- **公式**：`week_number = (current_date - start_date).days // 7 + 1`
- **规则**：周一零点为新的一周开始

### 8.2 周汇总统计

- **接口**：`GET /api/submissions/week-summary/{week_number}`
- **代码**：`server/app/routers/submission.py::get_week_summary()`
- **统计范围**：
  - **只统计 approved 的 Submission**
  - 不统计 pending、rejected、cancelled

### 8.3 统计数据

| 统计项 | 说明 |
|--------|------|
| `late_count` | 迟到人次（多次迟到算多次） |
| `absent_count` | 缺勤人次 |
| `leave_count` | 请假期人次 |
| `other_count` | 其他人次 |
| `late_student_count` | 迟到学生数（去重） |
| `absent_student_count` | 缺勤学生数（去重） |
| `total_abnormal_students` | 异常学生总数（去重） |

### 8.4 Excel 导出

- **接口**：`GET /api/submissions/export/{week_number}`
- **代码**：`server/app/routers/submission.py::export_week_excel()`
- **读取的数据**：
  - 实时查询 `attendance_records` 表
  - 通过 `submission_records` 关联
  - **不是快照，是实时数据**

### 8.5 关键风险

**如果审核通过后原始记录被修改，导出的 Excel 会跟着变化**

因为：
1. Excel 导出读取的是实时 `attendance_records`
2. 记录可以被用户随时修改
3. 修改会同步到服务端
4. **没有版本控制或快照机制**

### 8.6 发布汇总

- **操作**：管理员导出 Excel 后，系统自动创建 `week_export` 记录
- **标记**：`is_published = true`
- **普通成员**：只能查看已发布的周次汇总

---

## 九、数据同步流程

### 9.1 本地优先架构

```
用户操作 → Notifier → Repository → LocalDS (Drift)
                                    ↓
                              SyncQueue 入队
                                    ↓
                              SyncService 消费
                                    ↓
                              RemoteDS → API → MySQL
```

### 9.2 创建任务时

1. `AttendanceRepository.createTask()`
2. 写入 `attendance_tasks` 表
3. 入队 SyncQueue：`entityType=task, action=create`
4. SyncService 每 10 秒消费队列
5. 调用 `POST /api/tasks` 创建服务端任务

### 9.3 创建记录时

1. `AttendanceRepository.createRecord()`
2. 写入 `attendance_records` 表
3. 入队 SyncQueue：`entityType=record, action=create`
4. SyncService 消费
5. 调用 `POST /api/tasks/{id}/records` 批量创建

### 9.4 修改记录时

1. `RecordsRepository.updateRecord()`
2. 更新 `attendance_records` 表
3. 入队 SyncQueue：`entityType=record, action=update`
4. SyncService 消费
5. 调用 `PUT /api/records/by-task-student` 或 `PUT /api/records/{id}`

### 9.5 SyncQueue 入队逻辑

- **代码**：`attendance_local_ds.dart::enqueueSync()`
- **合并规则**：
  - 如果同一记录有 pending 的 create，update 会合并到 create 的 payload
  - 不重复创建 queue item

### 9.6 SyncService 同步时机

1. **定时同步**：每 10 秒自动消费队列
2. **启动同步**：App 启动时检查 pending/failed 记录，自动同步
3. **手动同步**：设置页可手动触发
4. **编辑后立即同步**：`record_detail_page.dart::_updateStatus()` 中调用 `syncService.syncNow()`

### 9.7 提交前强制同步

- **代码**：`submission_page.dart::_submit()`
- **逻辑**：
  1. 调用 `syncNow()`
  2. 如果有失败项 → 阻止提交
  3. 如果全部成功 → 继续提交流程

### 9.8 同步失败处理（v0.6.0+）

**三种失败分类**：

| 错误类型 | 处理方式 | retryCount | 用户提示 |
|---------|---------|-----------|---------|
| **网络错误** | 标记 failed，自动重试 | +1 | "网络不可用，请检查网络后重试" |
| **认证过期 401** | 标记 failed=999，中断同步 | 999 | "登录状态已过期，请重新登录后继续同步" |
| **其他错误** | 正常重试，5次后放弃 | +1 | 按原有逻辑 |

**401 闭环处理**：
1. Token 过期 → 同步返回 401
2. 只清除 token，保留 userId 和本地数据（**避免数据丢失**）
3. `pendingSyncCountProvider` 统计到 retryCount=999 的项
4. 关键操作（提交/导出/退出登录）被阻止
5. 用户重新登录 → `resetAuthFailedSyncItems()` 恢复为 pending
6. 自动触发 `syncNow()` 继续同步

**网络错误处理**：
- 标记 failed，下次自动重试（最多5次）
- 网络恢复后自动继续同步
- 用户可手动触发同步（设置 → 手动同步）

**404 错误**：
- 标记为 synced（跳过）
- 通常表示服务端记录已被删除

### 9.9 Token 过期处理（v0.6.0+）

- **检测**：API 返回 401
- **处理**：
  1. **只清理 token**，保留 userId 等用户信息
  2. **不清空本地数据库**（数据不丢失）
  3. 跳转登录页
  4. 弹出提示："登录状态已过期，需要重新认证。本地数据已保留，登录后可继续同步。"
  5. 重新登录后自动重置 auth failed 项并触发同步

### 9.10 退出登录保护（v0.6.0+）

**触发条件**：有未同步数据（含 pending + failed(retry<5) + auth_failed(retry=999)）

**表现**：
- 弹窗提示"无法退出登录"
- 红色警告区域显示未同步数据数量
- **禁用"退出"按钮**
- 只提供"立即同步"按钮

**目的**：防止用户误操作导致未同步数据永久丢失

### 9.11 可能出现的不同步场景

| 场景 | 风险 | 当前处理 |
|------|------|----------|
| 网络不稳定 | 同步失败 | 自动重试 5 次 |
| App 关闭 | 队列未消费完 | 下次启动继续同步 |
| 缓存未刷新 | 显示旧数据 | 下拉刷新或重新进入页面 |
| 多设备登录 | 同一账号多设备 | **无处理，各自独立** |
| 编辑后立即提交 | 同步未完成 | 强制同步，失败阻止提交 |
| 服务端记录被删 | 同步 404 | 标记为 synced，跳过 |

---

## 十、状态流转表

### 10.1 AttendanceTask.status

| 状态值 | 含义 | 触发操作 | 允许编辑记录 | 允许提交 | 允许撤回 | 进入周汇总 |
|--------|------|----------|--------------|----------|----------|------------|
| `in_progress` | 进行中 | 创建任务后 | ✅ | ❌ | - | ❌ |
| `completed` | 已完成 | 点击"确认名单"后 | ✅ | ✅ | - | ❌ |
| `abandoned` | 已放弃 | 点击"放弃"后 | ❌ | ❌ | - | ❌ |

### 10.2 AttendanceTask.phase

| 状态值 | 含义 | 触发操作 |
|--------|------|----------|
| `selecting` | 选择中 | 刚创建任务 |
| `executing` | 执行中 | 进入记名/点名页面 |
| `confirming` | 确认中 | 点击"确认名单"后 |
| `text_generating` | 文本生成中 | 进入汇报文本页 |

### 10.3 AttendanceRecord.status

| 状态值 | 含义 | 显示颜色 |
|--------|------|----------|
| `pending` | 待查 | 灰色 |
| `present` | 到课 | 绿色 |
| `absent` | 缺勤 | 红色 |
| `late_` | 迟到 | 黄色 |
| `leave` | 请假 | 蓝色 |
| `other` | 其他 | 紫色 |

### 10.4 Submission.status

| 状态值 | 含义 | 触发操作 | 允许编辑记录 | 允许再次提交 | 允许撤回 |
|--------|------|----------|--------------|--------------|----------|
| `pending` | 待审核 | 创建提交后 | ✅ | ❌ | ✅ |
| `approved` | 已通过 | 管理员审核通过 | ✅ | ❌ | ❌ |
| `rejected` | 已拒绝 | 管理员审核拒绝 | ✅ | ✅ | ❌ |
| `cancelled` | 已撤销 | 成员撤回后 | ✅ | ✅ | ❌ |

### 10.5 SyncQueue.syncStatus

| 状态值 | 含义 | 触发操作 | retryCount |
|--------|------|----------|-----------|
| `pending` | 待同步 | 创建/更新记录后入队 | 0 |
| `syncing` | 同步中 | SyncService 正在处理 | - |
| `synced` | 已同步 | 同步成功或 404 跳过 | - |
| `failed` | 失败（可重试） | 网络错误或其他错误 | < 5 |
| `failed` | 失败（认证过期） | 401 未登录 | **999** |

---

## 十一、风险点与修复状态

### 11.1 数据一致性风险 ✅ 已修复（v0.6.0）

**原问题**：审核通过后，用户仍可在客户端修改记录，修改会同步到服务端，导致导出的 Excel 与实际提交时的数据不一致。

**修复措施**：
- 服务端 `records.py` 新增 `_check_record_editable()`：已关联 pending/approved submission 的记录返回 403
- 前端 `record_detail_page.dart`：进入页面检查任务是否已提交，已提交则禁用编辑并显示橙色提示条
- 服务端 `update_task` 在改为 `abandoned` 时检查是否已提交，已提交则返回 403

### 11.2 重复提交风险 ⚠️ 已缓解

**原问题**：虽然服务端有 `uk_record` 唯一约束防止同一 record 被多次提交，但如果用户在客户端删除任务后重新创建，可能产生重复数据。

**缓解措施**：
- 删除任务改为标记 `abandoned`（v0.6.0+），已提交的任务不能删除
- 但其他场景（如 rejected 后删除再创建）仍可能产生重复

### 11.3 同步延迟风险 ⚠️ 仍存

**问题**：如果用户在同步完成前关闭 App，下次启动时自动同步，但如果用户在此期间在另一设备上操作，可能产生冲突。

**代码证据**：
- 没有乐观锁或版本号机制
- 同步策略是"最后写入 wins"

**建议**：
- 短期内不处理（单用户单设备场景为主）
- 长期可考虑添加 `version` 字段或 `updated_at` 时间戳校验

### 11.4 总群汇报不是"最终"标记 ✅ 已修复（文案层面）

**原问题**：总群汇报的警告对话框提示"此操作不可撤销"，用户可能误以为点击后就锁定了数据。

**修复措施**：
- 文案已修正，删除"不可撤销"误导
- 提示改为"请前往扩展功能 → 名单提交"，明确告知用户还需要单独提交
- 总群汇报只是文本复制工具，不修改任何状态（这是设计如此）

### 11.5 周汇总统计可能不准确 ⚠️ 仍存

**问题**：周汇总统计的是 approved Submission 关联的实时 attendance_records，如果审核通过后记录被修改，统计结果会变化。

**代码证据**：
- `submission.py::get_week_summary()` 实时查询 AttendanceRecord
- 没有使用提交时的快照

**影响**：
- 已修复 11.1 后，普通用户无法再修改已提交记录
- 只有管理员或有特殊权限的用户才能修改，风险降低
- 长期可考虑在 approved 时创建 snapshot 表

---

---

## 十二、批量同步机制（v0.6.0+）

### 12.1 流程

```
SyncQueue: [record_update, record_update, task_update, record_update, ...]
              ↓
遍历队列时，遇到连续的 record/update：
  - 收集连续项（最多 50 条）
  - 只有 ≥2 条才走批量接口
  - 不足 2 条或中间被其他类型打断 → 逐条处理
              ↓
调用 POST /records/batch-update
  Body: [{task_id, student_id, status}, ...]
              ↓
服务端逐个校验：
  - 记录是否存在
  - 是否已关联 pending/approved submission
  - 是否有权限
  → 通过则加入 success 列表
  → 不通过则加入 failed 列表
              ↓
服务端统一 db.commit()
              ↓
App 解析返回：
  - success 项 → markSynced
  - failed 项按 reason 处理：
      * "记录不存在"/"已提交审核" → markSynced（跳过）
      * 其他 → markSyncFailed + retry
  - 网络错误 → 整个 batch 标记 failed，中断同步
```

### 12.2 触发条件

- 连续的 `record/update` 项 ≥ 2 条
- 最多合并 50 条
- 被其他 entityType 打断时，当前 batch 结束

### 12.3 效果

- 修改 3 个学生状态 → 1 次批量请求（原本 3 次）
- 修改 50 个学生状态 → 1 次批量请求（原本 50 次）
- 混合操作（record update + task update + record update）→ 2 个 batch

---

## 十三、FAQ 帮助页面（v0.6.0+）

### 13.1 入口

**设置 → 常见问题与解决方案**

### 13.2 内容结构

按 5 个类别分组，共 16 个问题：

**数据同步（4个）**
- 为什么提交名单前要等同步完成？
- 为什么有未同步数据时不能提交名单或导出 Excel？
- 网络断开或同步失败怎么办？
- 登录状态过期了怎么办？

**名单提交（5个）**
- 为什么提交审核后就不能修改记录了？
- 提交后发现名单有误怎么办？
- 为什么我删除了查课记录后，它还在名单提交里？
- 总群汇报和名单提交是什么关系？
- 多次修改记录后，怎么确保提交的是最终名单？

**管理员审核（2个）**
- 管理员审核"通过"和"拒绝"分别意味着什么？
- 周汇总和 Excel 导出依据是什么？

**账户安全（1个）**
- 为什么有时退出登录会被禁止？

**查课记录（2个）**
- 查课记录可以修改几次？有次数限制吗？
- 为什么查课记录里有"放弃"的任务？

**记名操作（2个）**
- 记名时没处理完所有学生就退出了，数据会丢失吗？
- 一个学生被错误标记了，怎么改？

### 13.3 交互

- 折叠卡片：点击问题展开/收起答案
- 带动画效果（旋转箭头 + 淡入淡出）
- 按类别分组显示，带颜色标题

### 13.4 代码位置

`app/lib/features/settings/presentation/faq_page.dart`

---

> 本文档完。所有内容基于 `v0.6.0` 代码实际实现整理，未做任何假设或推测。
