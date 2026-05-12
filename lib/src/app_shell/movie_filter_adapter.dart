import 'package:jellyfin_service/src/models/movie_filter_models.dart' as movie_models;
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;

/// 根包 MovieFilter ↔ movies 模块 MovieFilter 的双向转换
class MovieFilterAdapter {
  /// 将 movies 模块的纯 Dart [MovieFilter] 转为根包的 [MovieFilter]（含 jellyfin_dart 类型）
  static movie_models.MovieFilter convert(movies.MovieFilter filter) {
    return movie_models.MovieFilter(
      parentId: filter.parentId,
      startIndex: filter.startIndex,
      limit: filter.limit,
      genres: filter.genres,
      tags: filter.tags,
      years: filter.years,
      nameStartsWith: filter.nameStartsWith,
      studios: filter.studios,
      productionLocations: filter.productionLocations,
      minCommunityRating: filter.minCommunityRating,
      minOfficialRating: filter.minOfficialRating,
      maxOfficialRating: filter.maxOfficialRating,
      isHD: filter.isHD,
      is4K: filter.is4K,
      recursive: filter.recursive,
      filters: filter.isUnplayed == true
          ? const [jellyfin_dart.ItemFilter.isUnplayed]
          : null,
      sortBy: filter.sortBy?.map(convertSortField).toList(),
      sortOrder: filter.sortOrder?.map(convertSortOrder).toList(),
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

  static jellyfin_dart.ItemSortBy convertSortField(movies.MovieSortField field) {
    switch (field) {
      case movies.MovieSortField.dateCreated: return jellyfin_dart.ItemSortBy.dateCreated;
      case movies.MovieSortField.sortName: return jellyfin_dart.ItemSortBy.sortName;
      case movies.MovieSortField.productionYear: return jellyfin_dart.ItemSortBy.productionYear;
      case movies.MovieSortField.premiereDate: return jellyfin_dart.ItemSortBy.premiereDate;
      case movies.MovieSortField.random: return jellyfin_dart.ItemSortBy.random;
      case movies.MovieSortField.communityRating: return jellyfin_dart.ItemSortBy.communityRating;
    }
  }

  static jellyfin_dart.SortOrder convertSortOrder(movies.MovieSortOrder order) {
    switch (order) {
      case movies.MovieSortOrder.ascending: return jellyfin_dart.SortOrder.ascending;
      case movies.MovieSortOrder.descending: return jellyfin_dart.SortOrder.descending;
    }
  }
}
