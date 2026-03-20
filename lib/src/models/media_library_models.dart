import 'package:equatable/equatable.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;

/// 媒体库信息（业务模型）
///
/// 封装Jellyfin媒体库的信息
class MediaLibrary extends Equatable {
  /// 媒体库ID
  final String id;

  /// 媒体库名称
  final String name;

  /// 媒体库类型
  final MediaLibraryType type;

  /// 主图片标签（用于封面）
  final String? primaryImageTag;

  /// 背景图片标签
  final String? backdropImageTag;

  /// 媒体项数量
  final int? itemCount;

  /// 服务器URL
  final String serverUrl;

  /// 访问令牌（用于图片认证）
  final String? accessToken;

  const MediaLibrary({
    required this.id,
    required this.name,
    required this.type,
    required this.serverUrl,
    this.primaryImageTag,
    this.backdropImageTag,
    this.itemCount,
    this.accessToken,
  });

  /// 从jellyfin_dart的BaseItemDto创建Media库
  factory MediaLibrary.fromDto(
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

    final backdropImageTags = dto.backdropImageTags;
    final hasBackdrop = backdropImageTags != null && backdropImageTags.isNotEmpty;

    return MediaLibrary(
      id: dto.id ?? '',
      name: dto.name ?? '未知媒体库',
      type: MediaLibraryType.fromCollectionType(dto.collectionType),
      serverUrl: serverUrl,
      primaryImageTag: hasImageTag ? primaryImageTag : (hasImage ? 'has_image' : null),
      backdropImageTag: hasBackdrop ? backdropImageTags.first : null,
      itemCount: dto.childCount,
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

  /// 获取背景图片URL
  String? getBackdropImageUrl() {
    if (backdropImageTag == null) return null;

    // Jellyfin图片URL格式：/Items/{id}/Images/Backdrop?tag={imageTag}
    var url = '$serverUrl/Items/$id/Images/Backdrop';

    // 优先使用图片标签
    if (backdropImageTag != null && backdropImageTag!.isNotEmpty) {
      url += '?tag=$backdropImageTag';
    }
    // 如果没有图片标签但有访问令牌，使用访问令牌
    else if (accessToken != null && accessToken!.isNotEmpty) {
      url += '?api_key=$accessToken';
    }

    return url;
  }

  /// 是否有封面图片
  bool get hasCoverImage => primaryImageTag != null;

  /// 是否有背景图片
  bool get hasBackdropImage => backdropImageTag != null;

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        serverUrl,
        primaryImageTag,
        backdropImageTag,
        itemCount,
        accessToken,
      ];

  @override
  String toString() {
    return 'MediaLibrary(id: $id, name: $name, type: $type, itemCount: $itemCount)';
  }
}

/// 媒体库类型（业务模型）
///
/// 简化的媒体库类型枚举
enum MediaLibraryType {
  /// 电影
  movies,

  /// 电视剧
  tvshows,

  /// 音乐
  music,

  /// 音乐视频
  musicVideos,

  /// 家庭视频
  homeVideos,

  /// 电影合集
  boxSets,

  /// 其他/未知
  unknown;

  /// 从jellyfin_dart的CollectionType转换
  static MediaLibraryType fromCollectionType(
    jellyfin_dart.CollectionType? collectionType,
  ) {
    if (collectionType == null) return MediaLibraryType.unknown;

    switch (collectionType) {
      case jellyfin_dart.CollectionType.movies:
        return MediaLibraryType.movies;
      case jellyfin_dart.CollectionType.tvshows:
        return MediaLibraryType.tvshows;
      case jellyfin_dart.CollectionType.music:
        return MediaLibraryType.music;
      case jellyfin_dart.CollectionType.musicvideos:
        return MediaLibraryType.musicVideos;
      case jellyfin_dart.CollectionType.homevideos:
        return MediaLibraryType.homeVideos;
      case jellyfin_dart.CollectionType.boxsets:
        return MediaLibraryType.boxSets;
      default:
        return MediaLibraryType.unknown;
    }
  }

  /// 获取显示名称（中文）
  String get displayName {
    switch (this) {
      case MediaLibraryType.movies:
        return '电影';
      case MediaLibraryType.tvshows:
        return '电视剧';
      case MediaLibraryType.music:
        return '音乐';
      case MediaLibraryType.musicVideos:
        return '音乐视频';
      case MediaLibraryType.homeVideos:
        return '家庭视频';
      case MediaLibraryType.boxSets:
        return '电影合集';
      case MediaLibraryType.unknown:
        return '其他';
    }
  }

  /// 获取图标（Emoji）
  String get icon {
    switch (this) {
      case MediaLibraryType.movies:
        return '🎬';
      case MediaLibraryType.tvshows:
        return '📺';
      case MediaLibraryType.music:
        return '🎵';
      case MediaLibraryType.musicVideos:
        return '🎼';
      case MediaLibraryType.homeVideos:
        return '📹';
      case MediaLibraryType.boxSets:
        return '📦';
      case MediaLibraryType.unknown:
        return '📁';
    }
  }

  /// 获取默认颜色
  String get color {
    switch (this) {
      case MediaLibraryType.movies:
        return '#E53935'; // 红色
      case MediaLibraryType.tvshows:
        return '#1E88E5'; // 蓝色
      case MediaLibraryType.music:
        return '#43A047'; // 绿色
      case MediaLibraryType.musicVideos:
        return '#FB8C00'; // 橙色
      case MediaLibraryType.homeVideos:
        return '#8E24AA'; // 紫色
      case MediaLibraryType.boxSets:
        return '#F4511E'; // 深橙色
      case MediaLibraryType.unknown:
        return '#757575'; // 灰色
    }
  }
}

/// 媒体库列表结果（业务模型）
///
/// 封装媒体库列表查询结果
class MediaLibraryListResult extends Equatable {
  /// 媒体库列表
  final List<MediaLibrary> libraries;

  /// 总数
  final int? totalCount;

  const MediaLibraryListResult({
    required this.libraries,
    this.totalCount,
  });

  /// 从jellyfin_dart的BaseItemDtoQueryResult创建
  factory MediaLibraryListResult.fromDto(
    jellyfin_dart.BaseItemDtoQueryResult dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final libraries = dto.items
            ?.map((item) => MediaLibrary.fromDto(
                  item,
                  serverUrl,
                  accessToken: accessToken,
                ))
            .toList() ??
        [];

    return MediaLibraryListResult(
      libraries: libraries,
      totalCount: dto.totalRecordCount,
    );
  }

  /// 是否为空
  bool get isEmpty => libraries.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => libraries.isNotEmpty;

  /// 数量
  int get length => libraries.length;

  @override
  List<Object?> get props => [libraries, totalCount];
}
