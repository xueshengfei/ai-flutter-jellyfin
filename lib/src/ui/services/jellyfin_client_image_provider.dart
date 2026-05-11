import 'dart:typed_data';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';
import '../../jellyfin_client.dart';

/// JellyfinClient 的图片加载适配器
///
/// 将根包的 JellyfinClient.image 适配为 jellyfin_ui_kit 的 JellyfinImageProvider 接口。
/// 根包 widget 在使用 jellyfin_ui_kit 的 JellyfinImage 等组件时，
/// 传入此适配器实例即可。
class JellyfinClientImageProvider implements JellyfinImageProvider {
  final JellyfinClient _client;

  JellyfinClientImageProvider(this._client);

  @override
  Future<Uint8List> getPrimaryImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality = 96,
  }) {
    return _client.image.getPrimaryImage(
      itemId: itemId,
      tag: tag,
      fillWidth: fillWidth,
      fillHeight: fillHeight,
      quality: quality,
    );
  }
}
