import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;

import '../session/app_session.dart';

/// 视频 App 数据访问网关协议
///
/// 包含电影 + 剧集 + 推荐等视频业务所需接口
abstract class JellyfinGateway {
  /// 登录认证
  Future<AppSession> login({
    required String serverUrl,
    required String username,
    required String password,
  });

  /// 管理员注册新用户
  Future<void> register({
    required String serverUrl,
    required String adminUsername,
    required String adminPassword,
    required String username,
    required String password,
  });

  /// 登出
  Future<void> logout();

  /// 获取媒体库列表
  Future<List<models.MediaLibrary>> getMediaLibraries();

  /// 获取继续观看
  Future<List<models.MediaItem>> getContinueWatching({int limit});

  /// 获取电影列表（按筛选条件）
  Future<movies.MovieFilterResult> fetchMovies(movies.MovieFilter filter);

  /// 获取媒体项列表（通用，用于剧集等）
  Future<models.MediaItemListResult> fetchMediaItems({
    required String parentId,
    bool recursive = true,
    int? startIndex,
    int? limit,
  });

  /// 获取媒体项详情
  Future<models.MediaItem> getMediaItemDetail(String itemId);

  /// 获取剧集季列表
  Future<models.SeasonListResult> getSeasons(String seriesId);

  /// 获取剧集集列表
  Future<models.EpisodeListResult> getEpisodes({
    required String seasonId,
    required String seriesId,
  });

  /// 获取最新媒体项（用于推荐）
  Future<List<models.MediaItem>> getLatestMediaItems(
    String parentId, {
    int limit,
  });
}
