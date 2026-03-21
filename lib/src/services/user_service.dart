import 'package:logger/logger.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import '../core/api_client.dart';
import '../models/media_item_models.dart';

/// 用户服务
///
/// 提供用户特定的媒体管理功能：
/// - 收藏/取消收藏
/// - 获取收藏列表
/// - 继续观看列表
/// - 观看历史记录
class UserService {
  final ApiClient _apiClient;
  final Logger _logger;

  UserService({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  /// 获取当前用户ID
  String? get currentUserId => _apiClient.config.userId;

  /// 标记为收藏
  ///
  /// [itemId] 媒体项ID
  /// [isFavorite] 是否收藏
  Future<void> markFavorite({
    required String itemId,
    required bool isFavorite,
  }) async {
    if (currentUserId == null) {
      throw Exception('用户未登录');
    }

    try {
      _logger.i('标记收藏: $itemId, 收藏状态: $isFavorite');

      final userLibraryApi = _apiClient.jellyfinClient.getUserLibraryApi();

      await userLibraryApi.markFavoriteItem(
        userId: currentUserId!,
        itemId: itemId,
        isFavorite: isFavorite,
      );

      _logger.i('收藏状态更新成功');
    } catch (e) {
      _logger.e('标记收藏失败: $e');
      rethrow;
    }
  }

  /// 获取收藏列表
  ///
  /// [mediaType] 媒体类型过滤 (可选): 'Movie', 'Series', 'Episode' 等
  /// [limit] 返回数量限制
  Future<MediaItemListResult> getFavorites({
    String? mediaType,
    int limit = 20,
  }) async {
    if (currentUserId == null) {
      throw Exception('用户未登录');
    }

    try {
      _logger.i('获取收藏列表: 媒体类型=$mediaType');

      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      // 构建查询参数
      final queryParams = {
        'userId': currentUserId!,
        'isFavorite': true,
        'limit': limit,
        'sortBy': 'SortName',
        'sortOrder': 'Ascending',
      };

      if (mediaType != null && mediaType.isNotEmpty) {
        queryParams['includeItemTypes'] = mediaType;
      }

      final response = await itemsApi.getItems(queryParams);

      if (response.data == null) {
        return MediaItemListResult(items: [], totalCount: 0);
      }

      final itemsDto = response.data!;
      final items = itemsDto.items?.map((dto) => MediaItem.fromDto(dto)).toList() ?? [];

      return MediaItemListResult(
        items: items,
        totalCount: itemsDto.totalRecordCount ?? items.length,
      );
    } catch (e) {
      _logger.e('获取收藏列表失败: $e');
      rethrow;
    }
  }

  /// 获取继续观看列表
  ///
  /// 获取用户已经开始观看但未完成的媒体项
  /// [limit] 返回数量限制
  Future<MediaItemListResult> getContinueWatching({
    int limit = 20,
  }) async {
    if (currentUserId == null) {
      throw Exception('用户未登录');
    }

    try {
      _logger.i('获取继续观看列表');

      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final queryParams = {
        'userId': currentUserId!,
        'limit': limit,
        'sortBy': 'DatePlayed',
        'sortOrder': 'Descending',
        'filters': 'IsResumable', // 可恢复播放（有播放进度但未完成）
        'recursive': true,
        'excludeItemTypes': 'Recording', // 排除录制
      };

      final response = await itemsApi.getItems(queryParams);

      if (response.data == null) {
        return MediaItemListResult(items: [], totalCount: 0);
      }

      final itemsDto = response.data!;
      final items = itemsDto.items?.map((dto) => MediaItem.fromDto(dto)).toList() ?? [];

      return MediaItemListResult(
        items: items,
        totalCount: itemsDto.totalRecordCount ?? items.length,
      );
    } catch (e) {
      _logger.e('获取继续观看列表失败: $e');
      rethrow;
    }
  }

  /// 获取观看历史记录
  ///
  /// [limit] 返回数量限制
  /// [mediaType] 媒体类型过滤 (可选)
  Future<MediaItemListResult> getWatchHistory({
    int limit = 50,
    String? mediaType,
  }) async {
    if (currentUserId == null) {
      throw Exception('用户未登录');
    }

    try {
      _logger.i('获取观看历史记录: 媒体类型=$mediaType');

      final itemsApi = _apiClient.jellyfinClient.getItemsApi();

      final queryParams = {
        'userId': currentUserId!,
        'limit': limit,
        'sortBy': 'DatePlayed',
        'sortOrder': 'Descending',
        'isPlayed': true, // 已播放完成
        'recursive': true,
      };

      if (mediaType != null && mediaType.isNotEmpty) {
        queryParams['includeItemTypes'] = mediaType;
      }

      final response = await itemsApi.getItems(queryParams);

      if (response.data == null) {
        return MediaItemListResult(items: [], totalCount: 0);
      }

      final itemsDto = response.data!;
      final items = itemsDto.items?.map((dto) => MediaItem.fromDto(dto)).toList() ?? [];

      return MediaItemListResult(
        items: items,
        totalCount: itemsDto.totalRecordCount ?? items.length,
      );
    } catch (e) {
      _logger.e('获取观看历史记录失败: $e');
      rethrow;
    }
  }

  /// 标记为已播放/未播放
  ///
  /// [itemId] 媒体项ID
  /// [isPlayed] 是否已播放
  Future<void> markAsPlayed({
    required String itemId,
    required bool isPlayed,
  }) async {
    if (currentUserId == null) {
      throw Exception('用户未登录');
    }

    try {
      _logger.i('标记播放状态: $itemId, 已播放: $isPlayed');

      final playstateApi = _apiClient.jellyfinClient.getPlaystateApi();

      if (isPlayed) {
        await playstateApi.markPlayedItem(
          userId: currentUserId!,
          itemId: itemId,
        );
      } else {
        await playstateApi.markUnplayedItem(
          userId: currentUserId!,
          itemId: itemId,
        );
      }

      _logger.i('播放状态更新成功');
    } catch (e) {
      _logger.e('标记播放状态失败: $e');
      rethrow;
    }
  }

  /// 更新媒体项的用户数据
  ///
  /// [itemId] 媒体项ID
  /// [isFavorite] 收藏状态（可选）
  /// [isPlayed] 已播放状态（可选）
  /// [playedPercentage] 播放百分比（可选）
  Future<void> updateUserItemData({
    required String itemId,
    bool? isFavorite,
    bool? isPlayed,
    double? playedPercentage,
  }) async {
    if (currentUserId == null) {
      throw Exception('用户未登录');
    }

    try {
      _logger.i('更新用户数据: $itemId');

      final userLibraryApi = _apiClient.jellyfinClient.getUserLibraryApi();

      await userLibraryApi.updateUserItemData(
        userId: currentUserId!,
        itemId: itemId,
        isFavorite: isFavorite,
        isPlayed: isPlayed,
        playedPercentage: playedPercentage,
      );

      _logger.i('用户数据更新成功');
    } catch (e) {
      _logger.e('更新用户数据失败: $e');
      rethrow;
    }
  }
}
