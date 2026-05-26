import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../session/app_session.dart';

/// 视频 App 图片加载实现
final class JellyfinVideoImageProvider implements JellyfinImageProvider {
  final String serverUrl;
  final String accessToken;

  JellyfinVideoImageProvider({
    required this.serverUrl,
    required this.accessToken,
  });

  factory JellyfinVideoImageProvider.fromSession(AppSession session) {
    return JellyfinVideoImageProvider(
      serverUrl: session.serverUrl,
      accessToken: session.accessToken,
    );
  }

  @override
  String buildImageUrl({
    required String itemId,
    JellyfinImageType imageType = JellyfinImageType.primary,
    String? imageTag,
    int? fillWidth,
    int? fillHeight,
  }) {
    if (serverUrl.isEmpty) return '';
    var url = '$serverUrl/Items/$itemId/Images/${imageType.pathSegment}';
    final params = <String, String>{};
    if (imageTag != null && imageTag.isNotEmpty) params['tag'] = imageTag;
    if (fillWidth != null) params['fillWidth'] = '$fillWidth';
    if (fillHeight != null) params['fillHeight'] = '$fillHeight';
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    return url;
  }

  @override
  Map<String, String>? get authHeaders {
    if (accessToken.isEmpty) return null;
    return {'X-Emby-Token': accessToken};
  }

  @override
  Future<Uint8List> getImage({
    required String itemId,
    JellyfinImageType imageType = JellyfinImageType.primary,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  }) async {
    var url = '$serverUrl/Items/$itemId/Images/${imageType.pathSegment}';
    final params = <String, String>{};
    if (tag != null && tag.isNotEmpty) params['tag'] = tag;
    if (fillWidth != null) params['fillWidth'] = '$fillWidth';
    if (fillHeight != null) params['fillHeight'] = '$fillHeight';
    if (quality != null) params['quality'] = '$quality';
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {'X-Emby-Token': accessToken},
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('图片加载失败: ${response.statusCode}');
  }
}
