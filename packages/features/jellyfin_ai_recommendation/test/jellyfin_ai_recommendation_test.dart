import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_ai_recommendation/jellyfin_ai_recommendation.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

/// 测试用 Fake 图片加载器
class FakeImageProvider implements JellyfinImageProvider {
  @override
  String buildImageUrl({
    required String itemId,
    JellyfinImageType imageType = JellyfinImageType.primary,
    String? imageTag,
    int? fillWidth,
    int? fillHeight,
  }) {
    return 'http://localhost/Items/$itemId/Images/${imageType.pathSegment}';
  }

  @override
  Map<String, String>? get authHeaders => null;

  @override
  Future<Uint8List> getImage({
    required String itemId,
    JellyfinImageType imageType = JellyfinImageType.primary,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  }) async {
    // 返回最小 PNG
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ]);
  }
}

void main() {
  group('SseEventType', () {
    test('fromName 解析所有事件类型', () {
      expect(SseEventType.fromName('thinking'), SseEventType.thinking);
      expect(SseEventType.fromName('tool'), SseEventType.tool);
      expect(SseEventType.fromName('token'), SseEventType.token);
      expect(SseEventType.fromName('card'), SseEventType.card);
      expect(SseEventType.fromName('session'), SseEventType.session);
      expect(SseEventType.fromName('done'), SseEventType.done);
      expect(SseEventType.fromName('error'), SseEventType.error);
    });

    test('fromName 未知类型兜底为 error', () {
      expect(SseEventType.fromName('unknown'), SseEventType.error);
      expect(SseEventType.fromName(''), SseEventType.error);
    });
  });

  group('AiCardType', () {
    test('fromName 解析所有卡片类型', () {
      expect(AiCardType.fromName('movie'), AiCardType.movie);
      expect(AiCardType.fromName('series'), AiCardType.series);
      expect(AiCardType.fromName('episode'), AiCardType.episode);
      expect(AiCardType.fromName('video'), AiCardType.video);
      expect(AiCardType.fromName('season'), AiCardType.season);
      expect(AiCardType.fromName('audio'), AiCardType.audio);
      expect(AiCardType.fromName('musicalbum'), AiCardType.musicalbum);
      expect(AiCardType.fromName('musicartist'), AiCardType.musicartist);
      expect(AiCardType.fromName('musicvideo'), AiCardType.musicvideo);
    });

    test('fromName null 和未知类型兜底为 video', () {
      expect(AiCardType.fromName(null), AiCardType.video);
      expect(AiCardType.fromName('unknown'), AiCardType.video);
    });

    test('icon 返回对应 IconData', () {
      expect(AiCardType.movie.icon, Icons.movie_outlined);
      expect(AiCardType.audio.icon, Icons.music_note_outlined);
      expect(AiCardType.musicartist.icon, Icons.person_outlined);
    });
  });

  group('AiCard', () {
    test('fromJson 正常解析', () {
      final json = {
        'id': 'abc123',
        'reason': '经典电影',
        'type': 'movie',
      };
      final card = AiCard.fromJson(json);
      expect(card.id, 'abc123');
      expect(card.reason, '经典电影');
      expect(card.type, AiCardType.movie);
    });

    test('fromJson 缺失字段使用默认值', () {
      final card = AiCard.fromJson({});
      expect(card.id, '');
      expect(card.reason, '');
      expect(card.type, AiCardType.video);
    });

    test('props 包含所有字段', () {
      const card = AiCard(id: 'x', reason: 'y', type: AiCardType.audio);
      expect(card.props, ['x', 'y', AiCardType.audio]);
    });
  });

  group('AiChatMessage', () {
    test('copyWith 正常复制', () {
      final msg = AiChatMessage(
        content: 'hello',
        isUser: true,
        timestamp: DateTime(2026),
      );
      final copy = msg.copyWith(content: 'world');
      expect(copy.content, 'world');
      expect(copy.isUser, true);
    });

    test('copyWith statusText null 清空', () {
      final msg = AiChatMessage(
        content: '',
        isUser: false,
        timestamp: DateTime(2026),
        statusText: '正在思考...',
      );
      final copy = msg.copyWith(statusText: null);
      expect(copy.statusText, isNull);
    });

    test('copyWith statusText 不传保留原值', () {
      final msg = AiChatMessage(
        content: '',
        isUser: false,
        timestamp: DateTime(2026),
        statusText: '正在思考...',
      );
      final copy = msg.copyWith(content: 'new');
      expect(copy.statusText, '正在思考...');
    });

    test('copyWith 追加卡片', () {
      final msg = AiChatMessage(
        content: '',
        isUser: false,
        timestamp: DateTime(2026),
        cards: [const AiCard(id: '1', reason: 'r1')],
      );
      final copy = msg.copyWith(
        cards: [...msg.cards, const AiCard(id: '2', reason: 'r2')],
      );
      expect(copy.cards.length, 2);
      expect(copy.cards[1].id, '2');
    });
  });

  group('SseEvent 数据类', () {
    test('SseThinkingEvent fromJson', () {
      final event = SseThinkingEvent.fromJson({'node': 'reason'});
      expect(event.node, 'reason');
    });

    test('SseToolEvent fromJson', () {
      final event = SseToolEvent.fromJson({
        'tool': 'search_media',
        'status': 'calling',
        'args': {'q': 'test'},
      });
      expect(event.tool, 'search_media');
      expect(event.status, 'calling');
      expect(event.args, isNotNull);
    });

    test('SseTokenEvent fromJson', () {
      final event = SseTokenEvent.fromJson({'content': '你好'});
      expect(event.content, '你好');
    });

    test('SseSessionEvent fromJson', () {
      final event = SseSessionEvent.fromJson({'session_id': 'sid123'});
      expect(event.sessionId, 'sid123');
    });

    test('SseDoneEvent fromJson', () {
      final event = SseDoneEvent.fromJson({
        'answer': '推荐如下',
        'cards': [
          {'id': '1', 'reason': '经典', 'type': 'movie'}
        ],
        'session_id': 'sid456',
      });
      expect(event.answer, '推荐如下');
      expect(event.cards?.length, 1);
      expect(event.sessionId, 'sid456');
    });
  });

  group('SseEvent', () {
    test('toString 包含类型和数据', () {
      const event = SseEvent(type: SseEventType.token, data: {'content': 'x'});
      expect(event.toString(), contains('token'));
    });
  });

  group('AiRecommendPill widget', () {
    testWidgets('渲染并响应点击', (WidgetTester tester) async {
      var pressed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AiRecommendPill(onPressed: () => pressed = true),
        ),
      ));

      // 查找按钮
      expect(find.byType(AiRecommendPill), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      // 点击
      await tester.tap(find.byType(InkWell));
      expect(pressed, isTrue);

      // 让 Future.delayed(2s) 的定时器触发，避免 pending timer 断言失败
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
