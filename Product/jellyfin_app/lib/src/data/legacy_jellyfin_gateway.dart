import 'package:jellyfin_service/jellyfin_service.dart' as legacy;
import 'jellyfin_gateway.dart';
import '../session/app_session.dart';

/// 旧根包 JellyfinClient 的桥接实现
///
/// 短期包住旧 SDK，让新 App 不直接在页面里 new JellyfinClient。
/// 后续可以替换为直接基于 jellyfin_api 的实现。
class LegacyJellyfinGateway implements JellyfinGateway {
  legacy.JellyfinClient? _client;

  /// 获取当前已认证的 client（供后续媒体库阶段使用）
  legacy.JellyfinClient? get client => _client;

  @override
  Future<AppSession> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final client = legacy.JellyfinClient(serverUrl: serverUrl);
    final result = await client.auth.authenticate(
      username: username,
      password: password,
    );

    _client = client;

    return AppSession(
      serverUrl: serverUrl,
      accessToken: result.accessToken,
      userId: result.user.id,
      username: result.user.name,
    );
  }

  @override
  Future<void> register({
    required String serverUrl,
    required String adminUsername,
    required String adminPassword,
    required String username,
    required String password,
  }) async {
    final client = legacy.JellyfinClient(serverUrl: serverUrl);
    await client.auth.registerWithAdmin(
      serverUrl: serverUrl,
      adminUsername: adminUsername,
      adminPassword: adminPassword,
      username: username,
      password: password,
    );
  }

  @override
  Future<void> logout() async {
    _client?.clearAuth();
    _client = null;
  }

  @override
  Future<List<LibraryInfo>> getMediaLibraries() async {
    _requireClient();
    final result = await _client!.mediaLibrary.getMediaLibraries();
    return result.libraries.map((lib) => LibraryInfo(
      id: lib.id,
      name: lib.name,
      type: lib.type.name,
      itemCount: lib.itemCount,
      primaryImageTag: lib.primaryImageTag,
    )).toList();
  }

  @override
  Future<List<ContinueWatchingItem>> getContinueWatching({int limit = 10}) async {
    _requireClient();
    final result = await _client!.user.getContinueWatching(limit: limit);
    return result.items.map((item) => ContinueWatchingItem(
      id: item.id,
      name: item.name,
      type: item.type,
      productionYear: item.productionYear,
      playedPercentage: item.playedPercentage,
      coverUrl: item.getCoverImageUrl(),
    )).toList();
  }

  void _requireClient() {
    if (_client == null) {
      throw StateError('未登录，请先调用 login()');
    }
  }
}
