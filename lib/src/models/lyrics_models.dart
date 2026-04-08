import 'package:equatable/equatable.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;

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

  factory LyricsLine.fromDto(jellyfin_dart.LyricLine dto) {
    return LyricsLine(
      text: dto.text,
      startTicks: dto.start,
    );
  }

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

  factory LyricsMetadata.fromDto(jellyfin_dart.LyricMetadata dto) {
    return LyricsMetadata(
      isSynced: dto.isSynced,
      artist: dto.artist,
      album: dto.album,
      title: dto.title,
      lengthTicks: dto.length,
      offsetTicks: dto.offset,
    );
  }

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

  factory LyricsData.fromDto(jellyfin_dart.LyricDto dto) {
    return LyricsData(
      metadata: dto.metadata != null
          ? LyricsMetadata.fromDto(dto.metadata!)
          : null,
      lines: dto.lyrics?.map(LyricsLine.fromDto).toList() ?? [],
    );
  }

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

  factory RemoteLyricsInfo.fromDto(jellyfin_dart.RemoteLyricInfoDto dto) {
    return RemoteLyricsInfo(
      id: dto.id,
      providerName: dto.providerName,
      lyrics: dto.lyrics != null ? LyricsData.fromDto(dto.lyrics!) : null,
    );
  }

  @override
  List<Object?> get props => [id, providerName, lyrics];
}
