import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        '\n2. **自动重试**：网络恢复后，App 会自动检测并重新同步失败的记录（最多重试 5 次）'
        '\n3. **手动同步**：可以在"设置 → 手动同步"里立即触发同步'
        '\n4. **失败提示**：如果同步一直失败，App 会提示你检查网络'
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
        '\n• 删除操作不会影响已经提交的审核'
        '\n• 已提交的名单仍然有效'
        '\n\n如果你删除前还没提交：'
        '\n• 标记为"已放弃"后，这条记录会从"名单提交"的候选列表里消失'
        '\n• 如果还能看到，请刷新页面或退出重进',
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
        '\n2. 管理员审核通过 → 状态变为"已通过"'
        '\n3. 管理员导出 Excel / 发布周汇总 → 只统计"已通过"的数据'
        '\n\n所以如果管理员还没审核，或者你的提交被拒绝了，你的数据就不会出现在周汇总里。'
        '\n\n**提示**：尽量在管理员汇总前完成提交并通过审核，否则当周数据会缺失。',
  ),

  // ========== 退出登录相关 ==========
  const FaqItem(
    category: '账户安全',
    question: '为什么有时退出登录会被禁止？',
    answer:
        '这是为了保护你的数据。'
        '\n\n如果你还有未同步的数据（比如修改了记录但还没同步到服务器），此时退出登录会导致这些数据永久丢失。'
        '\n\n遇到这种情况：'
        '\n1. 不要强制退出'
        '\n2. 在弹窗里点击"立即同步"按钮'
        '\n3. 等同步完成后就可以正常退出了'
        '\n\n如果你确实急需退出（比如换账号），建议先在设置页手动触发同步，等完成后再退出。',
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
        '\n• 管理员审核通过后不能修改'
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
        '\n\n**方式一：记名过程中直接改'
        '\n1. 点击该学生卡片选中'
        '\n2. 点击底部正确的状态按钮（到课/缺勤/迟到/请假/其他）'
        '\n3. 状态立即更新'
        '\n\n**方式二：记名完成后在查课记录里改'
        '\n1. 进入"首页 → 查课记录"'
        '\n2. 点击对应任务'
        '\n3. 点击"编辑"按钮'
        '\n4. 找到该学生，点击状态标签修改'
        '\n5. 修改后会自动同步到服务器',
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

    return Scaffold(
      appBar: AppBar(title: const Text('常见问题与解决方案')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: categoryNames.length,
        itemBuilder: (context, index) {
          final category = categoryNames[index];
          final items = categories[category]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  category,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...items.map((item) => _FaqCard(item: item)),
            ],
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    widget.item.answer,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}