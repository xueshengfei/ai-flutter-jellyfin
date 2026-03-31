import 'package:equatable/equatable.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;

/// 音乐专辑（业务模型）
class MusicAlbum extends Equatable {
  final String id;
  final String name;
  final String? sortName;
  final int? productionYear;
  final List<String>? artists;
  final List<String>? genres;
  final int? songCount;
  final double? communityRating;
  final String? overview;
  final String? primaryImageTag;
  final String? backdropImageTag;
  final String serverUrl;
  final String? accessToken;
  final String? parentId;

  const MusicAlbum({
    required this.id,
    required this.name,
    required this.serverUrl,
    this.sortName,
    this.productionYear,
    this.artists,
    this.genres,
    this.songCount,
    this.communityRating,
    this.overview,
    this.primaryImageTag,
    this.backdropImageTag,
    this.accessToken,
    this.parentId,
  });

  factory MusicAlbum.fromDto(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final imageTags = dto.imageTags;
    final primaryTag = imageTags?['Primary'];
    final hasImageTag = primaryTag != null && primaryTag.isNotEmpty;
    final hasBlurHash = dto.imageBlurHashes != null;
    final hasImage = hasImageTag || hasBlurHash;

    final backdropTags = dto.backdropImageTags;
    final hasBackdrop = backdropTags != null && backdropTags.isNotEmpty;

    // 提取艺术家名称
    final artists = <String>[];
    if (dto.albumArtists != null) {
      for (final a in dto.albumArtists!) {
        if (a.name != null) artists.add(a.name!);
      }
    }
    if (artists.isEmpty && dto.artists != null) {
      artists.addAll(dto.artists!);
    }

    return MusicAlbum(
      id: dto.id ?? '',
      name: dto.name ?? '未知专辑',
      sortName: dto.sortName,
      serverUrl: serverUrl,
      productionYear: dto.productionYear,
      artists: artists.isNotEmpty ? artists : null,
      genres: dto.genres,
      songCount: dto.childCount,
      communityRating: dto.communityRating,
      overview: dto.overview,
      primaryImageTag: hasImageTag ? primaryTag : (hasImage ? 'has_image' : null),
      backdropImageTag: hasBackdrop ? backdropTags.first : null,
      accessToken: accessToken,
      parentId: dto.parentId,
    );
  }

  /// 获取封面图URL
  String? getCoverImageUrl({int? fillWidth, int? fillHeight}) {
    if (primaryImageTag == null) return null;
    var url = '$serverUrl/Items/$id/Images/Primary?tag=$primaryImageTag';
    if (fillWidth != null) url += '&fillWidth=$fillWidth';
    if (fillHeight != null) url += '&fillHeight=$fillHeight';
    return url;
  }

  bool get hasCoverImage => primaryImageTag != null;

  /// 获取艺术家显示文本
  String get artistText => artists?.join(' / ') ?? '未知艺术家';

  @override
  List<Object?> get props => [id, name, serverUrl, productionYear, artists, songCount];

  @override
  String toString() => 'MusicAlbum(id: $id, name: $name, year: $productionYear)';
}

/// 音乐艺术家（业务模型）
class MusicArtist extends Equatable {
  final String id;
  final String name;
  final String? sortName;
  final int? albumCount;
  final int? songCount;
  final String? overview;
  final List<String>? genres;
  final double? communityRating;
  final String? primaryImageTag;
  final String? backdropImageTag;
  final String serverUrl;
  final String? accessToken;

  const MusicArtist({
    required this.id,
    required this.name,
    required this.serverUrl,
    this.sortName,
    this.albumCount,
    this.songCount,
    this.overview,
    this.genres,
    this.communityRating,
    this.primaryImageTag,
    this.backdropImageTag,
    this.accessToken,
  });

  factory MusicArtist.fromDto(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final imageTags = dto.imageTags;
    final primaryTag = imageTags?['Primary'];
    final hasImageTag = primaryTag != null && primaryTag.isNotEmpty;
    final hasBlurHash = dto.imageBlurHashes != null;
    final hasImage = hasImageTag || hasBlurHash;

    final backdropTags = dto.backdropImageTags;
    final hasBackdrop = backdropTags != null && backdropTags.isNotEmpty;

    return MusicArtist(
      id: dto.id ?? '',
      name: dto.name ?? '未知艺术家',
      sortName: dto.sortName,
      serverUrl: serverUrl,
      albumCount: dto.albumCount,
      songCount: dto.songCount,
      overview: dto.overview,
      genres: dto.genres,
      communityRating: dto.communityRating,
      primaryImageTag: hasImageTag ? primaryTag : (hasImage ? 'has_image' : null),
      backdropImageTag: hasBackdrop ? backdropTags.first : null,
      accessToken: accessToken,
    );
  }

  /// 获取头像图URL
  String? getPrimaryImageUrl({int? fillWidth, int? fillHeight}) {
    if (primaryImageTag == null) return null;
    var url = '$serverUrl/Items/$id/Images/Primary?tag=$primaryImageTag';
    if (fillWidth != null) url += '&fillWidth=$fillWidth';
    if (fillHeight != null) url += '&fillHeight=$fillHeight';
    return url;
  }

  bool get hasImage => primaryImageTag != null;

  @override
  List<Object?> get props => [id, name, serverUrl, albumCount];

  @override
  String toString() => 'MusicArtist(id: $id, name: $name)';
}

/// 歌曲/音轨（业务模型）
class MusicSong extends Equatable {
  final String id;
  final String name;
  final String? sortName;
  final String? albumId;
  final String? albumName;
  final String? albumPrimaryImageTag;
  final List<String>? artists;
  final List<ArtistRef>? artistRefs;
  final int? trackNumber;
  final int? discNumber;
  final int? runTimeTicks;
  final int? runTimeSeconds;
  final List<String>? genres;
  final double? communityRating;
  final String? parentId;
  final bool? isFavorite;
  final bool? played;
  final int? playCount;
  final String serverUrl;
  final String? accessToken;

  const MusicSong({
    required this.id,
    required this.name,
    required this.serverUrl,
    this.sortName,
    this.albumId,
    this.albumName,
    this.albumPrimaryImageTag,
    this.artists,
    this.artistRefs,
    this.trackNumber,
    this.discNumber,
    this.runTimeTicks,
    this.runTimeSeconds,
    this.genres,
    this.communityRating,
    this.parentId,
    this.isFavorite,
    this.played,
    this.playCount,
    this.accessToken,
  });

  factory MusicSong.fromDto(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl, {
    String? accessToken,
  }) {
    // 提取艺术家
    final artistRefs = <ArtistRef>[];
    final artistNames = <String>[];
    if (dto.artistItems != null) {
      for (final a in dto.artistItems!) {
        if (a.name != null && a.id != null) {
          artistRefs.add(ArtistRef(id: a.id!, name: a.name!));
          artistNames.add(a.name!);
        }
      }
    }
    if (artistNames.isEmpty && dto.artists != null) {
      artistNames.addAll(dto.artists!);
    }

    final runTimeSeconds = dto.runTimeTicks != null
        ? (dto.runTimeTicks! / 10000000).round()
        : null;

    final userData = dto.userData;

    return MusicSong(
      id: dto.id ?? '',
      name: dto.name ?? '未知歌曲',
      sortName: dto.sortName,
      serverUrl: serverUrl,
      albumId: dto.albumId,
      albumName: dto.album,
      albumPrimaryImageTag: dto.albumPrimaryImageTag,
      artists: artistNames.isNotEmpty ? artistNames : null,
      artistRefs: artistRefs.isNotEmpty ? artistRefs : null,
      trackNumber: dto.indexNumber,
      discNumber: dto.parentIndexNumber,
      runTimeTicks: dto.runTimeTicks,
      runTimeSeconds: runTimeSeconds,
      genres: dto.genres,
      communityRating: dto.communityRating,
      parentId: dto.parentId,
      isFavorite: userData?.isFavorite,
      played: userData?.played,
      playCount: userData?.playCount,
      accessToken: accessToken,
    );
  }

  /// 获取音频流URL
  String getStreamUrl({String? container, int? audioBitRate, int? startTimeTicks}) {
    var url = '$serverUrl/Audio/$id/universal?userId=${accessToken != null ? "" : ""}';
    // 使用更简洁的流URL
    url = '$serverUrl/Audio/$id/stream';
    if (container != null) url += '.$container';
    if (accessToken != null) url += '?api_key=$accessToken';
    if (audioBitRate != null) url += '&audioBitRate=$audioBitRate';
    if (startTimeTicks != null) url += '&startTimeTicks=$startTimeTicks';
    return url;
  }

  /// 获取专辑封面图URL（使用专辑ID）
  String? getAlbumCoverUrl({int? fillWidth, int? fillHeight}) {
    final targetId = albumId ?? id;
    final tag = albumPrimaryImageTag;
    if (tag == null) return null;
    var url = '$serverUrl/Items/$targetId/Images/Primary?tag=$tag';
    if (fillWidth != null) url += '&fillWidth=$fillWidth';
    if (fillHeight != null) url += '&fillHeight=$fillHeight';
    return url;
  }

  /// 获取播放时长文本
  String get durationText {
    if (runTimeSeconds == null) return '';
    final minutes = runTimeSeconds! ~/ 60;
    final seconds = runTimeSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 获取艺术家显示文本
  String get artistText => artists?.join(' / ') ?? '未知艺术家';

  @override
  List<Object?> get props => [id, name, serverUrl, albumId, trackNumber];

  @override
  String toString() => 'MusicSong(id: $id, name: $name, track: $trackNumber)';
}

/// 艺术家引用
class ArtistRef extends Equatable {
  final String id;
  final String name;

  const ArtistRef({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

/// 音乐类型（业务模型）
class MusicGenre extends Equatable {
  final String id;
  final String name;
  final String? primaryImageTag;
  final String serverUrl;

  const MusicGenre({
    required this.id,
    required this.name,
    required this.serverUrl,
    this.primaryImageTag,
  });

  factory MusicGenre.fromDto(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl,
  ) {
    final imageTags = dto.imageTags;
    final primaryTag = imageTags?['Primary'];

    return MusicGenre(
      id: dto.id ?? '',
      name: dto.name ?? '未知类型',
      serverUrl: serverUrl,
      primaryImageTag: primaryTag,
    );
  }

  @override
  List<Object?> get props => [id, name];

  @override
  String toString() => 'MusicGenre(name: $name)';
}

// ==================== 列表结果 ====================

/// 专辑列表结果
class MusicAlbumListResult extends Equatable {
  final List<MusicAlbum> albums;
  final int? totalCount;
  final int? startIndex;

  const MusicAlbumListResult({
    required this.albums,
    this.totalCount,
    this.startIndex,
  });

  factory MusicAlbumListResult.fromDto(
    jellyfin_dart.BaseItemDtoQueryResult dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final albums = dto.items
            ?.map((item) => MusicAlbum.fromDto(item, serverUrl, accessToken: accessToken))
            .toList() ??
        [];
    return MusicAlbumListResult(
      albums: albums,
      totalCount: dto.totalRecordCount,
      startIndex: dto.startIndex,
    );
  }

  bool get isEmpty => albums.isEmpty;
  bool get isNotEmpty => albums.isNotEmpty;
  int get length => albums.length;

  @override
  List<Object?> get props => [albums, totalCount, startIndex];
}

/// 艺术家列表结果
class MusicArtistListResult extends Equatable {
  final List<MusicArtist> artists;
  final int? totalCount;
  final int? startIndex;

  const MusicArtistListResult({
    required this.artists,
    this.totalCount,
    this.startIndex,
  });

  factory MusicArtistListResult.fromDto(
    jellyfin_dart.BaseItemDtoQueryResult dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final artists = dto.items
            ?.map((item) => MusicArtist.fromDto(item, serverUrl, accessToken: accessToken))
            .toList() ??
        [];
    return MusicArtistListResult(
      artists: artists,
      totalCount: dto.totalRecordCount,
      startIndex: dto.startIndex,
    );
  }

  bool get isEmpty => artists.isEmpty;
  bool get isNotEmpty => artists.isNotEmpty;
  int get length => artists.length;

  @override
  List<Object?> get props => [artists, totalCount, startIndex];
}

/// 歌曲列表结果
class MusicSongListResult extends Equatable {
  final List<MusicSong> songs;
  final int? totalCount;
  final int? startIndex;

  const MusicSongListResult({
    required this.songs,
    this.totalCount,
    this.startIndex,
  });

  factory MusicSongListResult.fromDto(
    jellyfin_dart.BaseItemDtoQueryResult dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final songs = dto.items
            ?.map((item) => MusicSong.fromDto(item, serverUrl, accessToken: accessToken))
            .toList() ??
        [];
    return MusicSongListResult(
      songs: songs,
      totalCount: dto.totalRecordCount,
      startIndex: dto.startIndex,
    );
  }

  bool get isEmpty => songs.isEmpty;
  bool get isNotEmpty => songs.isNotEmpty;
  int get length => songs.length;

  @override
  List<Object?> get props => [songs, totalCount, startIndex];
}
