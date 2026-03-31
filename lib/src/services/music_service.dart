import 'package:logger/logger.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import '../core/api_client.dart';
import '../exceptions/api_exception.dart';
import '../models/music_models.dart';

/// 音乐服务
///
/// 提供音乐相关功能：
/// - 浏览专辑、艺术家、歌曲
/// - 获取专辑/艺术家详情
/// - 获取音频流URL
/// - 音乐类型筛选
class MusicService {
  final ApiClient _apiClient;
  final Logger _logger;

  MusicService({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  String? get _userId => _apiClient.config.userId;
  String get _serverUrl => _apiClient.config.serverUrl;
  String? get _accessToken => _apiClient.config.accessToken;

  // ==================== 专辑 ====================

  /// 获取专辑列表
  ///
  /// [parentId] 媒体库ID（可选，不传则搜索所有库）
  /// [startIndex] 分页起始索引
  /// [limit] 返回数量限制
  /// [searchTerm] 搜索关键词
  /// [genres] 按类型筛选
  /// [sortBy] 排序字段
  /// [sortOrder] 排序方向
  Future<MusicAlbumListResult> getAlbums({
    String? parentId,
    int? startIndex = 0,
    int? limit = 50,
    String? searchTerm,
    List<String>? genres,
    List<String>? artistIds,
    List<jellyfin_dart.ItemSortBy>? sortBy,
    List<jellyfin_dart.SortOrder>? sortOrder,
  }) async {
    _logger.i('Fetching music albums');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
        searchTerm: searchTerm,
        genres: genres,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.musicAlbum],
        recursive: true,
        sortBy: sortBy ?? const [jellyfin_dart.ItemSortBy.sortName],
        sortOrder: sortOrder ?? const [jellyfin_dart.SortOrder.ascending],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.overview,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
        ],
        enableImages: true,
        enableUserData: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get albums: No response data', statusCode: response.statusCode);
      }

      _logger.i('Fetched ${response.data!.items?.length ?? 0} albums');

      return MusicAlbumListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch albums', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch albums: $e', cause: e, stackTrace: stackTrace);
    }
  }

  /// 获取专辑详情
  Future<MusicAlbum> getAlbumDetail(String albumId) async {
    _logger.i('Fetching album detail: $albumId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        ids: [albumId],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.overview,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
        ],
      );

      if (response.data == null || response.data!.items == null || response.data!.items!.isEmpty) {
        throw ApiException('Album not found: $albumId', statusCode: 404);
      }

      return MusicAlbum.fromDto(
        response.data!.items![0],
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch album detail', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch album detail: $e', cause: e, stackTrace: stackTrace);
    }
  }

  /// 获取专辑中的歌曲
  Future<MusicSongListResult> getAlbumSongs(
    String albumId, {
    int? startIndex = 0,
    int? limit = 200,
  }) async {
    _logger.i('Fetching songs for album: $albumId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        parentId: albumId,
        startIndex: startIndex,
        limit: limit,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.audio],
        sortBy: const [jellyfin_dart.ItemSortBy.sortName],
        sortOrder: const [jellyfin_dart.SortOrder.ascending],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
        ],
        enableImages: true,
        enableUserData: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get album songs: No response data', statusCode: response.statusCode);
      }

      _logger.i('Fetched ${response.data!.items?.length ?? 0} songs from album');

      return MusicSongListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch album songs', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch album songs: $e', cause: e, stackTrace: stackTrace);
    }
  }

  // ==================== 艺术家 ====================

  /// 获取艺术家列表（专辑艺术家）
  Future<MusicArtistListResult> getAlbumArtists({
    String? parentId,
    int? startIndex = 0,
    int? limit = 50,
    String? searchTerm,
    List<String>? genres,
    List<jellyfin_dart.ItemSortBy>? sortBy,
    List<jellyfin_dart.SortOrder>? sortOrder,
  }) async {
    _logger.i('Fetching album artists');

    try {
      final artistsApi = _apiClient.jellyfinClient.getArtistsApi();

      final response = await artistsApi.getAlbumArtists(
        userId: _userId,
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
        searchTerm: searchTerm,
        genres: genres,
        sortBy: sortBy ?? const [jellyfin_dart.ItemSortBy.sortName],
        sortOrder: sortOrder ?? const [jellyfin_dart.SortOrder.ascending],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.overview,
        ],
        enableImages: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get artists: No response data', statusCode: response.statusCode);
      }

      _logger.i('Fetched ${response.data!.items?.length ?? 0} artists');

      return MusicArtistListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch artists', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch artists: $e', cause: e, stackTrace: stackTrace);
    }
  }

  /// 获取所有艺术家
  Future<MusicArtistListResult> getArtists({
    String? parentId,
    int? startIndex = 0,
    int? limit = 50,
    String? searchTerm,
  }) async {
    _logger.i('Fetching all artists');

    try {
      final artistsApi = _apiClient.jellyfinClient.getArtistsApi();

      final response = await artistsApi.getArtists(
        userId: _userId,
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
        searchTerm: searchTerm,
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.overview,
        ],
        enableImages: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get artists: No response data', statusCode: response.statusCode);
      }

      return MusicArtistListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch artists', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch artists: $e', cause: e, stackTrace: stackTrace);
    }
  }

  /// 获取艺术家详情
  Future<MusicArtist> getArtistDetail(String artistId) async {
    _logger.i('Fetching artist detail: $artistId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        ids: [artistId],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.overview,
        ],
      );

      if (response.data == null || response.data!.items == null || response.data!.items!.isEmpty) {
        throw ApiException('Artist not found: $artistId', statusCode: 404);
      }

      return MusicArtist.fromDto(
        response.data!.items![0],
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch artist detail', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch artist detail: $e', cause: e, stackTrace: stackTrace);
    }
  }

  /// 获取艺术家的专辑
  Future<MusicAlbumListResult> getArtistAlbums(
    String artistId, {
    int? startIndex = 0,
    int? limit = 50,
    List<jellyfin_dart.ItemSortBy>? sortBy,
    List<jellyfin_dart.SortOrder>? sortOrder,
  }) async {
    _logger.i('Fetching albums for artist: $artistId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        albumArtistIds: [artistId],
        startIndex: startIndex,
        limit: limit,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.musicAlbum],
        recursive: true,
        sortBy: sortBy ?? const [jellyfin_dart.ItemSortBy.premiereDate, jellyfin_dart.ItemSortBy.productionYear],
        sortOrder: sortOrder ?? const [jellyfin_dart.SortOrder.descending],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
        ],
        enableImages: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get artist albums: No response data', statusCode: response.statusCode);
      }

      _logger.i('Fetched ${response.data!.items?.length ?? 0} albums for artist');

      return MusicAlbumListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch artist albums', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch artist albums: $e', cause: e, stackTrace: stackTrace);
    }
  }

  /// 获取艺术家的歌曲
  Future<MusicSongListResult> getArtistSongs(
    String artistId, {
    int? startIndex = 0,
    int? limit = 100,
    List<jellyfin_dart.ItemSortBy>? sortBy,
    List<jellyfin_dart.SortOrder>? sortOrder,
  }) async {
    _logger.i('Fetching songs for artist: $artistId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        artistIds: [artistId],
        startIndex: startIndex,
        limit: limit,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.audio],
        recursive: true,
        sortBy: sortBy ?? const [jellyfin_dart.ItemSortBy.sortName],
        sortOrder: sortOrder ?? const [jellyfin_dart.SortOrder.ascending],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
        ],
        enableImages: true,
        enableUserData: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get artist songs: No response data', statusCode: response.statusCode);
      }

      _logger.i('Fetched ${response.data!.items?.length ?? 0} songs for artist');

      return MusicSongListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch artist songs', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch artist songs: $e', cause: e, stackTrace: stackTrace);
    }
  }

  // ==================== 歌曲 ====================

  /// 获取歌曲列表（最新添加）
  Future<MusicSongListResult> getLatestSongs({
    String? parentId,
    int? limit = 50,
  }) async {
    _logger.i('Fetching latest songs');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        parentId: parentId,
        limit: limit,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.audio],
        recursive: true,
        sortBy: const [jellyfin_dart.ItemSortBy.dateCreated],
        sortOrder: const [jellyfin_dart.SortOrder.descending],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
        ],
        enableImages: true,
        enableUserData: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get songs: No response data', statusCode: response.statusCode);
      }

      return MusicSongListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch songs', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch songs: $e', cause: e, stackTrace: stackTrace);
    }
  }

  /// 获取常播放的歌曲
  Future<MusicSongListResult> getFrequentlyPlayedSongs({
    String? parentId,
    int? limit = 50,
  }) async {
    _logger.i('Fetching frequently played songs');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        parentId: parentId,
        limit: limit,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.audio],
        recursive: true,
        sortBy: const [jellyfin_dart.ItemSortBy.playCount],
        sortOrder: const [jellyfin_dart.SortOrder.descending],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
        ],
        enableImages: true,
        enableUserData: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get songs: No response data', statusCode: response.statusCode);
      }

      return MusicSongListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch songs', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch songs: $e', cause: e, stackTrace: stackTrace);
    }
  }

  // ==================== 音频流 ====================

  /// 获取音频流URL
  ///
  /// 返回可直接播放的音频URL
  String getAudioStreamUrl(
    String songId, {
    String? container,
    int? audioBitRate,
    int? startTimeTicks,
  }) {
    var url = '$_serverUrl/Audio/$songId/stream';
    if (container != null) url += '.$container';
    url += '?UserId=$_userId';
    if (_accessToken != null) url += '&api_key=$_accessToken';
    if (audioBitRate != null) url += '&audioBitRate=$audioBitRate';
    if (startTimeTicks != null) url += '&startTimeTicks=$startTimeTicks';
    return url;
  }

  /// 获取通用音频流URL（推荐，兼容性更好）
  String getUniversalAudioStreamUrl(
    String songId, {
    List<String>? container,
    String? audioCodec,
    int? audioBitRate,
    int? startTimeTicks,
  }) {
    var url = '$_serverUrl/Audio/$songId/universal';
    url += '?UserId=$_userId';
    if (_accessToken != null) url += '&api_key=$_accessToken';
    if (container != null && container.isNotEmpty) url += '&container=${container.join(',')}';
    if (audioCodec != null) url += '&audioCodec=$audioCodec';
    if (audioBitRate != null) url += '&audioBitRate=$audioBitRate';
    if (startTimeTicks != null) url += '&startTimeTicks=$startTimeTicks';
    return url;
  }

  // ==================== 音乐类型 ====================

  /// 获取音乐类型列表
  Future<List<MusicGenre>> getMusicGenres({
    String? parentId,
    int? startIndex = 0,
    int? limit = 100,
  }) async {
    _logger.i('Fetching music genres');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.musicGenre],
        recursive: true,
        sortBy: const [jellyfin_dart.ItemSortBy.sortName],
        sortOrder: const [jellyfin_dart.SortOrder.ascending],
      );

      if (response.data == null) {
        return [];
      }

      final items = response.data!.items ?? [];
      return items.map((item) => MusicGenre.fromDto(item, _serverUrl)).toList();
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch music genres', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch music genres: $e', cause: e, stackTrace: stackTrace);
    }
  }

  // ==================== 搜索 ====================

  /// 搜索音乐
  Future<MusicSongListResult> searchSongs({
    required String searchTerm,
    String? parentId,
    int? limit = 50,
  }) async {
    _logger.i('Searching songs: $searchTerm');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        parentId: parentId,
        searchTerm: searchTerm,
        limit: limit,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.audio],
        recursive: true,
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
        ],
        enableImages: true,
        enableUserData: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to search songs: No response data', statusCode: response.statusCode);
      }

      return MusicSongListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to search songs', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to search songs: $e', cause: e, stackTrace: stackTrace);
    }
  }

  /// 搜索专辑
  Future<MusicAlbumListResult> searchAlbums({
    required String searchTerm,
    String? parentId,
    int? limit = 50,
  }) async {
    _logger.i('Searching albums: $searchTerm');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        parentId: parentId,
        searchTerm: searchTerm,
        limit: limit,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.musicAlbum],
        recursive: true,
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
        ],
        enableImages: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to search albums: No response data', statusCode: response.statusCode);
      }

      return MusicAlbumListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to search albums', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to search albums: $e', cause: e, stackTrace: stackTrace);
    }
  }

  /// 搜索艺术家
  Future<MusicArtistListResult> searchArtists({
    required String searchTerm,
    String? parentId,
    int? limit = 50,
  }) async {
    _logger.i('Searching artists: $searchTerm');

    try {
      final artistsApi = _apiClient.jellyfinClient.getArtistsApi();

      final response = await artistsApi.getAlbumArtists(
        userId: _userId,
        parentId: parentId,
        searchTerm: searchTerm,
        limit: limit,
        enableImages: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to search artists: No response data', statusCode: response.statusCode);
      }

      return MusicArtistListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to search artists', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to search artists: $e', cause: e, stackTrace: stackTrace);
    }
  }
}
