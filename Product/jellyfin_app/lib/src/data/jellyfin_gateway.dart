import '../session/app_session.dart';

/// Jellyfin 数据访问网关协议
///
/// 新 App 的所有数据访问都通过此协议，
/// 页面不直接创建 JellyfinClient。
abstract class JellyfinGateway {
  /// 登录认证
  Future<AppSession> login({
    required String serverUrl,
    required String username,
    required String password,
  });

  /// 管理员注册新用户
  Future<void> register({
    required String serverUrl,
    required String adminUsername,
    required String adminPassword,
    required String username,
    required String password,
  });

  /// 登出
  Future<void> logout();
}
