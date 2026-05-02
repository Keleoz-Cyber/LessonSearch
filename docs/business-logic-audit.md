## 业务逻辑检查报告

> 基于 v0.6.0 代码实际实现和 business-flow.md 整理
> 检查日期：2026-05-01

---

### 1. 总体结论

当前业务逻辑**基本闭环**，但存在**两个严重漏洞**：

1. **审核通过后仍可修改原始记录**：服务端 `update_record` 和 `update_record_by_task_student` 接口完全没有校验 record 是否已关联 pending/approved submission。前端查课记录详情页也没有任何锁定检查。这会导致审核后的周汇总和 Excel 导出与实际提交时的数据不一致。

2. **提交后本地任务没有任何锁定标记**：提交成功后，本地 `AttendanceTask` 和 `AttendanceRecord` 的状态没有任何变化，用户可以继续编辑，且编辑会正常入队同步到服务端。

其余问题多为边界情况或体验优化，不影响核心流程。

---

### 2. 高风险问题

#### 问题 1：审核通过后用户仍可修改原始记录并同步到服务端
- 严重等级：**高**
- 涉及文件：
  - `server/routers/records.py`（update_record, update_record_by_task_student）
  - `app/lib/features/records/presentation/record_detail_page.dart`（_updateStatus）
  - `app/lib/features/records/data/records_repository.dart`（updateRecord）
- 当前代码行为：
  1. 服务端 `update_record` 接口只检查 record 是否存在，**不检查是否已关联 submission**
  2. 前端 `_updateStatus` 只检查是否正在同步，**不检查是否已提交**
  3. 修改后正常入队 SyncQueue，同步到服务端
- 为什么有风险：
  - 用户提交审核 → 管理员审核通过 → 用户回到查课记录修改某学生状态 → 同步到服务端 → 周汇总和 Excel 导出数据变化 → 与提交时不一致
- 可能出现的真实场景：
  - 学委反馈某学生状态有误，用户在审核通过后去修改
  - 多设备登录，设备 B 不知道设备 A 已提交
- 建议修复方式：
  - **服务端**：record update 接口增加校验：查询 `submission_records` 表，如果该 record 已关联 pending/approved submission，则返回 403 禁止普通用户修改
  - **前端**：编辑前查询或缓存 submitted/locked 状态，如果是 pending/approved，禁用编辑并提示"已提交审核，不可修改"
- 是否必须后端修复：**是**

#### 问题 2：提交后本地任务没有任何锁定标记
- 严重等级：**高**
- 涉及文件：
  - `app/lib/features/attendance/data/attendance_repository.dart`
  - `app/lib/features/extension/presentation/submission_page.dart`
- 当前代码行为：
  - 提交成功后，只刷新了 `submittedTaskIdsProvider` 和 `weekNameCheckTasksProvider`
  - 本地 `AttendanceTask` 的 status 仍然是 `completed`
  - 本地 `AttendanceRecord` 没有任何标记
- 为什么有风险：
  - 用户可以在不知道已提交的情况下继续编辑
  - 前端只能通过"已提交任务列表"间接知道，但查课记录页面没有任何提示
- 建议修复方式：
  - 提交成功后，给本地任务增加一个 `submission_status` 字段（或在内存中标记）
  - 查课记录列表和详情页显示"已提交审核"标签
  - 编辑按钮禁用或显示提示
- 是否必须后端修复：**否**（前端 + 本地数据库即可）

#### 问题 3：总群汇报的"确认最终记录"文案误导用户
- 严重等级：**中**
- 涉及文件：
  - `app/lib/features/attendance/presentation/text_generation/text_gen_page.dart`
  - `app/lib/features/records/presentation/record_detail_page.dart`（_TextSheet）
- 当前代码行为：
  - 文案："确认该记录为最终记录吗？确认后将复制文本并跳转微信，此操作不可撤销。"
  - 实际上：点击后只复制文本并跳转微信，**没有任何状态变更**，用户仍可编辑
- 为什么有风险：
  - 用户误以为点击"确认最终记录"后数据已锁定
  - 后续发现需要修改时会困惑
- 建议修复方式：
  - 文案改为："确认复制最终汇报文本？请随后前往'扩展功能 → 名单提交'完成提交审核。"
  - 删除"不可撤销"的表述
- 是否必须后端修复：**否**

#### 问题 4：get_submitted_task_ids 逻辑不够明确
- 严重等级：**中**
- 涉及文件：
  - `server/app/routers/submission.py`（get_submitted_task_ids）
- 当前代码行为：
  - 查询用户的**所有 submission**（包括 pending/approved/rejected/cancelled）
  - 遍历每个 submission 的 submission_records
  - 返回关联的 task_id 列表
- 为什么有风险：
  - 虽然 rejected/cancelled 的 submission_records 已被删除，实际不会返回 task_id
  - 但代码逻辑不清晰，维护者可能误以为会包含 rejected/cancelled
  - 如果未来 rejected/cancelled 不删除 submission_records，就会出 bug
- 建议修复方式：
  - 明确过滤：`Submission.status.in_(['pending', 'approved'])`
- 是否必须后端修复：**是**

#### 问题 5：周汇总和 Excel 导出读取实时数据，无快照
- 严重等级：**中**
- 涉及文件：
  - `server/app/routers/submission.py`（get_week_summary, export_week_excel）
- 当前代码行为：
  - `get_week_summary` 实时查询 `attendance_records` 表
  - `export_week_excel` 实时查询 `attendance_records` 表
  - 如果 approved 后记录被修改（目前可以修改），统计结果会变化
- 为什么有风险：
  - 管理员本周导出的 Excel 和上周看到的数据可能不一致
  - 历史数据无法追溯
- 建议修复方式：
  - **最小方案**：approved 后禁止修改原始记录（修复问题 1 后此问题缓解）
  - **更稳方案**：提交时保存 snapshot，汇总和导出使用 snapshot
- 是否必须后端修复：**是**

#### 问题 6：record update 接口没有 user_id 校验
- 严重等级：**中**
- 涉及文件：
  - `server/routers/records.py`（update_record, update_record_by_task_student）
- 当前代码行为：
  - `update_record` 只检查 record 是否存在，不检查当前用户是否有权修改
  - `update_record_by_task_student` 同样不检查用户权限
- 为什么有风险：
  - 理论上，任何登录用户都可以修改任何 record（虽然目前需要知道 record_id）
  - 配合问题 1，即使不是自己的记录也可以修改
- 建议修复方式：
  - 通过 record 的 task_id 找到 task，检查 task.user_id 是否等于当前用户
  - 或者检查 record 是否属于当前用户的 task
- 是否必须后端修复：**是**

---

### 3. 状态流转问题

#### 3.1 AttendanceRecord 可编辑性检查

| 状态 | 前端是否允许编辑 | 本地是否更新 | SyncQueue 是否入队 | 服务端是否接受更新 | 是否一致 |
|------|-----------------|-------------|-------------------|-------------------|---------|
| 未提交 | ✅ 允许 | ✅ 是 | ✅ 是 | ✅ 是 | ✅ 一致 |
| 已提交 pending | ✅ 允许 | ✅ 是 | ✅ 是 | ✅ 是 | ❌ **不一致** |
| 审核通过 approved | ✅ 允许 | ✅ 是 | ✅ 是 | ✅ 是 | ❌ **不一致** |
| 审核拒绝 rejected | ✅ 允许 | ✅ 是 | ✅ 是 | ✅ 是 | ⚠️ 应允许，但需先释放关联 |
| 已撤回 cancelled | ✅ 允许 | ✅ 是 | ✅ 是 | ✅ 是 | ⚠️ 应允许，但需先释放关联 |
| 周汇总已发布 | ✅ 允许 | ✅ 是 | ✅ 是 | ✅ 是 | ❌ **不一致** |
| Excel 已导出 | ✅ 允许 | ✅ 是 | ✅ 是 | ✅ 是 | ❌ **不一致** |

**结论**：除了"未提交"状态，其余所有状态下前端都允许编辑，服务端都接受更新。**这违反了业务规则 5、6、9**。

#### 3.2 Submission 状态流转检查

| 流转 | 当前代码支持 | 业务要求 | 是否一致 | 说明 |
|------|-------------|---------|---------|------|
| pending → approved | ✅ | ✅ | ✅ | 管理员审核通过 |
| pending → rejected | ✅ | ✅ | ✅ | 管理员审核拒绝 |
| pending → cancelled | ✅ | ✅ | ✅ | 成员撤回 |
| rejected → 重新提交 | ✅ | ✅ | ✅ | SubmissionRecord 已删除，可重新提交 |
| cancelled → 重新提交 | ✅ | ✅ | ✅ | SubmissionRecord 已删除，可重新提交 |

**结论**：Submission 状态流转本身是正确的。问题在于 approved 后没有锁定原始记录。

#### 3.3 get_submitted_task_ids 行为检查

| submission 状态 | 是否有 submission_records | 是否返回 task_id | 是否符合预期 |
|----------------|-------------------------|-----------------|-------------|
| pending | ✅ 有 | ✅ 是 | ✅ 符合 |
| approved | ✅ 有 | ✅ 是 | ✅ 符合 |
| rejected | ❌ 已删除 | ❌ 否 | ✅ 符合（巧合） |
| cancelled | ❌ 已删除 | ❌ 否 | ✅ 符合（巧合） |

**结论**：实际行为正确，但代码逻辑不明确。应明确过滤 status。

---

### 4. 数据一致性问题

#### 4.1 数据流分析

```
用户修改记录
    ↓
本地 Drift 更新
    ↓
SyncQueue 入队
    ↓
SyncService 同步到服务端 AttendanceRecord
    ↓
（如果已提交）SubmissionRecord 关联的是同一个 AttendanceRecord
    ↓
周汇总 / Excel 导出读取实时 AttendanceRecord
```

#### 4.2 不一致场景

**场景 1：审核通过后修改**
1. 用户提交审核（ Submission.status = pending，SubmissionRecord 关联 Record A）
2. 管理员审核通过（Submission.status = approved）
3. 用户在查课记录修改 Record A 的状态（缺勤 → 到课）
4. 同步到服务端，AttendanceRecord 更新
5. 管理员导出 Excel → Record A 显示"到课"（与提交时"缺勤"不一致）

**场景 2：多设备编辑**
1. 设备 A 提交审核（Submission.status = pending）
2. 设备 B 缓存了旧数据，用户继续编辑
3. 设备 B 的编辑同步到服务端
4. 服务端 record 已变，但 SubmissionRecord 关联的还是同一个 record

**场景 3：周汇总发布后修改**
1. 管理员审核通过并导出 Excel（WeekExport 创建）
2. 用户在查课记录修改某学生状态
3. 同步到服务端
4. 下周管理员查看同一周汇总 → 数据与上周导出的 Excel 不一致

#### 4.3 根本原因

- **没有记录锁定机制**：提交后 AttendanceRecord 仍可变
- **没有快照机制**：周汇总和 Excel 读取实时数据
- **没有版本控制**：无法区分"提交时的状态"和"当前状态"

---

### 5. 最小修复方案

#### P0（必须修复，影响数据一致性）

1. **服务端 record update 接口增加校验**
   ```python
   # server/routers/records.py
   def _check_record_editable(record_id, current_user, db):
       record = db.query(AttendanceRecord).filter(AttendanceRecord.id == record_id).first()
       if not record:
           raise HTTPException(404, "记录不存在")
       
       # 检查是否已关联 pending/approved submission
       sr = db.query(SubmissionRecord).join(Submission).filter(
           SubmissionRecord.record_id == record_id,
           Submission.status.in_(['pending', 'approved'])
       ).first()
       if sr:
           raise HTTPException(403, "该记录已提交审核，不可修改")
       
       # 检查是否属于自己的任务
       task = db.query(AttendanceTask).filter(AttendanceTask.id == record.task_id).first()
       if task and task.user_id != current_user.id:
           raise HTTPException(403, "无权修改此记录")
       
       return record
   ```

2. **前端查课记录详情页增加提交状态检查**
   - 进入页面时查询该 task 是否已提交（调用 `/submissions/submitted-task-ids`）
   - 如果已提交，禁用编辑按钮，显示"已提交审核，不可修改"
   - 或只允许 admin 编辑

3. **get_submitted_task_ids 明确过滤 status**
   ```python
   submissions = db.query(Submission).filter(
       Submission.user_id == current_user.id,
       Submission.status.in_(['pending', 'approved'])
   ).all()
   ```

#### P1（强烈建议修复，影响用户体验）

4. **提交成功后刷新本地状态**
   - 提交成功后，在本地标记 task 为"已提交"
   - 查课记录列表显示提交状态标签
   - 返回首页时刷新记录列表

5. **总群汇报文案修改**
   - 删除"不可撤销"表述
   - 增加提示："请随后前往'扩展功能 → 名单提交'完成提交审核"

6. **删除记录前检查提交状态**
   - 当前代码已检查（`records_list_page.dart::_confirmDelete`）
   - 但检查的是 submittedTaskIdsProvider，如果 rejected/cancelled 的任务不在其中，用户可以删除
   - 这是正确的：rejected/cancelled 后应该允许删除或重新提交

#### P2（长期优化，可选）

7. **增加提交快照表**
   - 新建 `submission_snapshots` 表
   - 提交时保存 record 的快照（record_id, status, remark, submitted_at）
   - 周汇总和 Excel 读取快照表，而不是实时 attendance_records

8. **增加 record version 校验**
   - 客户端同步时携带 `updated_at`
   - 服务端检查 `updated_at` 是否匹配，防止覆盖

---

### 6. 需要确认的业务规则

以下规则需要用户确认，代码中未明确体现：

1. **总群汇报后是否锁定？**
   - 当前代码：不锁定
   - 业务需求：只是"接近最终"，真正锁定在提交审核后
   - **建议：不锁定，但修改文案提示用户还需提交审核**

2. **approved 后是否允许管理员退回？**
   - 当前代码：不允许（没有 unapprove 接口）
   - 业务需求：？
   - **建议：如果管理员发现错误，可以联系用户撤回后重新提交**

3. **Excel 导出后是否永久锁定？**
   - 当前代码：没有锁定
   - 业务需求：？
   - **建议：如果 approved 后禁止修改，则 Excel 导出后自然锁定**

4. **请假/其他是否进入累计分？**
   - 当前代码：Excel 导出只统计迟到和缺勤，累计分 = 迟到/2 + 缺勤
   - 周汇总统计包括迟到、缺勤、请假、其他的人次和学生数
   - 业务需求：？

5. **一条记录被 rejected 后是否保留旧 submission 历史？**
   - 当前代码：保留 Submission 记录（status=rejected），但删除 SubmissionRecord 关联
   - 业务需求：？
   - **建议：保留历史，但释放关联以便重新提交**

6. **没有 duty 的用户是否能提交？**
   - 当前代码：前端检查 duty，但服务端 create_submission 没有检查 duty
   - 业务需求：？
   - **建议：服务端也应检查 duty，防止绕过前端**

---

### 7. 检查文件清单

已检查的文件：
- ✅ `docs/business-flow.md`
- ✅ `app/lib/features/records/presentation/record_detail_page.dart`
- ✅ `app/lib/features/records/data/records_repository.dart`
- ✅ `app/lib/features/attendance/data/attendance_repository.dart`
- ✅ `app/lib/features/attendance/application/name_check_notifier.dart`
- ✅ `app/lib/features/extension/presentation/submission_page.dart`
- ✅ `app/lib/features/extension/data/submission_service.dart`
- ✅ `app/lib/core/sync/sync_service.dart`
- ✅ `server/app/routers/submission.py`
- ✅ `server/app/models/submission.py`
- ✅ `server/routers/tasks.py`
- ✅ `server/routers/records.py`
- ✅ `server/app/models/record.py`
- ✅ `server/app/models/task.py`
- ✅ `app/lib/features/records/presentation/records_list_page.dart`

---

**总结**：核心流程基本正确，但存在**两个严重漏洞**（审核后可修改、无锁定标记）和**若干边界问题**。建议优先修复 P0 项。
