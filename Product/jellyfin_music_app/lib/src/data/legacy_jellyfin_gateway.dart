import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_music/jellyfin_music.dart' as music;

import 'jellyfin_gateway.dart';
import '../session/app_session.dart';

/// 基于 jellyfin_api 的 Gateway 实现（音乐 App 精简版）
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

  // ─── 音乐 ───

  @override
  Future<music.MusicAlbumListResult> fetchAlbums({
    required String parentId,
    int? startIndex,
    int? limit,
    String? sortBy,
  }) async {
    _requireClient();
    final config = _apiClient!.config;

    final response = await _apiClient!.jellyfinClient.getItemsApi().getItems(
      userId: config.userId,
      parentId: parentId,
      includeItemTypes: [jellyfin_dart.BaseItemKind.musicAlbum],
      recursive: true,
      startIndex: startIndex,
      limit: limit,
      sortBy: [jellyfin_dart.ItemSortBy.sortName],
    );

    final items = response.data?.items ?? [];
    return music.MusicAlbumListResult(
      albums: items
          .map((dto) => _mapMusicAlbum(dto, config.serverUrl))
          .toList(),
      totalCount: response.data?.totalRecordCount,
      startIndex: startIndex,
    );
  }

  @override
  Future<music.MusicArtistListResult> fetchArtists({
    required String parentId,
    int? startIndex,
    int? limit,
  }) async {
    _requireClient();
    final config = _apiClient!.config;

    final response = await _apiClient!.jellyfinClient.getItemsApi().getItems(
      userId: config.userId,
      parentId: parentId,
      includeItemTypes: [jellyfin_dart.BaseItemKind.musicArtist],
      recursive: true,
      startIndex: startIndex,
      limit: limit,
      sortBy: [jellyfin_dart.ItemSortBy.sortName],
    );

    final items = response.data?.items ?? [];
    return music.MusicArtistListResult(
      artists: items
          .map((dto) => _mapMusicArtist(dto, config.serverUrl))
          .toList(),
      totalCount: response.data?.totalRecordCount,
      startIndex: startIndex,
    );
  }

  @override
  Future<music.MusicSongListResult> fetchSongs({
    required String parentId,
    int? startIndex,
    int? limit,
  }) async {
    _requireClient();
    final config = _apiClient!.config;

    final response = await _apiClient!.jellyfinClient.getItemsApi().getItems(
      userId: config.userId,
      parentId: parentId,
      includeItemTypes: [jellyfin_dart.BaseItemKind.audio],
      recursive: true,
      startIndex: startIndex,
      limit: limit,
      sortBy: [jellyfin_dart.ItemSortBy.sortName],
    );

    final items = response.data?.items ?? [];
    return music.MusicSongListResult(
      songs: items
          .map(
            (dto) => _mapMusicSong(dto, config.serverUrl, config.accessToken),
          )
          .toList(),
      totalCount: response.data?.totalRecordCount,
      startIndex: startIndex,
    );
  }

  @override
  Future<music.MusicAlbum> getAlbumDetail(String albumId) async {
    _requireClient();
    final config = _apiClient!.config;

    final response = await _apiClient!.jellyfinClient.getItemsApi().getItems(
      userId: config.userId,
      ids: [albumId],
      fields: [
        jellyfin_dart.ItemFields.overview,
        jellyfin_dart.ItemFields.genres,
      ],
    );

    final items = response.data?.items ?? [];
    if (items.isEmpty) {
      throw StateError('找不到专辑: $albumId');
    }
    return _mapMusicAlbum(items.first, config.serverUrl);
  }

  @override
  Future<music.MusicSongListResult> getAlbumSongs(String albumId) async {
    _requireClient();
    final config = _apiClient!.config;

    final response = await _apiClient!.jellyfinClient.getItemsApi().getItems(
      userId: config.userId,
      parentId: albumId,
      includeItemTypes: [jellyfin_dart.BaseItemKind.audio],
      sortBy: [jellyfin_dart.ItemSortBy.sortName],
    );

    final items = response.data?.items ?? [];
    return music.MusicSongListResult(
      songs: items
          .map(
            (dto) => _mapMusicSong(dto, config.serverUrl, config.accessToken),
          )
          .toList(),
      totalCount: response.data?.totalRecordCount,
    );
  }

  @override
  Future<music.MusicArtist> getArtistDetail(String artistId) async {
    _requireClient();
    final config = _apiClient!.config;

    final response = await _apiClient!.jellyfinClient.getItemsApi().getItems(
      userId: config.userId,
      ids: [artistId],
      fields: [
        jellyfin_dart.ItemFields.overview,
        jellyfin_dart.ItemFields.genres,
      ],
    );

    final items = response.data?.items ?? [];
    if (items.isEmpty) {
      throw StateError('找不到艺术家: $artistId');
    }
    return _mapMusicArtist(items.first, config.serverUrl);
  }

  @override
  Future<music.MusicAlbumListResult> getArtistAlbums(String artistId) async {
    _requireClient();
    final config = _apiClient!.config;

    final response = await _apiClient!.jellyfinClient.getItemsApi().getItems(
      userId: config.userId,
      albumArtistIds: [artistId],
      includeItemTypes: [jellyfin_dart.BaseItemKind.musicAlbum],
      recursive: true,
      sortBy: [jellyfin_dart.ItemSortBy.sortName],
    );

    final items = response.data?.items ?? [];
    return music.MusicAlbumListResult(
      albums: items
          .map((dto) => _mapMusicAlbum(dto, config.serverUrl))
          .toList(),
      totalCount: response.data?.totalRecordCount,
    );
  }

  @override
  Future<music.MusicSearchResult> searchMusic({
    required String searchTerm,
    String? parentId,
    int? limit,
  }) async {
    _requireClient();
    final config = _apiClient!.config;
    final effectiveLimit = limit ?? 20;

    // 并行搜索艺术家、专辑、歌曲
    final results = await Future.wait([
      _apiClient!.jellyfinClient.getItemsApi().getItems(
        userId: config.userId,
        parentId: parentId,
        includeItemTypes: [jellyfin_dart.BaseItemKind.musicArtist],
        searchTerm: searchTerm,
        recursive: true,
        limit: effectiveLimit,
      ),
      _apiClient!.jellyfinClient.getItemsApi().getItems(
        userId: config.userId,
        parentId: parentId,
        includeItemTypes: [jellyfin_dart.BaseItemKind.musicAlbum],
        searchTerm: searchTerm,
        recursive: true,
        limit: effectiveLimit,
      ),
      _apiClient!.jellyfinClient.getItemsApi().getItems(
        userId: config.userId,
        parentId: parentId,
        includeItemTypes: [jellyfin_dart.BaseItemKind.audio],
        searchTerm: searchTerm,
        recursive: true,
        limit: (limit ?? 50),
      ),
    ]);

    final artists = (results[0].data?.items ?? [])
        .map((dto) => _mapMusicArtist(dto, config.serverUrl))
        .toList();
    final albums = (results[1].data?.items ?? [])
        .map((dto) => _mapMusicAlbum(dto, config.serverUrl))
        .toList();
    final songs = (results[2].data?.items ?? [])
        .map((dto) => _mapMusicSong(dto, config.serverUrl, config.accessToken))
        .toList();

    return music.MusicSearchResult(
      artists: artists,
      albums: albums,
      songs: songs,
    );
  }

  @override
  Future<music.LyricsData?> getLyrics(String itemId) async {
    _requireClient();

    try {
      final response = await _apiClient!.jellyfinClient
          .getLyricsApi()
          .getLyrics(itemId: itemId);
      final dto = response.data;
      if (dto == null) return null;
      return _mapLyricsData(dto);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<music.RemoteLyricsInfo>> searchRemoteLyrics(
    String itemId,
  ) async {
    _requireClient();

    final response = await _apiClient!.jellyfinClient
        .getLyricsApi()
        .searchRemoteLyrics(itemId: itemId);
    final items = response.data ?? [];
    return items.map(_mapRemoteLyricsInfo).toList();
  }

  @override
  Future<music.LyricsData> downloadRemoteLyrics({
    required String itemId,
    required String lyricId,
  }) async {
    _requireClient();

    final response = await _apiClient!.jellyfinClient
        .getLyricsApi()
        .downloadRemoteLyrics(itemId: itemId, lyricId: lyricId);
    final dto = response.data;
    if (dto == null) throw StateError('下载歌词失败');
    return _mapLyricsData(dto);
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

  /// BaseItemDto → MusicAlbum
  static music.MusicAlbum _mapMusicAlbum(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl,
  ) {
    final imageTags = dto.imageTags;
    final primaryImageTag = imageTags?['Primary'];
    final hasImageTag = primaryImageTag != null && primaryImageTag.isNotEmpty;

    final artists = dto.albumArtist != null
        ? [dto.albumArtist!]
        : dto.albumArtists?.map((a) => a.name ?? '').toList();

    return music.MusicAlbum(
      id: dto.id ?? '',
      name: dto.name ?? '未知专辑',
      serverUrl: serverUrl,
      productionYear: dto.productionYear,
      artists: artists,
      genres: dto.genres,
      songCount: dto.childCount,
      communityRating: dto.communityRating,
      overview: dto.overview,
      primaryImageTag: hasImageTag ? primaryImageTag : null,
      backdropImageTag: dto.backdropImageTags?.firstOrNull,
      parentId: dto.parentId,
    );
  }

  /// BaseItemDto → MusicArtist
  static music.MusicArtist _mapMusicArtist(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl,
  ) {
    final imageTags = dto.imageTags;
    final primaryImageTag = imageTags?['Primary'];
    final hasImageTag = primaryImageTag != null && primaryImageTag.isNotEmpty;

    return music.MusicArtist(
      id: dto.id ?? '',
      name: dto.name ?? '未知艺术家',
      serverUrl: serverUrl,
      albumCount: dto.childCount,
      overview: dto.overview,
      genres: dto.genres,
      communityRating: dto.communityRating,
      primaryImageTag: hasImageTag ? primaryImageTag : null,
      backdropImageTag: dto.backdropImageTags?.firstOrNull,
    );
  }

  /// BaseItemDto → MusicSong
  static music.MusicSong _mapMusicSong(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl,
    String? accessToken,
  ) {
    final artists = <String>[];
    final artistRefs = <music.ArtistRef>[];
    for (final artist in (dto.artistItems ?? [])) {
      artists.add(artist.name ?? '');
      artistRefs.add(
        music.ArtistRef(id: artist.id ?? '', name: artist.name ?? ''),
      );
    }

    String? albumId;
    String? albumName;
    String? albumPrimaryImageTag;
    if (dto.album != null) {
      albumId = dto.albumId;
      albumName = dto.album;
    }
    if (dto.albumPrimaryImageTag != null) {
      albumPrimaryImageTag = dto.albumPrimaryImageTag;
    }

    final runTimeTicks = dto.runTimeTicks;
    final runTimeSeconds = runTimeTicks != null
        ? (runTimeTicks / 10000000).round()
        : null;

    return music.MusicSong(
      id: dto.id ?? '',
      name: dto.name ?? '未知歌曲',
      serverUrl: serverUrl,
      albumId: albumId,
      albumName: albumName,
      albumPrimaryImageTag: albumPrimaryImageTag,
      artists: artists.isNotEmpty ? artists : null,
      artistRefs: artistRefs.isNotEmpty ? artistRefs : null,
      trackNumber: dto.indexNumber,
      runTimeTicks: runTimeTicks,
      runTimeSeconds: runTimeSeconds,
      genres: dto.genres,
      communityRating: dto.communityRating,
      parentId: dto.parentId,
      isFavorite: dto.userData?.isFavorite,
      played: dto.userData?.played,
      playCount: dto.userData?.playCount,
      accessToken: accessToken,
      path: dto.path,
    );
  }

  // ─── 歌词 DTO 映射 ───

  static music.LyricsData _mapLyricsData(jellyfin_dart.LyricDto dto) {
    return music.LyricsData(
      metadata:
          dto.metadata != null ? _mapLyricsMetadata(dto.metadata!) : null,
      lines: dto.lyrics?.map(_mapLyricsLine).toList() ?? [],
    );
  }

  static music.LyricsMetadata _mapLyricsMetadata(
    jellyfin_dart.LyricMetadata dto,
  ) {
    return music.LyricsMetadata(
      isSynced: dto.isSynced,
      artist: dto.artist,
      album: dto.album,
      title: dto.title,
      lengthTicks: dto.length,
      offsetTicks: dto.offset,
    );
  }

  static music.LyricsLine _mapLyricsLine(jellyfin_dart.LyricLine dto) {
    return music.LyricsLine(text: dto.text, startTicks: dto.start);
  }

  static music.RemoteLyricsInfo _mapRemoteLyricsInfo(
    jellyfin_dart.RemoteLyricInfoDto dto,
  ) {
    return music.RemoteLyricsInfo(
      id: dto.id,
      providerName: dto.providerName,
      lyrics: dto.lyrics != null ? _mapLyricsData(dto.lyrics!) : null,
    );
  }
}
