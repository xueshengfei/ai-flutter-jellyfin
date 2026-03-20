import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

void main() {
  group('Jellyfin Service SDK - 基础测试', () {
    test('客户端创建测试', () {
      final client = JellyfinClient(
        serverUrl: 'http://localhost:8096',
        enableLogging: false,
      );

      expect(client, isNotNull);
      expect(client.configuration.serverUrl, 'http://localhost:8096');
      expect(client.isAuthenticated, false);
    });

    test('配置测试', () {
      final config = JellyfinConfiguration(
        serverUrl: 'http://test.com',
        applicationName: 'Test App',
      );

      expect(config.serverUrl, 'http://test.com');
      expect(config.applicationName, 'Test App');
      expect(config.isAuthenticated, false);
    });

    test('客户端认证服务访问', () {
      final client = JellyfinClient(
        serverUrl: 'http://localhost:8096',
      );

      expect(client.auth, isNotNull);
      expect(client.configuration.serverUrl, 'http://localhost:8096');
    });

    test('Token管理测试', () {
      final client = JellyfinClient(
        serverUrl: 'http://localhost:8096',
      );

      // 初始状态
      expect(client.accessToken, isNull);
      expect(client.isAuthenticated, false);

      // 设置token
      client.updateAccessToken('test_token_123');
      expect(client.accessToken, 'test_token_123');
      expect(client.isAuthenticated, true);

      // 清除token
      client.clearAuth();
      expect(client.accessToken, isNull);
      expect(client.isAuthenticated, false);
    });
  });

  group('业务模型测试', () {
    test('UserProfile模型创建', () {
      // 注意：这需要实际的UserDto，这里只测试模型是否存在
      expect(UserProfile, isNotNull);
    });

    test('AuthenticationResult模型创建', () {
      // 注意：这需要实际的DTO，这里只测试模型是否存在
      expect(AuthenticationResult, isNotNull);
    });
  });
}
