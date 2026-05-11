/// jellyfin_media - 通用媒体业务模块
///
/// 包含：
/// - 媒体详情页 [MediaItemDetailPage]
/// - 人物详情页 [PersonDetailPage]
/// - 媒体项列表页 [MediaItemsPage]
/// - 人物头像卡片 [PersonAvatarCard] / [PersonListRow]
/// - 人物模型 [Person] / [PersonCreditsResult]
/// - 回调类型定义
///
/// **导入方式**：
/// ```dart
/// // 仅需要回调 typedef（已收敛到 jellyfin_models）
/// import 'package:jellyfin_models/jellyfin_models.dart';
///
/// // 需要页面
/// import 'package:jellyfin_media/jellyfin_media_pages.dart';
///
/// // 需要模型
/// import 'package:jellyfin_media/jellyfin_media_models.dart';
///
/// // 需要组件
/// import 'package:jellyfin_media/jellyfin_media_widgets.dart';
/// ```
library;

// 数据获取 typedef 已收敛到 jellyfin_models/media_contracts.dart
// PersonDetailFetcher 和 PersonCreditsFetcher 保留在此模块（依赖 Person 模型）
export 'src/pages/person_detail_page.dart'
    show PersonDetailFetcher, PersonCreditsFetcher;
