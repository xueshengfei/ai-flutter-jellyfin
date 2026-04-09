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
export 'src/services/music_service.dart';
export 'src/services/server_discovery_service.dart';
export 'src/services/book_service.dart';

// 业务模型（业务SDK的核心价值）
export 'src/models/user_models.dart';
export 'src/models/media_library_models.dart';
export 'src/models/media_item_models.dart';
export 'src/models/person_models.dart';
export 'src/models/movie_filter_models.dart';
export 'src/models/music_models.dart';
export 'src/models/lyrics_models.dart';
export 'src/models/server_discovery_models.dart';
export 'src/models/book_models.dart';

// 异常
export 'src/exceptions/jellyfin_exception.dart';
export 'src/exceptions/authentication_exception.dart';
export 'src/exceptions/api_exception.dart';

// 主客户端
export 'src/jellyfin_client.dart';

// 调试工具
export 'src/debug/network_simulator.dart';
export 'src/debug/flutter_debug_panel.dart';

// ==================== UI 层 ====================

// UI 模型
export 'src/ui/models/view_mode_models.dart';

// UI 服务
export 'src/ui/services/playback_service.dart';
export 'src/ui/services/view_mode_manager.dart';
export 'src/ui/services/audio_playback_manager.dart';

// UI 组件
export 'src/ui/widgets/jellyfin_image.dart';
export 'src/ui/widgets/media_item_card.dart';
export 'src/ui/widgets/actor_avatar_card.dart';
export 'src/ui/widgets/person_avatar_card.dart';
export 'src/ui/widgets/media_item_card_with_actions.dart';
export 'src/ui/widgets/media_list_builder.dart';
export 'src/ui/widgets/view_mode_selector.dart';
export 'src/ui/widgets/mini_player_card.dart';
export 'src/ui/widgets/alphabet_index_bar.dart';
export 'src/ui/widgets/media_grouped_scroll_view.dart';
export 'src/ui/widgets/library_card.dart';
export 'src/ui/widgets/continue_watching_card.dart';

// UI 页面
export 'src/ui/pages/login_page.dart';
export 'src/ui/pages/media_libraries_page.dart';
export 'src/ui/pages/video_player_page.dart';
export 'src/ui/pages/media_item_detail_page.dart';
export 'src/ui/pages/media_items_page.dart';
export 'src/ui/pages/movie_detail_page.dart';
export 'src/ui/pages/movie_filter_page.dart';
export 'src/ui/pages/personal_page.dart';
export 'src/ui/pages/person_detail_page.dart';
export 'src/ui/pages/episodes_page.dart';
export 'src/ui/pages/seasons_page.dart';
export 'src/ui/pages/music_library_page.dart';
export 'src/ui/pages/music_search_page.dart';
export 'src/ui/pages/artist_detail_page.dart';
export 'src/ui/pages/album_detail_page.dart';
export 'src/ui/pages/test_api_page.dart';
export 'src/ui/pages/lyrics_page.dart';
export 'src/ui/pages/book_library_page.dart';
export 'src/ui/pages/epub_reader_page.dart';
