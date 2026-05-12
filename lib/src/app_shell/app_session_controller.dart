import 'package:flutter/foundation.dart';
import 'package:jellyfin_service/src/app_shell/app_session.dart';
import 'package:jellyfin_service/src/jellyfin_client.dart';

/// 管理认证会话的 [ChangeNotifier]
///
/// 提供 login/logout 方法，外部可监听 [currentSession] 变化。
class AppSessionController extends ChangeNotifier {
  AppSession? _currentSession;

  /// 当前会话（未登录为 null）
  AppSession? get currentSession => _currentSession;
  bool get isLoggedIn => _currentSession != null;

  /// Stores an externally-created session.
  ///
  /// This lets LoginPage keep credential collection while AppShell owns session
  /// state and go_router redirection.
  void setSession(AppSession session) {
    _currentSession = session;
    notifyListeners();
  }

  /// 登录：创建 client、认证、存 session
  Future<AppSession> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final client = JellyfinClient(serverUrl: serverUrl);
    final result = await client.auth.authenticate(
      username: username,
      password: password,
    );
    _currentSession = AppSession(client: client, user: result.user);
    notifyListeners();
    return _currentSession!;
  }

  /// 登出：调用 client.auth.logout()，清 session
  Future<void> logout() async {
    await _currentSession?.client.auth.logout();
    _currentSession = null;
    notifyListeners();
  }
}
