/// Jellyfin客户端配置类
///
/// 用于配置Jellyfin服务器的连接参数
class JellyfinConfiguration {
  /// 服务器地址（例如：http://localhost:8096 或 https://jellyfin.example.com）
  final String serverUrl;

  /// 应用名称（用于识别客户端）
  final String applicationName;

  /// 应用版本
  final String applicationVersion;

  /// 设备名称（可选，默认为"Dart Client"）
  final String? deviceName;

  /// 设备ID（可选，自动生成）
  final String? deviceId;

  /// 客户端名称（例如："Jellyfin Flutter"）
  final String clientName;

  /// 是否启用调试日志
  final bool enableLogging;

  /// 连接超时时间（毫秒）
  final int connectionTimeout;

  /// 接收超时时间（毫秒）
  final int receiveTimeout;

  /// 是否启用HTTPS证书验证（生产环境建议启用）
  final bool validateCertificate;

  /// AI 推荐服务地址（为空则从 serverUrl 推导，端口默认 5005）
  final String? aiServiceUrl;

  /// AI 推荐服务端口（仅当 aiServiceUrl 为空时使用，默认 5005）
  final int aiServicePort;

  /// RVC 语音转换服务地址（为空则从 serverUrl 推导，端口默认 9880）
  final String? rvcServiceUrl;

  /// RVC 服务端口（仅当 rvcServiceUrl 为空时使用，默认 9880）
  final int rvcServicePort;

  /// 登录页默认服务器地址
  static const String defaultServerUrl = 'http://localhost:8096';

  /// 访问令牌（认证后设置）
  String? accessToken;

  /// 用户ID（认证后设置）
  String? userId;

  JellyfinConfiguration({
    required this.serverUrl,
    this.applicationName = 'Jellyfin Flutter Service',
    this.applicationVersion = '0.1.0',
    this.deviceName,
    this.deviceId,
    this.clientName = 'Jellyfin Flutter',
    this.enableLogging = false,
    this.connectionTimeout = 30000, // 30秒
    this.receiveTimeout = 30000, // 30秒
    this.validateCertificate = true,
    this.aiServiceUrl,
    this.aiServicePort = 5005,
    this.rvcServiceUrl,
    this.rvcServicePort = 9880,
    this.accessToken,
    this.userId,
  });

  /// 复制配置并修改部分属性
  JellyfinConfiguration copyWith({
    String? serverUrl,
    String? applicationName,
    String? applicationVersion,
    String? deviceName,
    String? deviceId,
    String? clientName,
    bool? enableLogging,
    int? connectionTimeout,
    int? receiveTimeout,
    bool? validateCertificate,
    String? aiServiceUrl,
    int? aiServicePort,
    String? rvcServiceUrl,
    int? rvcServicePort,
    String? accessToken,
    String? userId,
  }) {
    return JellyfinConfiguration(
      serverUrl: serverUrl ?? this.serverUrl,
      applicationName: applicationName ?? this.applicationName,
      applicationVersion: applicationVersion ?? this.applicationVersion,
      deviceName: deviceName ?? this.deviceName,
      deviceId: deviceId ?? this.deviceId,
      clientName: clientName ?? this.clientName,
      enableLogging: enableLogging ?? this.enableLogging,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      validateCertificate: validateCertificate ?? this.validateCertificate,
      aiServiceUrl: aiServiceUrl ?? this.aiServiceUrl,
      aiServicePort: aiServicePort ?? this.aiServicePort,
      rvcServiceUrl: rvcServiceUrl ?? this.rvcServiceUrl,
      rvcServicePort: rvcServicePort ?? this.rvcServicePort,
      accessToken: accessToken ?? this.accessToken,
      userId: userId ?? this.userId,
    );
  }

  /// 获取API请求的基础URL
  String get baseUrl {
    final url = serverUrl.trim();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// 获取 AI 服务完整地址
  String get resolvedAiServiceUrl {
    if (aiServiceUrl != null && aiServiceUrl!.isNotEmpty) return aiServiceUrl!;
    final uri = Uri.parse(serverUrl);
    return '${uri.scheme}://${uri.host}:$aiServicePort';
  }

  /// 获取 RVC 服务完整地址
  String get resolvedRvcServiceUrl {
    if (rvcServiceUrl != null && rvcServiceUrl!.isNotEmpty) return rvcServiceUrl!;
    final uri = Uri.parse(serverUrl);
    return '${uri.scheme}://${uri.host}:$rvcServicePort';
  }

  /// 检查是否已认证
  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;

  /// 清除认证凭据
  void clearAuth() {
    accessToken = null;
    userId = null;
  }

  @override
  String toString() {
    return 'JellyfinConfiguration('
        'serverUrl: $serverUrl, '
        'applicationName: $applicationName, '
        'applicationVersion: $applicationVersion, '
        'enableLogging: $enableLogging, '
        'isAuthenticated: $isAuthenticated'
        ')';
  }
}
