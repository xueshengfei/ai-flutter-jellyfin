import 'package:jellyfin_models/jellyfin_models.dart';

/// 测试用 UserProfile
const UserProfile testUserProfile = UserProfile(
  id: 'user-001',
  name: '测试用户',
  serverUrl: 'http://test-server:8096',
  isAdmin: false,
);

/// 测试用管理员 UserProfile
const UserProfile testAdminProfile = UserProfile(
  id: 'admin-001',
  name: '管理员',
  serverUrl: 'http://test-server:8096',
  isAdmin: true,
);

/// 测试用 AuthenticationResult
AuthenticationResult testAuthResult({
  String? accessToken,
  UserProfile? user,
}) {
  return AuthenticationResult(
    accessToken: accessToken ?? 'test-token-001',
    user: user ?? testUserProfile,
    serverId: 'server-001',
  );
}
