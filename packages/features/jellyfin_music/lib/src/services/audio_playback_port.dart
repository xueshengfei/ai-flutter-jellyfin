import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

/// 音轨抽象数据
///
/// 不依赖具体 MusicSong 模型，feature 包只使用此抽象。
/// 根包负责 AudioTrack ↔ MusicSong 的转换。
class AudioTrack extends Equatable {
  /// 唯一标识（对应 Jellyfin ItemId）
  final String id;

  /// 歌曲名称
  final String name;

  /// 音频流 URL
  final String streamUrl;

  /// 封面图 URL
  final String? coverUrl;

  /// 艺术家文本（如 "Artist A / Artist B"）
  final String? artistText;

  /// 歌曲时长
  final Duration? duration;

  /// 专辑名称
  final String? albumName;

  /// 音轨编号
  final int? trackNumber;

  /// 是否收藏
  final bool? isFavorite;

  const AudioTrack({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.coverUrl,
    this.artistText,
    this.duration,
    this.albumName,
    this.trackNumber,
    this.isFavorite,
  });

  @override
  List<Object?> get props => [id, name, streamUrl];
}

/// 音频播放器抽象接口
///
/// 根包 [AudioPlaybackManager] 实现此接口。
/// Feature 包只依赖接口，不依赖 just_audio 等具体实现。
abstract class AudioPlaybackPort extends ChangeNotifier {
  // ==================== 播放控制 ====================

  /// 播放指定音轨
  Future<void> playSong(AudioTrack track, List<AudioTrack> playlist, int startIndex);

  /// 暂停播放
  Future<void> pause();

  /// 恢复播放
  Future<void> resume();

  /// 跳转到指定位置
  Future<void> seek(Duration position);

  /// 播放下一首
  Future<void> playNext();

  /// 播放上一首
  Future<void> playPrevious();

  // ==================== 状态查询 ====================

  /// 当前播放的音轨
  AudioTrack? get currentTrack;

  /// 是否正在播放
  bool get isPlaying;

  /// 当前播放位置
  Duration get position;

  /// 音轨总时长
  Duration get duration;

  /// 是否有播放列表
  bool get hasPlaylist;

  /// 播放列表
  List<AudioTrack> get playlist;

  /// 当前播放索引
  int get currentIndex;

  // ==================== 播放模式 ====================

  /// 切换随机播放
  void toggleShuffle();

  /// 循环切换重复模式
  void cycleRepeatMode();
}
