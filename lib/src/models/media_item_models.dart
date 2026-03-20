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

  /// 制作年份
  final int? productionYear;

  /// 类型标签（如动作、喜剧等）
  final List<String>? genres;

  /// 社区评分
  final double? communityRating;

  /// 剧情简介
  final String? overview;

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
    this.productionYear,
    this.genres,
    this.communityRating,
    this.overview,
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

    return MediaItem(
      id: dto.id ?? '',
      name: dto.name ?? '未知媒体',
      type: typeString,
      serverUrl: serverUrl,
      primaryImageTag: hasImageTag ? primaryImageTag : (hasImage ? 'has_image' : null),
      productionYear: dto.productionYear,
      genres: dto.genres,
      communityRating: dto.communityRating,
      overview: dto.overview,
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

  /// 是否有封面图片
  bool get hasCoverImage => primaryImageTag != null;

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
        productionYear,
        genres,
        communityRating,
        overview,
        parentId,
        accessToken,
      ];

  @override
  String toString() {
    return 'MediaItem(id: $id, name: $name, type: $type, year: $productionYear)';
  }
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
