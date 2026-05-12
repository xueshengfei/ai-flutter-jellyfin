import 'package:flutter/foundation.dart';
import 'app_session.dart';

/// 管理登录态生命周期，作为 go_router 的 refreshListenable
class AppSessionController extends ChangeNotifier {
  AppSession? _session;

  AppSession? get currentSession => _session;
  bool get isLoggedIn => _session?.isValid == true;

  void setSession(AppSession session) {
    _session = session;
    notifyListeners();
  }

  void clearSession() {
    _session = null;
    notifyListeners();
  }
}
