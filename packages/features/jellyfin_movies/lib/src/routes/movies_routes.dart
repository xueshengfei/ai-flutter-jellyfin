import 'package:flutter/widgets.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../models/movie_filter_models.dart';
import '../pages/movie_detail_page.dart';
import '../pages/movie_filter_page.dart';

/// 电影业务 Feature 模块
///
/// 自注册路由：电影库列表、电影详情。
/// 导航通过 ServiceRegistry 获取 AppNavigator，不需要 Product App 注入回调。
final class MoviesFeatureModule extends JellyfinFeatureModule {
  MoviesFeatureModule();

  @override
  String get name => 'movies';

  @override
  String get version => '0.1.0';

  @override
  List<RouteDescriptor> buildRoutes(ModuleContext context) => [
    const RouteDescriptor(
      path: '/libraries/:libraryId/movies',
      name: 'movies.library',
    ),
    const RouteDescriptor(
      path: '/movies/:itemId',
      name: JellyfinRouteNames.movieDetail,
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
    switch (routeName) {
      case 'movies.library':
        final fetchMovies = ServiceRegistry.get<MoviesFetcher>(context);
        final libraryId = pathParameters['libraryId'] ?? '';
        final libraryName = (extra is Map && extra['libraryName'] is String)
            ? extra['libraryName'] as String
            : '';
        return MovieFilterPage(
          libraryId: libraryId,
          libraryName: libraryName,
          fetchMovies: fetchMovies,
        );

      case JellyfinRouteNames.movieDetail:
        final fetchDetail =
            ServiceRegistry.get<MovieDetailFetcher>(context);
        final itemId = pathParameters['itemId'] ?? '';
        final imageProvider =
            ServiceRegistry.tryGet<JellyfinImageProvider>(context);
        // extra 可能包含完整的 MediaItem 或只有 id
        final movie = extra is MediaItem
            ? extra
            : MediaItem(
                id: itemId,
                name: '',
                type: 'movie',
                serverUrl: '',
              );
        return MovieDetailPage(
          movie: movie,
          fetchDetail: fetchDetail,
          imageProvider: imageProvider,
        );

      default:
        throw ArgumentError(
          'MoviesFeatureModule: unknown route $routeName',
        );
    }
  }
}
