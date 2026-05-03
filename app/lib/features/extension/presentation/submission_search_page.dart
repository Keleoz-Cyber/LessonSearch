import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/providers.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('提交记录查询'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '共 $_total 条记录',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '第 $_page 页',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('没有找到记录'),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return _SubmissionCard(
                        item: _items[index],
                        onTap: () => _showDetail(_items[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          // 关键词搜索
          TextField(
            controller: _keywordController,
            decoration: InputDecoration(
              hintText: '搜索提交人、班级...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _keywordController.clear();
                  _loadData();
                },
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onSubmitted: (_) => _loadData(),
          ),
          const SizedBox(height: 8),
          // 筛选条件
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 状态筛选
                _buildFilterChip(
                  label: _statusOptions.firstWhere(
                    (o) => o['value'] == (_status ?? ''),
                    orElse: () => _statusOptions.first,
                  )['label']!,
                  onTap: () => _showStatusPicker(),
                ),
                const SizedBox(width: 8),
                // 周次筛选
                _buildFilterChip(
                  label: _weekNumber != null ? '第 $_weekNumber 周' : '全部周次',
                  onTap: () => _showWeekPicker(),
                ),
                const SizedBox(width: 8),
                // 日期范围
                _buildFilterChip(
                  label: (_startDate != null || _endDate != null)
                      ? '${_startDate ?? ''} ~ ${_endDate ?? ''}'
                      : '全部日期',
                  onTap: () => _showDateRangePicker(),
                ),
                const SizedBox(width: 8),
                // 重置按钮
                ActionChip(
                  label: const Text('重置'),
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

  Widget _buildFilterChip({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ],
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
    final startController = TextEditingController(text: _startDate ?? '');
    final endController = TextEditingController(text: _endDate ?? '');

    final result = await showDialog<Map<String, String?>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择日期范围'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startController,
              decoration: const InputDecoration(
                hintText: '开始日期，如 2024-01-01',
                labelText: '开始日期',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: endController,
              decoration: const InputDecoration(
                hintText: '结束日期，如 2024-12-31',
                labelText: '结束日期',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'start': startController.text.trim().isEmpty
                  ? null
                  : startController.text.trim(),
              'end': endController.text.trim().isEmpty
                  ? null
                  : endController.text.trim(),
            }),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result['start'];
        _endDate = result['end'];
      });
      _loadData();
    }
  }

  void _showDetail(Map<String, dynamic> item) {
    final userName = item['user_name'] ?? item['user_email'] ?? '未知';
    final status = item['status'] as String;
    final submittedAt = DateTime.parse(item['submitted_at'] as String);
    final reviewerName = item['reviewer_name'];
    final reviewTime = item['review_time'] != null
        ? DateTime.parse(item['review_time'] as String)
        : null;
    final recordCount = item['record_count'] as int? ?? 0;
    final classNames = item['class_names'] as String? ?? '';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = '待审核';
      case 'approved':
        statusColor = Colors.green;
        statusLabel = '已通过';
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = '已拒绝';
      case 'cancelled':
        statusColor = Colors.grey;
        statusLabel = '已撤回';
      default:
        statusColor = Colors.grey;
        statusLabel = status;
    }

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
              _buildDetailRow('提交时间', DateFormat('yyyy-MM-dd HH:mm').format(submittedAt)),
              _buildDetailRow('周次', '第 ${item['week_number']} 周'),
              if (classNames.isNotEmpty)
                _buildDetailRow('班级', classNames),
              _buildDetailRow('记录数量', '$recordCount 条'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('状态: ', style: TextStyle(color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (reviewerName != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow('审核人', reviewerName),
              ],
              if (reviewTime != null) ...[
                _buildDetailRow('审核时间', DateFormat('yyyy-MM-dd HH:mm').format(reviewTime)),
              ],
              if (item['review_note'] != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow('审核备注', item['review_note'] as String),
              ],
            ],
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
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
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
    final userName = item['user_name'] ?? item['user_email'] ?? '未知';
    final status = item['status'] as String;
    final submittedAt = DateTime.parse(item['submitted_at'] as String);
    final recordCount = item['record_count'] as int? ?? 0;
    final classNames = item['class_names'] as String? ?? '';
    final reviewerName = item['reviewer_name'];

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = '待审核';
      case 'approved':
        statusColor = Colors.green;
        statusLabel = '已通过';
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = '已拒绝';
      case 'cancelled':
        statusColor = Colors.grey;
        statusLabel = '已撤回';
      default:
        statusColor = Colors.grey;
        statusLabel = status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      userName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (classNames.isNotEmpty)
                Text(
                  classNames,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '第 ${item['week_number']} 周 · $recordCount 条记录',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MM-dd HH:mm').format(submittedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
              if (reviewerName != null) ...[
                const SizedBox(height: 4),
                Text(
                  '审核人: $reviewerName',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
