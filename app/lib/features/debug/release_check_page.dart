import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

// TODO: 使用 package_info_plus 读取真实 App 版本，避免手动维护
const _appVersion = '0.6.5';

class ReleaseCheckPage extends ConsumerStatefulWidget {
  const ReleaseCheckPage({super.key});

  @override
  ConsumerState<ReleaseCheckPage> createState() => _ReleaseCheckPageState();
}

class _ReleaseCheckPageState extends ConsumerState<ReleaseCheckPage> {
  bool _loading = true;
  bool _networkOk = false;
  int? _networkLatency;
  String? _tokenStatus;
  String? _tokenRemaining;
  int _taskCount = 0;
  int _recordCount = 0;
  int _unfinishedCount = 0;
  int _pendingCount = 0;
  int _failedCount = 0;
  bool _hasPassword = false;
  bool _hasPasswordError = false;

  @override
  void initState() {
    super.initState();
    _runAllChecks();
  }

  Future<void> _runAllChecks() async {
    if (!mounted) return;
    setState(() => _loading = true);

    // 并行执行所有检查
    await Future.wait([
      _checkNetwork(),
      _checkToken(),
      _checkLocalData(),
      _checkAccountSecurity(),
    ]);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _checkNetwork() async {
    try {
      final api = ref.read(apiClientProvider);
      final sw = Stopwatch()..start();
      final response = await api.dio.get('/health');
      sw.stop();
      if (!mounted) return;
      setState(() {
        _networkOk = response.statusCode == 200;
        _networkLatency = sw.elapsedMilliseconds;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _networkOk = false;
        _networkLatency = null;
      });
    }
  }

  Future<void> _checkToken() async {
    final auth = ref.read(authServiceProvider);
    if (auth.token == null || auth.token!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _tokenStatus = '未登录';
        _tokenRemaining = null;
      });
      return;
    }

    try {
      final parts = auth.token!.split('.');
      if (parts.length != 3) {
        if (!mounted) return;
        setState(() {
          _tokenStatus = '无效';
          _tokenRemaining = null;
        });
        return;
      }

      var payload = parts[1];
      payload +=
          List.generate((4 - payload.length % 4) % 4, (_) => '=').join();
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'] as int?;

      if (exp == null) {
        if (!mounted) return;
        setState(() {
          _tokenStatus = '无过期时间';
          _tokenRemaining = null;
        });
        return;
      }

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      final diff = expiry.difference(now);

      if (diff.isNegative) {
        if (!mounted) return;
        setState(() {
          _tokenStatus = '已过期';
          _tokenRemaining = null;
        });
      } else {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        if (!mounted) return;
        setState(() {
          _tokenStatus = '有效';
          _tokenRemaining = '${days}天${hours}小时';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tokenStatus = '解析失败';
        _tokenRemaining = null;
      });
    }
  }

  Future<void> _checkLocalData() async {
    try {
      final local = ref.read(attendanceLocalDSProvider);
      final db = ref.read(databaseProvider);
      final tasks = await (db.select(db.attendanceTasks)).get();
      final records = await (db.select(db.attendanceRecords)).get();
      final issueCount = await local.getSyncIssueCount();
      final failedItems = await local.getFailedSyncItems();

      if (!mounted) return;
      setState(() {
        _taskCount = tasks.length;
        _recordCount = records.length;
        // 未完成任务：status 不是 completed 也不是 abandoned
        _unfinishedCount = tasks
            .where((t) => t.status != 'completed' && t.status != 'abandoned')
            .length;
        _pendingCount = issueCount - failedItems.length;
        _failedCount = failedItems.length;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _checkAccountSecurity() async {
    try {
      final api = ref.read(apiClientProvider);
      final user = await api.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _hasPassword = user['has_password'] == true;
        _hasPasswordError = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _hasPassword = false;
        _hasPasswordError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasPassword = false;
        _hasPasswordError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final syncState = ref.watch(syncStateProvider);

    final totalIssues = _pendingCount + _failedCount;
    final hasTokenProblem = _tokenStatus == '已过期' ||
        _tokenStatus == '无效' ||
        _tokenStatus == '未登录';
    final canRelease = _networkOk &&
        !hasTokenProblem &&
        totalIssues == 0 &&
        !_hasPasswordError &&
        auth.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('发布前检查'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新检查',
            onPressed: _runAllChecks,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在检查...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 总体结论
                _buildConclusion(
                    canRelease, totalIssues, hasTokenProblem, _hasPasswordError),
                const SizedBox(height: 20),

                // 登录状态
                _buildSection(
                  context,
                  title: '登录状态',
                  icon: Icons.person,
                  items: [
                    _CheckItem(
                      label: '已登录',
                      value: auth.isLoggedIn ? '是' : '否',
                      ok: auth.isLoggedIn,
                    ),
                    if (auth.isLoggedIn) ...[
                      _CheckItem(
                        label: '邮箱',
                        value: auth.userEmail ?? '-',
                        ok: true,
                      ),
                      _CheckItem(
                        label: '角色',
                        value: auth.userRole,
                        ok: true,
                      ),
                    ],
                  ],
                ),

                // Token 状态
                _buildSection(
                  context,
                  title: 'Token 状态',
                  icon: Icons.token,
                  items: [
                    _CheckItem(
                      label: '状态',
                      value: _tokenStatus ?? '-',
                      ok: _tokenStatus == '有效',
                    ),
                    if (_tokenRemaining != null)
                      _CheckItem(
                        label: '剩余时间',
                        value: _tokenRemaining!,
                        ok: true,
                      ),
                  ],
                ),

                // 服务器连接
                _buildSection(
                  context,
                  title: '服务器连接',
                  icon: Icons.cloud,
                  items: [
                    _CheckItem(
                      label: '连接状态',
                      value: _networkOk ? '正常' : '异常',
                      ok: _networkOk,
                    ),
                    if (_networkLatency != null)
                      _CheckItem(
                        label: '延迟',
                        value: '${_networkLatency}ms',
                        ok: _networkLatency! < 1000,
                      ),
                    _CheckItem(
                      label: 'API 地址',
                      value: ApiClient.defaultBaseUrl,
                      ok: true,
                    ),
                  ],
                  trailing: !_networkOk
                      ? TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('重试'),
                          onPressed: () async {
                            await _checkNetwork();
                            if (mounted) setState(() {});
                          },
                        )
                      : null,
                ),

                // 同步状态
                _buildSection(
                  context,
                  title: '同步状态',
                  icon: Icons.sync,
                  items: [
                    _CheckItem(
                      label: '同步服务',
                      value: syncState == SyncState.syncing
                          ? '同步中'
                          : syncState == SyncState.error
                              ? '异常'
                              : '正常',
                      ok: syncState != SyncState.error,
                    ),
                    _CheckItem(
                      label: '待同步',
                      value: '$_pendingCount 条',
                      ok: _pendingCount == 0,
                    ),
                    _CheckItem(
                      label: '失败',
                      value: '$_failedCount 条',
                      ok: _failedCount == 0,
                    ),
                    if (_failedCount > 0)
                      _CheckItem(
                        label: '同步保护',
                        value: '已激活',
                        ok: false,
                      ),
                  ],
                  trailing: totalIssues > 0
                      ? TextButton.icon(
                          icon: Icon(
                            _failedCount > 0
                                ? Icons.warning_amber
                                : Icons.sync,
                            size: 16,
                          ),
                          label: Text(
                            _failedCount > 0 ? '查看同步问题' : '立即同步',
                          ),
                          onPressed: () async {
                            if (_failedCount > 0) {
                              // 有失败项，跳转同步问题详情页
                              context.push('/settings/sync-issues');
                            } else {
                              // 只有 pending，立即同步
                              await ref.read(syncServiceProvider).syncNow();
                              await _checkLocalData();
                              if (mounted) setState(() {});
                            }
                          },
                        )
                      : null,
                ),

                // 本地数据
                _buildSection(
                  context,
                  title: '本地数据',
                  icon: Icons.storage,
                  items: [
                    _CheckItem(
                      label: '任务数',
                      value: '$_taskCount',
                      ok: true,
                    ),
                    _CheckItem(
                      label: '记录数',
                      value: '$_recordCount',
                      ok: true,
                    ),
                    _CheckItem(
                      label: '未完成任务',
                      value: '$_unfinishedCount',
                      ok: _unfinishedCount == 0,
                    ),
                  ],
                ),

                // 账号安全
                _buildSection(
                  context,
                  title: '账号安全',
                  icon: Icons.security,
                  items: [
                    _CheckItem(
                      label: '密码状态',
                      value: _hasPasswordError
                          ? '加载失败'
                          : _hasPassword
                              ? '已设置'
                              : '未设置',
                      ok: !_hasPasswordError,
                    ),
                  ],
                  trailing: _hasPasswordError
                      ? TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('重试'),
                          onPressed: () async {
                            await _checkAccountSecurity();
                            if (mounted) setState(() {});
                          },
                        )
                      : null,
                ),

                // 版本信息
                _buildSection(
                  context,
                  title: '版本信息',
                  icon: Icons.info,
                  items: [
                    _CheckItem(
                      label: 'App 版本',
                      value: _appVersion,
                      ok: true,
                    ),
                    _CheckItem(
                      label: '平台',
                      value: Platform.operatingSystem,
                      ok: true,
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildConclusion(
    bool canRelease,
    int totalIssues,
    bool hasTokenProblem,
    bool hasPasswordError,
  ) {
    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    if (canRelease) {
      color = Colors.green;
      icon = Icons.check_circle;
      title = '可以发布';
      subtitle = '所有检查项通过，可以打包 APK 或交付使用';
    } else if (hasTokenProblem) {
      color = Colors.red;
      icon = Icons.error;
      title = '无法发布';
      subtitle = 'Token 状态异常，请重新登录后再试';
    } else if (totalIssues > 0) {
      color = Colors.red;
      icon = Icons.error;
      title = '暂不建议发布';
      subtitle = '有 $totalIssues 条同步问题未处理，请先解决';
    } else if (!_networkOk) {
      color = Colors.orange;
      icon = Icons.warning;
      title = '请谨慎发布';
      subtitle = '服务器连接异常，建议先确认网络状态';
    } else if (hasPasswordError) {
      color = Colors.orange;
      icon = Icons.warning;
      title = '请谨慎发布';
      subtitle = '账号安全状态加载失败，建议重试确认后再发布';
    } else {
      color = Colors.orange;
      icon = Icons.warning;
      title = '请检查';
      subtitle = '部分检查项未通过';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      color: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_CheckItem> items,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => _buildCheckRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckRow(_CheckItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            item.ok ? Icons.check_circle : Icons.error,
            size: 16,
            color: item.ok ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            item.label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const Spacer(),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: item.ok ? null : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem {
  final String label;
  final String value;
  final bool ok;

  const _CheckItem({
    required this.label,
    required this.value,
    required this.ok,
  });
}
