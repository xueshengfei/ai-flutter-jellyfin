import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_playback/jellyfin_playback.dart';

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
      monitor.recordSample(bytesDownloaded: 0, duration: const Duration(seconds: 1));
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
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p1080), isNull);
    });

    test('降级立即执行', () {
      final decider = AutoQualityDecider();
      // 1080P → 480P (降级)
      final result = decider.shouldSwitch(VideoQuality.p480, VideoQuality.p1080);
      expect(result, VideoQuality.p480);
    });

    test('升级需要 3 次确认', () {
      final decider = AutoQualityDecider();
      // 480P → 1080P (升级)
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), VideoQuality.p1080);
    });

    test('改变推荐目标重置计数', () {
      final decider = AutoQualityDecider();
      // 先推荐 720P
      expect(decider.shouldSwitch(VideoQuality.p720, VideoQuality.p480), isNull);
      // 改为推荐 1080P
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), VideoQuality.p1080);
    });

    test('reset 清除状态', () {
      final decider = AutoQualityDecider();
      decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480);
      decider.reset();
      // 重新开始，需要 3 次
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), isNull);
      expect(decider.shouldSwitch(VideoQuality.p1080, VideoQuality.p480), VideoQuality.p1080);
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
        getPlaybackUrl: ({required itemId, startTimeTicks, maxStreamingBitrate}) async {
          getUrlCalled = true;
          return const PlaybackInfo(url: 'http://test', playSessionId: 's1');
        },
        startSession: ({required itemId, required sessionIds}) async {},
        switchQuality: ({required itemId, required quality, required currentPosition}) async {
          return const PlaybackInfo(url: 'http://test', playSessionId: 's2');
        },
        stopEncoding: (sessionId) async {},
        stopSession: () async { stopCalled = true; },
        dispose: () {},
      );

      final info = await delegate.getPlaybackUrl(itemId: 'item1');
      expect(getUrlCalled, true);
      expect(info.playSessionId, 's1');

      await delegate.stopSession();
      expect(stopCalled, true);
    });
  });
}
