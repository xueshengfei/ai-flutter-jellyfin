import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 循环模式
enum RepeatMode { off, repeatAll, repeatOne }

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

  AudioPlayer get player => _player;

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
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.resume();
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

  // ==================== 内部方法 ====================

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
      );
      await _player.play(UrlSource(url));
    } catch (e) {
      _error = '播放失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupListeners() {
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      if (state == PlayerState.playing ||
          state == PlayerState.paused ||
          state == PlayerState.completed) {
        _isLoading = false;
      }
      notifyListeners();
    });

    _player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });

    _player.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });

    _player.onPlayerComplete.listen((_) {
      if (_repeatMode == RepeatMode.repeatOne) {
        _player.seek(Duration.zero);
        _player.resume();
      } else {
        playNext();
      }
    });
  }
}
