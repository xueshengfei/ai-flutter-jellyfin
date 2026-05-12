/// Stable route names used by the app shell and feature modules.
///
/// Feature modules should depend on these names through [AppNavigator] or
/// [NavigationIntent], not on concrete page classes from other modules.
abstract final class JellyfinRouteNames {
  static const login = 'auth.login';
  static const libraries = 'libraries.index';
  static const library = 'libraries.detail';
  static const mediaDetail = 'media.detail';
  static const movieDetail = 'movies.detail';
  static const seriesSeasons = 'series.seasons';
  static const seriesEpisodes = 'series.episodes';
  static const playbackVideo = 'playback.video';
  static const musicLibrary = 'music.library';
  static const musicAlbum = 'music.album';
  static const musicArtist = 'music.artist';
  static const musicSearch = 'music.search';
  static const aiRecommend = 'ai.recommend';
  static const profile = 'profile';
}
