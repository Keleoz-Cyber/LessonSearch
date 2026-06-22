import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_card.dart';

class FaqItem {
  final String question;
  final String answer;
  final String category;

  const FaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

final List<FaqItem> faqItems = [
  // ========== 同步相关 ==========
  const FaqItem(
    category: '数据同步',
    question: '为什么提交名单前要等同步完成？',
    answer:
        'App 采用"本地优先"设计，你的所有操作（记名、修改记录）都是先保存在手机本地，然后再同步到服务器。'
        '\n\n提交审核时，管理员看到的是服务器上的数据。如果本地数据还没同步上去，管理员看到的名单就可能和你手机上显示的不一样。'
        '\n\n所以提交前必须确保所有修改都已同步到服务器，这样才能保证你提交的内容准确无误。',
  ),
  const FaqItem(
    category: '数据同步',
    question: '为什么有未同步数据时不能提交名单或导出 Excel？',
    answer:
        '这是为了防止数据不一致。如果允许在同步未完成时提交，可能出现以下情况：'
        '\n\n• 你手机上显示某同学"缺勤"，但因为没同步，服务器上他还是"到课"'
        '\n• 管理员审核通过的数据和实际情况不符'
        '\n• 周汇总 Excel 里的数据不完整或有误'
        '\n\n所以系统会阻止这些关键操作，直到所有数据都成功同步。你可以下拉刷新或等待自动同步完成。',
  ),
  const FaqItem(
    category: '数据同步',
    question: '网络断开或同步失败怎么办？',
    answer:
        '不用担心，你的数据不会丢失。'
        '\n\n1. **数据安全**：所有记录都保存在手机本地，即使没有网络也不会丢失'
        '\n2. **批量同步**：系统会自动合并连续的记录修改，一次性批量同步到服务器，减少网络请求'
        '\n3. **自动重试**：网络恢复后，App 会自动检测并重新同步失败的记录（最多重试 5 次）'
        '\n4. **手动同步**：可以在"设置 → 手动同步"里立即触发同步'
        '\n5. **失败提示**：如果同步一直失败，App 会提示你检查网络'
        '\n\n**注意**：如果存在同步失败的数据，编辑、提交、放弃等操作会被暂时禁止（同步保护模式）。请先到"设置 → 同步问题"处理失败项后再继续操作。'
        '\n\n建议：在信号好的地方完成记名和修改，然后提交前确认同步已完成。',
  ),
  const FaqItem(
    category: '数据同步',
    question: '登录状态过期了怎么办？',
    answer:
        '如果你的登录 token 过期了，App 会提示你重新登录。'
        '\n\n**重要：你的本地数据不会丢失！**'
        '\n\n重新登录后：'
        '\n• 之前未同步的记录会自动恢复同步'
        '\n• 所有查课记录、修改历史都还在'
        '\n• 不需要重新记名或重新修改'
        '\n\n如果登录后同步仍然失败，请检查网络连接，或稍后再试。',
  ),
  const FaqItem(
    category: '数据同步',
    question: '同步问题详情页是做什么的？',
    answer:
        '你可以在"设置 → 同步问题"查看所有同步失败的记录详情。'
        '\n\n页面分为四类：'
        '\n• **待同步**：正在排队等待同步的记录'
        '\n• **认证过期**：登录状态失效，需要重新登录后才能继续同步'
        '\n• **重试中**：网络错误导致的失败，系统会自动重试（最多 5 次）'
        '\n• **已放弃**：重试超过 5 次仍未成功，需要手动点击"立即重试"'
        '\n\n操作建议：'
        '\n• 如果看到"认证过期"，请先重新登录（不要退出登录，会清数据）'
        '\n• 如果看到"已放弃"，确认网络正常后点击"立即重试"'
        '\n• 正常情况下不需要手动操作，系统会自动处理'
        '\n\n**重要**：存在同步失败数据时，编辑、提交、放弃等操作会被暂时禁止。请先处理失败项后再继续。',
  ),
  const FaqItem(
    category: '数据同步',
    question: '为什么编辑/提交按钮被禁用了，显示"存在同步失败数据"？',
    answer:
        '这是 v0.6.1 新增的"同步保护模式"。'
        '\n\n当存在同步失败的数据时，系统会暂时禁止以下操作：'
        '\n• 记名页面编辑学生状态'
        '\n• 查课记录详情页编辑'
        '\n• 放弃/删除任务'
        '\n• 名单提交'
        '\n• Excel 导出/发布'
        '\n• 退出登录'
        '\n\n**为什么要这样？**'
        '\n如果允许在同步失败时继续编辑，可能会导致：'
        '\n• 本地数据和服务端数据不一致'
        '\n• 提交的名单和实际记录不符'
        '\n• 更多修改堆积，问题越来越复杂'
        '\n\n**解决方法：**'
        '\n1. 进入"设置 → 同步问题"查看失败详情'
        '\n2. 确认网络正常'
        '\n3. 点击"立即重试"按钮'
        '\n4. 所有失败项处理完成后，编辑和提交功能会自动恢复',
  ),
  const FaqItem(
    category: '数据同步',
    question: '提交名单时提示"任务状态为 in_progress"怎么办？',
    answer:
        '这个提示意味着服务器上的任务状态还没有同步为"已完成"。'
        '\n\n常见原因：'
        '\n• 你在断网或网络不稳定时完成了记名，任务状态只保存在本地'
        '\n• App 重启后同步队列被打断，任务状态没有成功同步到服务器'
        '\n• 旧版本创建的任务在服务器上状态一直卡在"进行中"'
        '\n\n解决方法：'
        '\n1. 确保网络连接正常'
        '\n2. 进入"设置 → 同步问题"查看是否有失败的同步项'
        '\n3. 等待或手动触发同步完成后，再次尝试提交'
        '\n\n系统会在提交前自动检测并修复这个问题，如果修复失败会提示你先完成同步。',
  ),

  // ========== 提交审核相关 ==========
  const FaqItem(
    category: '名单提交',
    question: '为什么提交审核后就不能修改记录了？',
    answer:
        '一旦提交审核，你的名单就进入了"待审核"状态。此时系统会锁定这些记录，防止你在管理员审核期间继续修改，造成审核依据和你实际数据不一致。'
        '\n\n如果确实需要修改：'
        '\n1. 在"名单提交 → 我的提交"里找到这条提交'
        '\n2. 如果状态还是"待审核"，可以点击"撤回"'
        '\n3. 撤回后记录恢复可编辑状态，修改完成后再重新提交'
        '\n\n注意：如果管理员已经审核通过，就不能再撤回了。',
  ),
  const FaqItem(
    category: '名单提交',
    question: '提交后发现名单有误怎么办？',
    answer:
        '取决于当前状态：'
        '\n\n**情况一：还在【待审核】**'
        '\n→ 进入【扩展功能 → 名单提交 → 我的提交】'
        '\n→ 找到这条提交，点击【撤回】'
        '\n→ 回到查课记录修改后重新提交'
        '\n\n**情况二：已被管理员拒绝**'
        '\n→ 被拒后记录自动恢复可编辑状态'
        '\n→ 直接修改后重新提交即可'
        '\n\n**情况三：已被管理员通过**'
        '\n→ 审核通过后无法修改'
        '\n→ 如有紧急情况，请联系管理员处理',
  ),
  const FaqItem(
    category: '名单提交',
    question: '为什么我删除了查课记录后，它还在名单提交里？',
    answer:
        '删除查课记录后，App 会把它标记为"已放弃"，但数据不会立即从服务器删除。'
        '\n\n如果你删除前已经提交了这条记录：'
        '\n• **已提交的任务不能删除** — 系统会阻止删除操作，防止影响已审核的名单'
        '\n• 已提交的名单仍然有效，管理员可以正常审核'
        '\n\n如果你删除前还没提交：'
        '\n• 标记为"已放弃"后，这条记录会从"名单提交"的候选列表里消失'
        '\n• 如果还能看到，请刷新页面或退出重进',
  ),
  const FaqItem(
    category: '名单提交',
    question: '已拒绝的提交显示"无关联学生记录"是什么意思？',
    answer:
        '这说明管理员拒绝了你的提交，但打开详情时发现这条提交没有关联到任何学生记录。'
        '\n\n可能原因：'
        '\n• 提交时网络异常，导致提交成功但记录没有正确关联'
        '\n• 旧版本 App 创建的提交，当时的同步机制不够完善'
        '\n• 任务状态同步异常（本地显示已完成，但服务端状态不一致）'
        '\n\n建议操作：'
        '\n1. 查看拒绝原因，了解管理员反馈'
        '\n2. 重新进入"查课记录"，确认该任务的学生名单正常'
        '\n3. 修改确认无误后，重新提交一份正常记录'
        '\n4. 如果问题反复出现，请联系管理员确认任务状态',
  ),
  const FaqItem(
    category: '名单提交',
    question: '总群汇报和名单提交是什么关系？',
    answer:
        '它们是两个独立的操作，互不影响：'
        '\n\n**总群汇报**：'
        '\n• 只是帮你生成一段文本，方便复制到微信群'
        '\n• 不会把你的数据发送给管理员'
        '\n• 随时可以重新生成（即使名单已提交）'
        '\n\n**名单提交**：'
        '\n• 是把你的查课数据正式提交给管理员审核'
        '\n• 提交后管理员才能在"周汇总"里看到你的数据'
        '\n• 这是进入周汇总统计的必要步骤'
        '\n\n简单说：总群汇报是"发微信群给同学看"，名单提交是"正式交给管理员统计"。两者都要做。',
  ),
  const FaqItem(
    category: '名单提交',
    question: '多次修改记录后，怎么确保提交的是最终名单？',
    answer:
        '系统会自动确保：'
        '\n\n1. **提交前强制同步**：点击"提交审核"后，App 会先把你所有的修改同步到服务器，同步失败会阻止提交'
        '\n2. **提交时校验**：系统会再次确认所有选中的任务状态正常、记录完整'
        '\n3. **确认对话框**：提交前会显示每个任务的统计（总人数、迟到、缺勤等），你可以核对'
        '\n\n建议提交前：'
        '\n• 进入"查课记录"查看最终名单'
        '\n• 确认没有遗漏或错误'
        '\n• 确认同步已完成（设置页查看待同步数为 0）',
  ),

  // ========== 管理员相关 ==========
  const FaqItem(
    category: '管理员审核',
    question: '管理员审核"通过"和"拒绝"分别意味着什么？',
    answer:
        '**审核通过**：'
        '\n• 你的查课数据正式生效'
        '\n• 会进入周汇总统计'
        '\n• 这条提交不能再撤回或修改'
        '\n• 系统会自动创建快照，锁定提交内容'
        '\n\n**审核拒绝**：'
        '\n• 管理员认为数据有问题（如人数不对、班级错误等）'
        '\n• 你的记录恢复可编辑状态'
        '\n• 你可以修改后重新提交'
        '\n• 不会进入周汇总统计'
        '\n\n建议：如果被拒绝，查看拒绝原因，修改对应问题后重新提交。',
  ),
  const FaqItem(
    category: '管理员审核',
    question: '周汇总和 Excel 导出依据是什么？',
    answer:
        '周汇总和 Excel 只包含**审核通过**的提交数据。'
        '\n\n具体流程：'
        '\n1. 你提交名单 → 状态为"待审核"'
        '\n2. 管理员审核通过 → 状态变为"已通过"，系统自动创建快照'
        '\n3. 管理员导出 Excel / 发布周汇总 → 基于快照数据统计'
        '\n\n**快照机制（v0.6.1+）**：'
        '\n管理员审核通过时，系统会自动锁定提交内容。即使之后原始记录被修改，周汇总和 Excel 仍然基于审核通过时的数据。'
        '\n\n所以如果管理员还没审核，或者你的提交被拒绝了，你的数据就不会出现在周汇总里。'
        '\n\n**提示**：尽量在管理员汇总前完成提交并通过审核，否则当周数据会缺失。',
  ),
  const FaqItem(
    category: '管理员审核',
    question: '导出 Excel 后又有新提交被审核通过，再次导出会包含新数据吗？',
    answer:
        '会的。'
        '\n\nExcel 每次导出都基于"当前这一周所有已审核通过的快照"重新生成。'
        '\n\n举例：'
        '\n1. 周三：管理员导出第 10 周 Excel（包含 A、B 的数据）'
        '\n2. 周四：C 提交并被审核通过'
        '\n3. 周五：管理员再次导出第 10 周 Excel（包含 A、B、C 的数据）'
        '\n\n所以不用担心"导出过就不能再加数据"的问题。',
  ),

  // ========== 账户安全相关 ==========
  const FaqItem(
    category: '账户安全',
    question: '为什么有时退出登录会被禁止？',
    answer:
        '这是为了保护你的数据。'
        '\n\n以下情况会阻止退出登录：'
        '\n• **有未同步的数据**（pending）：修改了记录但还没同步到服务器'
        '\n• **有同步失败的数据**（failed）：同步出错，需要处理'
        '\n\n退出登录会清空本地数据，如果此时退出，这些数据会永久丢失。'
        '\n\n遇到这种情况：'
        '\n1. 不要强制退出'
        '\n2. 进入"设置 → 同步问题"查看失败详情'
        '\n3. 确认网络正常后点击"立即重试"'
        '\n4. 所有数据同步完成后就可以正常退出了',
  ),
  const FaqItem(
    category: '账户安全',
    question: '如何设置或修改密码？',
    answer:
        '你可以在"设置 → 账号安全"里设置或修改密码。'
        '\n\n**设置密码**（未设置过）：'
        '\n1. 使用验证码登录'
        '\n2. 进入"设置 → 账号安全"'
        '\n3. 点击"设置密码"'
        '\n4. 输入密码（至少 6 位）并确认'
        '\n5. 点击保存'
        '\n\n**修改密码**（已设置过）：'
        '\n1. 进入"设置 → 账号安全"'
        '\n2. 点击"修改密码"'
        '\n3. 输入新密码并确认'
        '\n4. 点击保存'
        '\n\n**忘记密码**：'
        '\n使用验证码登录后重新设置即可。'
        '\n\n**注意**：密码使用 bcrypt 加密存储，即使服务器数据泄露，密码也不会被破解。',
  ),
  const FaqItem(
    category: '账户安全',
    question: '设置页"账号安全"显示"加载失败，点击重试"怎么办？',
    answer:
        '这通常是因为网络波动导致无法获取账号安全状态。'
        '\n\n**解决方法**：'
        '\n1. 检查网络连接是否正常'
        '\n2. 点击"账号安全"行，系统会自动重试'
        '\n3. 重试成功后会显示"已设置密码"或"未设置密码"'
        '\n\n如果显示"登录状态已过期"：'
        '\n• 请点击进入，系统会跳转到登录页'
        '\n• 使用验证码或密码重新登录'
        '\n• 登录后本地数据不会丢失',
  ),

  // ========== 查课记录相关 ==========
  const FaqItem(
    category: '查课记录',
    question: '查课记录可以修改几次？有次数限制吗？',
    answer:
        '没有次数限制，你可以随时修改。'
        '\n\n修改流程：'
        '\n1. 进入"首页 → 查课记录"'
        '\n2. 点击要修改的任务'
        '\n3. 点击"编辑"按钮'
        '\n4. 修改学生状态'
        '\n5. 系统会自动同步修改到服务器'
        '\n\n**限制**：'
        '\n• 提交审核后不能修改（除非撤回）'
        '\n• 管理员审核通过后不能修改（快照已锁定）'
        '\n• 存在同步失败数据时，编辑按钮会被禁用（同步保护模式）'
        '\n\n建议：在提交前反复核对，尽量减少提交后的修改。',
  ),
  const FaqItem(
    category: '查课记录',
    question: '为什么查课记录里有"放弃"的任务？',
    answer:
        '"放弃"状态表示这条查课任务已被你删除。'
        '\n\nApp 不会真正删除数据，而是把状态改为"放弃"，这样可以：'
        '\n• 保留历史记录，方便追溯'
        '\n• 避免误删后无法恢复'
        '\n• 和服务端保持数据一致'
        '\n\n"放弃"的任务：'
        '\n• 不会出现在"名单提交"的候选列表里'
        '\n• 不会被计入周汇总'
        '\n• 但你可以在查课记录里查看历史',
  ),

  // ========== 记名相关 ==========
  const FaqItem(
    category: '记名操作',
    question: '记名时没处理完所有学生就退出了，数据会丢失吗？',
    answer:
        '不会丢失。'
        '\n\n如果你中途退出记名：'
        '\n1. 已标记的学生状态会保存在本地'
        '\n2. 下次进入 App 时，系统会检测到未完成的任务'
        '\n3. 弹出提示问你是否继续上次任务'
        '\n4. 选择"继续"即可从上次位置接着记名'
        '\n\n如果你点击了"完成"但还有学生没处理：'
        '\n• 系统会询问"还有 X 人未处理，是否标记为到课？"'
        '\n• 确认后未处理的学生会自动标记为"到课"'
        '\n• 然后进入确认名单页面',
  ),
  const FaqItem(
    category: '记名操作',
    question: '一个学生被错误标记了，怎么改？',
    answer:
        '在记名过程中或记名完成后都可以修改：'
        '\n\n**方式一：记名过程中直接改**'
        '\n1. 点击该学生卡片选中'
        '\n2. 点击底部正确的状态按钮（到课/缺勤/迟到/请假/其他）'
        '\n3. 状态立即更新'
        '\n\n**方式二：记名完成后在查课记录里改**'
        '\n1. 进入"首页 → 查课记录"'
        '\n2. 点击对应任务'
        '\n3. 点击"编辑"按钮'
        '\n4. 找到该学生，点击状态标签修改'
        '\n5. 修改后会自动同步到服务器',
  ),

  // ========== 查课计划 ==========
  const FaqItem(
    category: '查课计划',
    question: '查课计划是干什么的？',
    answer:
        '查课计划让你提前排好本周或未来几周的查课任务，**上课前 15 分钟**会通过系统通知栏自动提醒你，避免忘记查课。'
        '\n\n所有数据**完全本地存储**，不经过任何第三方服务器，学生信息安全。'
        '\n\n入口：首页 → 「查课计划」（📋 图标）。',
  ),
  const FaqItem(
    category: '查课计划',
    question: '怎么创建一条查课计划？',
    answer:
        '1. 进入「查课计划」页，点击右下角 **+ 新建**'
        '\n2. **选周次**（默认当前周，可通过 − / + 调整）'
        '\n3. **选星期**（周一到周五）'
        '\n4. **选节次**（1-8 节，每节显示对应时间）'
        '\n5. **选班级**（弹出对话框，支持按年级/专业筛选，可多选）'
        '\n6. **填教室**（必填，如 4213）'
        '\n7. **填备注**（可选，如"重点查课"）'
        '\n8. 确认底部预览的提醒时间，点击「创建并设置提醒」',
  ),
  const FaqItem(
    category: '查课计划',
    question: '8 节课的时间分别是？',
    answer:
        '| 节次 | 上课时间 |'
        '\n| --- | --- |'
        '\n| 第 1 节 | 08:30 - 09:15 |'
        '\n| 第 2 节 | 09:20 - 10:05 |'
        '\n| 第 3 节 | 10:25 - 11:10 |'
        '\n| 第 4 节 | 11:15 - 12:00 |'
        '\n| 第 5 节 | 14:30 - 15:15 |'
        '\n| 第 6 节 | 15:20 - 16:05 |'
        '\n| 第 7 节 | 16:25 - 17:10 |'
        '\n| 第 8 节 | 17:15 - 18:00 |'
        '\n\n提醒时间为上课前 15 分钟（例如第 1 节上课 08:30，08:15 提醒）。',
  ),
  const FaqItem(
    category: '查课计划',
    question: '班级太多怎么快速找到？',
    answer:
        '班级选择对话框顶部有**两行横向筛选 chip**：'
        '\n- 第一行：按**年级**筛选（按年份倒序，如 2024 级、2023 级）'
        '\n- 第二行：按**专业**筛选（如 软工、计科）'
        '\n\n只显示有数据的年级和专业。点击「全部年级 / 全部专业」清除该筛选。'
        '\n\n班级按 "年级 + 专业" 分组显示，方便定位。',
  ),
  const FaqItem(
    category: '查课计划',
    question: '怎么关闭/重新开启某条计划的提醒？',
    answer:
        '在计划列表页**长按对应卡片**，弹出底部菜单：'
        '\n- **关闭提醒**：取消通知调度，计划仍保留'
        '\n- **开启提醒**：重新调度通知'
        '\n\n卡片右上角的状态标签会显示：'
        '\n- 🟢 **已设提醒** — 正常会通知'
        '\n- ⚪ **提醒已关** — 不会通知'
        '\n- ⚪ **已结束** — 上课时间已过',
  ),
  const FaqItem(
    category: '查课计划',
    question: '没收到通知怎么办？',
    answer:
        '依次检查：'
        '\n\n**1. 通知权限**'
        '\n在「查课计划」页右上角点击 🔔 图标，确认权限已开启。如果显示"未开启"，进入系统设置 → 应用 → 考勤助手 → 通知 → 允许。'
        '\n\n**2. 精确闹钟权限（Android 12+）**'
        '\n创建计划时如果系统弹出"允许精确闹钟"，请允许。否则通知时间可能不准。'
        '\n\n**3. 厂商电池优化**'
        '\n华为/小米/OPPO/vivo 等厂商默认对后台 App 限制严格。请在系统设置中：'
        '\n- 「电池」→ 取消"考勤助手"的电池优化'
        '\n- 「应用启动管理」→ 允许"考勤助手"后台运行'
        '\n- 把"考勤助手"加入"白名单"'
        '\n\n**4. 提醒时间已过**'
        '\n如果创建时上课时间已经过去，计划仍会保存但不会通知。',
  ),
  const FaqItem(
    category: '查课计划',
    question: '查课计划会同步到云端吗？',
    answer:
        '**不会**。查课计划是**纯本地数据**，仅保存在你这台设备上，不会上传到任何服务器。'
        '\n\n好处：学生班级信息完全本地，符合隐私保护。'
        '\n\n限制：'
        '\n- **换设备需要重新创建**计划'
        '\n- **卸载 App 会丢失**所有计划'
        '\n- 不能跨设备同步',
  ),
  const FaqItem(
    category: '查课计划',
    question: '一节课可以查多个班级吗？',
    answer:
        '可以。在「选择班级」对话框中可以多选。'
        '\n\n例如某节课在同一教室合班上课，你可以一次选 2-3 个班级，提醒时一并通知。'
        '\n\n但一条计划**只能对应一节课**。如果你要查多节课，需要分别创建多条计划。',
  ),
  const FaqItem(
    category: '查课计划',
    question: '怎么删除查课计划？',
    answer:
        '在计划列表页**长按对应卡片** → 选择「删除」。'
        '\n\n删除会同时取消对应的本地通知。删除后无法恢复，请确认后操作。',
  ),
];

class FaqPage extends ConsumerWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 按类别分组
    final categories = <String, List<FaqItem>>{};
    for (final item in faqItems) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }
    final categoryNames = categories.keys.toList();

    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('常见问题与解决方案')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: categoryNames.length,
        itemBuilder: (context, index) {
          final category = categoryNames[index];
          final items = categories[category]!;
          return RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    category,
                    style: AppTextStyles.sm.copyWith(
                      color: c.brandPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...items.map((item) => _FaqCard(item: item)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FaqCard extends StatefulWidget {
  final FaqItem item;
  const _FaqCard({required this.item});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: AppCard(
        onTap: () => setState(() => _expanded = !_expanded),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.question,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: c.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: AppDuration.fast,
                  curve: AppCurves.normal,
                  child: Icon(
                    Icons.expand_more,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: MarkdownBody(
                  data: widget.item.answer,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: AppTextStyles.body.copyWith(
                      color: c.textSecondary,
                      height: 1.6,
                    ),
                    strong: AppTextStyles.bodyMedium.copyWith(
                      color: c.textPrimary,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                    listBullet: AppTextStyles.body.copyWith(
                      color: c.textSecondary,
                      height: 1.6,
                    ),
                    blockSpacing: AppSpacing.sm,
                    listIndent: 20,
                  ),
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: AppDuration.fast,
            ),
          ],
        ),
      ),
    );
  }
}