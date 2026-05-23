import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_personal/jellyfin_personal.dart' as personal;

import '../session/app_session.dart';
import '../session/app_session_controller.dart';
import 'legacy_jellyfin_gateway.dart';

/// 电影 App 的个人模块 Repository 适配器
///
/// 只处理电影类型（PersonalModuleConfig.moviesOnly）。
final class JellyfinPersonalRepositoryAdapter
    implements personal.PersonalRepository {
  final LegacyJellyfinGateway gateway;
  final AppSessionController sessionController;

  JellyfinPersonalRepositoryAdapter({
    required this.gateway,
    required this.sessionController,
  });

  ApiClient? get _client => gateway.apiClient;

  AppSession get _session {
    final session = sessionController.currentSession;
    if (session == null || !session.isValid) {
      throw StateError('登录态不存在，无法读取个人数据');
    }
    return session;
  }

  void _requireClient() {
    if (_client == null) {
      throw StateError('未登录，无法读取个人数据');
    }
  }

  @override
  Future<models.UserProfile> getProfile() async {
    final session = _session;
    return models.UserProfile(
      id: session.userId,
      name: session.username,
      serverUrl: session.serverUrl,
    );
  }

  @override
  Future<models.MediaItemListResult> getContinueWatching(
    personal.PersonalMediaQuery query,
  ) async {
    _requireClient();
    final client = _client!;
    final response = await client.jellyfinClient.getItemsApi().getResumeItems(
      userId: client.config.userId,
      startIndex: query.startIndex,
      limit: query.limit,
      includeItemTypes: _mapKinds(query.mediaKinds),
      enableUserData: true,
      enableImages: true,
      imageTypeLimit: 3,
      enableImageTypes: const [
        jellyfin_dart.ImageType.primary,
        jellyfin_dart.ImageType.backdrop,
        jellyfin_dart.ImageType.thumb,
      ],
    );
    return _mapResult(response.data, client.config.serverUrl);
  }

  @override
  Future<models.MediaItemListResult> getFavorites(
    personal.PersonalMediaQuery query,
  ) async {
    return _getItems(
      query: query,
      isFavorite: true,
      sortBy: const [jellyfin_dart.ItemSortBy.sortName],
      sortOrder: const [jellyfin_dart.SortOrder.ascending],
    );
  }

  @override
  Future<models.MediaItemListResult> getHistory(
    personal.PersonalMediaQuery query,
  ) async {
    return _getItems(
      query: query,
      isPlayed: true,
      sortBy: const [jellyfin_dart.ItemSortBy.datePlayed],
      sortOrder: const [jellyfin_dart.SortOrder.descending],
    );
  }

  @override
  Future<void> setFavorite({
    required String itemId,
    required bool isFavorite,
  }) async {
    _requireClient();
    final client = _client!;
    final api = client.jellyfinClient.getUserLibraryApi();
    if (isFavorite) {
      await api.markFavoriteItem(itemId: itemId, userId: client.config.userId);
    } else {
      await api.unmarkFavoriteItem(
        itemId: itemId,
        userId: client.config.userId,
      );
    }
  }

  @override
  Future<void> setPlayed({
    required String itemId,
    required bool isPlayed,
  }) async {
    _requireClient();
    final client = _client!;
    final api = client.jellyfinClient.getPlaystateApi();
    if (isPlayed) {
      await api.markPlayedItem(itemId: itemId, userId: client.config.userId);
    } else {
      await api.markUnplayedItem(itemId: itemId, userId: client.config.userId);
    }
  }

  @override
  Future<personal.PersonalStats> getStats(
    personal.PersonalMediaQuery query,
  ) async {
    _requireClient();
    final client = _client!;

    final breakdownFutures = query.mediaKinds.map((kind) async {
      final kinds = _mapKinds([kind]);
      final results = await Future.wait([
        client.jellyfinClient.getItemsApi().getItems(
              userId: client.config.userId,
              limit: 1,
              recursive: true,
              includeItemTypes: kinds,
              isPlayed: true,
              enableUserData: false,
              enableImages: false,
            ),
        client.jellyfinClient.getItemsApi().getItems(
              userId: client.config.userId,
              limit: 1,
              recursive: true,
              includeItemTypes: kinds,
              isFavorite: true,
              enableUserData: false,
              enableImages: false,
            ),
      ]);
      return personal.MediaTypeCount(
        kind: kind,
        watchedCount: results[0].data?.totalRecordCount ?? 0,
        favoriteCount: results[1].data?.totalRecordCount ?? 0,
      );
    });

    final resumeFuture = client.jellyfinClient.getItemsApi().getResumeItems(
          userId: client.config.userId,
          limit: 1,
          includeItemTypes: _mapKinds(query.mediaKinds),
          enableUserData: false,
          enableImages: false,
        );

    final results = await Future.wait([
      ...breakdownFutures,
      resumeFuture,
    ]);

    final breakdown = results
        .sublist(0, query.mediaKinds.length)
        .cast<personal.MediaTypeCount>();
    final resumeResult = results.last as dynamic;
    final continueWatchingCount =
        (resumeResult as jellyfin_dart.BaseItemDtoQueryResult?)
                ?.totalRecordCount ??
            0;

    return personal.PersonalStats(
      totalWatched: breakdown.fold<int>(0, (sum, b) => sum + b.watchedCount),
      totalFavorites:
          breakdown.fold<int>(0, (sum, b) => sum + b.favoriteCount),
      continueWatchingCount: continueWatchingCount,
      breakdown: breakdown,
    );
  }

  Future<models.MediaItemListResult> _getItems({
    required personal.PersonalMediaQuery query,
    bool? isFavorite,
    bool? isPlayed,
    List<jellyfin_dart.ItemSortBy>? sortBy,
    List<jellyfin_dart.SortOrder>? sortOrder,
  }) async {
    _requireClient();
    final client = _client!;
    final response = await client.jellyfinClient.getItemsApi().getItems(
      userId: client.config.userId,
      startIndex: query.startIndex,
      limit: query.limit,
      recursive: true,
      includeItemTypes: _mapKinds(query.mediaKinds),
      isFavorite: isFavorite,
      isPlayed: isPlayed,
      sortBy: sortBy,
      sortOrder: sortOrder,
      enableUserData: true,
      enableImages: true,
      imageTypeLimit: 3,
      enableImageTypes: const [
        jellyfin_dart.ImageType.primary,
        jellyfin_dart.ImageType.backdrop,
        jellyfin_dart.ImageType.thumb,
      ],
      fields: const [
        jellyfin_dart.ItemFields.overview,
        jellyfin_dart.ItemFields.people,
        jellyfin_dart.ItemFields.studios,
        jellyfin_dart.ItemFields.genres,
      ],
    );
    return _mapResult(response.data, client.config.serverUrl);
  }

  models.MediaItemListResult _mapResult(
    jellyfin_dart.BaseItemDtoQueryResult? result,
    String serverUrl,
  ) {
    final items = result?.items ?? const <jellyfin_dart.BaseItemDto>[];
    return models.MediaItemListResult(
      items: items
          .map((dto) => LegacyJellyfinGateway.mapMediaItem(dto, serverUrl))
          .toList(),
      totalCount: result?.totalRecordCount,
      startIndex: result?.startIndex,
    );
  }

  List<jellyfin_dart.BaseItemKind> _mapKinds(
    List<personal.PersonalMediaKind> kinds,
  ) {
    return [
      for (final kind in kinds)
        switch (kind) {
          personal.PersonalMediaKind.movie => jellyfin_dart.BaseItemKind.movie,
          personal.PersonalMediaKind.series =>
            jellyfin_dart.BaseItemKind.series,
          personal.PersonalMediaKind.episode =>
            jellyfin_dart.BaseItemKind.episode,
          personal.PersonalMediaKind.audio => jellyfin_dart.BaseItemKind.audio,
          personal.PersonalMediaKind.musicAlbum =>
            jellyfin_dart.BaseItemKind.musicAlbum,
          personal.PersonalMediaKind.musicArtist =>
            jellyfin_dart.BaseItemKind.musicArtist,
        },
    ];
  }
}
