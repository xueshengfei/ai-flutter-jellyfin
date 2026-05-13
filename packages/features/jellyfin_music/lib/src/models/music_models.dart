import 'package:flutter/widgets.dart';
import 'package:equatable/equatable.dart';

// ==================== 数据模型 ====================

/// 音乐专辑
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

  String? getCoverImageUrl({int? fillWidth, int? fillHeight}) {
    if (primaryImageTag == null) return null;
    var url = '$serverUrl/Items/$id/Images/Primary?tag=$primaryImageTag';
    if (fillWidth != null) url += '&fillWidth=$fillWidth';
    if (fillHeight != null) url += '&fillHeight=$fillHeight';
    return url;
  }

  bool get hasCoverImage => primaryImageTag != null;
  String get artistText => artists?.join(' / ') ?? '未知艺术家';

  @override
  List<Object?> get props => [id, name, serverUrl, productionYear, artists, songCount];

  @override
  String toString() => 'MusicAlbum(id: $id, name: $name, year: $productionYear)';
}

/// 音乐艺术家
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

/// 歌曲/音轨
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
  final String? path;

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
    this.path,
  });

  String getStreamUrl({String? container, int? audioBitRate, int? startTimeTicks}) {
    var url = '$serverUrl/Audio/$id/stream';
    if (container != null) url += '.$container';
    if (accessToken != null) url += '?api_key=$accessToken';
    if (audioBitRate != null) url += '&audioBitRate=$audioBitRate';
    if (startTimeTicks != null) url += '&startTimeTicks=$startTimeTicks';
    return url;
  }

  String? getAlbumCoverUrl({int? fillWidth, int? fillHeight}) {
    final targetId = albumId ?? id;
    final tag = albumPrimaryImageTag;
    if (tag == null) return null;
    var url = '$serverUrl/Items/$targetId/Images/Primary?tag=$tag';
    if (fillWidth != null) url += '&fillWidth=$fillWidth';
    if (fillHeight != null) url += '&fillHeight=$fillHeight';
    return url;
  }

  String get durationText {
    if (runTimeSeconds == null) return '';
    final minutes = runTimeSeconds! ~/ 60;
    final seconds = runTimeSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

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

/// 音乐类型
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

  bool get isEmpty => songs.isEmpty;
  bool get isNotEmpty => songs.isNotEmpty;
  int get length => songs.length;

  @override
  List<Object?> get props => [songs, totalCount, startIndex];
}

// ==================== 回调类型 ====================

/// 获取专辑详情
typedef AlbumDetailFetcher = Future<MusicAlbum> Function(String albumId);

/// 获取专辑歌曲列表
typedef AlbumSongsFetcher = Future<MusicSongListResult> Function(String albumId);

/// 获取艺术家详情
typedef ArtistDetailFetcher = Future<MusicArtist> Function(String artistId);

/// 获取艺术家专辑列表
typedef ArtistAlbumsFetcher = Future<MusicAlbumListResult> Function(String artistId);

/// 播放歌曲回调
typedef OnPlaySong = void Function(
  BuildContext context,
  MusicSong song,
  List<MusicSong> playlist,
  int initialIndex,
);

/// 导航到专辑详情
typedef OnNavigateToAlbum = void Function(BuildContext context, MusicAlbum album);

/// 打开专辑详情回调（从音乐库列表点击）
typedef OnOpenAlbum = void Function(BuildContext context, MusicAlbum album);

/// 打开艺术家详情回调（从音乐库列表点击）
typedef OnOpenArtist = void Function(BuildContext context, MusicArtist artist);

/// 获取专辑列表
typedef AlbumsFetcher = Future<MusicAlbumListResult> Function({
  required String parentId,
  int? startIndex,
  int? limit,
  String? sortBy,
});

/// 获取艺术家列表
typedef ArtistsFetcher = Future<MusicArtistListResult> Function({
  required String parentId,
  int? startIndex,
  int? limit,
});

/// 获取歌曲列表
typedef SongsFetcher = Future<MusicSongListResult> Function({
  required String parentId,
  int? startIndex,
  int? limit,
});

// ==================== 搜索 ====================

/// 音乐搜索结果（统一返回三种类型）
class MusicSearchResult extends Equatable {
  final List<MusicArtist> artists;
  final List<MusicAlbum> albums;
  final List<MusicSong> songs;

  const MusicSearchResult({
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
  });

  bool get isEmpty => artists.isEmpty && albums.isEmpty && songs.isEmpty;

  @override
  List<Object?> get props => [artists, albums, songs];
}

/// 音乐搜索回调
typedef MusicSearchFetcher = Future<MusicSearchResult> Function({
  required String searchTerm,
  String? parentId,
  int? limit,
});
