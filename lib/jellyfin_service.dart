/// Jellyfin Service SDK - 业务SDK
///
/// 基于接口SDK (jellyfin_dart) 构建的业务层，封装业务逻辑和用例
///
/// ## 功能
///
/// - **认证**: 用户名密码登录
/// - **媒体库**: 获取媒体库列表和详情
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
/// // 1. 登录
/// final result = await client.auth.authenticate(
///   username: 'user',
///   password: 'pass',
/// );
///
/// print('登录成功: ${result.user.name}');
///
/// // 2. 获取媒体库列表
/// final libraries = await client.mediaLibrary.getMediaLibraries();
/// for (final library in libraries.libraries) {
///   print('${library.type.icon} ${library.name}: ${library.itemCount} 项');
/// }
/// ```

// 配置
export 'src/jellyfin_configuration.dart';

// 核心客户端
export 'src/core/api_client.dart';

// 服务
export 'src/services/auth_service.dart';
export 'src/services/media_library_service.dart';
export 'src/services/image_service.dart';
export 'src/services/user_service.dart';

// 业务模型（业务SDK的核心价值）
export 'src/models/user_models.dart';
export 'src/models/media_library_models.dart';
export 'src/models/media_item_models.dart';
export 'src/models/person_models.dart';
export 'src/models/movie_filter_models.dart';

// 异常
export 'src/exceptions/jellyfin_exception.dart';
export 'src/exceptions/authentication_exception.dart';
export 'src/exceptions/api_exception.dart';

// 主客户端
export 'src/jellyfin_client.dart';
