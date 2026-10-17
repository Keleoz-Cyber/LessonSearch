/// Keep in sync with pubspec.yaml; guarded by app_version_test.dart.
const appVersion = '0.7.1';
const appBuildNumber = 35;
const appFullVersion = '$appVersion+$appBuildNumber';

/// Only stable semantic versions are eligible for the stable update channel.
bool isNewerAppVersion(String candidate, {String current = appVersion}) {
  List<int>? parse(String value) {
    final match = RegExp(
      r'^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\+\d+)?$',
    ).firstMatch(value.trim());
    if (match == null) return null;
    final parts = [for (var i = 1; i <= 3; i++) int.tryParse(match.group(i)!)];
    if (parts.contains(null)) return null;
    return parts.cast<int>();
  }

  final next = parse(candidate);
  final installed = parse(current);
  if (next == null || installed == null) return false;
  for (var i = 0; i < 3; i++) {
    if (next[i] != installed[i]) return next[i] > installed[i];
  }
  return false;
}
