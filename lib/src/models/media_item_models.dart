import 'package:equatable/equatable.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;

/// 媒体项信息（业务模型）
///
/// 封装Jellyfin媒体项的信息（如电影、电视剧、音乐等）
class MediaItem extends Equatable {
  /// 媒体项ID
  final String id;

  /// 媒体项名称
  final String name;

  /// 媒体项类型
  final String type;

  /// 主图片标签（用于封面）
  final String? primaryImageTag;

  /// 背景图片标签（用于海报背景）
  final String? backdropImageTag;

  /// 制作年份
  final int? productionYear;

  /// 类型标签（如动作、喜剧等）
  final List<String>? genres;

  /// 社区评分
  final double? communityRating;

  /// 投票数
  final int? voteCount;

  /// 官方评级（如 PG-13, R 等）
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

  /// 所属媒体库ID
  final String? parentId;

  /// 服务器URL
  final String serverUrl;

  /// 访问令牌（用于图片认证）
  final String? accessToken;

  const MediaItem({
    required this.id,
    required this.name,
    required this.type,
    required this.serverUrl,
    this.primaryImageTag,
    this.backdropImageTag,
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
    this.parentId,
    this.accessToken,
  });

  /// 从jellyfin_dart的BaseItemDto创建媒体项
  factory MediaItem.fromDto(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl, {
    String? accessToken,
  }) {
    // 检查是否有图片标签
    final imageTags = dto.imageTags;
    final primaryImageTag = imageTags?['Primary'];

    // 检查是否有图片（有图片标签或有blurhash）
    final hasImageTag = primaryImageTag != null && primaryImageTag.isNotEmpty;
    final hasBlurHash = dto.imageBlurHashes != null;

    // 使用图片标签作为图片标识
    final hasImage = hasImageTag || hasBlurHash;

    // 将BaseItemKind枚举转换为字符串
    final typeString = dto.type != null
        ? dto.type!.name
        : 'unknown';

    // 计算播放时长（分钟）
    final runTimeMinutes = dto.runTimeTicks != null
        ? (dto.runTimeTicks! / 600000000).round()
        : null;

    // 提取工作室名称
    final studios = dto.studios?.map((s) => s.name ?? '').toList();
    print('   🏢 工作室数量: ${studios?.length ?? 0}');
    if (studios != null && studios.isNotEmpty) {
      print('   🏢 工作室列表: $studios');
    }

    // 提取导演
    final directors = <String>[];
    print('   👤 人员总数: ${dto.people?.length ?? 0}');
    for (final person in (dto.people ?? [])) {
      // PersonKind 是枚举，直接比较枚举值
      final personType = person.type?.value ?? 'unknown';
      print('      人员: ${person.name} - 类型: $personType');

      if (person.type == jellyfin_dart.PersonKind.director && person.name != null) {
        directors.add(person.name!);
      }
    }
    print('   🎬 导演数量: ${directors.length}');
    if (directors.isNotEmpty) {
      print('   🎬 导演列表: $directors');
    }

    // 提取作者
    final writers = <String>[];
    for (final person in (dto.people ?? [])) {
      if (person.type == jellyfin_dart.PersonKind.writer && person.name != null) {
        writers.add(person.name!);
      }
    }
    print('   ✏️ 作者数量: ${writers.length}');

    // 检查背景图片标签
    // Jellyfin 有两种方式存储背景图片标签：
    // 1. ImageTags['Backdrop']
    // 2. BackdropImageTags 数组
    final backdropImageTags = dto.imageTags;
    final backdropTagsList = dto.backdropImageTags;

    String? backdropTag;
    if (backdropImageTags?['Backdrop'] != null && backdropImageTags!['Backdrop']!.isNotEmpty) {
      backdropTag = backdropImageTags!['Backdrop'];
    } else if (backdropTagsList != null && backdropTagsList.isNotEmpty) {
      backdropTag = backdropTagsList.first;
    }

    return MediaItem(
      id: dto.id ?? '',
      name: dto.name ?? '未知媒体',
      type: typeString,
      serverUrl: serverUrl,
      primaryImageTag: hasImageTag ? primaryImageTag : (hasImage ? 'has_image' : null),
      backdropImageTag: backdropTag,
      productionYear: dto.productionYear,
      genres: dto.genres,
      communityRating: dto.communityRating,
      voteCount: null, // BaseItemDto 中没有此字段
      officialRating: dto.officialRating,
      runTimeTicks: dto.runTimeTicks,
      runTimeMinutes: runTimeMinutes,
      overview: dto.overview,
      studios: studios,
      directors: directors,
      writers: writers,
      parentId: dto.parentId,
      accessToken: accessToken,
    );
  }

  /// 获取封面图片URL
  String? getCoverImageUrl() {
    if (primaryImageTag == null) return null;

    // Jellyfin图片URL格式：/Items/{id}/Images/Primary?tag={imageTag}
    var url = '$serverUrl/Items/$id/Images/Primary';

    // 优先使用图片标签
    if (primaryImageTag != null && primaryImageTag!.isNotEmpty) {
      url += '?tag=$primaryImageTag';
    }
    // 如果没有图片标签但有访问令牌，使用访问令牌
    else if (accessToken != null && accessToken!.isNotEmpty) {
      url += '?api_key=$accessToken';
    }

    return url;
  }

  /// 获取背景图片URL（用于海报）
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

  /// 是否有封面图片
  bool get hasCoverImage => primaryImageTag != null;

  /// 是否有背景图片
  bool get hasBackdropImage => backdropImageTag != null;

  /// 获取播放时长显示文本
  String get durationText {
    if (runTimeMinutes == null) return '';

    final hours = runTimeMinutes! ~/ 60;
    final minutes = runTimeMinutes! % 60;

    if (hours > 0) {
      return '${hours}小时${minutes}分钟';
    } else {
      return '${minutes}分钟';
    }
  }

  /// 获取评分显示文本
  String get ratingText {
    if (communityRating == null) return '';
    return communityRating!.toStringAsFixed(1);
  }

  /// 获取类型显示名称
  String get typeDisplayName {
    // 将BaseItemKind转换为中文显示名称
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
        return '🎬';
      case 'series':
        return '📺';
      case 'episode':
        return '📹';
      case 'musicalbum':
        return '💿';
      case 'musicartist':
        return '🎤';
      case 'audio':
        return '🎵';
      case 'boxset':
        return '📦';
      default:
        return '📄';
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
        parentId,
        accessToken,
      ];

  @override
  String toString() {
    return 'MediaItem(id: $id, name: $name, type: $type, year: $productionYear)';
  }
}

/// 季（Season）信息（业务模型）
///
/// 用于表示电视剧/动漫的季信息
class Season extends Equatable {
  /// 季ID
  final String id;

  /// 剧集ID（父级）
  final String seriesId;

  /// 季名称
  final String name;

  /// 季号（从0开始，0表示特别篇）
  final int indexNumber;

  /// 主图片标签（用于封面）
  final String? primaryImageTag;

  /// 剧情简介
  final String? overview;

  /// 该季的剧集数量
  final int? episodeCount;

  /// 服务器URL
  final String serverUrl;

  /// 访问令牌（用于图片认证）
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

  /// 从jellyfin_dart的BaseItemDto创建季信息
  factory Season.fromDto(
    jellyfin_dart.BaseItemDto dto,
    String seriesId,
    String serverUrl, {
    String? accessToken,
    int? episodeCount,
  }) {
    // 检查是否有图片标签
    final imageTags = dto.imageTags;
    final primaryImageTag = imageTags?['Primary'];

    // 检查是否有图片
    final hasImageTag = primaryImageTag != null && primaryImageTag.isNotEmpty;
    final hasBlurHash = dto.imageBlurHashes != null;
    final hasImage = hasImageTag || hasBlurHash;

    // 获取季号，默认为0
    final indexNumber = dto.indexNumber ?? 0;

    // 生成季名称
    final seasonName = _generateSeasonName(indexNumber, dto.name);

    return Season(
      id: dto.id ?? '',
      seriesId: seriesId,
      name: seasonName,
      indexNumber: indexNumber,
      serverUrl: serverUrl,
      primaryImageTag: hasImageTag ? primaryImageTag : (hasImage ? 'has_image' : null),
      overview: dto.overview,
      episodeCount: episodeCount,
      accessToken: accessToken,
    );
  }

  /// 生成季名称
  static String _generateSeasonName(int indexNumber, String? dtoName) {
    if (dtoName != null && dtoName.isNotEmpty) {
      return dtoName;
    }

    if (indexNumber == 0) {
      return '特别篇';
    } else {
      return '第 ${indexNumber} 季';
    }
  }

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

  /// 是否有封面图片
  bool get hasCoverImage => primaryImageTag != null;

  /// 获取季号显示文本
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
  String toString() {
    return 'Season(id: $id, name: $name, index: $indexNumber, episodes: $episodeCount)';
  }
}

/// 集（Episode）信息（业务模型）
///
/// 用于表示电视剧/动漫的单集信息
class Episode extends Equatable {
  /// 集ID
  final String id;

  /// 剧集ID
  final String seriesId;

  /// 季ID
  final String seasonId;

  /// 集名称
  final String name;

  /// 季号
  final int? seasonNumber;

  /// 集号
  final int? episodeNumber;

  /// 主图片标签（用于缩略图）
  final String? primaryImageTag;

  /// 剧情简介
  final String? overview;

  /// 播放时长（秒）
  final int? runTimeTicks;

  /// 播放时长（分钟）
  final int? runTimeMinutes;

  /// 社区评分
  final double? communityRating;

  /// 播放进度
  final double? playedPercentage;

  /// 是否已播放
  final bool? played;

  /// 服务器URL
  final String serverUrl;

  /// 访问令牌（用于图片认证）
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

  /// 从jellyfin_dart的BaseItemDto创建集信息
  factory Episode.fromDto(
    jellyfin_dart.BaseItemDto dto,
    String seriesId,
    String seasonId,
    String serverUrl, {
    String? accessToken,
  }) {
    // 检查是否有图片标签
    final imageTags = dto.imageTags;
    final primaryImageTag = imageTags?['Primary'];

    // 检查是否有图片
    final hasImageTag = primaryImageTag != null && primaryImageTag.isNotEmpty;
    final hasBlurHash = dto.imageBlurHashes != null;
    final hasImage = hasImageTag || hasBlurHash;

    // 计算播放时长（分钟）
    final runTimeMinutes = dto.runTimeTicks != null
        ? (dto.runTimeTicks! / 600000000).round()
        : null;

    // 从 userData 获取播放信息
    final userData = dto.userData;
    final playedPercentage = userData?.playedPercentage;
    final played = userData?.played;

    // seasonNumber 字段在 BaseItemDto 中不存在，使用 null 或从 seasonName 推断
    // 对于集来说，通常通过 parentId (seasonId) 来关联季，不需要单独存储季号

    return Episode(
      id: dto.id ?? '',
      seriesId: seriesId,
      seasonId: seasonId,
      name: dto.name ?? '未知剧集',
      serverUrl: serverUrl,
      seasonNumber: null, // BaseItemDto 中没有此字段
      episodeNumber: dto.indexNumber,
      primaryImageTag: hasImageTag ? primaryImageTag : (hasImage ? 'has_image' : null),
      overview: dto.overview,
      runTimeTicks: dto.runTimeTicks,
      runTimeMinutes: runTimeMinutes,
      communityRating: dto.communityRating,
      playedPercentage: playedPercentage,
      played: played,
      accessToken: accessToken,
    );
  }

  /// 获取缩略图URL
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

  /// 是否有缩略图
  bool get hasThumbnailImage => primaryImageTag != null;

  /// 获取集号显示文本（如 S01E05）
  String get episodeNumberText {
    final season = seasonNumber?.toString().padLeft(2, '0') ?? '??';
    final episode = episodeNumber?.toString().padLeft(2, '0') ?? '??';
    return 'S${season}E${episode}';
  }

  /// 获取播放时长显示文本
  String get durationText {
    if (runTimeMinutes == null) return '';

    final hours = runTimeMinutes! ~/ 60;
    final minutes = runTimeMinutes! % 60;

    if (hours > 0) {
      return '${hours}小时${minutes}分钟';
    } else {
      return '${minutes}分钟';
    }
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
  String toString() {
    return 'Episode(id: $id, name: $name, S${seasonNumber}E${episodeNumber}, duration: $durationText)';
  }
}

/// 季列表结果（业务模型）
class SeasonListResult extends Equatable {
  /// 季列表
  final List<Season> seasons;

  /// 总数
  final int? totalCount;

  const SeasonListResult({
    required this.seasons,
    this.totalCount,
  });

  /// 从DTO列表创建
  factory SeasonListResult.fromDto(
    List<jellyfin_dart.BaseItemDto> dtos,
    String seriesId,
    String serverUrl, {
    String? accessToken,
    Map<String, int>? episodeCounts,
  }) {
    final seasons = dtos
        .map((dto) => Season.fromDto(
              dto,
              seriesId,
              serverUrl,
              accessToken: accessToken,
              episodeCount: episodeCounts?[dto.id],
            ))
        .toList();

    // 按季号排序
    seasons.sort((a, b) => a.indexNumber.compareTo(b.indexNumber));

    return SeasonListResult(
      seasons: seasons,
      totalCount: seasons.length,
    );
  }

  /// 是否为空
  bool get isEmpty => seasons.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => seasons.isNotEmpty;

  /// 数量
  int get length => seasons.length;

  @override
  List<Object?> get props => [seasons, totalCount];
}

/// 集列表结果（业务模型）
class EpisodeListResult extends Equatable {
  /// 集列表
  final List<Episode> episodes;

  /// 总数
  final int? totalCount;

  /// 起始索引
  final int? startIndex;

  const EpisodeListResult({
    required this.episodes,
    this.totalCount,
    this.startIndex,
  });

  /// 从DTO创建
  factory EpisodeListResult.fromDto(
    jellyfin_dart.BaseItemDtoQueryResult dto,
    String seriesId,
    String seasonId,
    String serverUrl, {
    String? accessToken,
  }) {
    final episodes = dto.items
            ?.map((item) => Episode.fromDto(
                  item,
                  seriesId,
                  seasonId,
                  serverUrl,
                  accessToken: accessToken,
                ))
            .toList() ??
        [];

    return EpisodeListResult(
      episodes: episodes,
      totalCount: dto.totalRecordCount,
      startIndex: dto.startIndex,
    );
  }

  /// 是否为空
  bool get isEmpty => episodes.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => episodes.isNotEmpty;

  /// 数量
  int get length => episodes.length;

  @override
  List<Object?> get props => [episodes, totalCount, startIndex];
}

/// 媒体项列表结果（业务模型）
///
/// 封装媒体项列表查询结果
class MediaItemListResult extends Equatable {
  /// 媒体项列表
  final List<MediaItem> items;

  /// 总数
  final int? totalCount;

  /// 起始索引
  final int? startIndex;

  const MediaItemListResult({
    required this.items,
    this.totalCount,
    this.startIndex,
  });

  /// 从jellyfin_dart的BaseItemDtoQueryResult创建
  factory MediaItemListResult.fromDto(
    jellyfin_dart.BaseItemDtoQueryResult dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final items = dto.items
            ?.map((item) => MediaItem.fromDto(
                  item,
                  serverUrl,
                  accessToken: accessToken,
                ))
            .toList() ??
        [];

    return MediaItemListResult(
      items: items,
      totalCount: dto.totalRecordCount,
      startIndex: dto.startIndex,
    );
  }

  /// 是否为空
  bool get isEmpty => items.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => items.isNotEmpty;

  /// 数量
  int get length => items.length;

  @override
  List<Object?> get props => [items, totalCount, startIndex];
}
