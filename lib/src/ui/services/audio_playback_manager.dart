import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 循环模式（内部使用）
enum RepeatMode { off, repeatAll, repeatOne }

/// 播放模式（UI 展示）
enum PlayMode { sequential, shuffle, repeatOne }

/// 全局音频播放管理器（ChangeNotifier 单例）
///
/// 持有 [AudioPlayer] + 播放列表 + 当前索引 + shuffle/repeat 状态，
/// 生命周期与应用一致，退出歌曲详情页后音乐继续播放。
class AudioPlaybackManager extends ChangeNotifier {
  AudioPlaybackManager._() {
    _setupListeners();
  }

  static final AudioPlaybackManager instance = AudioPlaybackManager._();

  final AudioPlayer _player = AudioPlayer();

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

  // Stream 订阅
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _processingStateSub;

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

  /// 当前播放模式
  PlayMode get playMode {
    if (_shuffleMode) return PlayMode.shuffle;
    if (_repeatMode == RepeatMode.repeatOne) return PlayMode.repeatOne;
    return PlayMode.sequential;
  }

  /// 位置变化流（替代原 audioplayers 的 onPositionChanged）
  Stream<Duration> get onPositionChanged => _positionController.stream;

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
    _isPlaying = false;
    notifyListeners();
    await _player.pause();
  }

  Future<void> resume() async {
    _isPlaying = true;
    notifyListeners();
    await _player.play();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
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
      await _player.seek(Duration.zero);
      return;
    }

    final len = _playlist.length;
    if (len <= 1) {
      await _player.seek(Duration.zero);
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

  /// 循环切换播放模式：顺序 → 随机 → 单曲循环 → 顺序
  void cyclePlayMode() {
    switch (playMode) {
      case PlayMode.sequential:
        _shuffleMode = true;
        _repeatMode = RepeatMode.off;
        _initShuffleOrder();
      case PlayMode.shuffle:
        _shuffleMode = false;
        _repeatMode = RepeatMode.repeatOne;
      case PlayMode.repeatOne:
        _shuffleMode = false;
        _repeatMode = RepeatMode.off;
    }
    notifyListeners();
  }

  // ==================== 内部方法 ====================

  /// 从歌曲元数据获取时长（ticks → Duration）
  Duration _durationFromSong(MusicSong song) {
    if (song.runTimeTicks != null && song.runTimeTicks! > 0) {
      return Duration(microseconds: song.runTimeTicks! ~/ 10);
    }
    if (song.runTimeSeconds != null && song.runTimeSeconds! > 0) {
      return Duration(seconds: song.runTimeSeconds!);
    }
    return Duration.zero;
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
    // 优先用歌曲元数据的时长（FLAC 等格式流播放时 just_audio 可能获取不到 duration）
    _duration = _durationFromSong(currentSong!);
    notifyListeners();

    try {
      final song = currentSong!;
      final url = _client!.music.getUniversalAudioStreamUrl(
        song.id,
        container: const ['mp3', 'aac'],
        audioCodec: 'mp3',
      );
      await _player.setUrl(url);
      _isLoading = false;
      notifyListeners();
      // play() 的 Future 在播放结束才完成，不能 await
      unawaited(_player.play());
    } catch (e) {
      _error = '播放失败: $e';
      _isLoading = false;
      _isPlaying = false;
      notifyListeners();
    }
  }

  void _onPlaybackComplete() {
    if (_repeatMode == RepeatMode.repeatOne) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      playNext();
    }
  }

  void _setupListeners() {
    _positionSub = _player.positionStream.listen((pos) {
      _position = pos;
      _positionController.add(_position);
      notifyListeners();
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });

    _playerStateSub = _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });

    _processingStateSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onPlaybackComplete();
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _processingStateSub?.cancel();
    _positionController.close();
    _player.dispose();
    super.dispose();
  }
}
