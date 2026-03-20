import 'package:logger/logger.dart';
import '../core/api_client.dart';
import '../exceptions/api_exception.dart';
import '../models/media_library_models.dart';
import '../models/media_item_models.dart';

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
}
