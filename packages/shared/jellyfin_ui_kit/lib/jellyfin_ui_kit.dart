/// jellyfin_ui_kit - 跨业务复用的 Jellyfin UI 组件库
///
/// 包含：
/// - 图片加载抽象 [JellyfinImageProvider] 和实现 [JellyfinImage]
/// - 字母索引条 [AlphabetIndexBar]
/// - 视图模式配置 [ViewModeConfig] / 视图模式管理 [ViewModeManager]
/// - 视图模式选择器 [ViewModeSelector]
/// - 泛型分组滚动视图 [MediaGroupedScrollView]
/// - 媒体库卡片 [LibraryCard]
/// - 媒体项卡片 [MediaItemCard] / 带操作卡片 [MediaItemCardWithActions]
/// - 人员头像卡片 [PersonAvatarCard] / 人员横滚列表 [PersonListRow]
/// - 继续观看卡片 [ContinueWatchingCard]
/// - 媒体列表构建器 [MediaListBuilder] + 4 种布局（横幅/列表/海报/卡片网格）
library;

// 图片抽象和组件
export 'src/image/jellyfin_image_provider.dart';
export 'src/image/jellyfin_image.dart';

// 模型
export 'src/models/paged_result.dart';
export 'src/models/view_mode_models.dart';

// 服务
export 'src/services/view_mode_manager.dart';

// Widget - 基础
export 'src/widgets/alphabet_index_bar.dart';
export 'src/widgets/media_grouped_scroll_view.dart';
export 'src/widgets/library_card.dart';
export 'src/widgets/media_item_card.dart';
export 'src/widgets/media_item_card_with_actions.dart';
export 'src/widgets/person_avatar_card.dart';
export 'src/widgets/continue_watching_card.dart';
export 'src/widgets/view_mode_selector.dart';
export 'src/widgets/media_list_builder.dart';
export 'src/widgets/pagination_nav_bar.dart';
export 'src/widgets/paginated_list.dart';

// Widget - 布局
export 'src/widgets/media_list_layouts/banner_list_view.dart';
export 'src/widgets/media_list_layouts/vertical_list_view.dart';
export 'src/widgets/media_list_layouts/poster_grid_view.dart';
export 'src/widgets/media_list_layouts/card_grid_view.dart';
