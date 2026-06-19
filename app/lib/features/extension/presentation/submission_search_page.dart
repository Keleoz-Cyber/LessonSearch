import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_card.dart';
import '../../../shared/design_system/widgets/status_pill.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/toast.dart';
import '../data/submission_service.dart';

final _submissionServiceProvider = Provider<SubmissionService>((ref) {
  return SubmissionService(ref.watch(apiClientProvider));
});

class SubmissionSearchPage extends ConsumerStatefulWidget {
  const SubmissionSearchPage({super.key});

  @override
  ConsumerState<SubmissionSearchPage> createState() => _SubmissionSearchPageState();
}

class _SubmissionSearchPageState extends ConsumerState<SubmissionSearchPage> {
  final _scrollController = ScrollController();
  final _keywordController = TextEditingController();

  int _page = 1;
  final int _pageSize = 20;
  bool _loading = false;
  bool _hasMore = true;
  int _total = 0;
  List<Map<String, dynamic>> _items = [];

  // 筛选条件
  String? _status;
  int? _weekNumber;
  String? _startDate;
  String? _endDate;

  final List<Map<String, String>> _statusOptions = [
    {'value': '', 'label': '全部状态'},
    {'value': 'pending', 'label': '待审核'},
    {'value': 'approved', 'label': '已通过'},
    {'value': 'rejected', 'label': '已拒绝'},
    {'value': 'cancelled', 'label': '已撤回'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _page = 1;
      _items = [];
    });

    try {
      final service = ref.read(_submissionServiceProvider);
      final result = await service.adminSearchSubmissions(
        page: _page,
        pageSize: _pageSize,
        status: _status?.isNotEmpty == true ? _status : null,
        weekNumber: _weekNumber,
        startDate: _startDate,
        endDate: _endDate,
        keyword: _keywordController.text.trim().isNotEmpty
            ? _keywordController.text.trim()
            : null,
      );

      final items = (result['items'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

      setState(() {
        _items = items;
        _total = result['total'] as int? ?? 0;
        _hasMore = items.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) Toast.show(context, '加载失败: $e');
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);

    try {
      final nextPage = _page + 1;
      final service = ref.read(_submissionServiceProvider);
      final result = await service.adminSearchSubmissions(
        page: nextPage,
        pageSize: _pageSize,
        status: _status?.isNotEmpty == true ? _status : null,
        weekNumber: _weekNumber,
        startDate: _startDate,
        endDate: _endDate,
        keyword: _keywordController.text.trim().isNotEmpty
            ? _keywordController.text.trim()
            : null,
      );

      final items = (result['items'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

      setState(() {
        _items.addAll(items);
        _page = nextPage;
        _hasMore = items.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) Toast.show(context, '加载失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('提交记录查询'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    '共 $_total 条记录',
                    style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '第 $_page 页',
                    style: AppTextStyles.withTabular(AppTextStyles.sm)
                        .copyWith(color: c.textTertiary),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _items.isEmpty && !_loading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 32,
                            color: c.textTertiary,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            '没有找到记录',
                            style: AppTextStyles.body.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  c.brandPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SubmissionCard(
                          item: _items[index],
                          onTap: () => _showDetail(_items[index]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: c.bgSurface,
        border: Border(
          bottom: BorderSide(color: c.borderSubtle),
        ),
      ),
      child: Column(
        children: [
          // 关键词搜索
          TextField(
            controller: _keywordController,
            decoration: InputDecoration(
              hintText: '搜索提交人、班级...',
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: c.textSecondary,
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.close, size: 18, color: c.textTertiary),
                tooltip: '清除',
                onPressed: () {
                  _keywordController.clear();
                  _loadData();
                },
              ),
            ),
            style: AppTextStyles.body.copyWith(color: c.textPrimary),
            onSubmitted: (_) => _loadData(),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 筛选条件
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: _statusOptions.firstWhere(
                    (o) => o['value'] == (_status ?? ''),
                    orElse: () => _statusOptions.first,
                  )['label']!,
                  active: _status != null,
                  onTap: () => _showStatusPicker(),
                ),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip(
                  label: _weekNumber != null
                      ? '第 $_weekNumber 周'
                      : '全部周次',
                  active: _weekNumber != null,
                  onTap: () => _showWeekPicker(),
                ),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip(
                  label: (_startDate != null || _endDate != null)
                      ? _formatDateRangeLabel()
                      : '全部日期',
                  active: _startDate != null || _endDate != null,
                  onTap: () => _showDateRangePicker(),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ResetChip(
                  onPressed: () {
                    setState(() {
                      _status = null;
                      _weekNumber = null;
                      _startDate = null;
                      _endDate = null;
                      _keywordController.clear();
                    });
                    _loadData();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    final bg = active ? c.brandSubtle : c.bgMuted;
    final fg = active ? c.brandPrimary : c.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: active
                  ? c.brandPrimary.withValues(alpha: 0.3)
                  : c.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sm.copyWith(color: fg),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 16, color: fg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showStatusPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statusOptions.map((option) {
            return ListTile(
              title: Text(option['label']!),
              trailing: _status == option['value'] ||
                      (_status == null && option['value'] == '')
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, option['value']),
            );
          }).toList(),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _status = result.isEmpty ? null : result;
      });
      _loadData();
    }
  }

  Future<void> _showWeekPicker() async {
    final controller = TextEditingController(
      text: _weekNumber?.toString() ?? '',
    );
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择周次'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '输入周次数字，如 12',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx, text.isEmpty ? null : int.tryParse(text));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != _weekNumber) {
      setState(() => _weekNumber = result);
      _loadData();
    }
  }

  Future<void> _showDateRangePicker() async {
    // 选择开始日期
    final start = await showDatePicker(
      context: context,
      initialDate: _startDate != null
          ? DateTime.parse(_startDate!)
          : DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: '选择开始日期',
    );
    if (start == null) return;

    // 计算结束日期的 initialDate，保证在 [start, now] 范围内
    DateTime endInitialDate;
    if (_endDate != null) {
      endInitialDate = DateTime.parse(_endDate!);
      if (endInitialDate.isBefore(start)) {
        endInitialDate = start;
      }
    } else {
      endInitialDate = DateTime.now();
    }
    if (endInitialDate.isAfter(DateTime.now())) {
      endInitialDate = DateTime.now();
    }

    // 选择结束日期
    final end = await showDatePicker(
      context: context,
      initialDate: endInitialDate,
      firstDate: start,
      lastDate: DateTime.now(),
      helpText: '选择结束日期',
    );
    if (end == null) return;

    setState(() {
      _startDate = DateFormat('yyyy-MM-dd').format(start);
      _endDate = DateFormat('yyyy-MM-dd').format(end);
    });
    _loadData();
  }

  /// 格式化日期范围标签：同一年显示 MM-DD ~ MM-DD，跨年显示完整日期
  String _formatDateRangeLabel() {
    if (_startDate == null && _endDate == null) return '全部日期';
    if (_startDate != null && _endDate == null) return _startDate!;
    if (_startDate == null && _endDate != null) return _endDate!;

    final start = DateTime.parse(_startDate!);
    final end = DateTime.parse(_endDate!);

    if (start.year == end.year) {
      // 同年：MM-DD ~ MM-DD
      return '${DateFormat('MM-dd').format(start)} ~ ${DateFormat('MM-dd').format(end)}';
    } else {
      // 跨年：YYYY-MM-DD ~ YYYY-MM-DD
      return '${DateFormat('yyyy-MM-dd').format(start)} ~ ${DateFormat('yyyy-MM-dd').format(end)}';
    }
  }

  void _showDetail(Map<String, dynamic> item) {
    final c = context.colors;
    final userName = item['user_name'] ?? item['user_email'] ?? '未知';
    final status = item['status'] as String;
    final submittedAt = DateTime.parse(item['submitted_at'] as String);
    final reviewerName = item['reviewer_name'];
    final reviewTime = item['review_time'] != null
        ? DateTime.parse(item['review_time'] as String)
        : null;
    final recordCount = item['record_count'] as int? ?? 0;
    final classNames = item['class_names'] as String? ?? '';

    final (variant, statusLabel) = _statusVariant(status);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('提交详情 - $userName'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('提交人', userName),
              _buildDetailRow(
                '提交时间',
                DateFormat('yyyy-MM-dd HH:mm').format(submittedAt),
              ),
              _buildDetailRow('周次', '第 ${item['week_number']} 周'),
              if (classNames.isNotEmpty)
                _buildDetailRow('班级', classNames),
              _buildDetailRow('记录数量', '$recordCount 条'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    '状态: ',
                    style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                  ),
                  StatusPill(label: statusLabel, variant: variant),
                ],
              ),
              if (reviewerName != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildDetailRow('审核人', reviewerName),
              ],
              if (reviewTime != null)
                _buildDetailRow(
                  '审核时间',
                  DateFormat('yyyy-MM-dd HH:mm').format(reviewTime),
                ),
              if (item['review_note'] != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildDetailRow('审核备注', item['review_note'] as String),
              ],
              if (status == 'rejected') ...[
                const SizedBox(height: AppSpacing.md),
                _NoticeBox(
                  color: c.stateDanger,
                  icon: Icons.cancel,
                  title: '已拒绝',
                  body: item['review_note'] != null
                      ? '拒绝原因: ${item['review_note']}'
                      : null,
                ),
              ],
              if (recordCount == 0) ...[
                const SizedBox(height: AppSpacing.md),
                _NoticeBox(
                  color: c.stateWarning,
                  icon: Icons.warning_amber_outlined,
                  title: '无关联学生记录',
                  body: '可能是旧版本或同步异常产生的记录。建议重新提交一份正常记录，或联系管理员确认。',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          if (recordCount > 0)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showStudentDetail(item);
              },
              child: const Text('查看学生明细'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: AppTextStyles.sm.copyWith(color: c.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.sm.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  /// 查看学生明细，复用已有 /submissions/{id}/records 接口
  Future<void> _showStudentDetail(Map<String, dynamic> item) async {
    final c = context.colors;
    final submissionId = item['id'] as int;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在加载学生明细...'),
          ],
        ),
      ),
    );

    try {
      final service = ref.read(_submissionServiceProvider);
      final data = await service.getSubmissionRecords(submissionId);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (!mounted) return;

      final records = data['records'] as List? ?? [];
      final lateCount = data['late_count'] as int? ?? 0;
      final absentCount = data['absent_count'] as int? ?? 0;
      final leaveCount = data['leave_count'] as int? ?? 0;
      final otherCount = data['other_count'] as int? ?? 0;
      final recordCount = records.length;
      final submissionStatus = data['status'] as String?;
      final isRejected = submissionStatus == 'rejected';

      final absentRecords = records.where((r) => r['status'] == 'absent').toList();
      final lateRecords = records.where((r) => r['status'] == 'late').toList();
      final leaveRecords = records.where((r) => r['status'] == 'leave').toList();
      final otherRecords = records.where((r) => r['status'] == 'other').toList();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('学生明细 (${records.length}人)'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // rejected 状态提示（独立于空状态始终显示）
                  if (isRejected) ...[
                    _NoticeBox(
                      color: c.stateDanger,
                      icon: Icons.cancel,
                      title: '已拒绝',
                      body: '审核人: ${item['reviewer_name']}',
                    ),
                    if (item['review_note'] != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '拒绝原因: ${item['review_note']}',
                        style: AppTextStyles.sm.copyWith(color: c.stateDanger),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (recordCount == 0)
                    EmptyState.noLinkedRecords()
                  else if (lateCount + absentCount + leaveCount + otherCount == 0)
                    EmptyState.noAbnormalRecords()
                  else ...[
                    // 统计摘要
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (lateCount > 0)
                          _buildMiniStat('迟到', lateCount, Colors.orange),
                        if (absentCount > 0)
                          _buildMiniStat('缺勤', absentCount, Colors.red),
                        if (leaveCount > 0)
                          _buildMiniStat('请假', leaveCount, Colors.blue),
                        if (otherCount > 0)
                          _buildMiniStat('其他', otherCount, Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 名单
                    if (absentRecords.isNotEmpty) ...[
                      _buildRecordGroup('缺勤', absentRecords, Colors.red),
                    ],
                    if (lateRecords.isNotEmpty) ...[
                      _buildRecordGroup('迟到', lateRecords, Colors.orange),
                    ],
                    if (leaveRecords.isNotEmpty) ...[
                      _buildRecordGroup('请假', leaveRecords, Colors.blue),
                    ],
                    if (otherRecords.isNotEmpty) ...[
                      _buildRecordGroup('其他', otherRecords, Colors.grey),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) Toast.show(context, '加载学生明细失败: $e');
    }
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _buildRecordGroup(String label, List<dynamic> records, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label (${records.length}人)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        ...records.map((r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            '  ${r['student_name']} (${r['student_no']}) ${r['class_name']}',
            style: const TextStyle(fontSize: 12),
          ),
        )),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _SubmissionCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final userName = item['user_name'] ?? item['user_email'] ?? '未知';
    final status = item['status'] as String;
    final submittedAt = DateTime.parse(item['submitted_at'] as String);
    final recordCount = item['record_count'] as int? ?? 0;
    final classNames = item['class_names'] as String? ?? '';
    final reviewerName = item['reviewer_name'];

    final (variant, label) = _statusVariant(status);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  userName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(label: label, variant: variant),
            ],
          ),
          if (classNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              classNames,
              style: AppTextStyles.sm.copyWith(color: c.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Flexible(
                child: Text(
                  '第 ${item['week_number']} 周 · $recordCount 条记录',
                  style: AppTextStyles.xs.copyWith(color: c.textTertiary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                DateFormat('MM-dd HH:mm').format(submittedAt),
                style: AppTextStyles.withTabular(AppTextStyles.xs)
                    .copyWith(color: c.textTertiary),
              ),
            ],
          ),
          if (reviewerName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '审核人: $reviewerName',
              style: AppTextStyles.xs.copyWith(color: c.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResetChip extends StatelessWidget {
  final VoidCallback onPressed;
  const _ResetChip({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: c.bgMuted,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: c.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 14, color: c.textSecondary),
              const SizedBox(width: 4),
              Text(
                '重置',
                style: AppTextStyles.sm.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(StatusPillVariant, String) _statusVariant(String status) {
  switch (status) {
    case 'pending':
      return (StatusPillVariant.warning, '待审核');
    case 'approved':
      return (StatusPillVariant.success, '已通过');
    case 'rejected':
      return (StatusPillVariant.danger, '已拒绝');
    case 'cancelled':
      return (StatusPillVariant.neutral, '已撤回');
    default:
      return (StatusPillVariant.neutral, status);
  }
}

class _NoticeBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? body;
  const _NoticeBox({
    required this.color,
    required this.icon,
    required this.title,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.normal),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              body!,
              style: AppTextStyles.sm.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }
}
