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
      // 优先使用 body 中的 token，若为空则从响应头获取
      // Jellyfin 10.10+ 不在 body 中返回 AccessToken，改为响应头返回
      final token = authResult.accessToken
          ?? response.headers.value('access-token')
          ?? response.headers.value('x-emby-authorization')
          ?? '';
      _apiClient.updateAccessToken(token);

      // 保存用户ID到配置，UserService 等服务依赖此字段
      _apiClient.config.userId = authResult.user?.id;

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

  /// 使用管理员权限注册新用户
  ///
  /// 内部创建独立的临时管理员客户端，不修改当前 _apiClient 的认证状态。
  /// 仅完成：管理员登录 → 创建用户 → 更新策略。
  /// 调用方需自行用新用户凭据调用 [authenticate] 完成登录。
  Future<void> registerWithAdmin({
    required String serverUrl,
    required String adminUsername,
    required String adminPassword,
    required String username,
    required String password,
  }) async {
    _logger.i('Registering user $username with admin $adminUsername');

    try {
      // 创建独立的管理员 Dio，不影响当前 _apiClient
      final adminDio = Dio(BaseOptions(
        baseUrl: serverUrl,
        connectTimeout: const Duration(milliseconds: 5000),
        receiveTimeout: const Duration(milliseconds: 3000),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ));

      final adminJellyfin = jellyfin_dart.JellyfinDart(
        dio: adminDio,
        basePathOverride: serverUrl,
      );
      final userApi = adminJellyfin.getUserApi();

      // 1. 管理员登录
      final adminAuth = await userApi.authenticateUserByName(
        authenticateUserByName: jellyfin_dart.AuthenticateUserByName(
          username: adminUsername,
          pw: adminPassword,
        ),
      );

      if (adminAuth.data == null) {
        throw AuthenticationException(
          '管理员登录失败: 服务器未返回数据',
          errorCode: 'NO_RESPONSE_DATA',
        );
      }

      // 设置管理员 token 到 adminDio（body 可能为空，需要从响应头获取）
      final adminToken = adminAuth.data!.accessToken
          ?? adminAuth.headers.value('access-token')
          ?? adminAuth.headers.value('x-emby-authorization')
          ?? '';
      final config = _apiClient.config;
      final authHeader = 'MediaBrowser Client="${config.applicationName}", '
          'Device="${config.deviceName ?? 'Unknown'}", '
          'DeviceId="${config.deviceId ?? 'Unknown'}", '
          'Version="${config.applicationVersion}", '
          'Token="$adminToken"';
      adminDio.options.headers['X-Emby-Authorization'] = authHeader;

      // 2. 创建新用户
      final createResponse = await userApi.createUserByName(
        createUserByName: jellyfin_dart.CreateUserByName(
          name: username,
          password: password,
        ),
      );

      if (createResponse.data == null) {
        throw AuthenticationException(
          '注册失败: 服务器未返回数据',
          errorCode: 'NO_RESPONSE_DATA',
        );
      }

      // 3. 更新新用户策略 — 开启所有媒体库访问权限
      final newUserDto = createResponse.data!;
      final defaultPolicy = newUserDto.policy;
      if (defaultPolicy != null) {
        final updatedPolicy = defaultPolicy.copyWith(
          enableAllFolders: true,
          enableAllChannels: true,
          enableMediaPlayback: true,
          enableAudioPlaybackTranscoding: true,
          enableVideoPlaybackTranscoding: true,
          enablePlaybackRemuxing: true,
          enableContentDownloading: true,
          enableRemoteAccess: true,
          enableUserPreferenceAccess: true,
        );
        await userApi.updateUserPolicy(
          userId: newUserDto.id ?? '',
          userPolicy: updatedPolicy,
        );
        _logger.i('User $username policy updated');
      }

      _logger.i('Registration successful for user: $username');

      // 关闭临时管理员 Dio
      adminDio.close();
    } on AuthenticationException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Registration error', error: e, stackTrace: stackTrace);

      if (e is DioException) {
        throw AuthenticationException.fromDioError(e);
      }

      throw AuthenticationException(
        '注册失败: ${e.toString()}',
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
