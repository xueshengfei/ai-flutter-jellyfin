import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jellyfin_playback/jellyfin_playback.dart';

class WatchAssistClientException implements Exception {
  final String message;

  const WatchAssistClientException(this.message);

  @override
  String toString() => message;
}

class WatchAssistClient {
  final String aiServiceUrl;
  final http.Client _httpClient;

  WatchAssistClient({required this.aiServiceUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  Future<WatchAssistResponse> fetchWatchAssist(
    WatchAssistRequest request,
  ) async {
    final baseUrl = aiServiceUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseUrl/watch_assist');

    late final http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: const {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode(request.toJson()),
      );
    } catch (e) {
      throw WatchAssistClientException('AI 解读请求失败: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WatchAssistClientException(
        'AI 解读请求失败: HTTP ${response.statusCode}',
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('response is not an object');
      }
      return WatchAssistResponse.fromJson(decoded);
    } catch (e) {
      throw WatchAssistClientException('AI 解读响应解析失败: $e');
    }
  }
}
