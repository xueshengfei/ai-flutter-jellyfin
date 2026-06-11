import 'package:flutter/widgets.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

import '../models/series_models.dart';
import '../pages/seasons_page.dart';
import '../pages/episodes_page.dart';

/// 剧集 Feature 模块
///
/// 自注册路由：剧集库列表、季列表、集列表。
/// 导航通过 ServiceRegistry 获取 AppNavigator，不需要 Product App 注入回调。
final class SeriesFeatureModule extends JellyfinFeatureModule {
  SeriesFeatureModule();

  @override
  String get name => 'series';

  @override
  String get version => '0.1.0';

  @override
  List<RouteDescriptor> buildRoutes(ModuleContext context) => [
    const RouteDescriptor(
      path: '/libraries/:libraryId/series',
      name: 'series.library',
    ),
    const RouteDescriptor(
      path: '/series/:seriesId/seasons',
      name: JellyfinRouteNames.seriesSeasons,
    ),
    const RouteDescriptor(
      path: '/series/:seriesId/seasons/:seasonId/episodes',
      name: JellyfinRouteNames.seriesEpisodes,
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
    return switch (routeName) {
      'series.library' => _buildSeriesLibraryPage(
          pathParameters: pathParameters,
          extra: extra,
        ),
      JellyfinRouteNames.seriesSeasons => _buildSeasonsPage(
          buildContext: context,
          pathParameters: pathParameters,
          extra: extra,
        ),
      JellyfinRouteNames.seriesEpisodes => _buildEpisodesPage(
          buildContext: context,
          pathParameters: pathParameters,
          extra: extra,
        ),
      _ => throw ArgumentError(
          'SeriesFeatureModule: unknown route $routeName',
        ),
    };
  }

  /// 从 ServiceRegistry 获取服务器地址
  String _getServerUrl(BuildContext context) {
    final config =
        ServiceRegistry.tryGet<JellyfinConfiguration>(context);
    return config?.serverUrl ?? '';
  }

  Widget _buildSeriesLibraryPage({
    required Map<String, String> pathParameters,
    Object? extra,
  }) {
    // series.library 路由预留，可后续扩展
    return const SizedBox.shrink();
  }

  Widget _buildSeasonsPage({
    required BuildContext buildContext,
    required Map<String, String> pathParameters,
    Object? extra,
  }) {
    final fetchSeasons =
        ServiceRegistry.get<SeasonsFetcher>(buildContext);
    final MediaItem series;
    if (extra is MediaItem) {
      series = extra;
    } else {
      final seriesId = pathParameters['seriesId'] ?? '';
      final serverUrl = _getServerUrl(buildContext);
      series = MediaItem(
        id: seriesId,
        name: '',
        type: 'Series',
        serverUrl: serverUrl,
      );
    }

    return SeasonsPage(
      series: series,
      fetchSeasons: fetchSeasons,
    );
  }

  Widget _buildEpisodesPage({
    required BuildContext buildContext,
    required Map<String, String> pathParameters,
    Object? extra,
  }) {
    final fetchEpisodes =
        ServiceRegistry.get<EpisodesFetcher>(buildContext);

    final seriesId = pathParameters['seriesId'] ?? '';
    final seasonId = pathParameters['seasonId'] ?? '';
    final serverUrl = _getServerUrl(buildContext);

    // extra 可传入预加载的 MediaItem 和 Season
    MediaItem series;
    Season season;
    if (extra is Map<String, dynamic>) {
      series = extra['series'] as MediaItem? ??
          MediaItem(
            id: seriesId,
            name: '',
            type: 'Series',
            serverUrl: serverUrl,
          );
      season = extra['season'] as Season? ??
          Season(
            id: seasonId,
            name: '',
            seriesId: seriesId,
            indexNumber: 0,
            serverUrl: serverUrl,
          );
    } else {
      series = MediaItem(
        id: seriesId,
        name: '',
        type: 'Series',
        serverUrl: serverUrl,
      );
      season = Season(
        id: seasonId,
        name: '',
        seriesId: seriesId,
        indexNumber: 0,
        serverUrl: serverUrl,
      );
    }

    return EpisodesPage(
      series: series,
      season: season,
      fetchEpisodes: fetchEpisodes,
    );
  }
}
