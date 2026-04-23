import 'package:dio/dio.dart';

import 'jellyfin_configuration.dart';
import 'core/api_client.dart';
import 'services/auth_service.dart';
import 'services/media_library_service.dart';
import 'services/image_service.dart';
import 'services/user_service.dart';
import 'services/music_service.dart';

/// Jellyfin客户端 - 简化版
///
/// 包含认证和媒体库功能的主客户端
class JellyfinClient {
  /// 配置
  final JellyfinConfiguration configuration;

  /// API客户端
  late final ApiClient _apiClient;

  /// 认证服务
  late final AuthService auth;

  /// 媒体库服务
  late final MediaLibraryService mediaLibrary;

  /// 图片服务
  late final ImageService image;

  /// 用户服务
  late final UserService user;

  /// 音乐服务
  late final MusicService music;

  /// 私有构造函数
  JellyfinClient._internal(this.configuration, [List<Interceptor>? interceptors]) {
    _apiClient = ApiClient(configuration, interceptors: interceptors);
    auth = AuthService(apiClient: _apiClient);
    mediaLibrary = MediaLibraryService(apiClient: _apiClient);
    image = ImageService(apiClient: _apiClient);
    user = UserService(apiClient: _apiClient);
    music = MusicService(apiClient: _apiClient);
  }

  /// 工厂构造函数 - 创建客户端实例
  factory JellyfinClient({
    required String serverUrl,
    String applicationName = 'Jellyfin Flutter Service',
    String applicationVersion = '0.1.0',
    String? deviceName,
    String? deviceId,
    String clientName = 'Jellyfin Flutter',
    bool enableLogging = false,
    List<Interceptor>? interceptors,
  }) {
    final config = JellyfinConfiguration(
      serverUrl: serverUrl,
      applicationName: applicationName,
      applicationVersion: applicationVersion,
      deviceName: deviceName,
      deviceId: deviceId,
      clientName: clientName,
      enableLogging: enableLogging,
    );

    return JellyfinClient._internal(config, interceptors);
  }

  /// 从配置创建客户端
  factory JellyfinClient.fromConfig(JellyfinConfiguration config, {List<Interceptor>? interceptors}) {
    return JellyfinClient._internal(config, interceptors);
  }

  /// 获取API客户端（用于高级用法）
  ApiClient get apiClient => _apiClient;

  /// 获取当前配置
  JellyfinConfiguration get config => configuration;

  /// 检查是否已认证
  bool get isAuthenticated => configuration.isAuthenticated;

  /// 获取当前访问令牌
  String? get accessToken => configuration.accessToken;

  /// 获取当前用户ID
  String? get userId => configuration.userId;

  /// 更新访问令牌
  void updateAccessToken(String? token) {
    configuration.accessToken = token;
    _apiClient.updateAccessToken(token);
  }

  /// 清除认证信息
  void clearAuth() {
    configuration.clearAuth();
    _apiClient.updateAccessToken(null);
  }

  @override
  String toString() {
    return 'JellyfinClient('
        'serverUrl: ${configuration.serverUrl}, '
        'isAuthenticated: $isAuthenticated'
        ')';
  }
}
