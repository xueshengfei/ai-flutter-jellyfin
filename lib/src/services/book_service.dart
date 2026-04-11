import 'package:logger/logger.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import '../core/api_client.dart';
import '../exceptions/api_exception.dart';
import '../models/book_models.dart';

/// 书籍服务
///
/// 提供书籍相关功能：
/// - 浏览电子书、有声书、书籍系列
/// - 获取书籍详情
/// - 获取电子书下载URL
/// - 获取有声书音频流URL
class BookService {
  final ApiClient _apiClient;
  final Logger _logger;

  BookService({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  String? get _userId => _apiClient.config.userId;
  String get _serverUrl => _apiClient.config.serverUrl;
  String? get _accessToken => _apiClient.config.accessToken;

  // ==================== 电子书 ====================

  /// 获取电子书列表
  Future<BookListResult> getBooks({
    String? parentId,
    int? startIndex = 0,
    int? limit = 50,
    String? searchTerm,
    List<String>? genres,
    List<jellyfin_dart.ItemSortBy>? sortBy,
    List<jellyfin_dart.SortOrder>? sortOrder,
  }) async {
    _logger.i('Fetching books');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
        searchTerm: searchTerm,
        genres: genres,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.book],
        recursive: true,
        sortBy: sortBy ?? const [jellyfin_dart.ItemSortBy.sortName],
        sortOrder: sortOrder ?? const [jellyfin_dart.SortOrder.ascending],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.overview,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
          jellyfin_dart.ItemFields.people,
          jellyfin_dart.ItemFields.studios,
        ],
        enableImages: true,
        enableUserData: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get books: No response data', statusCode: response.statusCode);
      }

      _logger.i('Fetched ${response.data!.items?.length ?? 0} books');

      return BookListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch books', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch books: $e', cause: e, stackTrace: stackTrace);
    }
  }

  /// 获取单本书详情
  Future<Book> getBookDetail(String bookId) async {
    _logger.i('Fetching book detail: $bookId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        ids: [bookId],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.overview,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
          jellyfin_dart.ItemFields.people,
          jellyfin_dart.ItemFields.studios,
        ],
      );

      if (response.data == null || response.data!.items == null || response.data!.items!.isEmpty) {
        throw ApiException('Book not found: $bookId', statusCode: 404);
      }

      return Book.fromDto(
        response.data!.items![0],
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch book detail', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch book detail: $e', cause: e, stackTrace: stackTrace);
    }
  }

  // ==================== 书籍系列 ====================

  /// 获取书籍系列列表
  Future<BookSeriesListResult> getBookSeries({
    String? parentId,
    int? startIndex = 0,
    int? limit = 50,
    String? searchTerm,
    List<jellyfin_dart.ItemSortBy>? sortBy,
    List<jellyfin_dart.SortOrder>? sortOrder,
  }) async {
    _logger.i('Fetching book series');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
        searchTerm: searchTerm,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.boxSet],
        recursive: true,
        sortBy: sortBy ?? const [jellyfin_dart.ItemSortBy.sortName],
        sortOrder: sortOrder ?? const [jellyfin_dart.SortOrder.ascending],
        fields: const [
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
        ],
        enableImages: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get book series: No response data', statusCode: response.statusCode);
      }

      _logger.i('Fetched ${response.data!.items?.length ?? 0} book series');

      return BookSeriesListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch book series', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch book series: $e', cause: e, stackTrace: stackTrace);
    }
  }

  /// 获取系列中的所有书
  Future<BookListResult> getBookSeriesBooks(
    String seriesId, {
    int? startIndex = 0,
    int? limit = 100,
  }) async {
    _logger.i('Fetching books for series: $seriesId');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        parentId: seriesId,
        startIndex: startIndex,
        limit: limit,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.book],
        sortBy: const [jellyfin_dart.ItemSortBy.sortName],
        sortOrder: const [jellyfin_dart.SortOrder.ascending],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.overview,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
          jellyfin_dart.ItemFields.people,
          jellyfin_dart.ItemFields.studios,
        ],
        enableImages: true,
        enableUserData: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get series books: No response data', statusCode: response.statusCode);
      }

      return BookListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch series books', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch series books: $e', cause: e, stackTrace: stackTrace);
    }
  }

  // ==================== 有声书 ====================

  /// 获取有声书列表
  Future<AudioBookListResult> getAudioBooks({
    String? parentId,
    int? startIndex = 0,
    int? limit = 50,
    String? searchTerm,
    List<String>? genres,
    List<jellyfin_dart.ItemSortBy>? sortBy,
    List<jellyfin_dart.SortOrder>? sortOrder,
  }) async {
    _logger.i('Fetching audiobooks');

    try {
      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final response = await itemsApi.getItems(
        userId: _userId,
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
        searchTerm: searchTerm,
        genres: genres,
        includeItemTypes: const [jellyfin_dart.BaseItemKind.audioBook],
        recursive: true,
        sortBy: sortBy ?? const [jellyfin_dart.ItemSortBy.sortName],
        sortOrder: sortOrder ?? const [jellyfin_dart.SortOrder.ascending],
        fields: const [
          jellyfin_dart.ItemFields.genres,
          jellyfin_dart.ItemFields.overview,
          jellyfin_dart.ItemFields.primaryImageAspectRatio,
          jellyfin_dart.ItemFields.people,
          jellyfin_dart.ItemFields.studios,
        ],
        enableImages: true,
        enableUserData: true,
      );

      if (response.data == null) {
        throw ApiException('Failed to get audiobooks: No response data', statusCode: response.statusCode);
      }

      _logger.i('Fetched ${response.data!.items?.length ?? 0} audiobooks');

      return AudioBookListResult.fromDto(
        response.data!,
        _serverUrl,
        accessToken: _accessToken,
      );
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to fetch audiobooks', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to fetch audiobooks: $e', cause: e, stackTrace: stackTrace);
    }
  }

  // ==================== 下载/流 ====================

  /// 获取电子书下载URL
  ///
  /// 返回可直接下载的文件URL（支持 epub 等格式）
  String getBookDownloadUrl(String bookId) {
    var url = '$_serverUrl/Items/$bookId/Download';
    if (_accessToken != null) url += '?api_key=$_accessToken';
    return url;
  }

  /// 获取有声书音频流URL
  ///
  /// 复用 Jellyfin 的 Audio API 播放有声书
  String getAudioBookStreamUrl(String audioBookId, {int? startTimeTicks}) {
    var url = '$_serverUrl/Audio/$audioBookId/stream';
    url += '?UserId=$_userId';
    if (_accessToken != null) url += '&api_key=$_accessToken';
    if (startTimeTicks != null) url += '&startTimeTicks=$startTimeTicks';
    return url;
  }
}
