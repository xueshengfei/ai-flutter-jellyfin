/// jellyfin_movies - 电影业务模块
///
/// 包含：
/// - 电影过滤页 [MovieFilterPage]
/// - 电影详情页 [MovieDetailPage]
/// - 电影过滤模型 [MovieFilter] / [MovieFilterResult]
/// - 回调类型 [MoviesFetcher] / [MovieDetailFetcher]
///
/// **导入方式**：
/// ```dart
/// import 'package:jellyfin_movies/jellyfin_movies.dart';
/// ```
library;

export 'src/models/movie_filter_models.dart';
export 'src/pages/movie_detail_page.dart' show MovieDetailPage, MovieDetailFetcher;
