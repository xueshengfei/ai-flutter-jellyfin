/// 应用会话 — 持有当前登录态信息
class AppSession {
  final String serverUrl;
  final String accessToken;
  final String userId;
  final String username;

  const AppSession({
    required this.serverUrl,
    required this.accessToken,
    required this.userId,
    required this.username,
  });

  bool get isValid =>
      serverUrl.isNotEmpty &&
      accessToken.isNotEmpty &&
      userId.isNotEmpty;
}
