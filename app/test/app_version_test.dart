import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lesson_search/core/app_version.dart';
import 'package:lesson_search/core/announcement/announcement_config.dart';

void main() {
  test('release labels match package and backend version', () {
    expect(
      File('pubspec.yaml').readAsStringSync().replaceAll('\r\n', '\n'),
      contains('version: $appFullVersion\n'),
    );
    expect(
      File('../server/app/version.py').readAsStringSync(),
      contains('API_VERSION = "$appVersion"'),
    );
    expect(announcementTitle, '考勤助手 v$appVersion');
    expect(latestUpdateNotes, contains('v$appVersion'));
    expect(updateNotes, contains('## v0.7.0 更新内容'));
    expect(announcementVersion, greaterThan(36));
  });

  test('stable update comparison never recommends downgrading', () {
    for (final version in [
      '0.7.0',
      '0.6.5',
      '0.7.1',
      'v0.7.1',
      '0.7.1+35',
      '0.0.0',
    ]) {
      expect(isNewerAppVersion(version), isFalse, reason: version);
    }
    for (final version in ['0.7.2', 'v0.8.0', '0.10.0', '1.0.0', '0.7.10']) {
      expect(isNewerAppVersion(version), isTrue, reason: version);
    }
    for (final version in [
      '',
      'latest',
      '0.8',
      '0.8.0-beta',
      '0.08.0',
      '0.7.-1',
    ]) {
      expect(isNewerAppVersion(version), isFalse, reason: version);
    }
  });
}
