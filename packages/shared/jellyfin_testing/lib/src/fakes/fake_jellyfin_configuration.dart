import 'package:jellyfin_core/jellyfin_core.dart';

/// 测试用固定配置
///
/// 提供一组合理的默认值，不需要真实服务器
JellyfinConfiguration fakeJellyfinConfiguration({
  String serverUrl = 'http://test-server:8096',
  String? accessToken,
  String? userId,
  bool enableLogging = false,
}) {
  return JellyfinConfiguration(
    serverUrl: serverUrl,
    applicationName: 'Test App',
    applicationVersion: '0.0.1',
    clientName: 'Test Client',
    deviceName: 'Test Device',
    deviceId: 'test-device-id',
    enableLogging: enableLogging,
    accessToken: accessToken,
    userId: userId,
  );
}

/// 已认证的测试配置
JellyfinConfiguration fakeAuthenticatedConfig({
  String serverUrl = 'http://test-server:8096',
}) {
  return fakeJellyfinConfiguration(
    serverUrl: serverUrl,
    accessToken: 'test-access-token',
    userId: 'test-user-id',
  );
}
