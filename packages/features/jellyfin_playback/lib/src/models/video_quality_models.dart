import 'dart:collection';

/// 视频画质档位
enum VideoQuality {
  auto('自动', null),
  p4k('4K', 15000000),
  p1080('1080P', 5000000),
  p720('720P', 2500000),
  p480('480P', 1000000);

  const VideoQuality(this.label, this.bitrate);

  /// 显示标签
  final String label;

  /// 目标码率 (bps)，auto 模式为 null
  final int? bitrate;
}

/// 网速采样记录
class _BandwidthSample {
  final int bytesDownloaded;
  final Duration duration;
  final DateTime timestamp;

  _BandwidthSample({
    required this.bytesDownloaded,
    required this.duration,
    required this.timestamp,
  });
}

/// 网络质量监测器
///
/// 通过滑动窗口采样估算当前带宽，推荐合适的画质档位
class NetworkQualityMonitor {
  /// 滑动窗口最大采样数
  static const int _maxSamples = 10;

  /// 窗口有效时长（超出此时间的采样丢弃）
  static const Duration _windowDuration = Duration(minutes: 3);

  /// 安全系数（推荐码率 = 带宽 × 安全系数）
  static const double _safetyFactor = 0.7;

  /// 采样队列
  final Queue<_BandwidthSample> _samples = Queue();

  /// 当前估算带宽 (bps)
  int _estimatedBandwidth = 0;

  /// 获取当前估算带宽
  int get estimatedBandwidth => _estimatedBandwidth;

  /// 当前使用的码率（用于自动模式）
  int _currentBitrate = 5000000;
  int get currentBitrate => _currentBitrate;
  set currentBitrate(int value) => _currentBitrate = value;

  /// 记录一次带宽采样
  void recordSample({required int bytesDownloaded, required Duration duration}) {
    if (bytesDownloaded <= 0 || duration.inMilliseconds <= 0) return;

    _samples.add(_BandwidthSample(
      bytesDownloaded: bytesDownloaded,
      duration: duration,
      timestamp: DateTime.now(),
    ));

    _trimWindow();
    _recalculate();
  }

  /// 从 buffering 事件推算带宽
  void recordFromBuffering({
    required int bufferedBytes,
    required Duration bufferDuration,
  }) {
    recordSample(bytesDownloaded: bufferedBytes, duration: bufferDuration);
  }

  /// 推荐画质档位
  VideoQuality recommendQuality() {
    if (_estimatedBandwidth <= 0) return VideoQuality.p1080;

    final safeBitrate = (_estimatedBandwidth * _safetyFactor).round();

    if (safeBitrate >= VideoQuality.p4k.bitrate!) return VideoQuality.p4k;
    if (safeBitrate >= VideoQuality.p1080.bitrate!) return VideoQuality.p1080;
    if (safeBitrate >= VideoQuality.p720.bitrate!) return VideoQuality.p720;
    return VideoQuality.p480;
  }

  /// 裁剪窗口，移除过期采样
  void _trimWindow() {
    final cutoff = DateTime.now().subtract(_windowDuration);
    while (_samples.isNotEmpty && _samples.first.timestamp.isBefore(cutoff)) {
      _samples.removeFirst();
    }
    while (_samples.length > _maxSamples) {
      _samples.removeFirst();
    }
  }

  /// 重新计算估算带宽
  void _recalculate() {
    if (_samples.isEmpty) return;

    int totalBytes = 0;
    int totalMicroseconds = 0;
    for (final sample in _samples) {
      totalBytes += sample.bytesDownloaded;
      totalMicroseconds += sample.duration.inMicroseconds;
    }

    if (totalMicroseconds <= 0) return;

    _estimatedBandwidth = (totalBytes / totalMicroseconds * 1000000 * 8).round();
  }

  /// 重置所有采样
  void reset() {
    _samples.clear();
    _estimatedBandwidth = 0;
  }
}

/// 自动画质切换决策器
///
/// 实现防抖逻辑：降级立即执行，升级需要多次确认
class AutoQualityDecider {
  int _consecutiveCount = 0;
  VideoQuality? _lastRecommended;

  /// 降级需要的确认次数（立即执行 = 1）
  static const int _downgradeThreshold = 1;

  /// 升级需要的确认次数
  static const int _upgradeThreshold = 3;

  /// 判断是否应该切换画质
  ///
  /// 返回 null 表示不切换，返回 VideoQuality 表示应该切换到该画质
  VideoQuality? shouldSwitch(VideoQuality recommended, VideoQuality current) {
    if (recommended == current) {
      _consecutiveCount = 0;
      _lastRecommended = null;
      return null;
    }

    if (recommended == _lastRecommended) {
      _consecutiveCount++;
    } else {
      _consecutiveCount = 1;
      _lastRecommended = recommended;
    }

    final isDowngrade = recommended.bitrate != null &&
        current.bitrate != null &&
        recommended.bitrate! < current.bitrate!;

    final threshold = isDowngrade ? _downgradeThreshold : _upgradeThreshold;

    if (_consecutiveCount >= threshold) {
      _consecutiveCount = 0;
      _lastRecommended = null;
      return recommended;
    }

    return null;
  }

  /// 重置状态
  void reset() {
    _consecutiveCount = 0;
    _lastRecommended = null;
  }
}
