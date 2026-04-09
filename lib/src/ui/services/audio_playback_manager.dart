import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 循环模式
enum RepeatMode { off, repeatAll, repeatOne }

/// 全局音频播放管理器（ChangeNotifier 单例）
///
/// 持有 [FlutterSoundPlayer] + 播放列表 + 当前索引 + shuffle/repeat 状态，
/// 生命周期与应用一致，退出歌曲详情页后音乐继续播放。
class AudioPlaybackManager extends ChangeNotifier {
  AudioPlaybackManager._() {
    _init();
  }

  static final AudioPlaybackManager instance = AudioPlaybackManager._();

  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  List<MusicSong> _playlist = [];
  int _currentIndex = 0;
  JellyfinClient? _client;

  // Shuffle / Repeat
  bool _shuffleMode = false;
  RepeatMode _repeatMode = RepeatMode.off;
  List<int> _shuffleOrder = [];
  int _shufflePosition = 0;

  // 缓存的播放状态
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _error;

  // 位置流（供外部订阅实时位置更新）
  final _positionController = StreamController<Duration>.broadcast();

  // ==================== 公开 getter ====================

  MusicSong? get currentSong =>
      _playlist.isNotEmpty ? _playlist[_currentIndex] : null;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get hasPlaylist => _playlist.isNotEmpty;
  int get playlistLength => _playlist.length;
  int get currentIndex => _currentIndex;
  bool get shuffleMode => _shuffleMode;
  RepeatMode get repeatMode => _repeatMode;
  String? get error => _error;
  List<MusicSong> get playlist => List.unmodifiable(_playlist);

  /// 位置变化流（替代原 audioplayers 的 onPositionChanged）
  Stream<Duration> get onPositionChanged => _positionController.stream;

  FlutterSoundPlayer get player => _player;

  /// 用于UI显示和进度条的可靠时长
  ///
  /// 优先使用歌曲模型的 runTimeSeconds（来自 Jellyfin API，准确），
  /// 回退到播放器报告的 duration（鸿蒙平台部分音频流可能不准确）。
  Duration get displayDuration {
    final songSeconds = currentSong?.runTimeSeconds;
    if (songSeconds != null && songSeconds > 0) {
      final modelMs = songSeconds * 1000;
      // 播放器时长偏差超过 50% 或超过 1 小时 → 使用模型时长
      if (_duration.inMilliseconds > modelMs * 1.5 ||
          _duration.inSeconds > 3600) {
        return Duration(milliseconds: modelMs);
      }
    }
    return _duration;
  }

  // ==================== 核心方法 ====================

  Future<void> play(
    List<MusicSong> playlist,
    int startIndex,
    JellyfinClient client,
  ) async {
    _client = client;
    _playlist = List.of(playlist);
    _currentIndex = startIndex;
    _initShuffleOrder();
    await _playSong();
  }

  Future<void> pause() async {
    await _player.pausePlayer();
  }

  Future<void> resume() async {
    await _player.resumePlayer();
  }

  Future<void> seek(Duration position) async {
    await _player.seekToPlayer(position);
  }

  Future<void> playNext() async {
    final len = _playlist.length;
    if (len <= 1 && _repeatMode != RepeatMode.repeatAll) return;

    if (_shuffleMode) {
      _shufflePosition++;
      if (_shufflePosition >= len) {
        if (_repeatMode == RepeatMode.repeatAll) {
          _initShuffleOrder();
        } else {
          return;
        }
      }
      _currentIndex = _shuffleOrder[_shufflePosition];
    } else {
      if (_currentIndex < len - 1) {
        _currentIndex++;
      } else if (_repeatMode == RepeatMode.repeatAll) {
        _currentIndex = 0;
      } else {
        return;
      }
    }
    notifyListeners();
    await _playSong();
  }

  Future<void> playPrevious() async {
    // 播放超过 3 秒先回到开头
    if (_position.inSeconds >= 3) {
      await _player.seekToPlayer(Duration.zero);
      return;
    }

    final len = _playlist.length;
    if (len <= 1) {
      await _player.seekToPlayer(Duration.zero);
      return;
    }

    if (_shuffleMode) {
      if (_shufflePosition > 0) {
        _shufflePosition--;
      } else {
        _shufflePosition = len - 1;
      }
      _currentIndex = _shuffleOrder[_shufflePosition];
    } else {
      if (_currentIndex > 0) {
        _currentIndex--;
      } else {
        _currentIndex = len - 1;
      }
    }
    notifyListeners();
    await _playSong();
  }

  void toggleShuffle() {
    _shuffleMode = !_shuffleMode;
    if (_shuffleMode) _initShuffleOrder();
    notifyListeners();
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.repeatAll;
      case RepeatMode.repeatAll:
        _repeatMode = RepeatMode.repeatOne;
      case RepeatMode.repeatOne:
        _repeatMode = RepeatMode.off;
    }
    notifyListeners();
  }

  // ==================== 内部方法 ====================

  Future<void> _init() async {
    await _player.openPlayer();
    _player.setSubscriptionDuration(const Duration(milliseconds: 200));
    _setupListeners();
  }

  void _initShuffleOrder() {
    _shuffleOrder = List.generate(_playlist.length, (i) => i);
    _shuffleOrder.shuffle();
    // Ensure current song is first in shuffle
    _shuffleOrder.remove(_currentIndex);
    _shuffleOrder.insert(0, _currentIndex);
    _shufflePosition = 0;
  }

  Future<void> _playSong() async {
    if (_client == null || _playlist.isEmpty) return;
    _isLoading = true;
    _error = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();

    try {
      final song = currentSong!;
      final url = _client!.music.getUniversalAudioStreamUrl(
        song.id,
        container: const ['mp3', 'aac'],
        audioCodec: 'mp3',
      );
      await _player.startPlayer(
        fromURI: url,
        whenFinished: _onPlaybackComplete,
      );
      _isPlaying = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '播放失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onPlaybackComplete() {
    if (_repeatMode == RepeatMode.repeatOne) {
      _player.seekToPlayer(Duration.zero);
      _player.resumePlayer();
    } else {
      playNext();
    }
  }

  void _setupListeners() {
    _player.onProgress!.listen((event) {
      if (event.duration != null) {
        print('🔔 flutter_sound duration: ${event.duration} (inSeconds=${event.duration!.inSeconds}, inMilliseconds=${event.duration!.inMilliseconds})');
        _duration = event.duration!;
      }
      if (event.position != null) {
        _position = event.position!;
        _positionController.add(_position);
      }
      _isPlaying = _player.isPlaying;
      notifyListeners();
    });
  }
}
