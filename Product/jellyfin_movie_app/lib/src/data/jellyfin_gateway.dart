import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;

import '../session/app_session.dart';

/// 电影 App 数据访问网关协议
///
/// 只包含电影业务所需的最小接口集
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

  /// 获取电影列表（按筛选条件）
  Future<movies.MovieFilterResult> fetchMovies(movies.MovieFilter filter);

  /// 获取媒体项详情
  Future<models.MediaItem> getMediaItemDetail(String itemId);
}
