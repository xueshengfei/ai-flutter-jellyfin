import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import '../jellyfin_configuration.dart';
import '../exceptions/api_exception.dart';

/// 简化的API客户端，封装jellyfin_dart
///
/// 提供：
/// - 自动认证头管理
/// - 请求/响应拦截器（日志和错误处理）
/// - 异常转换
class ApiClient {
  /// Jellyfin配置
  final JellyfinConfiguration _config;

  /// Dio HTTP客户端
  late final Dio _dio;

  /// Jellyfin dart客户端
  late final jellyfin_dart.JellyfinDart _jellyfinClient;

  /// Logger实例
  final Logger _logger;

  /// 认证头
  static const String _authHeaderKey = 'X-Emby-Authorization';

  /// 构造函数
  ApiClient(
    this._config, {
    Logger? logger,
  }) : _logger = logger ?? Logger() {
    _initializeDio();
    _initializeJellyfinClient();
  }

  /// 初始化Dio HTTP客户端
  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: Duration(milliseconds: _config.connectionTimeout),
      receiveTimeout: Duration(milliseconds: _config.receiveTimeout),
      sendTimeout: Duration(milliseconds: _config.connectionTimeout),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        _authHeaderKey: _buildAuthHeader(),
      },
    ));

    _setupInterceptors();
  }

  /// 初始化jellyfin_dart客户端
  void _initializeJellyfinClient() {
    // 创建自定义的 Dio 实例，可以设置认证头
    final customDio = Dio(BaseOptions(
      baseUrl: _config.serverUrl,
      connectTimeout: const Duration(milliseconds: 5000),
      receiveTimeout: const Duration(milliseconds: 3000),
    ));

    // 添加认证拦截器
    customDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 设置认证头
          options.headers[_authHeaderKey] = _buildAuthHeader();
          handler.next(options);
        },
      ),
    );

    _jellyfinClient = jellyfin_dart.JellyfinDart(
      dio: customDio,
      basePathOverride: _config.serverUrl,
    );

    // 更新访问令牌（如果有）
    if (_config.accessToken != null) {
      _updateAuthHeader(_config.accessToken!);
    }
  }

  /// 构建X-Emby-Authorization头
  String _buildAuthHeader() {
    final parts = [
      'MediaBrowser Client="${_config.applicationName}"',
      'Device="${_config.deviceName ?? 'Unknown'}"',
      'DeviceId="${_config.deviceId ?? 'Unknown'}"',
      'Version="${_config.applicationVersion}"',
    ];

    if (_config.accessToken != null && _config.accessToken!.isNotEmpty) {
      parts.add('Token="${_config.accessToken}"');
    }

    return parts.join(', ');
  }

  /// 设置拦截器
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_config.enableLogging) {
            _logger.d('API Request: ${options.method} ${options.uri}');
          }

          // 确保认证头是最新的
          options.headers[_authHeaderKey] = _buildAuthHeader();

          handler.next(options);
        },
        onResponse: (response, handler) {
          if (_config.enableLogging) {
            _logger.d('API Response: ${response.statusCode}');
          }
          handler.next(response);
        },
        onError: (error, handler) {
          if (_config.enableLogging) {
            _logger.e('API Error: ${error.message}');
          }

          // 转换Dio异常为ApiException
          final apiException = ApiException.fromDioError(error);
          handler.reject(DioException(
            requestOptions: error.requestOptions,
            error: apiException,
            response: error.response,
            type: error.type,
          ));
        },
      ),
    );
  }

  /// 更新认证令牌
  void _updateAuthHeader(String token) {
    // 更新配置中的认证头
    if (_dio.options.headers[_authHeaderKey] != null) {
      _dio.options.headers[_authHeaderKey] = _buildAuthHeader();
    }
  }

  /// 更新访问令牌
  void updateAccessToken(String? token) {
    _config.accessToken = token;
    // 更新 Dio 客户端的默认头
    _dio.options.headers[_authHeaderKey] = _buildAuthHeader();
  }

  /// 获取jellyfin_dart客户端（直接访问底层API）
  jellyfin_dart.JellyfinDart get jellyfinClient => _jellyfinClient;

  /// 获取Dio客户端（用于高级用法）
  Dio get dio => _dio;

  /// 获取当前配置
  JellyfinConfiguration get config => _config;
}
