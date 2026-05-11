import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'package:jellyfin_core/jellyfin_core.dart';
import 'exceptions/api_exception.dart';

/// Jellyfin API 客户端
///
/// 封装 Dio HTTP 客户端和 jellyfin_dart 接口 SDK，提供：
/// - 自动认证头管理
/// - 请求/响应拦截器（日志和错误处理）
/// - 异常转换
class ApiClient {
  /// Jellyfin 配置
  final JellyfinConfiguration _config;

  /// 主 Dio 客户端
  late final Dio _dio;

  /// jellyfin_dart 客户端
  late final jellyfin_dart.JellyfinDart _jellyfinClient;

  /// Logger 实例
  final Logger _logger;

  /// 认证头键名
  static const String _authHeaderKey = 'X-Emby-Authorization';

  /// 外部注入的拦截器
  final List<Interceptor> _extraInterceptors;

  /// 构造函数
  ApiClient(
    this._config, {
    Logger? logger,
    List<Interceptor>? interceptors,
  })  : _logger = logger ?? Logger(),
        _extraInterceptors = interceptors ?? const [] {
    _initializeDio();
    _initializeJellyfinClient();
  }

  /// 初始化主 Dio 客户端
  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: Duration(milliseconds: _config.connectionTimeout),
      receiveTimeout: Duration(milliseconds: _config.receiveTimeout),
      sendTimeout: Duration(milliseconds: _config.connectionTimeout),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        _authHeaderKey: _config.buildAuthHeader(),
      },
    ));

    _setupInterceptors();
    _dio.interceptors.addAll(_extraInterceptors);
  }

  /// 初始化 jellyfin_dart 客户端（使用独立的 Dio 实例 + 拦截器动态设置认证头）
  void _initializeJellyfinClient() {
    final customDio = Dio(BaseOptions(
      baseUrl: _config.serverUrl,
      connectTimeout: const Duration(milliseconds: 5000),
      receiveTimeout: const Duration(milliseconds: 3000),
    ));

    customDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers[_authHeaderKey] = _config.buildAuthHeader();
          handler.next(options);
        },
      ),
    );

    customDio.interceptors.addAll(_extraInterceptors);

    _jellyfinClient = jellyfin_dart.JellyfinDart(
      dio: customDio,
      basePathOverride: _config.serverUrl,
    );
  }

  /// 设置拦截器
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_config.enableLogging) {
            _logger.d('API Request: ${options.method} ${options.uri}');
          }
          options.headers[_authHeaderKey] = _config.buildAuthHeader();
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

  /// 更新访问令牌
  void updateAccessToken(String? token) {
    _config.accessToken = token;
    _dio.options.headers[_authHeaderKey] = _config.buildAuthHeader();
  }

  /// 获取 jellyfin_dart 客户端
  jellyfin_dart.JellyfinDart get jellyfinClient => _jellyfinClient;

  /// 获取主 Dio 客户端
  Dio get dio => _dio;

  /// 获取当前配置
  JellyfinConfiguration get config => _config;
}
