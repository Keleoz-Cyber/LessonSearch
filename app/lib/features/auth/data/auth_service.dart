import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _userNicknameKey = 'user_nickname';
  static const _userRealNameKey = 'user_real_name';
  static const _userRoleKey = 'user_role';

  final SharedPreferences _prefs;

  AuthService(this._prefs);

  bool get isLoggedIn => _prefs.getString(_tokenKey) != null;

  String? get token => _prefs.getString(_tokenKey);

  int? get userId => _prefs.getInt(_userIdKey);

  String? get userEmail => _prefs.getString(_userEmailKey);

  String? get userNickname => _prefs.getString(_userNicknameKey);

  String? get userRealName => _prefs.getString(_userRealNameKey);

  String get userRole => _prefs.getString(_userRoleKey) ?? 'member';

  bool get hasRealName =>
      userRealName != null && userRealName!.trim().isNotEmpty;

  bool get isAdmin => userRole == 'admin';

  Future<void> saveAuth({
    required String token,
    required int userId,
    required String email,
    String? nickname,
    String? realName,
    String? role,
  }) async {
    final commits = <Future<bool>>[];
    commits.add(_prefs.setString(_tokenKey, token));
    commits.add(_prefs.setInt(_userIdKey, userId));
    commits.add(_prefs.setString(_userEmailKey, email));
    if (nickname != null) {
      commits.add(_prefs.setString(_userNicknameKey, nickname));
    }
    if (realName != null) {
      commits.add(_prefs.setString(_userRealNameKey, realName));
    }
    if (role != null) {
      commits.add(_prefs.setString(_userRoleKey, role));
    }
    await Future.wait(commits);
  }

  Future<void> updateRealName(String realName) async {
    await _prefs.setString(_userRealNameKey, realName);
  }

  Future<void> clearAuth() async {
    final keys = [
      _tokenKey,
      _userIdKey,
      _userEmailKey,
      _userNicknameKey,
      _userRealNameKey,
      _userRoleKey,
    ];
    await Future.wait(keys.map((k) => _prefs.remove(k)));
  }
}
