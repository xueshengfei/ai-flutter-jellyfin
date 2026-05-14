import 'dart:typed_data';

/// Jellyfin 图片类型枚举
///
/// 对应 Jellyfin API 的 `/Items/{id}/Images/{type}` 路径段。
enum JellyfinImageType {
  primary('Primary'),
  backdrop('Backdrop'),
  thumb('Thumb'),
  logo('Logo'),
  banner('Banner');

  final String pathSegment;
  const JellyfinImageType(this.pathSegment);
}

/// 图片加载抽象接口
///
/// JellyfinImage 依赖此接口加载认证图片，不直接绑定任何具体服务实现。
/// 根包或各 feature 包提供具体实现（如包装 JellyfinClient.image）。
abstract class JellyfinImageProvider {
  /// 获取图片的完整 URL
  ///
  /// 用于 CachedNetworkImage 直接加载（支持磁盘+内存缓存）。
  /// [itemId] 媒体项ID
  /// [imageType] 图片类型，默认 Primary（封面）
  /// [imageTag] 图片标签
  /// [fillWidth] 填充宽度
  /// [fillHeight] 填充高度
  String buildImageUrl({
    required String itemId,
    JellyfinImageType imageType = JellyfinImageType.primary,
    String? imageTag,
    int? fillWidth,
    int? fillHeight,
  });

  /// 请求图片时需要的认证 header
  ///
  /// 返回 null 表示无需认证（URL 自带 token 等场景）。
  Map<String, String>? get authHeaders => null;

  /// 获取图片原始字节
  ///
  /// 作为 CachedNetworkImage 不可用时的降级方案。
  /// [itemId] 媒体项ID
  /// [imageType] 图片类型
  /// [tag] 图片标签
  /// [fillWidth] 填充宽度
  /// [fillHeight] 填充高度
  /// [quality] 图片质量 0-100
  Future<Uint8List> getImage({
    required String itemId,
    JellyfinImageType imageType = JellyfinImageType.primary,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  });
}
