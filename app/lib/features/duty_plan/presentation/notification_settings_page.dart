import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notification/notification_service.dart';
import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});
  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage>
    with WidgetsBindingObserver {
  NotificationPermissionState? _permissions;
  bool _busy = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _requestId++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    try {
      final state = await ref
          .read(notificationServiceProvider)
          .permissionState();
      if (mounted && requestId == _requestId) {
        setState(() {
          _permissions = state;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = '暂时无法读取通知设置，请重试');
      }
    }
  }

  Future<void> _run(
    Future<void> Function(NotificationService service) action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final service = ref.read(notificationServiceProvider);
    final repo = ref.read(dutyPlanRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await action(service);
      await service.reconcile(repo);
      container.invalidate(dutyPlansProvider);
      container.invalidate(upcomingDutyPlansProvider);
      if (!mounted) return;
      await _load();
      if (mounted) Toast.show(context, '已核对提醒状态，可在查课计划中查看结果');
    } catch (_) {
      if (mounted) setState(() => _error = '操作未完成，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final permissions = _permissions;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(title: const Text('系统通知与提醒')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: c.stateDanger)),
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('重试'),
            ),
          ],
          if (permissions == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (permissions != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('通知权限'),
              subtitle: Text(
                !permissions.supported
                    ? '当前平台暂不支持'
                    : permissions.notificationsEnabled
                    ? '已开启'
                    : '未开启，提醒不会显示',
              ),
            ),
            if (permissions.supported) ...[
              AppButton.primary(
                label: permissions.notificationsEnabled ? '打开系统通知设置' : '允许通知',
                fullWidth: true,
                loading: _busy,
                onPressed: _busy
                    ? null
                    : () => _run((service) async {
                        if (permissions.notificationsEnabled) {
                          await service.openSettings();
                        } else if (!await service.requestPermission()) {
                          await service.openSettings();
                        }
                      }),
              ),
              const SizedBox(height: 20),
            ],
            if (android) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm),
                title: const Text('精确提醒'),
                subtitle: Text(
                  permissions.exactAlarms
                      ? '已允许，按计划时间提醒'
                      : '未允许，系统仍会安排提醒，但可能延迟',
                ),
              ),
              AppButton.secondary(
                label: '设置精确提醒',
                fullWidth: true,
                onPressed: _busy
                    ? null
                    : () => _run((service) async {
                        await service.requestExactPermission();
                      }),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.pending_actions),
                title: const Text('查课进度通知'),
                subtitle: Text(
                  permissions.liveUpdatesSupported
                      ? permissions.liveUpdatesEnabled
                            ? '支持实时更新，展示方式由系统决定'
                            : '可使用普通进度通知，实时更新尚未开启'
                      : '查课进行时显示普通进度通知',
                ),
              ),
              if (permissions.liveUpdatesSupported)
                AppButton.secondary(
                  label: '实时更新设置',
                  fullWidth: true,
                  onPressed: _busy
                      ? null
                      : () => _run(
                          (service) => service.openSettings(kind: 'live'),
                        ),
                ),
              const SizedBox(height: 20),
            ],
            if (permissions.supported)
              AppButton.secondary(
                label: '重新核对并恢复提醒',
                fullWidth: true,
                loading: _busy,
                onPressed: _busy ? null : () => _run((_) async {}),
              ),
          ],
          const SizedBox(height: 24),
          Text('提醒如何工作', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('查课前的提醒由系统安排。正常返回桌面、锁屏或划走最近任务后，通常仍可提醒；设备的省电策略可能影响送达。'),
          const SizedBox(height: 12),
          const Text('在系统设置中“强行停止”应用后，提醒会被系统取消。再次打开应用会核对并恢复未来计划；已错过的提醒不会重复补发。'),
          const SizedBox(height: 12),
          const Text('查课开始后可在通知中查看处理进度，点按继续任务。通知不展示学生姓名和具体考勤状态，完成后会自动移除。'),
        ],
      ),
    );
  }
}
