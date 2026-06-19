import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/design_system/widgets/app_card.dart';
import '../../../shared/design_system/widgets/segmented_control.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_overlay.dart';
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

  // 前 3 名奖牌色（仅用于排名徽章；其余视觉一律 design system token）
  static const _gold1 = Color(0xFFFFD700);
  static const _gold2 = Color(0xFFDAA520);
  static const _silver1 = Color(0xFFC0C0C0);
  static const _silver2 = Color(0xFFA8A8A8);
  static const _bronze1 = Color(0xFFCD7F32);
  static const _bronze2 = Color(0xFFB87333);

  static const _periods = [
    AppSegmentedItem(value: '7d', label: '近 7 天'),
    AppSegmentedItem(value: '30d', label: '近 30 天'),
    AppSegmentedItem(value: 'total', label: '总榜'),
  ];

  static const _rankTypes = [
    AppSegmentedItem(value: 'score', label: '异常分'),
    AppSegmentedItem(value: 'rate', label: '缺勤率'),
    AppSegmentedItem(value: 'count', label: '缺勤'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rankingAsync = ref.watch(
      rankingListProvider((period: _periodType, type: _rankType)),
    );

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('排行榜')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: AppSegmentedControl<String>(
              items: _periods,
              value: _periodType,
              onChanged: (v) => setState(() => _periodType = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: AppSegmentedControl<String>(
              items: _rankTypes,
              value: _rankType,
              onChanged: (v) => setState(() => _rankType = v),
            ),
          ),
          Expanded(
            child: rankingAsync.when(
              data: (data) => _buildContent(context, data),
              loading: () => const LoadingOverlay(
                isLoading: true,
                child: SizedBox.expand(),
              ),
              error: (err, _) => _buildErrorState(err),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object err) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 32, color: c.stateDanger),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '加载失败',
              style: AppTextStyles.h3.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$err',
              style: AppTextStyles.sm.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: '重试',
              onPressed: _refresh,
              leadingIcon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    final calculatedAt = data['calculated_at'] as String?;

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events_outlined,
        message: '当前周期暂无可展示数据',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await ref.read(
          rankingListProvider((period: _periodType, type: _rankType)).future,
        );
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        itemCount: items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildSummaryCard(context, summary),
            );
          }
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _buildRulesSection(context, calculatedAt),
            );
          }
          final itemIndex = index - 2;
          final item = items[itemIndex] as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _buildRankingItem(context, item),
          );
        },
      ),
    );
  }

  // ============================================================
  // 概览卡片
  // ============================================================

  Widget _buildSummaryCard(BuildContext context, Map<String, dynamic> summary) {
    final c = context.colors;
    final avgValue = summary['avg_value'] as num;
    final topClass = summary['top_class_name'] as String?;
    final topValue = summary['top_value'] as num?;
    final totalClasses = summary['total_classes'] as int;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: c.brandPrimary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '本期概览',
                style: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    label: _getAvgLabel(),
                    value: _formatValue(avgValue),
                  ),
                ),
                _SummaryDivider(color: c.borderSubtle),
                Expanded(
                  child: _SummaryStat(
                    label: _getTopLabel(),
                    value: topValue != null ? _formatValue(topValue) : '-',
                    subtitle: topClass,
                    valueColor: c.stateDanger,
                  ),
                ),
                _SummaryDivider(color: c.borderSubtle),
                Expanded(
                  child: _SummaryStat(
                    label: '上榜班级',
                    value: totalClasses.toString(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 规则说明（折叠卡片）
  // ============================================================

  Widget _buildRulesSection(BuildContext context, String? calculatedAt) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _rulesExpanded = !_rulesExpanded),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: c.brandPrimary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '统计规则说明',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    duration: AppDuration.fast,
                    turns: _rulesExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_rulesExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: c.borderSubtle),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: c.brandPrimary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '每日凌晨 2 点自动更新',
                        style: AppTextStyles.sm.copyWith(color: c.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildPeriodRule(context),
                  const SizedBox(height: AppSpacing.md),
                  _buildRankTypeRule(context),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: c.bgMuted,
                      borderRadius: BorderRadius.circular(AppRadius.normal),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rankType == 'score'
                              ? '异常分数计算公式'
                              : _rankType == 'rate'
                                  ? '缺勤率计算公式'
                                  : '缺勤人次统计说明',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (_rankType == 'score') ...[
                          _RuleLine(
                            text:
                                '分子：Σ(缺勤×1.0 + 请假×0.5 + 迟到×0.3 + 其他×0.2)',
                          ),
                          const SizedBox(height: 4),
                          const _RuleLine(text: '分母：班级人数 × 查课次数'),
                          const SizedBox(height: 4),
                          const _RuleLine(
                            text: '例：34 人班级被查 2 次，异常加权 18，分数 = 18÷68 = 0.26',
                            muted: true,
                          ),
                        ] else if (_rankType == 'rate') ...[
                          const _RuleLine(text: '分子：缺勤人次'),
                          const SizedBox(height: 4),
                          const _RuleLine(text: '分母：班级人数 × 查课次数'),
                          const SizedBox(height: 4),
                          const _RuleLine(
                            text: '例：34 人班级被查 2 次，缺勤 6 次，缺勤率 = 6÷68 = 8.8%',
                            muted: true,
                          ),
                        ] else ...[
                          const _RuleLine(
                            text: '统计该周期内所有已审核提交中的"缺勤"状态累计人次',
                          ),
                          const SizedBox(height: 4),
                          const _RuleLine(
                            text: '注：多次查课同一人多次缺勤会累计，反映该班缺勤总频次',
                            muted: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (calculatedAt != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Icon(Icons.update, size: 14, color: c.textTertiary),
                        const SizedBox(width: 6),
                        Text(
                          '上次更新: ${_formatCalculatedAt(calculatedAt)}',
                          style: AppTextStyles.xs.copyWith(
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodRule(BuildContext context) {
    final c = context.colors;
    String periodText;
    if (_periodType == '7d') {
      periodText =
          '统计最近 7 天的考勤数据。分数 = 异常加权人次 ÷ (班级人数 × 查课次数)，每日凌晨 2 点自动更新';
    } else if (_periodType == '30d') {
      periodText =
          '统计最近 30 天的考勤数据。分数 = 异常加权人次 ÷ (班级人数 × 查课次数)，每日凌晨 2 点自动更新';
    } else {
      periodText =
          '统计所有历史考勤数据。分数 = 异常加权人次 ÷ (班级人数 × 查课次数)，每日凌晨 2 点自动更新';
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            color: c.brandPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            periodText,
            style: AppTextStyles.sm.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildRankTypeRule(BuildContext context) {
    final c = context.colors;
    String rankText;
    if (_rankType == 'score') {
      rankText =
          '异常分数：综合考量缺勤、请假、迟到、其他状态。分母 = 班级人数 × 查课次数，避免查课次数多的班级虚高';
    } else if (_rankType == 'rate') {
      rankText =
          '缺勤率：仅统计"缺勤"状态人次。分母 = 班级人数 × 查课次数，体现每次查课的平均缺勤率';
    } else {
      rankText = '缺勤人次：仅统计"缺勤"状态的累计人次（原始数据，不做除法）';
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            color: c.brandPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            rankText,
            style: AppTextStyles.sm.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 排名行（前 3 名奖牌 / 其余品牌色 #N）
  // ============================================================

  Widget _buildRankingItem(BuildContext context, Map<String, dynamic> item) {
    final c = context.colors;
    final rank = item['rank'] as int;
    final className = item['class_name'] as String;
    final rankValue = item['rank_value'] as num;
    final trendRank = item['trend_rank'] as String?;
    final absentCount = item['absent_count'] as int?;
    final leaveCount = item['leave_count'] as int?;
    final lateCount = item['late_count'] as int?;
    final otherCount = item['other_count'] as int?;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          _buildRankBadge(context, rank),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: c.textPrimary,
                    fontWeight: rank <= 3 ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (absentCount != null ||
                    leaveCount != null ||
                    lateCount != null ||
                    otherCount != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs + 2,
                    runSpacing: 4,
                    children: [
                      if (absentCount != null && absentCount > 0)
                        _MiniBadge(label: '缺', count: absentCount, color: c.stateDanger),
                      if (lateCount != null && lateCount > 0)
                        _MiniBadge(label: '迟', count: lateCount, color: c.stateWarning),
                      if (leaveCount != null && leaveCount > 0)
                        _MiniBadge(label: '假', count: leaveCount, color: c.stateInfo),
                      if (otherCount != null && otherCount > 0)
                        _MiniBadge(label: '他', count: otherCount, color: c.textSecondary),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (trendRank != null && _periodType != 'total')
                _buildTrendBadge(context, trendRank),
              const SizedBox(height: 4),
              Text(
                _formatValue(rankValue),
                style: AppTextStyles.withTabular(AppTextStyles.h2).copyWith(
                  color: c.stateDanger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(BuildContext context, int rank) {
    final c = context.colors;
    if (rank <= 3) {
      final colors = rank == 1
          ? [_gold1, _gold2]
          : rank == 2
              ? [_silver1, _silver2]
              : [_bronze1, _bronze2];

      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: colors[1].withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
            style: const TextStyle(fontSize: 22),
          ),
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: c.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: AppTextStyles.bodyMedium.copyWith(
            color: c.brandPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTrendBadge(BuildContext context, String trendRank) {
    final c = context.colors;
    Color color;
    String text;

    if (trendRank.startsWith('UP')) {
      // 排名上升 = 异常分变高 = 变差，红色
      final num = trendRank.replaceAll('UP', '');
      color = c.stateDanger;
      text = '↑$num';
    } else if (trendRank.startsWith('DOWN')) {
      // 排名下降 = 异常分变低 = 变好，绿色
      final num = trendRank.replaceAll('DOWN', '');
      color = c.stateSuccess;
      text = '↓$num';
    } else {
      color = c.stateInfo;
      text = 'NEW';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: AppTextStyles.xs.copyWith(color: color),
      ),
    );
  }

  // ============================================================
  // helpers
  // ============================================================

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

// ============================================================
// 私有子组件
// ============================================================

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  const _SummaryStat({
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTextStyles.xs.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.withTabular(AppTextStyles.h1).copyWith(
            color: valueColor ?? c.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: AppTextStyles.xs.copyWith(color: c.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  final Color color;
  const _SummaryDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      color: color,
    );
  }
}

class _RuleLine extends StatelessWidget {
  final String text;
  final bool muted;
  const _RuleLine({required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text,
      style: AppTextStyles.sm.copyWith(
        color: muted ? c.textTertiary : c.textSecondary,
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _MiniBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '$label $count',
        style: AppTextStyles.xs.copyWith(color: color),
      ),
    );
  }
}
