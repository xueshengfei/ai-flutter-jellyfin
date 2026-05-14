import 'package:equatable/equatable.dart';

/// 演员信息
class ActorInfo extends Equatable {
  /// 演员名称
  final String name;

  /// 角色名称
  final String? role;

  /// 头像图片URL
  final String? imageUrl;

  /// 演员ID
  final String? id;

  const ActorInfo({required this.name, this.role, this.imageUrl, this.id});

  @override
  List<Object?> get props => [name, role, imageUrl, id];

  @override
  String toString() =>
      'ActorInfo(name: $name, role: $role, hasImage: ${imageUrl != null})';
}

/// 媒体项信息
class MediaItem extends Equatable {
  /// 媒体项ID
  final String id;

  /// 媒体项名称
  final String name;

  /// 媒体项类型
  final String type;

  /// 主图片标签（用于封面）
  final String? primaryImageTag;

  /// 背景图片标签
  final String? backdropImageTag;

  /// 缩略图标签（横向图片，用于剧集截图、继续观看等）
  final String? thumbImageTag;

  /// 制作年份
  final int? productionYear;

  /// 类型标签
  final List<String>? genres;

  /// 社区评分
  final double? communityRating;

  /// 投票数
  final int? voteCount;

  /// 官方评级
  final String? officialRating;

  /// 播放时长（Ticks）
  final int? runTimeTicks;

  /// 播放时长（分钟）
  final int? runTimeMinutes;

  /// 剧情简介
  final String? overview;

  /// 工作室列表
  final List<String>? studios;

  /// 导演列表
  final List<String>? directors;

  /// 作者列表
  final List<String>? writers;

  /// 演员列表（名称）
  final List<String>? actors;

  /// 演员列表（完整信息）
  final List<ActorInfo>? actorInfos;

  /// 导演列表（完整信息）
  final List<ActorInfo>? directorInfos;

  /// 编剧列表（完整信息）
  final List<ActorInfo>? writerInfos;

  /// 所属媒体库ID
  final String? parentId;

  /// 服务器URL
  final String serverUrl;

  /// 访问令牌
  final String? accessToken;

  /// 是否收藏
  final bool? isFavorite;

  /// 是否已播放
  final bool? played;

  /// 播放进度百分比
  final double? playedPercentage;

  const MediaItem({
    required this.id,
    required this.name,
    required this.type,
    required this.serverUrl,
    this.primaryImageTag,
    this.backdropImageTag,
    this.thumbImageTag,
    this.productionYear,
    this.genres,
    this.communityRating,
    this.voteCount,
    this.officialRating,
    this.runTimeTicks,
    this.runTimeMinutes,
    this.overview,
    this.studios,
    this.directors,
    this.writers,
    this.actors,
    this.actorInfos,
    this.directorInfos,
    this.writerInfos,
    this.parentId,
    this.accessToken,
    this.isFavorite,
    this.played,
    this.playedPercentage,
  });

  /// 获取封面图片URL
  String? getCoverImageUrl() {
    if (primaryImageTag == null) return null;
    var url = '$serverUrl/Items/$id/Images/Primary';
    if (primaryImageTag != null && primaryImageTag!.isNotEmpty) {
      url += '?tag=$primaryImageTag';
    } else if (accessToken != null && accessToken!.isNotEmpty) {
      url += '?api_key=$accessToken';
    }
    return url;
  }

  /// 获取背景图片URL
  String? getBackdropImageUrl() {
    if (backdropImageTag == null) return null;
    var url = '$serverUrl/Items/$id/Images/Backdrop';
    if (backdropImageTag != null && backdropImageTag!.isNotEmpty) {
      url += '?tag=$backdropImageTag';
    } else if (accessToken != null && accessToken!.isNotEmpty) {
      url += '?api_key=$accessToken';
    }
    return url;
  }

  bool get hasCoverImage => primaryImageTag != null;
  bool get hasBackdropImage => backdropImageTag != null;
  bool get hasThumbImage => thumbImageTag != null;

  /// 获取缩略图URL
  String? getThumbImageUrl() {
    if (thumbImageTag == null) return null;
    var url = '$serverUrl/Items/$id/Images/Thumb';
    if (thumbImageTag != null && thumbImageTag!.isNotEmpty) {
      url += '?tag=$thumbImageTag';
    } else if (accessToken != null && accessToken!.isNotEmpty) {
      url += '?api_key=$accessToken';
    }
    return url;
  }

  /// 获取播放时长显示文本
  String get durationText {
    if (runTimeMinutes == null) return '';
    final hours = runTimeMinutes! ~/ 60;
    final minutes = runTimeMinutes! % 60;
    if (hours > 0) return '${hours}小时${minutes}分钟';
    return '${minutes}分钟';
  }

  /// 获取评分显示文本
  String get ratingText {
    if (communityRating == null) return '';
    return communityRating!.toStringAsFixed(1);
  }

  /// 获取类型显示名称
  String get typeDisplayName {
    switch (type.toLowerCase()) {
      case 'movie':
        return '电影';
      case 'series':
        return '剧集';
      case 'episode':
        return '单集';
      case 'musicalbum':
        return '专辑';
      case 'musicartist':
        return '艺术家';
      case 'audio':
        return '音频';
      case 'boxset':
        return '合集';
      default:
        return type;
    }
  }

  /// 获取类型图标
  String get typeIcon {
    switch (type.toLowerCase()) {
      case 'movie':
        return '\u{1F3AC}';
      case 'series':
        return '\u{1F4FA}';
      case 'episode':
        return '\u{1F4F9}';
      case 'musicalbum':
        return '\u{1F4BF}';
      case 'musicartist':
        return '\u{1F3A4}';
      case 'audio':
        return '\u{1F3B5}';
      case 'boxset':
        return '\u{1F4E6}';
      default:
        return '\u{1F4C4}';
    }
  }

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    serverUrl,
    primaryImageTag,
    backdropImageTag,
    thumbImageTag,
    productionYear,
    genres,
    communityRating,
    voteCount,
    officialRating,
    runTimeTicks,
    runTimeMinutes,
    overview,
    studios,
    directors,
    writers,
    actors,
    actorInfos,
    directorInfos,
    writerInfos,
    parentId,
    accessToken,
    isFavorite,
    played,
    playedPercentage,
  ];

  @override
  String toString() =>
      'MediaItem(id: $id, name: $name, type: $type, year: $productionYear)';
}

/// 媒体项列表结果
class MediaItemListResult extends Equatable {
  final List<MediaItem> items;
  final int? totalCount;
  final int? startIndex;

  const MediaItemListResult({
    required this.items,
    this.totalCount,
    this.startIndex,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get length => items.length;

  @override
  List<Object?> get props => [items, totalCount, startIndex];
}

/// 季信息
class Season extends Equatable {
  final String id;
  final String seriesId;
  final String name;
  final int indexNumber;
  final String? primaryImageTag;
  final String? overview;
  final int? episodeCount;
  final String serverUrl;
  final String? accessToken;

  const Season({
    required this.id,
    required this.seriesId,
    required this.name,
    required this.indexNumber,
    required this.serverUrl,
    this.primaryImageTag,
    this.overview,
    this.episodeCount,
    this.accessToken,
  });

  String? getCoverImageUrl() {
    if (primaryImageTag == null) return null;
    var url = '$serverUrl/Items/$id/Images/Primary';
    if (primaryImageTag != null && primaryImageTag!.isNotEmpty) {
      url += '?tag=$primaryImageTag';
    } else if (accessToken != null && accessToken!.isNotEmpty) {
      url += '?api_key=$accessToken';
    }
    return url;
  }

  bool get hasCoverImage => primaryImageTag != null;

  String get seasonNumberText {
    if (indexNumber == 0) return 'SP';
    return 'S${indexNumber.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
    id,
    seriesId,
    name,
    indexNumber,
    serverUrl,
    primaryImageTag,
    overview,
    episodeCount,
    accessToken,
  ];

  @override
  String toString() =>
      'Season(id: $id, name: $name, index: $indexNumber, episodes: $episodeCount)';
}

/// 集信息
class Episode extends Equatable {
  final String id;
  final String seriesId;
  final String seasonId;
  final String name;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? primaryImageTag;
  final String? overview;
  final int? runTimeTicks;
  final int? runTimeMinutes;
  final double? communityRating;
  final double? playedPercentage;
  final bool? played;
  final String serverUrl;
  final String? accessToken;

  const Episode({
    required this.id,
    required this.seriesId,
    required this.seasonId,
    required this.name,
    required this.serverUrl,
    this.seasonNumber,
    this.episodeNumber,
    this.primaryImageTag,
    this.overview,
    this.runTimeTicks,
    this.runTimeMinutes,
    this.communityRating,
    this.playedPercentage,
    this.played,
    this.accessToken,
  });

  String? getThumbnailImageUrl() {
    if (primaryImageTag == null) return null;
    var url = '$serverUrl/Items/$id/Images/Primary';
    if (primaryImageTag != null && primaryImageTag!.isNotEmpty) {
      url += '?tag=$primaryImageTag';
    } else if (accessToken != null && accessToken!.isNotEmpty) {
      url += '?api_key=$accessToken';
    }
    return url;
  }

  bool get hasThumbnailImage => primaryImageTag != null;

  String get episodeNumberText {
    final season = seasonNumber?.toString().padLeft(2, '0') ?? '??';
    final episode = episodeNumber?.toString().padLeft(2, '0') ?? '??';
    return 'S${season}E${episode}';
  }

  String get durationText {
    if (runTimeMinutes == null) return '';
    final hours = runTimeMinutes! ~/ 60;
    final minutes = runTimeMinutes! % 60;
    if (hours > 0) return '${hours}小时${minutes}分钟';
    return '${minutes}分钟';
  }

  @override
  List<Object?> get props => [
    id,
    seriesId,
    seasonId,
    name,
    seasonNumber,
    episodeNumber,
    serverUrl,
    primaryImageTag,
    overview,
    runTimeTicks,
    runTimeMinutes,
    communityRating,
    playedPercentage,
    played,
    accessToken,
  ];

  @override
  String toString() =>
      'Episode(id: $id, name: $name, S${seasonNumber}E${episodeNumber})';
}

/// 季列表结果
class SeasonListResult extends Equatable {
  final List<Season> seasons;
  final int? totalCount;

  const SeasonListResult({required this.seasons, this.totalCount});

  bool get isEmpty => seasons.isEmpty;
  bool get isNotEmpty => seasons.isNotEmpty;
  int get length => seasons.length;

  @override
  List<Object?> get props => [seasons, totalCount];
}

/// 集列表结果
class EpisodeListResult extends Equatable {
  final List<Episode> episodes;
  final int? totalCount;
  final int? startIndex;

  const EpisodeListResult({
    required this.episodes,
    this.totalCount,
    this.startIndex,
  });

  bool get isEmpty => episodes.isEmpty;
  bool get isNotEmpty => episodes.isNotEmpty;
  int get length => episodes.length;

  @override
  List<Object?> get props => [episodes, totalCount, startIndex];
}
