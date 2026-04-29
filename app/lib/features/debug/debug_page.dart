import 'dart:io';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/providers.dart';
import 'sync_tab.dart';
import 'log_tab.dart';

class DebugPage extends ConsumerStatefulWidget {
  const DebugPage({super.key});

  @override
  ConsumerState<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends ConsumerState<DebugPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试工具'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: '概览'),
            Tab(icon: Icon(Icons.sync), text: '同步'),
            Tab(icon: Icon(Icons.article_outlined), text: '日志'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          SyncTab(),
          LogTab(),
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  int _taskCount = 0;
  int _recordCount = 0;
  int _pendingCount = 0;
  int _failedCount = 0;
  bool _loading = true;

  bool _networkLoading = false;
  String? _networkResult;
  int? _networkLatency;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final local = ref.read(attendanceLocalDSProvider);
      final db = ref.read(databaseProvider);
      final pending = await local.getPendingSyncItems();
      final failed = await local.getFailedSyncItems();
      final tasks = await (db.select(db.attendanceTasks)).get();
      final records = await (db.select(db.attendanceRecords)).get();
      setState(() {
        _taskCount = tasks.length;
        _recordCount = records.length;
        _pendingCount = pending.length;
        _failedCount = failed.length;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _testNetwork() async {
    setState(() {
      _networkLoading = true;
      _networkResult = null;
      _networkLatency = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final sw = Stopwatch()..start();
      final response = await api.dio.get('/sync/version');
      sw.stop();
      if (response.statusCode == 200) {
        setState(() {
          _networkResult = 'ok';
          _networkLatency = sw.elapsedMilliseconds;
        });
      } else {
        setState(() => _networkResult = 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      String msg = '网络错误';
      if (e.toString().contains('connectionTimeout') ||
          e.toString().contains('ConnectionTimeout')) {
        msg = '连接超时';
      } else if (e.toString().contains('receiveTimeout') ||
          e.toString().contains('ReceiveTimeout')) {
        msg = '接收超时';
      } else if (e.toString().contains('SocketException')) {
        msg = '无法连接服务器';
      } else {
        msg = e.toString();
        if (msg.length > 80) msg = '${msg.substring(0, 80)}...';
      }
      setState(() => _networkResult = msg);
    } finally {
      setState(() => _networkLoading = false);
    }
  }

  String? _tokenRemainingTime;

  void _checkTokenExpiry() {
    final token = ref.read(authServiceProvider).token;
    if (token == null || token.isEmpty) {
      setState(() => _tokenRemainingTime = '未登录');
      return;
    }

    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        setState(() => _tokenRemainingTime = '无效 Token');
        return;
      }

      // base64url decode payload
      var payload = parts[1];
      payload += List.generate((4 - payload.length % 4) % 4, (_) => '=').join();
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'] as int?;

      if (exp == null) {
        setState(() => _tokenRemainingTime = '无过期时间');
        return;
      }

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      final diff = expiry.difference(now);

      if (diff.isNegative) {
        setState(() => _tokenRemainingTime = '已过期');
      } else {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        final minutes = diff.inMinutes % 60;
        setState(() => _tokenRemainingTime = '${days}天 ${hours}小时 ${minutes}分');
      }
    } catch (e) {
      setState(() => _tokenRemainingTime = '解析失败: $e');
    }
  }

  Future<void> _simulateTokenExpiry() async {
    final authService = ref.read(authServiceProvider);
    // 只清除 token，保留 userId，模拟"token 过期"状态
    await authService.clearTokenOnly();
    ref.invalidate(authServiceProvider);
    ref.invalidate(isLoggedInProvider);
    ref.invalidate(apiClientProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token 已清除，正在跳转登录页...'),
          duration: Duration(seconds: 1),
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final syncState = ref.watch(syncStateProvider);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, '数据统计', Icons.storage),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(label: '任务', value: '$_taskCount', color: Colors.blue),
              _StatChip(label: '记录', value: '$_recordCount', color: Colors.green),
              _StatChip(
                  label: '待同步', value: '$_pendingCount', color: Colors.orange),
              _StatChip(label: '失败', value: '$_failedCount', color: Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                syncState == SyncState.syncing
                    ? Icons.sync
                    : syncState == SyncState.error
                        ? Icons.sync_problem
                        : Icons.check_circle,
                size: 16,
                color: syncState == SyncState.error
                    ? Colors.red
                    : syncState == SyncState.syncing
                        ? Colors.orange
                        : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                syncState == SyncState.syncing
                    ? '同步中...'
                    : syncState == SyncState.error
                        ? '同步异常'
                        : '同步正常',
                style: TextStyle(
                  fontSize: 13,
                  color: syncState == SyncState.error
                      ? Colors.red
                      : syncState == SyncState.syncing
                          ? Colors.orange
                          : Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _sectionHeader(context, '网络连通性', Icons.wifi),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: (_networkResult == 'ok' ? Colors.green : Colors.grey)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _networkResult == null
                              ? '点击测试'
                              : _networkResult == 'ok'
                                  ? '连接正常'
                                  : _networkResult!,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _networkResult == 'ok'
                                ? Colors.green
                                : _networkResult != null
                                    ? Colors.red
                                    : null,
                          ),
                        ),
                        if (_networkLatency != null)
                          Text(
                            '延迟: ${_networkLatency}ms',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _networkLoading ? null : _testNetwork,
                    child: _networkLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('测试'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader(context, '用户状态', Icons.person),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _InfoRow(label: '已登录', value: auth.isLoggedIn ? '是' : '否'),
                  if (auth.isLoggedIn) ...[
                    _InfoRow(
                        label: '用户ID', value: '${auth.userId ?? "-"}'),
                    _InfoRow(label: '邮箱', value: auth.userEmail ?? '-'),
                    _InfoRow(label: '角色', value: auth.userRole),
                    _InfoRow(
                        label: '实名', value: auth.userRealName ?? '未填写'),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader(context, 'Token 测试', Icons.token),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                      label: 'Token 状态',
                      value: auth.token != null ? '有效' : '无效'),
                  if (auth.token != null) ...[
                    _InfoRow(
                        label: 'Token 长度',
                        value: '${auth.token!.length} 字符'),
                    _InfoRow(
                        label: '自动刷新',
                        value: '剩余<7天时自动刷新'),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: auth.isLoggedIn ? _checkTokenExpiry : null,
                          icon: const Icon(Icons.timer, size: 18),
                          label: const Text('查看剩余时间'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: auth.isLoggedIn ? _simulateTokenExpiry : null,
                          icon: const Icon(Icons.logout, size: 18,
                              color: Colors.red),
                          label: const Text('模拟过期',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: Colors.red.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_tokenRemainingTime != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            '剩余时间: $_tokenRemainingTime',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader(context, '版本信息', Icons.info),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _InfoRow(label: 'App版本', value: '0.5.6'),
                  _InfoRow(
                      label: 'API地址', value: ApiClient.defaultBaseUrl),
                  _InfoRow(label: '平台', value: Platform.operatingSystem),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

Widget _sectionHeader(BuildContext context, String title, IconData icon) {
  return Row(
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 6),
      Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    ],
  );
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
