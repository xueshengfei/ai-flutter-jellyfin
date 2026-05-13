import 'package:equatable/equatable.dart';

/// 歌词行（业务模型）
class LyricsLine extends Equatable {
  final String? text;
  final int? startTicks;

  const LyricsLine({
    this.text,
    this.startTicks,
  });

  /// ticks 转 Duration：10,000,000 ticks = 1 秒
  Duration? get startTime =>
      startTicks != null ? Duration(microseconds: startTicks! ~/ 10) : null;

  @override
  List<Object?> get props => [text, startTicks];
}

/// 歌词元数据（业务模型）
class LyricsMetadata extends Equatable {
  final bool? isSynced;
  final String? artist;
  final String? album;
  final String? title;
  final int? lengthTicks;
  final int? offsetTicks;

  const LyricsMetadata({
    this.isSynced,
    this.artist,
    this.album,
    this.title,
    this.lengthTicks,
    this.offsetTicks,
  });

  @override
  List<Object?> get props => [isSynced, artist, album, title, lengthTicks, offsetTicks];
}

/// 歌词数据（业务模型）
class LyricsData extends Equatable {
  final LyricsMetadata? metadata;
  final List<LyricsLine> lines;

  const LyricsData({
    this.metadata,
    required this.lines,
  });

  /// 是否为同步歌词（有时间戳）
  bool get isSynced =>
      metadata?.isSynced == true ||
      lines.any((line) => line.startTicks != null);

  /// 是否有歌词内容
  bool get hasLyrics => lines.isNotEmpty;

  @override
  List<Object?> get props => [metadata, lines];
}

/// 远程歌词信息（业务模型）
class RemoteLyricsInfo extends Equatable {
  final String? id;
  final String? providerName;
  final LyricsData? lyrics;

  const RemoteLyricsInfo({
    this.id,
    this.providerName,
    this.lyrics,
  });

  @override
  List<Object?> get props => [id, providerName, lyrics];
}
