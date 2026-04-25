import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_state.dart';
import '../data/ranking_service.dart';

class RankingPage extends ConsumerStatefulWidget {
  const RankingPage({super.key});

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage>
    with WidgetsBindingObserver {
  String _periodType = '7d';
  String _rankType = 'score';
  bool _rulesExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _refresh() {
    ref.invalidate(rankingListProvider((period: _periodType, type: _rankType)));
  }

  static const Color _goldPrimary = Color(0xFFD4AF37);
  static const Color _goldLight = Color(0xFFF5DEB3);
  static const Color _goldDark = Color(0xFFB8860B);
  static const Color _accentRed = Color(0xFFC41E3A);
  static const Color _amberAccent = Color(0xFFFFB300);
  static const Color _warmBg = Color(0xFFFFF8E7);
  static const Color _warmBgLight = Color(0xFFFFFAF0);

  final List<({String value, String label})> _periods = [
    (value: '7d', label: '近7天'),
    (value: '30d', label: '近30天'),
    (value: 'total', label: '总榜'),
  ];

  final List<({String value, String label, IconData icon})> _rankTypes = [
    (value: 'score', label: '异常分数', icon: Icons.analytics_outlined),
    (value: 'rate', label: '缺勤率', icon: Icons.percent),
    (value: 'count', label: '缺勤人次', icon: Icons.people_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final rankingAsync = ref.watch(
      rankingListProvider((period: _periodType, type: _rankType)),
    );

    return DefaultTabController(
      length: _periods.length,
      child: Scaffold(
        backgroundColor: _warmBgLight,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: _goldPrimary, size: 24),
              const SizedBox(width: 8),
              const Text('排行榜'),
            ],
          ),
          backgroundColor: _warmBg,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_goldLight.withValues(alpha: 0.3), _warmBg],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  gradient: LinearGradient(colors: [_goldPrimary, _goldDark]),
                  borderRadius: BorderRadius.circular(4),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                tabs: _periods.map((p) => Tab(text: p.label)).toList(),
                onTap: (index) {
                  setState(() => _periodType = _periods[index].value);
                },
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            _buildTypeSelector(),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_warmBgLight, _warmBg],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: TabBarView(
                  children: _periods
                      .map(
                        (_) => rankingAsync.when(
                          data: (data) => _buildContent(context, data),
                          loading: () => Center(
                            child: CircularProgressIndicator(
                              color: _goldPrimary,
                            ),
                          ),
                          error: (err, stack) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: _accentRed,
                                ),
                                const SizedBox(height: 16),
                                Text('加载失败: $err'),
                                const SizedBox(height: 16),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _goldPrimary,
                                  ),
                                  onPressed: () => ref.invalidate(
                                    rankingListProvider((
                                      period: _periodType,
                                      type: _rankType,
                                    )),
                                  ),
                                  child: const Text('重试'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _warmBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return _goldPrimary;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.grey.shade700;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: _goldLight.withValues(alpha: 0.5)),
          ),
        ),
        segments: _rankTypes
            .map(
              (r) => ButtonSegment(
                value: r.value,
                label: Text(r.label),
                icon: Icon(r.icon),
              ),
            )
            .toList(),
        selected: {_rankType},
        onSelectionChanged: (Set<String> selection) {
          setState(() => _rankType = selection.first);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    final calculatedAt = data['calculated_at'] as String?;

    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.emoji_events_outlined,
        message: '当前周期暂无可展示数据',
        color: _goldPrimary,
      );
    }

    return RefreshIndicator(
      color: _goldPrimary,
      onRefresh: () async {
        _refresh();
        await ref.read(rankingListProvider((period: _periodType, type: _rankType)).future);
      },
      child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSummaryCard(context, summary);
        }
        if (index == 1) {
          return _buildRulesSection(context, calculatedAt);
        }
        final itemIndex = index - 2;
        final item = items[itemIndex] as Map<String, dynamic>;
        return AnimatedOpacity(
          opacity: 1.0,
          duration: Duration(milliseconds: 100 + itemIndex * 50),
          child: _buildRankingItem(context, item),
        );
      },
    ),
    );
  }

  Widget _buildRulesSection(BuildContext context, String? calculatedAt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _goldLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _rulesExpanded = !_rulesExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _goldPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '统计规则说明',
                    style: TextStyle(
                      color: _goldDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _rulesExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _goldPrimary,
                  ),
                ],
              ),
            ),
          ),
          if (_rulesExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _goldLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: _goldDark),
                        const SizedBox(width: 8),
                        Text(
                          '每日凌晨2点自动更新',
                          style: TextStyle(
                            fontSize: 13,
                            color: _goldDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPeriodRule(context),
                  const SizedBox(height: 12),
                  _buildRankTypeRule(context),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _goldLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '异常分数计算公式',
                          style: TextStyle(
                            color: _goldDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Σ(缺勤×1.0 + 请假×0.5 + 迟到×0.3 + 其他×0.2) ÷ 应到人次',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (calculatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.update,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '上次更新: ${_formatCalculatedAt(calculatedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodRule(BuildContext context) {
    String periodText;
    if (_periodType == '7d') {
      periodText = '统计最近7天的考勤数据，每日凌晨2点自动更新';
    } else if (_periodType == '30d') {
      periodText = '统计最近30天的考勤数据，每日凌晨2点自动更新';
    } else {
      periodText = '统计所有历史考勤数据，每日凌晨2点自动更新';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: _goldPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            periodText,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  Widget _buildRankTypeRule(BuildContext context) {
    String rankText;
    if (_rankType == 'score') {
      rankText = '异常分数：综合考量缺勤、请假、迟到、其他状态，权重越高影响越大';
    } else if (_rankType == 'rate') {
      rankText = '缺勤率：仅统计"缺勤"状态人次占总应到人次的百分比';
    } else {
      rankText = '缺勤人次：仅统计"缺勤"状态的累计人次';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: _goldPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            rankText,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, Map<String, dynamic> summary) {
    final avgValue = summary['avg_value'] as num;
    final topClass = summary['top_class_name'] as String?;
    final topValue = summary['top_value'] as num?;
    final totalClasses = summary['total_classes'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_goldLight.withValues(alpha: 0.4), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _goldLight.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _goldPrimary.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _goldPrimary.withValues(alpha: 0.1),
                    _goldLight.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_goldPrimary, _goldDark]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.summarize_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '概览统计',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatColumn(
                          icon: Icons.bar_chart_rounded,
                          label: _getAvgLabel(),
                          value: _formatValue(avgValue),
                        ),
                      ),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: _goldLight.withValues(alpha: 0.5),
                      ),
                      Expanded(
                        child: _buildStatColumn(
                          icon: Icons.emoji_events_rounded,
                          label: _getTopLabel(),
                          value: topValue != null
                              ? _formatValue(topValue)
                              : '-',
                          subtitle: topClass,
                        ),
                      ),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: _goldLight.withValues(alpha: 0.5),
                      ),
                      Expanded(
                        child: _buildStatColumn(
                          icon: Icons.school_rounded,
                          label: '上榜班级',
                          value: totalClasses.toString(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _goldLight.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _goldDark, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _accentRed,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: _amberAccent,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildRankingItem(BuildContext context, Map<String, dynamic> item) {
    final rank = item['rank'] as int;
    final className = item['class_name'] as String;
    final rankValue = item['rank_value'] as num;
    final trendRank = item['trend_rank'] as String?;
    final absentCount = item['absent_count'] as int?;
    final leaveCount = item['leave_count'] as int?;
    final lateCount = item['late_count'] as int?;
    final otherCount = item['other_count'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: rank <= 3
            ? Border.all(
                color: _getRankBorderColor(rank),
                width: rank == 1 ? 2 : 1.5,
              )
            : Border.all(color: _goldLight.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _goldPrimary.withValues(alpha: rank <= 3 ? 0.1 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildRankBadge(rank),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    className,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: rank <= 3 ? FontWeight.w600 : FontWeight.w500,
                      color: rank == 1 ? _goldDark : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (absentCount != null ||
                      leaveCount != null ||
                      lateCount != null ||
                      otherCount != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (absentCount != null && absentCount > 0)
                          _buildMiniBadge('缺勤', absentCount, _accentRed),
                        if (leaveCount != null && leaveCount > 0)
                          _buildMiniBadge('请假', leaveCount, _amberAccent),
                        if (lateCount != null && lateCount > 0)
                          _buildMiniBadge('迟到', lateCount, Color(0xFFFFA000)),
                        if (otherCount != null && otherCount > 0)
                          _buildMiniBadge('其他', otherCount, _goldPrimary),
                      ],
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (trendRank != null && _periodType != 'total')
                  _buildTrendBadge(trendRank),
                const SizedBox(height: 6),
                Text(
                  _formatValue(rankValue),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _accentRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank <= 3) {
      final colors = rank == 1
          ? [Color(0xFFFFD700), Color(0xFFDAA520)]
          : rank == 2
          ? [Color(0xFFC0C0C0), Color(0xFFA8A8A8)]
          : [Color(0xFFCD7F32), Color(0xFFB87333)];

      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors[1].withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            rank == 1
                ? '🥇'
                : rank == 2
                ? '🥈'
                : '🥉',
            style: const TextStyle(fontSize: 28),
          ),
        ),
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: _goldLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _goldLight.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _goldDark.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Color _getRankBorderColor(int rank) {
    if (rank == 1) return Color(0xFFDAA520);
    if (rank == 2) return Color(0xFFA8A8A8);
    return Color(0xFFB87333);
  }

  Widget _buildMiniBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTrendBadge(String trendRank) {
    Color color;
    String text;

    if (trendRank.startsWith('UP')) {
      final num = trendRank.replaceAll('UP', '');
      color = _goldPrimary;
      text = '↑$num';
    } else if (trendRank.startsWith('DOWN')) {
      final num = trendRank.replaceAll('DOWN', '');
      color = _accentRed;
      text = '↓$num';
    } else {
      color = _amberAccent;
      text = 'NEW';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getAvgLabel() {
    if (_rankType == 'score') return '平均异常';
    if (_rankType == 'rate') return '平均缺勤率';
    return '平均缺勤';
  }

  String _getTopLabel() {
    if (_rankType == 'score') return '最高异常';
    if (_rankType == 'rate') return '最高缺勤率';
    return '最高缺勤';
  }

  String _formatValue(num value) {
    if (_rankType == 'rate') {
      return '${(value * 100).toStringAsFixed(1)}%';
    } else if (_rankType == 'count') {
      return value.toInt().toString();
    } else {
      return value.toStringAsFixed(2);
    }
  }

  String _formatCalculatedAt(String calculatedAt) {
    try {
      final dt = DateTime.parse(calculatedAt);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return calculatedAt;
    }
  }
}
