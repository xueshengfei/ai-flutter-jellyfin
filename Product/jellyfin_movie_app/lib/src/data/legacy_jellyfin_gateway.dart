import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;

import 'jellyfin_gateway.dart';
import '../session/app_session.dart';

/// 基于 jellyfin_api 的 Gateway 实现（电影 App 精简版）
class LegacyJellyfinGateway implements JellyfinGateway {
  ApiClient? _apiClient;

  /// 获取当前已认证的 client
  ApiClient? get apiClient => _apiClient;

  @override
  Future<AppSession> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final config = JellyfinConfiguration(
      serverUrl: serverUrl,
      enableLogging: false,
    );
    final client = ApiClient(config);

    final response = await client.jellyfinClient
        .getUserApi()
        .authenticateUserByName(
          authenticateUserByName: jellyfin_dart.AuthenticateUserByName(
            username: username,
            pw: password,
          ),
        );

    final data = response.data!;
    config.accessToken = data.accessToken;
    config.userId = data.user?.id;
    client.updateAccessToken(data.accessToken);

    _apiClient = client;

    return AppSession(
      serverUrl: serverUrl,
      accessToken: data.accessToken!,
      userId: data.user?.id ?? '',
      username: data.user?.name ?? '',
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
    final config = JellyfinConfiguration(
      serverUrl: serverUrl,
      enableLogging: false,
    );
    final adminClient = ApiClient(config);

    final authResponse = await adminClient.jellyfinClient
        .getUserApi()
        .authenticateUserByName(
          authenticateUserByName: jellyfin_dart.AuthenticateUserByName(
            username: adminUsername,
            pw: adminPassword,
          ),
        );
    config.accessToken = authResponse.data!.accessToken;
    adminClient.updateAccessToken(authResponse.data!.accessToken);

    await adminClient.jellyfinClient.getUserApi().createUserByName(
      createUserByName: jellyfin_dart.CreateUserByName(
        name: username,
        password: password,
      ),
    );
  }

  @override
  Future<void> logout() async {
    _apiClient?.config.clearAuth();
    _apiClient = null;
  }

  @override
  Future<List<models.MediaLibrary>> getMediaLibraries() async {
    _requireClient();
    final config = _apiClient!.config;

    final response = await _apiClient!.jellyfinClient
        .getUserViewsApi()
        .getUserViews(userId: config.userId);

    final items = response.data?.items ?? [];
    return items.map((dto) => _mapLibrary(dto, config.serverUrl)).toList();
  }

  @override
  Future<movies.MovieFilterResult> fetchMovies(
    movies.MovieFilter filter,
  ) async {
    _requireClient();
    final config = _apiClient!.config;

    final sortBy = <jellyfin_dart.ItemSortBy>[];
    for (final field in (filter.sortBy ?? <movies.MovieSortField>[])) {
      sortBy.add(_mapSortField(field));
    }

    final sortOrder = <jellyfin_dart.SortOrder>[];
    for (final order in (filter.sortOrder ?? <movies.MovieSortOrder>[])) {
      sortOrder.add(_mapSortOrder(order));
    }

    final response = await _apiClient!.jellyfinClient.getItemsApi().getItems(
      userId: config.userId,
      parentId: filter.parentId,
      startIndex: filter.startIndex,
      limit: filter.limit,
      includeItemTypes: [jellyfin_dart.BaseItemKind.movie],
      sortBy: sortBy.isNotEmpty ? sortBy : null,
      sortOrder: sortOrder.isNotEmpty ? sortOrder : null,
      recursive: filter.recursive,
      genres: filter.genres,
      years: filter.years,
      nameStartsWith: filter.nameStartsWith,
      searchTerm: filter.searchTerm,
      isPlayed: filter.isPlayed,
      isFavorite: filter.isFavorite,
      fields: [
        jellyfin_dart.ItemFields.overview,
        jellyfin_dart.ItemFields.people,
        jellyfin_dart.ItemFields.studios,
        jellyfin_dart.ItemFields.genres,
      ],
    );

    final items = response.data?.items ?? [];
    return movies.MovieFilterResult(
      movies: items.map((dto) => mapMediaItem(dto, config.serverUrl)).toList(),
      totalCount: response.data?.totalRecordCount,
      startIndex: filter.startIndex,
    );
  }

  @override
  Future<models.MediaItem> getMediaItemDetail(String itemId) async {
    _requireClient();
    final config = _apiClient!.config;

    final response = await _apiClient!.jellyfinClient.getItemsApi().getItems(
      userId: config.userId,
      ids: [itemId],
      fields: [
        jellyfin_dart.ItemFields.overview,
        jellyfin_dart.ItemFields.people,
        jellyfin_dart.ItemFields.studios,
        jellyfin_dart.ItemFields.genres,
      ],
    );

    final items = response.data?.items ?? [];
    if (items.isEmpty) {
      throw StateError('找不到媒体项: $itemId');
    }
    return mapMediaItem(items.first, config.serverUrl);
  }

  void _requireClient() {
    if (_apiClient == null) {
      throw StateError('未登录，请先调用 login()');
    }
  }

  // ─── DTO → 共享模型映射 ───

  static models.MediaLibrary _mapLibrary(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl,
  ) {
    final imageTags = dto.imageTags;
    final primaryImageTag = imageTags?['Primary'];
    final hasImageTag = primaryImageTag != null && primaryImageTag.isNotEmpty;
    final hasBlurHash = dto.imageBlurHashes != null;
    final hasImage = hasImageTag || hasBlurHash;

    return models.MediaLibrary(
      id: dto.id ?? '',
      name: dto.name ?? '未知媒体库',
      type: _mapLibraryType(dto.collectionType),
      serverUrl: serverUrl,
      primaryImageTag: hasImageTag
          ? primaryImageTag
          : (hasImage ? 'has_image' : null),
      itemCount: dto.childCount,
    );
  }

  static models.MediaLibraryType _mapLibraryType(
    jellyfin_dart.CollectionType? collectionType,
  ) {
    if (collectionType == null) return models.MediaLibraryType.unknown;
    switch (collectionType) {
      case jellyfin_dart.CollectionType.movies:
        return models.MediaLibraryType.movies;
      case jellyfin_dart.CollectionType.tvshows:
        return models.MediaLibraryType.tvshows;
      case jellyfin_dart.CollectionType.music:
        return models.MediaLibraryType.music;
      default:
        return models.MediaLibraryType.unknown;
    }
  }

  static models.MediaItem mapMediaItem(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl,
  ) {
    final imageTags = dto.imageTags;
    final primaryImageTag = imageTags?['Primary'];
    final hasImageTag = primaryImageTag != null && primaryImageTag.isNotEmpty;
    final hasBlurHash = dto.imageBlurHashes != null;
    final hasImage = hasImageTag || hasBlurHash;

    final runTimeMinutes = dto.runTimeTicks != null
        ? (dto.runTimeTicks! / 600000000).round()
        : null;

    final studios = dto.studios?.map((s) => s.name ?? '').toList();

    final directors = <String>[];
    final actors = <String>[];
    final actorInfos = <models.ActorInfo>[];

    for (final person in (dto.people ?? [])) {
      if (person.name == null) continue;

      final personImageTag = person.primaryImageTag;
      String? personImageUrl;
      if (personImageTag != null && personImageTag.isNotEmpty) {
        personImageUrl =
            '$serverUrl/Items/${person.id}/Images/Primary?tag=$personImageTag';
      }

      if (person.type == jellyfin_dart.PersonKind.director) {
        directors.add(person.name!);
      } else if (person.type == jellyfin_dart.PersonKind.actor) {
        actors.add(person.name!);
        actorInfos.add(
          models.ActorInfo(
            name: person.name!,
            role: person.role,
            imageUrl: personImageUrl,
            id: person.id,
          ),
        );
      }
    }

    final backdropImageTags = dto.backdropImageTags;
    final backdropTag =
        dto.imageTags?['Backdrop'] ??
        (backdropImageTags != null && backdropImageTags.isNotEmpty
            ? backdropImageTags.first
            : null);

    final thumbImageTag = imageTags?['Thumb'];
    final hasThumbTag = thumbImageTag != null && thumbImageTag.isNotEmpty;

    return models.MediaItem(
      id: dto.id ?? '',
      name: dto.name ?? '未知媒体',
      type: dto.type?.name ?? 'unknown',
      serverUrl: serverUrl,
      primaryImageTag: hasImageTag
          ? primaryImageTag
          : (hasImage ? 'has_image' : null),
      backdropImageTag: backdropTag,
      thumbImageTag: hasThumbTag ? thumbImageTag : null,
      productionYear: dto.productionYear,
      genres: dto.genres,
      communityRating: dto.communityRating,
      officialRating: dto.officialRating,
      runTimeTicks: dto.runTimeTicks,
      runTimeMinutes: runTimeMinutes,
      overview: dto.overview,
      studios: studios,
      directors: directors,
      actors: actors,
      actorInfos: actorInfos.isNotEmpty ? actorInfos : null,
      parentId: dto.parentId,
      isFavorite: dto.userData?.isFavorite,
      played: dto.userData?.played,
      playedPercentage: dto.userData?.playedPercentage,
    );
  }

  static jellyfin_dart.ItemSortBy _mapSortField(movies.MovieSortField field) {
    switch (field) {
      case movies.MovieSortField.dateCreated:
        return jellyfin_dart.ItemSortBy.dateCreated;
      case movies.MovieSortField.sortName:
        return jellyfin_dart.ItemSortBy.sortName;
      case movies.MovieSortField.productionYear:
        return jellyfin_dart.ItemSortBy.productionYear;
      case movies.MovieSortField.premiereDate:
        return jellyfin_dart.ItemSortBy.premiereDate;
      case movies.MovieSortField.random:
        return jellyfin_dart.ItemSortBy.random;
      case movies.MovieSortField.communityRating:
        return jellyfin_dart.ItemSortBy.communityRating;
    }
  }

  static jellyfin_dart.SortOrder _mapSortOrder(movies.MovieSortOrder order) {
    switch (order) {
      case movies.MovieSortOrder.ascending:
        return jellyfin_dart.SortOrder.ascending;
      case movies.MovieSortOrder.descending:
        return jellyfin_dart.SortOrder.descending;
    }
  }
}
