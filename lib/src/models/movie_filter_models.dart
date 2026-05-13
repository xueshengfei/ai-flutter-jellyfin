import 'package:equatable/equatable.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;

/// 电影过滤器
///
/// 用于封装电影列表查询的所有过滤和排序参数
class MovieFilter extends Equatable {
  /// 媒体库ID（必需）
  final String parentId;

  /// 起始索引（用于分页，默认0）
  final int startIndex;

  /// 限制返回数量（默认20）
  final int limit;

  /// 类型过滤（如：动作、喜剧、科幻等）
  final List<String>? genres;

  /// 用户标签过滤
  final List<String>? tags;

  /// 年份过滤（支持多个年份）
  final List<int>? years;

  /// 首字母过滤（如：'A', 'B', 'C'等）
  final String? nameStartsWith;

  /// 工作室过滤（如：漫威、迪士尼等）
  final List<String>? studios;

  /// 制作地区过滤（如：美国、中国等）
  final List<String>? productionLocations;

  /// 最低社区评分（0-10）
  final double? minCommunityRating;

  /// 最低官方分级（如：PG, PG-13等）
  final String? minOfficialRating;

  /// 最高官方分级
  final String? maxOfficialRating;

  /// 是否只显示高清电影
  final bool? isHD;

  /// 是否只显示4K电影
  final bool? is4K;

  /// 是否只显示已播放的电影
  final bool? isPlayed;

  /// 是否只显示收藏的电影
  final bool? isFavorite;

  /// 高级过滤器（如未播放、已播放、收藏等）
  final List<jellyfin_dart.ItemFilter>? filters;

  /// 排序字段（可多选组合排序）
  final List<jellyfin_dart.ItemSortBy>? sortBy;

  /// 排序顺序（升序或降序）
  final List<jellyfin_dart.SortOrder>? sortOrder;

  /// 额外返回的字段（如类型、演员、导演等信息）
  final List<jellyfin_dart.ItemFields>? fields;

  /// 是否递归搜索子文件夹（默认true）
  final bool? recursive;

  const MovieFilter({
    required this.parentId,
    this.startIndex = 0,
    this.limit = 20,
    this.genres,
    this.tags,
    this.years,
    this.nameStartsWith,
    this.studios,
    this.productionLocations,
    this.minCommunityRating,
    this.minOfficialRating,
    this.maxOfficialRating,
    this.isHD,
    this.is4K,
    this.isPlayed,
    this.isFavorite,
    this.filters,
    this.sortBy,
    this.sortOrder,
    this.fields,
    this.recursive = true,
  });

  /// 创建默认的电影过滤器
  factory MovieFilter.defaultFilter({
    required String parentId,
    int startIndex = 0,
    int limit = 20,
  }) {
    return MovieFilter(
      parentId: parentId,
      startIndex: startIndex,
      limit: limit,
      sortBy: const [
        jellyfin_dart.ItemSortBy.dateCreated,
        jellyfin_dart.ItemSortBy.sortName,
        jellyfin_dart.ItemSortBy.productionYear,
      ],
      sortOrder: const [
        jellyfin_dart.SortOrder.ascending,
        jellyfin_dart.SortOrder.ascending,
        jellyfin_dart.SortOrder.ascending,
      ],
      fields: const [
        jellyfin_dart.ItemFields.primaryImageAspectRatio,
        jellyfin_dart.ItemFields.mediaSourceCount,
        jellyfin_dart.ItemFields.genres,
        jellyfin_dart.ItemFields.studios,
        jellyfin_dart.ItemFields.people,
        jellyfin_dart.ItemFields.overview,
        jellyfin_dart.ItemFields.productionLocations,
      ],
    );
  }

  /// 复制过滤器并修改部分参数
  MovieFilter copyWith({
    String? parentId,
    int? startIndex,
    int? limit,
    List<String>? genres,
    List<String>? tags,
    List<int>? years,
    String? nameStartsWith,
    List<String>? studios,
    List<String>? productionLocations,
    double? minCommunityRating,
    String? minOfficialRating,
    String? maxOfficialRating,
    bool? isHD,
    bool? is4K,
    bool? isPlayed,
    bool? isFavorite,
    List<jellyfin_dart.ItemFilter>? filters,
    List<jellyfin_dart.ItemSortBy>? sortBy,
    List<jellyfin_dart.SortOrder>? sortOrder,
    List<jellyfin_dart.ItemFields>? fields,
    bool? recursive,
    bool clearGenres = false,
    bool clearTags = false,
    bool clearYears = false,
    bool clearStudios = false,
    bool clearProductionLocations = false,
  }) {
    return MovieFilter(
      parentId: parentId ?? this.parentId,
      startIndex: startIndex ?? this.startIndex,
      limit: limit ?? this.limit,
      genres: clearGenres ? null : (genres ?? this.genres),
      tags: clearTags ? null : (tags ?? this.tags),
      years: clearYears ? null : (years ?? this.years),
      nameStartsWith: nameStartsWith ?? this.nameStartsWith,
      studios: clearStudios ? null : (studios ?? this.studios),
      productionLocations: clearProductionLocations ? null : (productionLocations ?? this.productionLocations),
      minCommunityRating: minCommunityRating ?? this.minCommunityRating,
      minOfficialRating: minOfficialRating ?? this.minOfficialRating,
      maxOfficialRating: maxOfficialRating ?? this.maxOfficialRating,
      isHD: isHD ?? this.isHD,
      is4K: is4K ?? this.is4K,
      isPlayed: isPlayed ?? this.isPlayed,
      isFavorite: isFavorite ?? this.isFavorite,
      filters: filters ?? this.filters,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      fields: fields ?? this.fields,
      recursive: recursive ?? this.recursive,
    );
  }

  @override
  List<Object?> get props => [
        parentId,
        startIndex,
        limit,
        genres,
        tags,
        years,
        nameStartsWith,
        studios,
        productionLocations,
        minCommunityRating,
        minOfficialRating,
        maxOfficialRating,
        isHD,
        is4K,
        isPlayed,
        isFavorite,
        filters,
        sortBy,
        sortOrder,
        fields,
        recursive,
      ];

  @override
  String toString() {
    return 'MovieFilter('
        'parentId: $parentId, '
        'startIndex: $startIndex, '
        'limit: $limit, '
        'genres: $genres, '
        'tags: $tags, '
        'years: $years, '
        'nameStartsWith: $nameStartsWith, '
        'studios: $studios, '
        'productionLocations: $productionLocations'
        ')';
  }
}

/// 电影过滤结果
///
/// 封装电影列表查询的返回结果
class MovieFilterResult extends Equatable {
  /// 电影列表
  final List<MovieItem> movies;

  /// 总记录数
  final int? totalCount;

  /// 起始索引
  final int? startIndex;

  const MovieFilterResult({
    required this.movies,
    this.totalCount,
    this.startIndex,
  });

  /// 是否为空
  bool get isEmpty => movies.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => movies.isNotEmpty;

  /// 数量
  int get length => movies.length;

  @override
  List<Object?> get props => [movies, totalCount, startIndex];
}

/// 电影项（简化版媒体项）
///
/// 用于电影列表展示的简化模型
class MovieItem extends Equatable {
  /// 电影ID
  final String id;

  /// 电影名称
  final String name;

  /// 制作年份
  final int? productionYear;

  /// 类型列表
  final List<String>? genres;

  /// 社区评分
  final double? communityRating;

  /// 官方分级
  final String? officialRating;

  /// 剧情简介
  final String? overview;

  /// 封面图片URL
  final String? coverImageUrl;

  /// 背景图片URL
  final String? backdropImageUrl;

  /// 运行时长（分钟）
  final int? runTimeMinutes;

  /// 工作室列表
  final List<String>? studios;

  /// 制作地区
  final List<String>? productionLocations;

  const MovieItem({
    required this.id,
    required this.name,
    this.productionYear,
    this.genres,
    this.communityRating,
    this.officialRating,
    this.overview,
    this.coverImageUrl,
    this.backdropImageUrl,
    this.runTimeMinutes,
    this.studios,
    this.productionLocations,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        productionYear,
        genres,
        communityRating,
        officialRating,
        overview,
        coverImageUrl,
        backdropImageUrl,
        runTimeMinutes,
        studios,
        productionLocations,
      ];

  @override
  String toString() {
    return 'MovieItem(id: $id, name: $name, year: $productionYear)';
  }
}
