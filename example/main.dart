import 'package:jellyfin_service/jellyfin_service.dart';

/// Jellyfin Service SDK 使用示例
///
/// 这是一个简单的示例，展示如何使用简化版的 Jellyfin Service SDK
/// 进行用户认证
void main() async {
  // 1. 创建客户端
  final client = JellyfinClient(
    serverUrl: 'http://localhost:8096',
    enableLogging: true,
  );

  print('✓ 客户端创建成功');
  print('  服务器: ${client.configuration.serverUrl}');

  // 2. 用户认证
  try {
    print('\n正在登录...');

    final result = await client.auth.authenticate(
      username: 'your_username',
      password: 'your_password',
    );

    print('✓ 登录成功!');
    print('  用户: ${result.user.name}');
    print('  用户ID: ${result.user.id}');
    print('  是否管理员: ${result.user.isAdmin}');
    print('  访问令牌: ${result.accessToken.substring(0, 20)}...');

    // 3. 检查认证状态
    if (client.isAuthenticated) {
      print('\n✓ 客户端已认证');
    }

    // 4. 登出
    print('\n正在登出...');
    await client.auth.logout();
    print('✓ 登出成功');

  } on AuthenticationException catch (e) {
    print('✗ 认证失败: $e');
    if (e.errorCode != null) {
      print('  错误代码: ${e.errorCode}');
    }
  } catch (e) {
    print('✗ 发生错误: $e');
  }
}

/// 在Flutter应用中的使用示例
///
/// 展示如何在Flutter应用中使用这个SDK
class FlutterExample {
  /// 创建客户端并进行认证
  static Future<JellyfinClient> loginAndAuthenticate() async {
    // 创建客户端
    final client = JellyfinClient(
      serverUrl: 'http://localhost:8096',
      applicationName: 'My Flutter App',
      enableLogging: true,
    );

    // 认证
    final result = await client.auth.authenticate(
      username: 'user',
      password: 'pass',
    );

    // 保存用户信息
    print('登录成功: ${result.user.name}');

    return client;
  }

  /// 检查认证状态
  static void checkAuthStatus(JellyfinClient client) {
    if (client.isAuthenticated) {
      print('用户已认证');
      print('用户ID: ${client.userId}');
      print('访问令牌: ${client.accessToken}');
    } else {
      print('用户未认证');
    }
  }

  /// 登出
  static Future<void> logout(JellyfinClient client) async {
    await client.auth.logout();
    print('已登出');
  }
}
