import 'package:equatable/equatable.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

/// 排序字段
enum MovieSortField {
  dateCreated,
  sortName,
  productionYear,
  premiereDate,
  random,
  communityRating,
}

/// 排序顺序
enum MovieSortOrder {
  ascending,
  descending,
}

/// 电影过滤器
///
/// 纯 Dart 模型，不依赖 jellyfin_dart。
/// jellyfin_dart 的 ItemSortBy/SortOrder/ItemFilter 转换只允许在根包适配层。
class MovieFilter extends Equatable {
  final String parentId;
  final int startIndex;
  final int limit;
  final List<String>? genres;
  final List<String>? tags;
  final List<int>? years;
  final String? nameStartsWith;
  final String? searchTerm;
  final List<String>? studios;
  final List<String>? productionLocations;
  final double? minCommunityRating;
  final String? minOfficialRating;
  final String? maxOfficialRating;
  final bool? isHD;
  final bool? is4K;
  final bool? isPlayed;
  final bool? isFavorite;
  final bool? isUnplayed;
  final List<MovieSortField>? sortBy;
  final List<MovieSortOrder>? sortOrder;
  final bool? recursive;

  const MovieFilter({
    required this.parentId,
    this.startIndex = 0,
    this.limit = 20,
    this.genres,
    this.tags,
    this.years,
    this.nameStartsWith,
    this.searchTerm,
    this.studios,
    this.productionLocations,
    this.minCommunityRating,
    this.minOfficialRating,
    this.maxOfficialRating,
    this.isHD,
    this.is4K,
    this.isPlayed,
    this.isFavorite,
    this.isUnplayed,
    this.sortBy,
    this.sortOrder,
    this.recursive = true,
  });

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
        MovieSortField.dateCreated,
        MovieSortField.sortName,
        MovieSortField.productionYear,
      ],
      sortOrder: const [
        MovieSortOrder.ascending,
        MovieSortOrder.ascending,
        MovieSortOrder.ascending,
      ],
    );
  }

  MovieFilter copyWith({
    String? parentId,
    int? startIndex,
    int? limit,
    List<String>? genres,
    List<String>? tags,
    List<int>? years,
    String? nameStartsWith,
    String? searchTerm,
    List<String>? studios,
    List<String>? productionLocations,
    double? minCommunityRating,
    String? minOfficialRating,
    String? maxOfficialRating,
    bool? isHD,
    bool? is4K,
    bool? isPlayed,
    bool? isFavorite,
    bool? isUnplayed,
    List<MovieSortField>? sortBy,
    List<MovieSortOrder>? sortOrder,
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
      searchTerm: searchTerm ?? this.searchTerm,
      studios: clearStudios ? null : (studios ?? this.studios),
      productionLocations: clearProductionLocations ? null : (productionLocations ?? this.productionLocations),
      minCommunityRating: minCommunityRating ?? this.minCommunityRating,
      minOfficialRating: minOfficialRating ?? this.minOfficialRating,
      maxOfficialRating: maxOfficialRating ?? this.maxOfficialRating,
      isHD: isHD ?? this.isHD,
      is4K: is4K ?? this.is4K,
      isPlayed: isPlayed ?? this.isPlayed,
      isFavorite: isFavorite ?? this.isFavorite,
      isUnplayed: isUnplayed ?? this.isUnplayed,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      recursive: recursive ?? this.recursive,
    );
  }

  @override
  List<Object?> get props => [
        parentId, startIndex, limit, genres, tags, years,
        nameStartsWith, searchTerm, studios, productionLocations,
        minCommunityRating, minOfficialRating, maxOfficialRating,
        isHD, is4K, isPlayed, isFavorite, isUnplayed,
        sortBy, sortOrder, recursive,
      ];
}

/// 电影过滤结果
class MovieFilterResult extends Equatable {
  final List<MediaItem> movies;
  final int? totalCount;
  final int? startIndex;

  const MovieFilterResult({
    required this.movies,
    this.totalCount,
    this.startIndex,
  });

  bool get isEmpty => movies.isEmpty;
  bool get isNotEmpty => movies.isNotEmpty;
  int get length => movies.length;

  @override
  List<Object?> get props => [movies, totalCount, startIndex];
}

/// 获取电影列表回调
typedef MoviesFetcher = Future<MovieFilterResult> Function(MovieFilter filter);
