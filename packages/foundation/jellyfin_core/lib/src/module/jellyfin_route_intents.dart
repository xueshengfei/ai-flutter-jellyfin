import 'jellyfin_route_names.dart';
import 'navigation_intent.dart';

/// 类型安全的路由意图工厂方法
///
/// 提供静态方法创建常见路由的 [RouteNavigationIntent]，
/// 避免调用方手动拼写路由名和参数键名。
abstract final class JellyfinRouteIntents {
  /// 播放视频
  static RouteNavigationIntent playbackVideo({required String itemId}) =>
      RouteNavigationIntent(
        routeName: JellyfinRouteNames.playbackVideo,
        arguments: {'itemId': itemId},
      );

  /// 电影详情
  static RouteNavigationIntent movieDetail({required String itemId}) =>
      RouteNavigationIntent(
        routeName: JellyfinRouteNames.movieDetail,
        arguments: {'itemId': itemId},
      );

  /// 通用媒体详情
  static RouteNavigationIntent mediaDetail({required String itemId}) =>
      RouteNavigationIntent(
        routeName: JellyfinRouteNames.mediaDetail,
        arguments: {'itemId': itemId},
      );

  /// 剧集季列表
  static RouteNavigationIntent seriesSeasons({required String seriesId}) =>
      RouteNavigationIntent(
        routeName: JellyfinRouteNames.seriesSeasons,
        arguments: {'seriesId': seriesId},
      );

  /// 剧集集列表
  static RouteNavigationIntent seriesEpisodes({
    required String seriesId,
    required String seasonId,
  }) =>
      RouteNavigationIntent(
        routeName: JellyfinRouteNames.seriesEpisodes,
        arguments: {'seriesId': seriesId, 'seasonId': seasonId},
      );

  /// 媒体库详情
  static RouteNavigationIntent library({required String libraryId}) =>
      RouteNavigationIntent(
        routeName: JellyfinRouteNames.library,
        arguments: {'libraryId': libraryId},
      );

  /// 音乐专辑
  static RouteNavigationIntent musicAlbum({required String albumId}) =>
      RouteNavigationIntent(
        routeName: JellyfinRouteNames.musicAlbum,
        arguments: {'albumId': albumId},
      );

  /// 音乐艺术家
  static RouteNavigationIntent musicArtist({required String artistId}) =>
      RouteNavigationIntent(
        routeName: JellyfinRouteNames.musicArtist,
        arguments: {'artistId': artistId},
      );

  /// 音乐媒体库
  static RouteNavigationIntent musicLibrary({required String libraryId}) =>
      RouteNavigationIntent(
        routeName: JellyfinRouteNames.musicLibrary,
        arguments: {'libraryId': libraryId},
      );

  /// 音乐搜索
  static RouteNavigationIntent musicSearch({String? libraryId}) =>
      RouteNavigationIntent(
        routeName: JellyfinRouteNames.musicSearch,
        arguments: {if (libraryId != null) 'libraryId': libraryId},
      );

  /// 媒体库列表（无参）
  static RouteNavigationIntent libraries() =>
      const RouteNavigationIntent(
        routeName: JellyfinRouteNames.libraries,
      );

  /// 个人资料（无参）
  static RouteNavigationIntent profile() =>
      const RouteNavigationIntent(
        routeName: JellyfinRouteNames.profile,
      );
}
