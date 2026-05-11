/// jellyfin_ui_kit - 跨业务复用的 Jellyfin UI 组件库
///
/// 包含：
/// - 图片加载抽象 [JellyfinImageProvider] 和实现 [JellyfinImage]
/// - 字母索引条 [AlphabetIndexBar]
/// - 视图模式配置 [ViewModeConfig]
/// - 泛型分组滚动视图 [MediaGroupedScrollView]
/// - 媒体库卡片 [LibraryCard]
/// - 媒体项卡片 [MediaItemCard]
library;

// 图片抽象和组件
export 'src/image/jellyfin_image_provider.dart';
export 'src/image/jellyfin_image.dart';

// 模型
export 'src/models/view_mode_models.dart';

// Widget
export 'src/widgets/alphabet_index_bar.dart';
export 'src/widgets/media_grouped_scroll_view.dart';
export 'src/widgets/library_card.dart';
export 'src/widgets/media_item_card.dart';
