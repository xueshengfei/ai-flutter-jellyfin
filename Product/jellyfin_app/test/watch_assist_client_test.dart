import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jellyfin_app/src/data/watch_assist_client.dart';
import 'package:jellyfin_playback/jellyfin_playback.dart';

void main() {
  group('WatchAssistClient', () {
    test('发送符合后端协议的请求并解析响应', () async {
      late http.Request captured;
      final client = WatchAssistClient(
        aiServiceUrl: 'http://127.0.0.1:5005/',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'schemaVersion': 'watch_assist_v2',
              'itemId': 'movie-1',
              'title': 'AI 解读',
              'mode': 'safe',
              'requestedAssistType': 'character_analysis',
              'assistType': 'character_analysis',
              'assistTypeLabel': '人物解析',
              'capabilityLabel': '基于进度',
              'notice': '无字幕提示',
              'progress': {'stage': '中段：关系变化'},
              'activeContent': {
                'title': '人物解析',
                'text': '重点观察人物关系。',
                'items': ['主角立场变化'],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final response = await client.fetchWatchAssist(
        const WatchAssistRequest(
          itemId: 'movie-1',
          positionSeconds: 4200,
          spoilerMode: WatchAssistSpoilerMode.safe,
          assistType: WatchAssistType.characterAnalysis,
          subtitleWindow: null,
        ),
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'http://127.0.0.1:5005/watch_assist');
      expect(captured.headers['content-type'], contains('application/json'));
      expect(jsonDecode(captured.body), {
        'item_id': 'movie-1',
        'position_seconds': 4200,
        'spoiler_mode': 'safe',
        'assist_type': 'character_analysis',
        'subtitle_window': null,
      });
      expect(response.schemaVersion, 'watch_assist_v2');
      expect(response.assistType, WatchAssistType.characterAnalysis);
      expect(response.activeContent.text, '重点观察人物关系。');
    });

    test('非 200 时抛出可展示错误', () async {
      final client = WatchAssistClient(
        aiServiceUrl: 'http://127.0.0.1:5005',
        httpClient: MockClient((_) async => http.Response('bad gateway', 502)),
      );

      expect(
        () => client.fetchWatchAssist(
          const WatchAssistRequest(itemId: 'movie-1', positionSeconds: 1),
        ),
        throwsA(isA<WatchAssistClientException>()),
      );
    });

    test('JSON 解析失败时抛出可展示错误', () async {
      final client = WatchAssistClient(
        aiServiceUrl: 'http://127.0.0.1:5005',
        httpClient: MockClient((_) async => http.Response('not json', 200)),
      );

      expect(
        () => client.fetchWatchAssist(
          const WatchAssistRequest(itemId: 'movie-1', positionSeconds: 1),
        ),
        throwsA(isA<WatchAssistClientException>()),
      );
    });
  });
}
