import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;

import '../session/app_session.dart';

/// Jellyfin 数据访问网关协议
///
/// 新 App 的所有数据访问都通过此协议，
/// 直接返回 jellyfin_models 共享类型，页面不直接创建 ApiClient。
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
  Future<List<models.MediaItem>> getContinueWatching({int limit = 10});

  /// 获取媒体项详情
  Future<models.MediaItem> getMediaItemDetail(String itemId);

  /// 获取剧集季列表
  Future<models.SeasonListResult> getSeasons(String seriesId);

  /// 获取剧集集列表
  Future<models.EpisodeListResult> getEpisodes({
    required String seasonId,
    required String seriesId,
  });

  /// 获取电影列表（按筛选条件）
  Future<movies.MovieFilterResult> fetchMovies(movies.MovieFilter filter);
}
