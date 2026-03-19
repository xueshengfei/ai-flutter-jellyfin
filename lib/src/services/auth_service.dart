import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import '../core/api_client.dart';
import '../exceptions/authentication_exception.dart';
import '../models/user_models.dart';

/// 认证服务
///
/// 提供用户认证相关功能：
/// - 用户名/密码登录
/// - 登出功能
/// - 认证状态检查
class AuthService {
  final ApiClient _apiClient;
  final Logger _logger;

  AuthService({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  /// 用户名密码认证
  ///
  /// 使用用户名和密码登录到Jellyfin服务器
  ///
  /// 参数：
  /// - [username] 用户名
  /// - [password] 密码
  ///
  /// 返回：[AuthenticationResult] 包含访问令牌和用户信息
  ///
  /// 抛出：
  /// - [AuthenticationException] 认证失败时
  Future<AuthenticationResult> authenticate({
    required String username,
    required String password,
  }) async {
    _logger.i('Attempting authentication for user: $username');

    try {
      final userApi = _apiClient.jellyfinClient.getUserApi();

      // 创建认证请求对象
      final authenticateRequest = jellyfin_dart.AuthenticateUserByName(
        username: username,
        pw: password,
      );

      // 调用 API - 使用命名参数
      final response = await userApi.authenticateUserByName(
        authenticateUserByName: authenticateRequest,
      );

      if (response.data == null) {
        throw AuthenticationException(
          'Authentication failed: No response data',
          errorCode: 'NO_RESPONSE_DATA',
        );
      }

      final authResult = response.data!;

      // 更新API客户端的访问令牌
      _apiClient.updateAccessToken(authResult.accessToken ?? '');

      _logger.i('Authentication successful for user: $username');

      // 创建会话信息
      SessionInfo? sessionInfo;
      if (authResult.sessionInfo != null) {
        final sessionDto = authResult.sessionInfo!;
        sessionInfo = SessionInfo(
          playSessionId: sessionDto.id, // 使用 id 而不是 playSessionId
          userId: sessionDto.userId,
          username: null, // SessionInfoDto 没有 userName 属性
          serverId: sessionDto.serverId,
        );
      }

      return AuthenticationResult(
        accessToken: authResult.accessToken ?? '',
        user: UserProfile.fromDto(authResult.user!),
        serverId: authResult.serverId,
        sessionInfo: sessionInfo,
      );
    } on AuthenticationException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Authentication error', error: e, stackTrace: stackTrace);

      if (e is DioException) {
        throw AuthenticationException.fromDioError(e);
      }

      throw AuthenticationException(
        'Authentication failed: ${e.toString()}',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 登出
  ///
  /// 清除本地认证信息
  ///
  /// 注意：这不会在服务器上使会话失效，只是清除本地存储的凭据
  Future<void> logout() async {
    _logger.i('Logging out');

    // 清除API客户端的访问令牌
    _apiClient.updateAccessToken(null);

    // 清除配置中的认证信息
    _apiClient.config.clearAuth();

    _logger.i('Logout complete');
  }

  /// 检查当前是否已认证
  bool isAuthenticated() {
    return _apiClient.config.isAuthenticated;
  }

  /// 获取当前访问令牌
  String? getAccessToken() {
    return _apiClient.config.accessToken;
  }

  /// 获取当前用户ID
  String? getCurrentUserId() {
    return _apiClient.config.userId;
  }
}
