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

  /// 个人设置（无参）
  static RouteNavigationIntent profileSettings() =>
      const RouteNavigationIntent(
        routeName: JellyfinRouteNames.profileSettings,
      );

  /// 个人统计（无参）
  static RouteNavigationIntent profileStats() =>
      const RouteNavigationIntent(
        routeName: JellyfinRouteNames.profileStats,
      );

  /// 音乐播放（无参）
  static RouteNavigationIntent playbackMusic() =>
      const RouteNavigationIntent(
        routeName: JellyfinRouteNames.playbackMusic,
      );

  /// 歌词页（无参）
  static RouteNavigationIntent musicLyrics() =>
      const RouteNavigationIntent(
        routeName: JellyfinRouteNames.musicLyrics,
      );

  /// RVC 语音转换
  static RouteNavigationIntent rvc({String? audioPath}) =>
      RouteNavigationIntent(
        routeName: JellyfinRouteNames.rvc,
        arguments: {if (audioPath != null) 'audioPath': audioPath},
      );

  /// AI 推荐（无参）
  static RouteNavigationIntent aiRecommend() =>
      const RouteNavigationIntent(
        routeName: JellyfinRouteNames.aiRecommend,
      );

  /// 下载管理（无参）
  static RouteNavigationIntent downloads() =>
      const RouteNavigationIntent(
        routeName: JellyfinRouteNames.downloads,
      );
}
