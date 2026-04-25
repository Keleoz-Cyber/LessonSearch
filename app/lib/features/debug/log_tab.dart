import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

enum LogFilter { all, sync, network, error }

class LogTab extends ConsumerStatefulWidget {
  const LogTab({super.key});

  @override
  ConsumerState<LogTab> createState() => _LogTabState();
}

class _LogTabState extends ConsumerState<LogTab> {
  List<String> _logs = [];
  LogFilter _filter = LogFilter.all;

  static const _filterLabels = {
    LogFilter.all: '全部',
    LogFilter.sync: '同步',
    LogFilter.network: '网络',
    LogFilter.error: '错误',
  };

  static const _filterKeywords = <LogFilter, List<String>>{
    LogFilter.sync: ['同步', 'Sync', 'sync', '队列'],
    LogFilter.network: ['网络', '连接', '超时', 'timeout', 'Network', 'API'],
    LogFilter.error: ['\u274c', '失败', '错误', 'Error', 'error', '异常'],
  };

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final saved =
        ref.read(sharedPreferencesProvider).getStringList('debug_logs') ?? [];
    if (!mounted) return;
    setState(() => _logs = saved);
  }

  Future<void> _saveLogs() async {
    await ref
        .read(sharedPreferencesProvider)
        .setStringList('debug_logs', _logs);
  }

  void _addLog(String msg, {bool isError = false}) {
    final ts = DateTime.now().toString().substring(11, 19);
    final log = '[$ts] ${isError ? "\u274c " : ""}$msg';
    setState(() {
      _logs.insert(0, log);
      if (_logs.length > 200) _logs.removeRange(200, _logs.length);
    });
    _saveLogs();
  }

  Future<void> _clearLogs() async {
    setState(() => _logs.clear());
    await _saveLogs();
  }

  List<String> get _filteredLogs {
    if (_filter == LogFilter.all) return _logs;
    final keywords = _filterKeywords[_filter]!;
    return _logs.where((log) => keywords.any((k) => log.contains(k))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 4,
                children: [
                  Text('日志',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(width: 8),
                  ...LogFilter.values.map((f) => ChoiceChip(
                        label: Text(_filterLabels[f]!),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                        visualDensity: VisualDensity.compact,
                      )),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      if (filtered.isEmpty) return;
                      Share.share(filtered.join('\n'));
                    },
                    icon: const Icon(Icons.share, size: 18),
                    tooltip: '导出日志',
                  ),
                  IconButton(
                    onPressed: _clearLogs,
                    icon: const Icon(Icons.clear_all, size: 18),
                    tooltip: '清空',
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 32, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('暂无日志',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    final isError = log.contains('\u274c');
                    return InkWell(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: log));
                        Toast.show(context, '已复制');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isError ? Colors.red : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
