/// jellyfin_ai_recommendation - AI 对话推荐业务模块
///
/// 业务解耦设计：
/// - 通过 JellyfinImageProvider 加载图片
/// - 通过 MediaItemDetailFetcher 获取详情
/// - 通过回调函数跳转到其它 feature 页面
/// - 不直接 import MediaItemDetailPage/AlbumDetailPage/ArtistDetailPage/AudioPlayerPage

// 模型
export 'src/models/ai_recommendation_models.dart';
export 'src/models/tts_models.dart';

// 服务
export 'src/services/ai_recommendation_service.dart';
export 'src/services/tts_playback_service.dart';
export 'src/services/tts_settings_storage.dart';
export 'src/services/tts_voice_loader.dart';

// 页面
export 'src/pages/ai_recommend_page.dart';

// 组件
export 'src/widgets/ai_recommend_pill.dart';
export 'src/widgets/tts_control_button.dart';
export 'src/widgets/tts_settings_dialog.dart';
