import 'package:equatable/equatable.dart';

/// 媒体库类型
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
        return '\u{1F3AC}';
      case MediaLibraryType.tvshows:
        return '\u{1F4FA}';
      case MediaLibraryType.music:
        return '\u{1F3B5}';
      case MediaLibraryType.musicVideos:
        return '\u{1F3BC}';
      case MediaLibraryType.homeVideos:
        return '\u{1F4F9}';
      case MediaLibraryType.boxSets:
        return '\u{1F4E6}';
      case MediaLibraryType.unknown:
        return '\u{1F4C1}';
    }
  }

  /// 获取默认颜色
  String get color {
    switch (this) {
      case MediaLibraryType.movies:
        return '#E53935';
      case MediaLibraryType.tvshows:
        return '#1E88E5';
      case MediaLibraryType.music:
        return '#43A047';
      case MediaLibraryType.musicVideos:
        return '#FB8C00';
      case MediaLibraryType.homeVideos:
        return '#8E24AA';
      case MediaLibraryType.boxSets:
        return '#F4511E';
      case MediaLibraryType.unknown:
        return '#757575';
    }
  }
}

/// 媒体库信息
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

  /// 是否有封面图片
  bool get hasCoverImage => primaryImageTag != null;

  /// 是否有背景图片
  bool get hasBackdropImage => backdropImageTag != null;

  @override
  List<Object?> get props => [
        id, name, type, serverUrl,
        primaryImageTag, backdropImageTag, itemCount, accessToken,
      ];

  @override
  String toString() =>
      'MediaLibrary(id: $id, name: $name, type: $type, itemCount: $itemCount)';
}

/// 媒体库列表结果
class MediaLibraryListResult extends Equatable {
  /// 媒体库列表
  final List<MediaLibrary> libraries;

  /// 总数
  final int? totalCount;

  const MediaLibraryListResult({
    required this.libraries,
    this.totalCount,
  });

  bool get isEmpty => libraries.isEmpty;
  bool get isNotEmpty => libraries.isNotEmpty;
  int get length => libraries.length;

  @override
  List<Object?> get props => [libraries, totalCount];
}
