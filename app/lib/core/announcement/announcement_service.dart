import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'announcement_config.dart';

class AnnouncementService {
  static const _prefKey = 'dismissed_announcement_version';
  static const _cacheKey = 'cached_announcement';
  static const _cacheTitleKey = 'cached_announcement_title';
  static const _cacheVersionKey = 'cached_announcement_version';

  static Future<Map<String, dynamic>?> fetchAnnouncement() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.keleoz.cn/api/announcement',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      final data = response.data as Map<String, dynamic>;
      final version = data['version'] as int;
      if (version == 0) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCachedAnnouncement() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(_cacheVersionKey) ?? 0;
    if (version == 0) return null;
    final title = prefs.getString(_cacheTitleKey) ?? '';
    final content = prefs.getString(_cacheKey) ?? '';
    if (content.isEmpty) return null;
    return {'version': version, 'title': title, 'content': content};
  }

  static Future<void> cacheAnnouncement(
    Map<String, dynamic> announcement,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final version = announcement['version'] as int;
    final title = announcement['title'] as String? ?? '';
    final content = announcement['content'] as String? ?? '';
    await prefs.setInt(_cacheVersionKey, version);
    await prefs.setString(_cacheTitleKey, title);
    await prefs.setString(_cacheKey, content);
  }

  static Future<void> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getInt(_prefKey) ?? 0;

    Map<String, dynamic>? announcement = await fetchAnnouncement();
    if (announcement == null) {
      announcement = await getCachedAnnouncement();
    } else {
      await cacheAnnouncement(announcement);
    }

    if (announcement == null) {
      announcement = {
        'version': announcementVersion,
        'title': announcementTitle,
        'content': announcementContent,
      };
    }

    final version = announcement['version'] as int;
    if (dismissed >= version) return;
    if (!context.mounted) return;

    final title = announcement['title'] as String? ?? announcementTitle;
    final content = announcement['content'] as String? ?? announcementContent;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              MarkdownBody(
                data: content.trim(),
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(height: 1.6),
                  listBullet: const TextStyle(height: 1.6),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MarkdownBody(
                  data: updateNotes.trim(),
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 13, height: 1.5),
                    listBullet: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
          FilledButton(
            onPressed: () async {
              await prefs.setInt(_prefKey, version);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('不再显示'),
          ),
        ],
      ),
    );
  }
}
