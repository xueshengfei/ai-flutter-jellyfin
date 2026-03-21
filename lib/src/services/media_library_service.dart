import 'package:logger/logger.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import '../core/api_client.dart';
import '../exceptions/api_exception.dart';
import '../models/media_library_models.dart';
import '../models/media_item_models.dart';
import '../models/person_models.dart';

/// 媒体库服务
///
/// 提供媒体库相关功能：
/// - 获取媒体库列表
/// - 获取媒体库详情
class MediaLibraryService {
  final ApiClient _apiClient;
  final Logger _logger;

  MediaLibraryService({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  /// 获取所有媒体库
  ///
  /// 返回用户可访问的所有媒体库（电影、电视剧、音乐等）
  ///
  /// 返回：[MediaLibraryListResult] 包含媒体库列表
  ///
  /// 抛出：
  /// - [ApiException] 请求失败时
  Future<MediaLibraryListResult> getMediaLibraries() async {
    _logger.i('Fetching media libraries');

    try {
      final libraryApi = _apiClient.jellyfinClient.getLibraryApi();

      // 调用接口SDK获取媒体文件夹
      final response = await libraryApi.getMediaFolders();

      if (response.data == null) {
        throw ApiException(
          'Failed to get media libraries: No response data',
          statusCode: response.statusCode,
        );
      }

      final result = response.data!;

      _logger.i(
        'Successfully fetched ${result.items?.length ?? 0} media libraries',
      );

      // 转换为业务模型，传递访问令牌用于图片认证
      return MediaLibraryListResult.fromDto(
        result,
        _apiClient.config.serverUrl,
        accessToken: _apiClient.config.accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch media libraries',
          error: e, stackTrace: stackTrace);

      throw ApiException(
        'Failed to fetch media libraries: ${e.toString()}',
          cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 获取媒体库详情
  ///
  /// 参数：
  /// - [libraryId] 媒体库ID
  ///
  /// 返回：[MediaLibrary] 媒体库详情
  ///
  /// 抛出：
  /// - [ApiException] 请求失败时
  Future<MediaLibrary> getMediaLibraryDetail(String libraryId) async {
    _logger.i('Fetching media library detail: $libraryId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      // 获取媒体库信息
      final response = await itemsApi.getItems(userId: _apiClient.config.userId);

      if (response.data == null) {
        throw ApiException(
          'Failed to get media library detail: No response data',
          statusCode: response.statusCode,
        );
      }

      // 查找指定的媒体库
      final library = response.data!.items?.firstWhere(
        (item) => item.id == libraryId,
        orElse: () => throw ApiException(
          'Media library not found: $libraryId',
          statusCode: 404,
        ),
      );

      if (library == null) {
        throw ApiException(
          'Media library not found: $libraryId',
          statusCode: 404,
        );
      }

      _logger.i('Successfully fetched media library: ${library.name}');

      return MediaLibrary.fromDto(
        library,
        _apiClient.config.serverUrl,
        accessToken: _apiClient.config.accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch media library detail',
          error: e, stackTrace: stackTrace);

      throw ApiException(
        'Failed to fetch media library detail: ${e.toString()}',
          cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 按类型获取媒体库
  ///
  /// 参数：
  /// - [type] 媒体库类型
  ///
  /// 返回：指定类型的媒体库列表
  ///
  /// 抛出：
  /// - [ApiException] 请求失败时
  Future<List<MediaLibrary>> getMediaLibrariesByType(
    MediaLibraryType type,
  ) async {
    _logger.i('Fetching media libraries by type: $type');

    try {
      final result = await getMediaLibraries();

      final filteredLibraries = result.libraries
          .where((library) => library.type == type)
          .toList();

      _logger.i(
        'Found ${filteredLibraries.length} libraries of type $type',
      );

      return filteredLibraries;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch media libraries by type',
          error: e, stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 获取媒体库中的媒体项列表
  ///
  /// 参数：
  /// - [parentId] 媒体库ID
  /// - [startIndex] 起始索引（用于分页）
  /// - [limit] 限制返回数量
  /// - [recursive] 是否递归获取子项（默认true）
  ///
  /// 返回：[MediaItemListResult] 包含媒体项列表
  ///
  /// 抛出：
  /// - [ApiException] 请求失败时
  Future<MediaItemListResult> getMediaItems({
    required String parentId,
    int? startIndex = 0,
    int? limit = 20,
    bool recursive = true,
  }) async {
    _logger.i('Fetching media items for parent: $parentId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      // 调用接口SDK获取媒体项
      final response = await itemsApi.getItems(
        userId: _apiClient.config.userId,
        parentId: parentId,
        recursive: recursive,
        startIndex: startIndex,
        limit: limit,
      );

      if (response.data == null) {
        throw ApiException(
          'Failed to get media items: No response data',
          statusCode: response.statusCode,
        );
      }

      final result = response.data!;

      _logger.i(
        'Successfully fetched ${result.items?.length ?? 0} media items',
      );

      // 转换为业务模型，传递访问令牌用于图片认证
      return MediaItemListResult.fromDto(
        result,
        _apiClient.config.serverUrl,
        accessToken: _apiClient.config.accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch media items',
          error: e, stackTrace: stackTrace);

      throw ApiException(
        'Failed to fetch media items: ${e.toString()}',
          cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 获取剧集的所有季
  ///
  /// 参数：
  /// - [seriesId] 剧集ID
  ///
  /// 返回：[SeasonListResult] 包含季列表
  ///
  /// 抛出：
  /// - [ApiException] 请求失败时
  Future<SeasonListResult> getSeasons(String seriesId) async {
    _logger.i('Fetching seasons for series: $seriesId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      // 获取剧集的所有季
      // 使用 includeItemTypes 参数只获取 Season 类型
      final response = await itemsApi.getItems(
        userId: _apiClient.config.userId,
        parentId: seriesId,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.season],
      );

      if (response.data == null) {
        throw ApiException(
          'Failed to get seasons: No response data',
          statusCode: response.statusCode,
        );
      }

      final result = response.data!;
      final seasonItems = result.items ?? [];

      _logger.i('Successfully fetched ${seasonItems.length} seasons');

      // 调试：打印所有返回的项
      if (seasonItems.isEmpty) {
        _logger.w('⚠️ 没有找到任何季！');
        _logger.w('   seriesId: $seriesId');
        _logger.w('   totalRecordCount: ${result.totalRecordCount}');
      } else {
        _logger.i('找到的季列表:');
        for (var i = 0; i < seasonItems.length && i < 10; i++) {
          final item = seasonItems[i];
          _logger.i('  [$i] ${item.name} (id: ${item.id}, type: ${item.type?.name})');
        }
      }

      // 获取每个季的剧集数量（可选）
      final episodeCounts = <String, int>{};
      for (final season in seasonItems) {
        if (season.id != null) {
          try {
            final episodeResponse = await itemsApi.getItems(
              userId: _apiClient.config.userId,
              parentId: season.id!,
            );
            episodeCounts[season.id!] = episodeResponse.data?.totalRecordCount ?? 0;
          } catch (e) {
            _logger.w('Failed to get episode count for season ${season.id}: $e');
            episodeCounts[season.id!] = 0;
          }
        }
      }

      // 转换为业务模型
      return SeasonListResult.fromDto(
        seasonItems,
        seriesId,
        _apiClient.config.serverUrl,
        accessToken: _apiClient.config.accessToken,
        episodeCounts: episodeCounts,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch seasons',
          error: e, stackTrace: stackTrace);

      throw ApiException(
        'Failed to fetch seasons: ${e.toString()}',
          cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 获取季的所有集
  ///
  /// 参数：
  /// - [seasonId] 季ID
  /// - [seriesId] 剧集ID（必需，用于Episode模型）
  /// - [startIndex] 起始索引（用于分页）
  /// - [limit] 限制返回数量
  ///
  /// 返回：[EpisodeListResult] 包含集列表
  ///
  /// 抛出：
  /// - [ApiException] 请求失败时
  Future<EpisodeListResult> getEpisodes({
    required String seasonId,
    required String seriesId,
    int? startIndex = 0,
    int? limit = 50,
  }) async {
    _logger.i('Fetching episodes for season: $seasonId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      // 获取季的所有集
      // 使用 includeItemTypes 参数只获取 Episode 类型
      final response = await itemsApi.getItems(
        userId: _apiClient.config.userId,
        parentId: seasonId,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.episode],
        startIndex: startIndex,
        limit: limit,
        sortBy: const [jellyfin_dart.ItemSortBy.sortName],
        sortOrder: const [jellyfin_dart.SortOrder.ascending],
      );

      if (response.data == null) {
        throw ApiException(
          'Failed to get episodes: No response data',
          statusCode: response.statusCode,
        );
      }

      final result = response.data!;

      _logger.i('Successfully fetched ${result.items?.length ?? 0} episodes');

      // 转换为业务模型
      return EpisodeListResult.fromDto(
        result,
        seriesId,
        seasonId,
        _apiClient.config.serverUrl,
        accessToken: _apiClient.config.accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch episodes',
          error: e, stackTrace: stackTrace);

      throw ApiException(
        'Failed to fetch episodes: ${e.toString()}',
          cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 获取剧集详情
  ///
  /// 参数：
  /// - [seriesId] 剧集ID
  ///
  /// 返回：[MediaItem] 剧集详情
  ///
  /// 抛出：
  /// - [ApiException] 请求失败时
  Future<MediaItem> getSeriesDetail(String seriesId) async {
    _logger.i('Fetching series detail: $seriesId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      // 获取用户项目，筛选出指定ID的剧集
      final response = await itemsApi.getItems(
        userId: _apiClient.config.userId,
        ids: [seriesId],
      );

      if (response.data == null || response.data!.items == null || response.data!.items!.isEmpty) {
        throw ApiException(
          'Series not found: $seriesId',
          statusCode: 404,
        );
      }

      final seriesDto = response.data!.items![0];

      _logger.i('Successfully fetched series: ${seriesDto.name}');

      // 转换为业务模型
      return MediaItem.fromDto(
        seriesDto,
        _apiClient.config.serverUrl,
        accessToken: _apiClient.config.accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch series detail',
          error: e, stackTrace: stackTrace);

      throw ApiException(
        'Failed to fetch series detail: ${e.toString()}',
          cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 获取媒体项详情
  ///
  /// 参数：
  /// - [itemId] 媒体项ID
  ///
  /// 返回：[MediaItem] 包含完整元数据的媒体项
  ///
  /// 抛出：
  /// - [ApiException] 请求失败时
  Future<MediaItem> getMediaItemDetail(String itemId) async {
    _logger.i('Fetching media item detail: $itemId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      // 获取媒体项详情，指定要返回的字段
      final response = await itemsApi.getItems(
        userId: _apiClient.config.userId,
        ids: [itemId],
        // 指定要返回的额外字段
        fields: const [
          jellyfin_dart.ItemFields.genres,              // 类型
          jellyfin_dart.ItemFields.studios,             // 工作室
          jellyfin_dart.ItemFields.people,              // 人员（导演、演员、作者等）
          jellyfin_dart.ItemFields.overview,            // 剧情简介
          jellyfin_dart.ItemFields.productionLocations, // 制作地点
        ],
      );

      if (response.data == null || response.data!.items == null || response.data!.items!.isEmpty) {
        throw ApiException(
          'Media item not found: $itemId',
          statusCode: 404,
        );
      }

      final itemDto = response.data!.items![0];

      _logger.i('Successfully fetched item: ${itemDto.name}');
      _logger.i('  Genres: ${itemDto.genres}');
      _logger.i('  Studios: ${itemDto.studios}');
      _logger.i('  People count: ${itemDto.people?.length ?? 0}');
      _logger.i('  Overview: ${itemDto.overview?.substring(0, itemDto.overview!.length > 50 ? 50 : itemDto.overview!.length)}...');

      // 转换为业务模型，包含完整元数据
      return MediaItem.fromDto(
        itemDto,
        _apiClient.config.serverUrl,
        accessToken: _apiClient.config.accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch media item detail',
          error: e, stackTrace: stackTrace);

      throw ApiException(
        'Failed to fetch media item detail: ${e.toString()}',
          cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 获取人员详细信息
  ///
  /// 参数：
  /// - [personId] 人员ID
  /// - [personType] 人员类型（演员、导演、编剧等）
  ///
  /// 返回：[Person] 人员详细信息
  ///
  /// 抛出：
  /// - [ApiException] 请求失败时
  Future<Person> getPersonDetail(
    String personId,
    jellyfin_dart.PersonKind personType,
  ) async {
    _logger.i('Fetching person detail: $personId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      // 获取人员详情
      final response = await itemsApi.getItems(
        userId: _apiClient.config.userId,
        ids: [personId],
      );

      if (response.data == null || response.data!.items == null || response.data!.items!.isEmpty) {
        throw ApiException(
          'Failed to get person detail: No response data',
          statusCode: response.statusCode,
        );
      }

      final personDto = response.data!.items![0];

      _logger.i('Successfully fetched person: ${personDto.name}');

      // 转换为业务模型
      return Person.fromDto(
        personDto,
        personType,
        _apiClient.config.serverUrl,
        accessToken: _apiClient.config.accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch person detail',
          error: e, stackTrace: stackTrace);

      throw ApiException(
        'Failed to fetch person detail: ${e.toString()}',
          cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 获取人员参与的作品列表
  ///
  /// 参数：
  /// - [personId] 人员ID
  /// - [includeItemTypes] 包含的媒体类型（默认为电影和剧集）
  /// - [limit] 限制返回数量（默认50）
  ///
  /// 返回：[PersonCreditsResult] 包含作品列表的结果
  ///
  /// 抛出：
  /// - [ApiException] 请求失败时
  Future<PersonCreditsResult> getPersonCredits({
    required String personId,
    List<jellyfin_dart.BaseItemKind>? includeItemTypes,
    int? limit,
  }) async {
    _logger.i('Fetching person credits for: $personId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      // 按人员ID筛选作品（递归搜索）
      final response = await itemsApi.getItems(
        userId: _apiClient.config.userId,
        personIds: [personId],
        includeItemTypes: includeItemTypes ??
            const [jellyfin_dart.BaseItemKind.movie, jellyfin_dart.BaseItemKind.series],
        recursive: true, // 重要！递归搜索所有子文件夹
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.overview,
          jellyfin_dart.ItemFields.people,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
        ],
        limit: limit ?? 50,
        sortBy: const [
          jellyfin_dart.ItemSortBy.premiereDate,
          jellyfin_dart.ItemSortBy.productionYear,
          jellyfin_dart.ItemSortBy.sortName,
        ],
        sortOrder: const [
          jellyfin_dart.SortOrder.descending,
          jellyfin_dart.SortOrder.descending,
          jellyfin_dart.SortOrder.ascending,
        ],
      );

      if (response.data == null) {
        throw ApiException(
          'Failed to get person credits: No response data',
          statusCode: response.statusCode,
        );
      }

      final result = response.data!;

      _logger.i('Successfully fetched ${result.items?.length ?? 0} credits for person $personId');

      // 转换为业务模型
      final items = result.items
              ?.map((dto) => MediaItem.fromDto(
                    dto,
                    _apiClient.config.serverUrl,
                    accessToken: _apiClient.config.accessToken,
                  ))
              .toList() ??
          [];

      return PersonCreditsResult(
        items: items,
        totalCount: result.totalRecordCount,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch person credits',
          error: e, stackTrace: stackTrace);

      throw ApiException(
        'Failed to fetch person credits: ${e.toString()}',
          cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 获取人员参与的作品（按类型筛选）
  ///
  /// 参数：
  /// - [personId] 人员ID
  /// - [personType] 人员类型
  /// - [limit] 限制返回数量（默认50）
  ///
  /// 返回：[PersonCreditsResult] 包含作品列表的结果
  ///
  /// 抛出：
  /// - [ApiException] 请求失败时
  Future<PersonCreditsResult> getPersonCreditsByType({
    required String personId,
    required jellyfin_dart.PersonKind personType,
    int? limit,
  }) async {
    // 根据人员类型筛选，这里默认为电影和剧集
    // 如果需要更精细的筛选，可以扩展此方法
    return getPersonCredits(
      personId: personId,
      includeItemTypes: const [
        jellyfin_dart.BaseItemKind.movie,
        jellyfin_dart.BaseItemKind.series,
      ],
      limit: limit,
    );
  }
}
