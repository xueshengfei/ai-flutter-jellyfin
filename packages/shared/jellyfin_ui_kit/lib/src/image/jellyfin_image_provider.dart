import 'dart:typed_data';

/// 图片加载抽象接口
///
/// JellyfinImage 依赖此接口加载认证图片，不直接绑定任何具体服务实现。
/// 根包或各 feature 包提供具体实现（如包装 JellyfinClient.image）。
abstract class JellyfinImageProvider {
  /// 获取主图片（封面）
  ///
  /// [itemId] 媒体项ID
  /// [tag] 图片标签
  /// [fillWidth] 填充宽度
  /// [fillHeight] 填充高度
  /// [quality] 图片质量 0-100
  Future<Uint8List> getPrimaryImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  });
}
