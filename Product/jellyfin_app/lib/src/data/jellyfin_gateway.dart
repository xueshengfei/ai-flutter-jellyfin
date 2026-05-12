import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;
import 'package:jellyfin_music/jellyfin_music.dart' as music;

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

  /// 获取媒体项列表（通用，用于剧集/动漫等）
  Future<models.MediaItemListResult> fetchMediaItems({
    required String parentId,
    bool recursive = true,
    int? limit,
  });

  // ─── 音乐 ───

  /// 获取专辑列表
  Future<music.MusicAlbumListResult> fetchAlbums({
    required String parentId,
    int? startIndex,
    int? limit,
    String? sortBy,
  });

  /// 获取艺术家列表
  Future<music.MusicArtistListResult> fetchArtists({
    required String parentId,
    int? startIndex,
    int? limit,
  });

  /// 获取歌曲列表
  Future<music.MusicSongListResult> fetchSongs({
    required String parentId,
    int? startIndex,
    int? limit,
  });

  /// 获取专辑详情
  Future<music.MusicAlbum> getAlbumDetail(String albumId);

  /// 获取专辑歌曲列表
  Future<music.MusicSongListResult> getAlbumSongs(String albumId);

  /// 获取艺术家详情
  Future<music.MusicArtist> getArtistDetail(String artistId);

  /// 获取艺术家专辑列表
  Future<music.MusicAlbumListResult> getArtistAlbums(String artistId);
}
