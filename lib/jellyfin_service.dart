/// Jellyfin Service SDK - 简化版
///
/// 只包含认证功能的基础SDK
///
/// ## 功能
///
/// - **认证**: 用户名密码登录
/// - **会话管理**: 访问令牌管理
/// - **错误处理**: 完整的异常处理体系
///
/// ## 快速开始
///
/// ```dart
/// import 'package:jellyfin_service/jellyfin_service.dart';
///
/// // 创建客户端
/// final client = JellyfinClient(
///   serverUrl: 'http://localhost:8096',
/// );
///
/// // 登录
/// final result = await client.auth.authenticate(
///   username: 'user',
///   password: 'pass',
/// );
///
/// print('登录成功: ${result.user.name}');
/// ```

// 配置
export 'src/jellyfin_configuration.dart';

// 核心客户端
export 'src/core/api_client.dart';

// 认证服务
export 'src/services/auth_service.dart';

// 数据模型
export 'src/models/user_models.dart';

// 异常
export 'src/exceptions/jellyfin_exception.dart';
export 'src/exceptions/authentication_exception.dart';
export 'src/exceptions/api_exception.dart';

// 主客户端
export 'src/jellyfin_client.dart';
