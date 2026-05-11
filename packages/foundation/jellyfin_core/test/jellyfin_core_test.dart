import 'package:test/test.dart';
import 'package:jellyfin_core/jellyfin_core.dart';

void main() {
  group('JellyfinConfiguration', () {
    test('应正确设置基础属性', () {
      final config = JellyfinConfiguration(serverUrl: 'http://localhost:8096');
      expect(config.serverUrl, 'http://localhost:8096');
      expect(config.isAuthenticated, isFalse);
      expect(config.baseUrl, 'http://localhost:8096');
    });

    test('baseUrl 应去除末尾斜杠', () {
      final config = JellyfinConfiguration(serverUrl: 'http://localhost:8096/');
      expect(config.baseUrl, 'http://localhost:8096');
    });

    test('认证状态应正确更新', () {
      final config = JellyfinConfiguration(serverUrl: 'http://localhost:8096');
      expect(config.isAuthenticated, isFalse);

      config.accessToken = 'test-token';
      config.userId = 'user-1';
      expect(config.isAuthenticated, isTrue);

      config.clearAuth();
      expect(config.isAuthenticated, isFalse);
      expect(config.accessToken, isNull);
      expect(config.userId, isNull);
    });

    test('copyWith 应正确复制并修改属性', () {
      final config = JellyfinConfiguration(serverUrl: 'http://localhost:8096');
      final copied = config.copyWith(serverUrl: 'http://new-server:8096');

      expect(copied.serverUrl, 'http://new-server:8096');
      expect(copied.applicationName, config.applicationName);
    });

    test('应正确推导 AI 服务地址', () {
      final config = JellyfinConfiguration(serverUrl: 'http://192.168.1.100:8096');
      expect(config.resolvedAiServiceUrl, 'http://192.168.1.100:5005');
    });

    test('应正确推导 RVC 服务地址', () {
      final config = JellyfinConfiguration(serverUrl: 'http://192.168.1.100:8096');
      expect(config.resolvedRvcServiceUrl, 'http://192.168.1.100:9880');
    });

    test('自定义服务地址应覆盖推导', () {
      final config = JellyfinConfiguration(
        serverUrl: 'http://192.168.1.100:8096',
        aiServiceUrl: 'http://ai.example.com:6000',
        rvcServiceUrl: 'http://rvc.example.com:7000',
      );
      expect(config.resolvedAiServiceUrl, 'http://ai.example.com:6000');
      expect(config.resolvedRvcServiceUrl, 'http://rvc.example.com:7000');
    });

    test('buildAuthHeader 应包含必要字段', () {
      final config = JellyfinConfiguration(
        serverUrl: 'http://localhost:8096',
        clientName: 'Test Client',
        deviceName: 'Test Device',
        deviceId: 'test-id',
        applicationVersion: '1.0.0',
      );
      final header = config.buildAuthHeader();
      expect(header, contains('MediaBrowser'));
      expect(header, contains('Test Client'));
      expect(header, contains('Test Device'));
      expect(header, isNot(contains('Token=')));
    });

    test('buildAuthHeader 认证后应包含 Token', () {
      final config = JellyfinConfiguration(
        serverUrl: 'http://localhost:8096',
        accessToken: 'my-token',
      );
      final header = config.buildAuthHeader();
      expect(header, contains('Token="my-token"'));
    });
  });

  group('JellyfinException', () {
    test('应正确存储消息', () {
      const exception = JellyfinException('测试错误');
      expect(exception.message, '测试错误');
      expect(exception.cause, isNull);
    });

    test('toString 应包含消息', () {
      const exception = JellyfinException('测试错误');
      expect(exception.toString(), contains('测试错误'));
    });

    test('toString 有 cause 时应包含 cause', () {
      final exception = JellyfinException('测试错误', cause: Exception('原始错误'));
      expect(exception.toString(), contains('原始错误'));
    });
  });

  group('NavigationIntent', () {
    test('GenericNavigationIntent 应创建通用意图', () {
      const intent = GenericNavigationIntent(
        action: 'open_media_item',
        arguments: {'itemId': 'item-123', 'type': 'Movie'},
      );
      expect(intent.action, 'open_media_item');
      expect(intent.arguments['itemId'], 'item-123');
      expect(intent.arguments['type'], 'Movie');
    });

    test('arg<T> 应正确获取参数', () {
      const intent = GenericNavigationIntent(
        action: 'test',
        arguments: {'key': 'value', 'count': 42},
      );
      expect(intent.arg<String>('key'), 'value');
      expect(intent.arg<int>('count'), 42);
      expect(intent.arg<String>('missing'), isNull);
    });

    test('NavigationIntent 是抽象类', () {
      // NavigationIntent 不能被直接实例化
      // 只能通过子类（如 GenericNavigationIntent）使用
      const intent = GenericNavigationIntent(action: 'test');
      expect(intent, isA<NavigationIntent>());
    });
  });

  group('RouteDescriptor', () {
    test('应正确创建路由描述', () {
      const descriptor = RouteDescriptor(
        path: '/media/:id',
        name: 'media_detail',
        metadata: {'requiresAuth': true},
      );
      expect(descriptor.path, '/media/:id');
      expect(descriptor.name, 'media_detail');
      expect(descriptor.metadata['requiresAuth'], true);
    });
  });

  group('NavigationEntry', () {
    test('应正确创建导航入口', () {
      const entry = NavigationEntry(
        title: '电影',
        routePath: '/movies',
        iconName: 'movie',
        order: 1,
      );
      expect(entry.title, '电影');
      expect(entry.routePath, '/movies');
      expect(entry.iconName, 'movie');
      expect(entry.order, 1);
    });
  });
}
