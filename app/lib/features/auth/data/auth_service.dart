import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _userNicknameKey = 'user_nickname';

  final SharedPreferences _prefs;

  AuthService(this._prefs);

  bool get isLoggedIn => _prefs.getString(_tokenKey) != null;

  String? get token => _prefs.getString(_tokenKey);

  int? get userId => _prefs.getInt(_userIdKey);

  String? get userEmail => _prefs.getString(_userEmailKey);

  String? get userNickname => _prefs.getString(_userNicknameKey);

  Future<void> saveAuth({
    required String token,
    required int userId,
    required String email,
    String? nickname,
  }) async {
    final commits = <Future<bool>>[];
    commits.add(_prefs.setString(_tokenKey, token));
    commits.add(_prefs.setInt(_userIdKey, userId));
    commits.add(_prefs.setString(_userEmailKey, email));
    if (nickname != null) {
      commits.add(_prefs.setString(_userNicknameKey, nickname));
    }
    await Future.wait(commits);
  }

  Future<void> clearAuth() async {
    final keys = [_tokenKey, _userIdKey, _userEmailKey, _userNicknameKey];
    await Future.wait(keys.map((k) => _prefs.remove(k)));
  }
}
