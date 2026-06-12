import 'package:flutter/widgets.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

import '../models/playback_models.dart';
import '../models/watch_assist_models.dart';
import '../pages/video_player_page.dart';
import '../viewmodels/video_player_viewmodel.dart';

/// 视频播放 Feature 模块
///
/// 自注册路由：视频播放页。
/// 播放页为叶子页面，不包含导航回调。
/// 通过 ServiceRegistry 获取 PlaybackDelegate 等服务。
final class PlaybackFeatureModule extends JellyfinFeatureModule {
  PlaybackFeatureModule();

  @override
  String get name => 'playback';

  @override
  String get version => '0.1.0';

  @override
  List<RouteDescriptor> buildRoutes(ModuleContext context) => [
    const RouteDescriptor(
      path: '/playback/video/:itemId',
      name: JellyfinRouteNames.playbackVideo,
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
    final args = (extra as Map<String, Object?>?) ?? const {};

    // 从 extra 中获取完整 MediaItem（由调用方传入）
    final item = args['item'] as MediaItem?;
    if (item == null) {
      throw ArgumentError(
        'PlaybackFeatureModule: extra["item"] (MediaItem) is required',
      );
    }

    // 从 ServiceRegistry 获取服务
    final playback = ServiceRegistry.get<PlaybackDelegate>(context);
    final fetchWatchAssist =
        ServiceRegistry.tryGet<WatchAssistFetcher>(context);
    final onStartDownload =
        ServiceRegistry.tryGet<StartDownloadAction>(context);

    // 创建 ViewModel
    final viewModel = VideoPlayerViewModel(
      item: item,
      playback: playback,
    );

    return switch (routeName) {
      JellyfinRouteNames.playbackVideo => VideoPlayerPage(
          viewModel: viewModel,
          fetchWatchAssist: fetchWatchAssist,
          onStartDownload: onStartDownload?.call,
        ),
      _ => throw ArgumentError(
          'PlaybackFeatureModule: unknown route $routeName',
        ),
    };
  }
}

/// 下载按钮回调包装
///
/// 避免使用 Function 作为 ServiceRegistry key（类型冲突）。
/// Product App 注册:
/// ```dart
/// services[StartDownloadAction] = StartDownloadAction((ctx, item) => ...)
/// ```
final class StartDownloadAction {
  final void Function(BuildContext context, MediaItem item) call;
  const StartDownloadAction(this.call);
}
