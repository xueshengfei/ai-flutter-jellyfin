import 'package:equatable/equatable.dart';

import 'personal_media_query.dart';

/// 按媒体类型统计
final class MediaTypeCount extends Equatable {
  final PersonalMediaKind kind;
  final int watchedCount;
  final int favoriteCount;

  const MediaTypeCount({
    required this.kind,
    this.watchedCount = 0,
    this.favoriteCount = 0,
  });

  @override
  List<Object?> get props => [kind, watchedCount, favoriteCount];
}

/// 个人统计
final class PersonalStats extends Equatable {
  final int totalWatched;
  final int totalFavorites;
  final int continueWatchingCount;
  final List<MediaTypeCount> breakdown;

  const PersonalStats({
    this.totalWatched = 0,
    this.totalFavorites = 0,
    this.continueWatchingCount = 0,
    this.breakdown = const [],
  });

  @override
  List<Object?> get props => [
        totalWatched,
        totalFavorites,
        continueWatchingCount,
        breakdown,
      ];
}
