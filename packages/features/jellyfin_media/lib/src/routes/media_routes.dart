import 'package:flutter/widgets.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../pages/media_item_detail_page.dart';

/// 媒体详情 Feature 模块
///
/// 自注册路由：通用媒体详情。
/// 导航通过 ServiceRegistry 获取 AppNavigator，不需要 Product App 注入回调。
final class MediaFeatureModule extends JellyfinFeatureModule {
  MediaFeatureModule();

  @override
  String get name => 'media';

  @override
  String get version => '0.1.0';

  @override
  List<RouteDescriptor> buildRoutes(ModuleContext context) => [
    const RouteDescriptor(
      path: '/media/items/:itemId',
      name: JellyfinRouteNames.mediaDetail,
    ),
  ];

  @override
  List<NavigationEntry> buildNavigationEntries(ModuleContext context) => [];

  @override
  Widget buildPage(
    BuildContext context,
    String routeName, {
    Map<String, String> pathParameters = const {},
    Object? extra,
  }) {
    final fetchDetail =
        ServiceRegistry.get<MediaItemDetailFetcher>(context);
    final fetchSeasons =
        ServiceRegistry.tryGet<SeasonsFetcher>(context);
    final imageProvider =
        ServiceRegistry.tryGet<JellyfinImageProvider>(context);

    // 从 pathParameters 或 extra 中获取 itemId
    final itemId = pathParameters['itemId'] ?? '';
    // extra 可以传入预加载的 MediaItem
    final MediaItem item;
    if (extra is MediaItem) {
      item = extra;
    } else {
      // 仅传入 itemId 时，构造最小 MediaItem
      final serverUrl = _getServerUrl(context);
      item = MediaItem(
        id: itemId,
        name: '',
        type: '',
        serverUrl: serverUrl,
      );
    }

    return switch (routeName) {
      JellyfinRouteNames.mediaDetail => MediaItemDetailPage(
          item: item,
          fetchDetail: fetchDetail,
          fetchSeasons: fetchSeasons,
          imageProvider: imageProvider,
        ),
      _ => throw ArgumentError(
          'MediaFeatureModule: unknown route $routeName',
        ),
    };
  }

  /// 从 ServiceRegistry 获取服务器地址
  String _getServerUrl(BuildContext context) {
    final config =
        ServiceRegistry.tryGet<JellyfinConfiguration>(context);
    return config?.serverUrl ?? '';
  }
}
