import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:jellyfin_music/jellyfin_music.dart' as music;

import 'audio_cache_manager.dart';

/// 基于 just_audio 的音频播放适配器
///
/// 实现 [AudioPlaybackPort] 接口，单例模式。
/// 生命周期与 App 一致，退出播放页后音乐继续。
/// 支持 LRU 音频缓存，播放过的歌曲自动缓存到本地。
class AudioPlaybackAdapter extends music.AudioPlaybackPort {
  AudioPlaybackAdapter._() {
    _setupListeners();
  }

  static final AudioPlaybackAdapter instance = AudioPlaybackAdapter._();

  final AudioPlayer _player = AudioPlayer();
  final AudioCacheManager _cacheManager = AudioCacheManager();

  List<music.AudioTrack> _playlist = [];
  int _currentIndex = 0;

  // Shuffle / Repeat
  bool _shuffleMode = false;
  _RepeatMode _repeatMode = _RepeatMode.off;
  List<int> _shuffleOrder = [];
  int _shufflePosition = 0;

  // 缓存的播放状态
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _error;

  // 位置流
  final _positionController = StreamController<Duration>.broadcast();

  // Stream 订阅
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _processingStateSub;

  // ==================== AudioPlaybackPort 实现 ====================

  @override
  music.AudioTrack? get currentTrack =>
      _playlist.isNotEmpty ? _playlist[_currentIndex] : null;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  bool get hasPlaylist => _playlist.isNotEmpty;

  @override
  List<music.AudioTrack> get playlist => List.unmodifiable(_playlist);

  @override
  int get playlistLength => _playlist.length;

  @override
  int get currentIndex => _currentIndex;

  @override
  music.PlayMode get playMode {
    if (_shuffleMode) return music.PlayMode.shuffle;
    if (_repeatMode == _RepeatMode.repeatOne) return music.PlayMode.repeatOne;
    return music.PlayMode.sequential;
  }

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Future<void> playSong(
    music.AudioTrack track,
    List<music.AudioTrack> playlist,
    int startIndex,
  ) async {
    _playlist = List.of(playlist);
    _currentIndex = startIndex;
    _initShuffleOrder();
    await _playCurrentTrack();
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    notifyListeners();
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    _isPlaying = true;
    notifyListeners();
    await _player.play();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> playNext() async {
    final len = _playlist.length;
    if (len <= 1 && _repeatMode != _RepeatMode.repeatAll) return;

    if (_shuffleMode) {
      _shufflePosition++;
      if (_shufflePosition >= len) {
        if (_repeatMode == _RepeatMode.repeatAll) {
          _initShuffleOrder();
        } else {
          return;
        }
      }
      _currentIndex = _shuffleOrder[_shufflePosition];
    } else {
      if (_currentIndex < len - 1) {
        _currentIndex++;
      } else if (_repeatMode == _RepeatMode.repeatAll) {
        _currentIndex = 0;
      } else {
        return;
      }
    }
    notifyListeners();
    await _playCurrentTrack();
  }

  @override
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
    await _playCurrentTrack();
  }

  @override
  void toggleShuffle() {
    _shuffleMode = !_shuffleMode;
    if (_shuffleMode) _initShuffleOrder();
    notifyListeners();
  }

  @override
  void cycleRepeatMode() {
    switch (_repeatMode) {
      case _RepeatMode.off:
        _repeatMode = _RepeatMode.repeatAll;
      case _RepeatMode.repeatAll:
        _repeatMode = _RepeatMode.repeatOne;
      case _RepeatMode.repeatOne:
        _repeatMode = _RepeatMode.off;
    }
    notifyListeners();
  }

  @override
  void cyclePlayMode() {
    switch (playMode) {
      case music.PlayMode.sequential:
        _shuffleMode = true;
        _repeatMode = _RepeatMode.off;
        _initShuffleOrder();
      case music.PlayMode.shuffle:
        _shuffleMode = false;
        _repeatMode = _RepeatMode.repeatOne;
      case music.PlayMode.repeatOne:
        _shuffleMode = false;
        _repeatMode = _RepeatMode.off;
    }
    notifyListeners();
  }

  @override
  void updateTrackFavorite(String trackId, bool isFavorite) {
    final idx = _playlist.indexWhere((t) => t.id == trackId);
    if (idx == -1) return;
    final old = _playlist[idx];
    _playlist[idx] = music.AudioTrack(
      id: old.id,
      name: old.name,
      streamUrl: old.streamUrl,
      coverUrl: old.coverUrl,
      artistText: old.artistText,
      duration: old.duration,
      albumName: old.albumName,
      trackNumber: old.trackNumber,
      isFavorite: isFavorite,
      path: old.path,
    );
    notifyListeners();
  }

  // ==================== 内部方法 ====================

  void _initShuffleOrder() {
    _shuffleOrder = List.generate(_playlist.length, (i) => i);
    _shuffleOrder.shuffle();
    _shuffleOrder.remove(_currentIndex);
    _shuffleOrder.insert(0, _currentIndex);
    _shufflePosition = 0;
  }

  Future<void> _playCurrentTrack() async {
    if (_playlist.isEmpty) return;
    _isLoading = true;
    _error = null;
    _position = Duration.zero;
    _duration = currentTrack?.duration ?? Duration.zero;
    notifyListeners();

    try {
      final track = currentTrack!;

      // 优先使用缓存
      final cachedFile = await _cacheManager.getCacheFile(track.id);
      if (cachedFile != null) {
        await _player.setFilePath(cachedFile.path);
      } else {
        await _player.setUrl(track.streamUrl);
        // 后台缓存，不阻塞播放
        _cacheManager.cacheInBackground(track.id, track.streamUrl);
      }

      _isLoading = false;
      notifyListeners();
      unawaited(_player.play());
    } catch (e) {
      _error = '播放失败: $e';
      _isLoading = false;
      _isPlaying = false;
      notifyListeners();
    }
  }

  void _onPlaybackComplete() {
    if (_repeatMode == _RepeatMode.repeatOne) {
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

/// 内部循环模式
enum _RepeatMode { off, repeatAll, repeatOne }
