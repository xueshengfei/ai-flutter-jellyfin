import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_playback/jellyfin_playback.dart';
import 'package:jellyfin_playback/jellyfin_playback_pages.dart';

void main() {
  group('VideoQuality', () {
    test('各画质有正确的 label 和 bitrate', () {
      expect(VideoQuality.auto.label, '自动');
      expect(VideoQuality.auto.bitrate, isNull);
      expect(VideoQuality.p4k.label, '4K');
      expect(VideoQuality.p4k.bitrate, 15000000);
      expect(VideoQuality.p1080.label, '1080P');
      expect(VideoQuality.p1080.bitrate, 5000000);
      expect(VideoQuality.p720.label, '720P');
      expect(VideoQuality.p720.bitrate, 2500000);
      expect(VideoQuality.p480.label, '480P');
      expect(VideoQuality.p480.bitrate, 1000000);
    });

    test('有 5 种画质', () {
      expect(VideoQuality.values.length, 5);
    });
  });

  group('NetworkQualityMonitor', () {
    test('初始带宽为 0', () {
      final monitor = NetworkQualityMonitor();
      expect(monitor.estimatedBandwidth, 0);
    });

    test('记录采样后更新带宽', () {
      final monitor = NetworkQualityMonitor();
      // 1MB in 1 second = 8 Mbps
      monitor.recordSample(
        bytesDownloaded: 1000000,
        duration: const Duration(seconds: 1),
      );
      expect(monitor.estimatedBandwidth, greaterThan(0));
      // 应该接近 8 Mbps (8,000,000 bps)
      expect(monitor.estimatedBandwidth, closeTo(8000000, 100000));
    });

    test('多次采样取平均', () {
      final monitor = NetworkQualityMonitor();
      // 两次采样: 1MB/1s + 2MB/1s = 3MB/2s = 12 Mbps
      monitor.recordSample(
        bytesDownloaded: 1000000,
        duration: const Duration(seconds: 1),
      );
      monitor.recordSample(
        bytesDownloaded: 2000000,
        duration: const Duration(seconds: 1),
      );
      expect(monitor.estimatedBandwidth, closeTo(12000000, 200000));
    });

    test('低带宽推荐低画质', () {
      final monitor = NetworkQualityMonitor();
      // 100KB in 1 second = 0.8 Mbps
      monitor.recordSample(
        bytesDownloaded: 100000,
        duration: const Duration(seconds: 1),
      );
      // 0.8 * 0.7 = 0.56 → 480P
      expect(monitor.recommendQuality(), VideoQuality.p480);
    });

    test('高带宽推荐高画质', () {
      final monitor = NetworkQualityMonitor();
      // 3MB in 1 second = 24 Mbps
      monitor.recordSample(
        bytesDownloaded: 3000000,
        duration: const Duration(seconds: 1),
      );
      // 24 * 0.7 = 16.8 → 4K
      expect(monitor.recommendQuality(), VideoQuality.p4k);
    });

    test('无采样时默认推荐 1080P', () {
      final monitor = NetworkQualityMonitor();
      expect(monitor.recommendQuality(), VideoQuality.p1080);
    });

    test('忽略无效采样', () {
      final monitor = NetworkQualityMonitor();
      monitor.recordSample(
          bytesDownloaded: 0, duration: const Duration(seconds: 1));
      monitor.recordSample(bytesDownloaded: 100, duration: Duration.zero);
      expect(monitor.estimatedBandwidth, 0);
    });

    test('reset 清除所有采样', () {
      final monitor = NetworkQualityMonitor();
      monitor.recordSample(
        bytesDownloaded: 1000000,
        duration: const Duration(seconds: 1),
      );
      expect(monitor.estimatedBandwidth, greaterThan(0));
      monitor.reset();
      expect(monitor.estimatedBandwidth, 0);
    });

    test('recordFromBuffering 委托给 recordSample', () {
      final monitor = NetworkQualityMonitor();
      monitor.recordFromBuffering(
        bufferedBytes: 500000,
        bufferDuration: const Duration(milliseconds: 500),
      );
      expect(monitor.estimatedBandwidth, greaterThan(0));
    });
  });

  group('AutoQualityDecider', () {
    test('相同画质不切换', () {
      final decider = AutoQualityDecider();
      expect(
          decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p1080), isNull);
    });

    test('降级立即执行', () {
      final decider = AutoQualityDecider();
      // 1080P → 480P (降级)
      final result =
          decider.shouldSwitch(VideoQuality.p480, VideoQuality.p1080);
      expect(result, VideoQuality.p480);
    });

    test('升级需要 3 次确认', () {
      final decider = AutoQualityDecider();
      // 480P → 1080P (升级)
      expect(
          decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(
          decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480),
          VideoQuality.p1080);
    });

    test('改变推荐目标重置计数', () {
      final decider = AutoQualityDecider();
      // 先推荐 720P
      expect(
          decider.shouldSwitch(VideoQuality.p720, VideoQuality.p480), isNull);
      // 改为推荐 1080P
      expect(
          decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(
          decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480),
          VideoQuality.p1080);
    });

    test('reset 清除状态', () {
      final decider = AutoQualityDecider();
      decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480);
      decider.reset();
      // 重新开始，需要 3 次
      expect(
          decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(
          decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480),
          VideoQuality.p1080);
    });
  });

  group('PlaybackInfo', () {
    test('构造和字段访问', () {
      const info = PlaybackInfo(
        url: 'http://example.com/video.mp4',
        playSessionId: 'session123',
        isTranscoded: false,
      );
      expect(info.url, 'http://example.com/video.mp4');
      expect(info.playSessionId, 'session123');
      expect(info.isTranscoded, false);
      expect(info.actualBitrate, isNull);
    });

    test('转码流带码率', () {
      const info = PlaybackInfo(
        url: 'http://example.com/transcode.ts',
        playSessionId: 'session456',
        isTranscoded: true,
        actualBitrate: 5000000,
      );
      expect(info.isTranscoded, true);
      expect(info.actualBitrate, 5000000);
    });
  });

  group('PlaybackDelegate', () {
    test('构造并调用回调', () async {
      var getUrlCalled = false;
      var stopCalled = false;

      final delegate = PlaybackDelegate(
        getPlaybackUrl: (
            {required itemId, startTimeTicks, maxStreamingBitrate}) async {
          getUrlCalled = true;
          return const PlaybackInfo(url: 'http://test', playSessionId: 's1');
        },
        startSession: ({required itemId, required sessionIds}) async {},
        switchQuality: (
            {required itemId,
            required quality,
            required currentPosition}) async {
          return const PlaybackInfo(url: 'http://test', playSessionId: 's2');
        },
        stopEncoding: (sessionId) async {},
        stopSession: () async {
          stopCalled = true;
        },
        dispose: () {},
      );

      final info = await delegate.getPlaybackUrl(itemId: 'item1');
      expect(getUrlCalled, true);
      expect(info.playSessionId, 's1');

      await delegate.stopSession();
      expect(stopCalled, true);
    });
  });

  group('WatchAssistType', () {
    test('有正确的后端值、文案和剧透要求', () {
      expect(WatchAssistType.currentStage.apiValue, 'current_stage');
      expect(WatchAssistType.currentStage.label, '当前阶段');
      expect(WatchAssistType.currentStage.requiresSpoiler, false);
      expect(WatchAssistType.plotSummary.apiValue, 'plot_summary');
      expect(WatchAssistType.plotSummary.label, '全文概括');
      expect(WatchAssistType.characterAnalysis.apiValue, 'character_analysis');
      expect(WatchAssistType.characterAnalysis.label, '人物解析');
      expect(WatchAssistType.themeAnalysis.apiValue, 'theme_analysis');
      expect(WatchAssistType.themeAnalysis.label, '主题寓意');
      expect(WatchAssistType.endingExplanation.apiValue, 'ending_explanation');
      expect(WatchAssistType.endingExplanation.label, '结局解析');
      expect(WatchAssistType.endingExplanation.requiresSpoiler, true);
    });

    test('fromApiValue 未知值回退到 currentStage', () {
      expect(
        WatchAssistType.fromApiValue('character_analysis'),
        WatchAssistType.characterAnalysis,
      );
      expect(
        WatchAssistType.fromApiValue('unknown'),
        WatchAssistType.currentStage,
      );
    });
  });

  group('WatchAssistResponse', () {
    test('解析 watch_assist_v2 activeContent 和按钮列表', () {
      final response = WatchAssistResponse.fromJson({
        'schemaVersion': 'watch_assist_v2',
        'itemId': 'movie-1',
        'title': 'AI 解读',
        'mode': 'safe',
        'requestedAssistType': 'character_analysis',
        'assistType': 'character_analysis',
        'assistTypeLabel': '人物解析',
        'availableAssistTypes': [
          {
            'type': 'current_stage',
            'label': '当前阶段',
            'requiresSpoiler': false,
          },
          {
            'type': 'ending_explanation',
            'label': '结局解析',
            'requiresSpoiler': true,
          },
        ],
        'capabilityLabel': '基于进度',
        'notice': '未检测到可用字幕',
        'progress': {
          'positionSeconds': 4200,
          'stage': '中段：关系变化',
        },
        'activeContent': {
          'title': '人物解析',
          'text': '重点观察人物关系。',
          'items': ['主角立场变化'],
        },
      });

      expect(response.schemaVersion, 'watch_assist_v2');
      expect(response.mode, WatchAssistSpoilerMode.safe);
      expect(response.requestedAssistType, WatchAssistType.characterAnalysis);
      expect(response.assistType, WatchAssistType.characterAnalysis);
      expect(response.capabilityLabel, '基于进度');
      expect(response.notice, '未检测到可用字幕');
      expect(response.progressStage, '中段：关系变化');
      expect(response.activeContent.title, '人物解析');
      expect(response.activeContent.items, ['主角立场变化']);
      expect(response.availableAssistTypes.length, 2);
      expect(
        response.availableAssistTypes.last.type,
        WatchAssistType.endingExplanation,
      );
      expect(response.availableAssistTypes.last.requiresSpoiler, true);
    });

    test('缺失可选字段时使用安全兜底', () {
      final response = WatchAssistResponse.fromJson({});

      expect(response.schemaVersion, '');
      expect(response.itemId, '');
      expect(response.mode, WatchAssistSpoilerMode.safe);
      expect(response.requestedAssistType, WatchAssistType.currentStage);
      expect(response.assistType, WatchAssistType.currentStage);
      expect(response.activeContent.title, '');
      expect(response.activeContent.text, '');
      expect(response.activeContent.items, isEmpty);
      expect(response.availableAssistTypes, isEmpty);
    });
  });

  group('WatchAssist widgets', () {
    testWidgets('WatchAssistButton 点击会触发回调', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatchAssistButton(
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('AI 解读'));
      expect(tapped, true);
    });

    testWidgets('WatchAssistSheet 首次打开请求 safe current_stage', (tester) async {
      final requests = <WatchAssistRequest>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatchAssistSheet(
              itemId: 'movie-1',
              initialPositionSeconds: 42,
              fetchWatchAssist: (request) async {
                requests.add(request);
                return _watchAssistResponse(
                  assistType: WatchAssistType.currentStage,
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(requests, hasLength(1));
      expect(requests.single.itemId, 'movie-1');
      expect(requests.single.positionSeconds, 42);
      expect(requests.single.spoilerMode, WatchAssistSpoilerMode.safe);
      expect(requests.single.assistType, WatchAssistType.currentStage);
      expect(find.text('当前阶段内容'), findsOneWidget);
    });

    testWidgets('WatchAssistSheet 点击人物解析后重新请求', (tester) async {
      final requests = <WatchAssistRequest>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatchAssistSheet(
              itemId: 'movie-1',
              initialPositionSeconds: 42,
              fetchWatchAssist: (request) async {
                requests.add(request);
                return _watchAssistResponse(assistType: request.assistType);
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('人物解析'));
      await tester.pump();
      await tester.pump();

      expect(requests, hasLength(2));
      expect(requests.last.assistType, WatchAssistType.characterAnalysis);
      expect(find.text('人物解析内容'), findsOneWidget);
    });

    testWidgets('WatchAssistSheet 请求失败时展示错误和重试', (tester) async {
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatchAssistSheet(
              itemId: 'movie-1',
              initialPositionSeconds: 42,
              fetchWatchAssist: (_) async {
                calls += 1;
                if (calls == 1) {
                  throw StateError('network down');
                }
                return _watchAssistResponse(
                  assistType: WatchAssistType.currentStage,
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      expect(find.textContaining('network down'), findsOneWidget);

      await tester.tap(find.text('重试'));
      await tester.pump();
      await tester.pump();

      expect(calls, 2);
      expect(find.text('当前阶段内容'), findsOneWidget);
    });
  });
}

WatchAssistResponse _watchAssistResponse({
  required WatchAssistType assistType,
}) {
  return WatchAssistResponse(
    schemaVersion: 'watch_assist_v2',
    itemId: 'movie-1',
    title: 'AI 解读',
    mode: WatchAssistSpoilerMode.safe,
    requestedAssistType: assistType,
    assistType: assistType,
    assistTypeLabel: assistType.label,
    availableAssistTypes: const [
      WatchAssistTypeOption(
        type: WatchAssistType.currentStage,
        label: '当前阶段',
        requiresSpoiler: false,
      ),
      WatchAssistTypeOption(
        type: WatchAssistType.characterAnalysis,
        label: '人物解析',
        requiresSpoiler: false,
      ),
    ],
    capabilityLabel: '基于进度',
    notice: '',
    progressStage: '中段：关系变化',
    activeContent: WatchAssistContent(
      title: assistType.label,
      text: '${assistType.label}内容',
      items: const ['要点一'],
    ),
  );
}
