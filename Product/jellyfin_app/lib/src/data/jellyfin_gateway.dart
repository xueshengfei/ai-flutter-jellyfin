import '../session/app_session.dart';

/// 媒体库简要信息
class LibraryInfo {
  final String id;
  final String name;
  final String type; // movies, music, tvshows, etc.
  final int? itemCount;
  final String? primaryImageTag;

  const LibraryInfo({
    required this.id,
    required this.name,
    required this.type,
    this.itemCount,
    this.primaryImageTag,
  });
}

/// 继续观看简要信息
class ContinueWatchingItem {
  final String id;
  final String name;
  final String type;
  final int? productionYear;
  final double? playedPercentage;
  final String? coverUrl;

  const ContinueWatchingItem({
    required this.id,
    required this.name,
    required this.type,
    this.productionYear,
    this.playedPercentage,
    this.coverUrl,
  });
}

/// Jellyfin 数据访问网关协议
///
/// 新 App 的所有数据访问都通过此协议，
/// 页面不直接创建 JellyfinClient。
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
  Future<List<LibraryInfo>> getMediaLibraries();

  /// 获取继续观看
  Future<List<ContinueWatchingItem>> getContinueWatching({int limit = 10});
}
