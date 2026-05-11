import 'package:jellyfin_models/jellyfin_models.dart';

/// 测试用电影 MediaItem
const MediaItem testMovieItem = MediaItem(
  id: 'item-movie-001',
  name: '测试电影',
  type: 'Movie',
  serverUrl: 'http://test-server:8096',
  productionYear: 2024,
  genres: ['动作', '科幻'],
  communityRating: 8.5,
  runTimeMinutes: 120,
  overview: '这是一部测试电影',
  directors: ['测试导演'],
  actors: ['测试演员A', '测试演员B'],
);

/// 测试用剧集 MediaItem
const MediaItem testSeriesItem = MediaItem(
  id: 'item-series-001',
  name: '测试剧集',
  type: 'Series',
  serverUrl: 'http://test-server:8096',
  productionYear: 2023,
  genres: ['剧情', '悬疑'],
  communityRating: 9.0,
);

/// 测试用季
const Season testSeason = Season(
  id: 'season-001',
  seriesId: 'item-series-001',
  name: '第 1 季',
  indexNumber: 1,
  serverUrl: 'http://test-server:8096',
  episodeCount: 10,
);

/// 测试用集
const Episode testEpisode = Episode(
  id: 'episode-001',
  seriesId: 'item-series-001',
  seasonId: 'season-001',
  name: '第 1 集',
  serverUrl: 'http://test-server:8096',
  seasonNumber: 1,
  episodeNumber: 1,
  runTimeMinutes: 45,
);

/// 测试用媒体项列表
const MediaItemListResult testMediaItemList = MediaItemListResult(
  items: [testMovieItem, testSeriesItem],
  totalCount: 2,
);
