import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import '../core/api_client.dart';

/// 图片信息模型
class ImageInfo {
  final String imageType;
  final String imageTag;
  final String? path;
  final String? blurHash;
  final int? height;
  final int? width;
  final int? size;

  ImageInfo({
    required this.imageType,
    required this.imageTag,
    this.path,
    this.blurHash,
    this.height,
    this.width,
    this.size,
  });

  factory ImageInfo.fromJson(Map<String, dynamic> json) {
    return ImageInfo(
      imageType: json['ImageType'] ?? '',
      imageTag: json['ImageTag'] ?? '',
      path: json['Path'],
      blurHash: json['BlurHash'],
      height: json['Height'],
      width: json['Width'],
      size: json['Size'],
    );
  }

  @override
  String toString() {
    return 'ImageInfo(type: $imageType, tag: $imageTag, size: ${width}x$height)';
  }
}

/// 图片服务
///
/// 提供图片下载功能，解决认证问题
class ImageService {
  final ApiClient _apiClient;
  final Logger _logger;

  ImageService({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  /// 获取媒体项的所有图片信息
  ///
  /// 返回图片信息列表，包含ImageType, ImageTag等
  Future<List<ImageInfo>> getItemImages(String itemId) async {
    _logger.i('Getting item images info: $itemId');

    try {
      final response = await _apiClient.dio.get(
        '/Items/$itemId/Images',
      );

      if (response.data == null) {
        throw Exception('Failed to get item images: No data received');
      }

      final List<dynamic> dataList = response.data is List
          ? response.data as List<dynamic>
          : (response.data as Map<String, dynamic>)['Items'] ?? [];

      final imageInfos = dataList
          .map((json) => ImageInfo.fromJson(json as Map<String, dynamic>))
          .toList();

      _logger.i('Got ${imageInfos.length} image infos for item $itemId');

      return imageInfos;
    } catch (e, stackTrace) {
      _logger.e('Failed to get item images info',
          error: e, stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 获取媒体项图片（完整版）
  ///
  /// 支持的参数：
  /// - [itemId] 媒体项ID
  /// - [imageType] 图片类型（Primary, Thumb, Backdrop等）
  /// - [fillWidth] 填充宽度（对应URL中的fillWidth）
  /// - [fillHeight] 填充高度（对应URL中的fillHeight）
  /// - [quality] 图片质量 0-100（对应URL中的quality）
  /// - [tag] 图片标签（对应URL中的tag）
  /// - [maxWidth] 最大宽度
  /// - [maxHeight] 最大高度
  ///
  /// 返回：图片二进制数据
  ///
  /// 抛出：
  /// - [DioException] 请求失败时
  Future<Uint8List> getItemImage({
    required String itemId,
    required jellyfin_dart.ImageType imageType,
    int? fillWidth,
    int? fillHeight,
    int? quality,
    String? tag,
    int? maxWidth,
    int? maxHeight,
  }) async {
    _logger.i('Getting item image: $itemId, type: $imageType');

    try {
      final imageApi = _apiClient.jellyfinClient.getImageApi();

      final response = await imageApi.getItemImage(
        itemId: itemId,
        imageType: imageType,
        fillWidth: fillWidth,
        fillHeight: fillHeight,
        quality: quality,
        tag: tag,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      final imageData = response.data;
      if (imageData == null) {
        throw Exception('Failed to get item image: No data received');
      }

      _logger.i('Successfully got item image: ${imageData.length} bytes');

      return imageData;
    } catch (e, stackTrace) {
      _logger.e('Failed to get item image',
          error: e, stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 获取主图片（封面）- 使用fillWidth/fillHeight
  Future<Uint8List> getPrimaryImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality = 96,
  }) async {
    return getItemImage(
      itemId: itemId,
      imageType: jellyfin_dart.ImageType.primary,
      tag: tag,
      fillWidth: fillWidth,
      fillHeight: fillHeight,
      quality: quality,
    );
  }

  /// 获取缩略图 - 使用fillWidth/fillHeight
  Future<Uint8List> getThumbImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality = 96,
  }) async {
    return getItemImage(
      itemId: itemId,
      imageType: jellyfin_dart.ImageType.thumb,
      tag: tag,
      fillWidth: fillWidth,
      fillHeight: fillHeight,
      quality: quality,
    );
  }

  /// 获取背景图片 - 使用fillWidth/fillHeight
  Future<Uint8List> getBackdropImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality = 96,
  }) async {
    return getItemImage(
      itemId: itemId,
      imageType: jellyfin_dart.ImageType.backdrop,
      tag: tag,
      fillWidth: fillWidth,
      fillHeight: fillHeight,
      quality: quality,
    );
  }
}
