import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'announcement_config.dart';

class AnnouncementService {
  static const _prefKey = 'dismissed_announcement_version';

  /// 检查是否需要显示公告，如需要则弹窗
  static Future<void> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getInt(_prefKey) ?? 0;

    if (dismissed >= announcementVersion) return;
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(announcementTitle),
        content: SingleChildScrollView(
          child: Text(announcementContent, style: const TextStyle(height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
          FilledButton(
            onPressed: () async {
              await prefs.setInt(_prefKey, announcementVersion);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('不再显示'),
          ),
        ],
      ),
    );
  }
}
