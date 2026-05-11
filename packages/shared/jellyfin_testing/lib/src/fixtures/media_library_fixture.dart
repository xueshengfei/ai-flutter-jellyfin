import 'package:jellyfin_models/jellyfin_models.dart';

/// 测试用电影库
const MediaLibrary testMovieLibrary = MediaLibrary(
  id: 'lib-movies-001',
  name: '电影',
  type: MediaLibraryType.movies,
  serverUrl: 'http://test-server:8096',
  itemCount: 100,
);

/// 测试用音乐库
const MediaLibrary testMusicLibrary = MediaLibrary(
  id: 'lib-music-001',
  name: '音乐',
  type: MediaLibraryType.music,
  serverUrl: 'http://test-server:8096',
  itemCount: 500,
);

/// 测试用剧集库
const MediaLibrary testTvShowLibrary = MediaLibrary(
  id: 'lib-tvshows-001',
  name: '电视剧',
  type: MediaLibraryType.tvshows,
  serverUrl: 'http://test-server:8096',
  itemCount: 50,
);

/// 测试用媒体库列表
const MediaLibraryListResult testLibraryList = MediaLibraryListResult(
  libraries: [testMovieLibrary, testMusicLibrary, testTvShowLibrary],
  totalCount: 3,
);
