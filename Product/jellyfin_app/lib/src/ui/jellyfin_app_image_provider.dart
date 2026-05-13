import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';
import '../session/app_session.dart';

/// Product app 层的图片加载实现
///
/// 使用当前登录会话的 serverUrl + accessToken 加载认证图片。
class JellyfinAppImageProvider implements JellyfinImageProvider {
  final String serverUrl;
  final String accessToken;

  JellyfinAppImageProvider({
    required this.serverUrl,
    required this.accessToken,
  });

  /// 从 AppSession 创建
  factory JellyfinAppImageProvider.fromSession(AppSession session) {
    return JellyfinAppImageProvider(
      serverUrl: session.serverUrl,
      accessToken: session.accessToken,
    );
  }

  @override
  Future<Uint8List> getPrimaryImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  }) async {
    var url = '$serverUrl/Items/$itemId/Images/Primary';
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
