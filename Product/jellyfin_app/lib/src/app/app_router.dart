import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_auth/jellyfin_auth_pages.dart';
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_music/jellyfin_music.dart' as music;
import 'package:jellyfin_music/jellyfin_music_pages.dart';
import '../data/jellyfin_gateway.dart';
import '../features/home/media_libraries_page.dart';
import '../features/media/media_route_pages.dart';
import '../features/music/music_route_pages.dart';
import '../features/playback/playback_route_page.dart';
import '../session/app_session.dart';
import '../session/app_session_controller.dart';

/// 认证重定向纯函数
String? resolveAuthRedirect({
  required bool isLoggedIn,
  required String matchedLocation,
  String loginPath = '/login',
  String homePath = '/libraries',
}) {
  final isLogin = matchedLocation == loginPath;
  if (!isLoggedIn && !isLogin) return loginPath;
  if (isLoggedIn && isLogin) return homePath;
  return null;
}

/// 创建 App 路由表
GoRouter createAppRouter({
  required AppSessionController sessionController,
  JellyfinGateway? gateway,
  music.AudioPlaybackPort? audioPlaybackPort,
  String initialLocation = '/login',
}) {
  final effectiveGateway = gateway ?? _StubGateway();
  final effectiveAudioPort = audioPlaybackPort;

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: sessionController,
    redirect: (context, state) => resolveAuthRedirect(
      isLoggedIn: sessionController.isLoggedIn,
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          onLogin: ({required serverUrl, required username, required password}) async {
            try {
              final session = await effectiveGateway.login(
                serverUrl: serverUrl,
                username: username,
                password: password,
              );
              sessionController.setSession(session);
              return null;
            } catch (e) {
              return '登录失败: $e';
            }
          },
        ),
      ),
      GoRoute(
        path: '/libraries',
        builder: (context, state) {
          final session = sessionController.currentSession;
          return MediaLibrariesPage(
            gateway: effectiveGateway,
            username: session?.username ?? '',
            onLibraryTap: (library) {
              switch (library.type) {
                case models.MediaLibraryType.movies:
                  context.push('/libraries/${library.id}/movies?name=${Uri.encodeComponent(library.name)}');
                case models.MediaLibraryType.tvshows:
                  context.push('/libraries/${library.id}/series');
                case models.MediaLibraryType.music:
                  context.push('/libraries/${library.id}/music');
                default:
                  context.push('/libraries/${library.id}/movies?name=${Uri.encodeComponent(library.name)}');
              }
            },
            onContinueWatchingTap: (item) {
              context.push('/media/items/${item.id}');
            },
            onLogout: () => sessionController.clearSession(),
          );
        },
      ),
      // 电影筛选页
      GoRoute(
        path: '/libraries/:libraryId/movies',
        builder: (context, state) {
          final libraryId = state.pathParameters['libraryId']!;
          final libraryName = state.uri.queryParameters['name'] ?? '媒体库';
          return MoviesRoutePage(
            gateway: effectiveGateway,
            libraryId: libraryId,
            libraryName: libraryName,
          );
        },
      ),
      // 剧集列表页
      GoRoute(
        path: '/libraries/:libraryId/series',
        builder: (context, state) {
          final libraryId = state.pathParameters['libraryId']!;
          final libraryName = state.uri.queryParameters['name'] ?? '剧集';
          return SeriesListRoutePage(
            gateway: effectiveGateway,
            library: models.MediaLibrary(
              id: libraryId,
              name: libraryName,
              type: models.MediaLibraryType.tvshows,
              serverUrl: sessionController.currentSession?.serverUrl ?? '',
            ),
          );
        },
      ),
      // 音乐库列表页
      GoRoute(
        path: '/libraries/:libraryId/music',
        builder: (context, state) {
          final libraryId = state.pathParameters['libraryId']!;
          final libraryName = state.uri.queryParameters['name'] ?? '音乐';
          return MusicLibraryRoutePage(
            gateway: effectiveGateway,
            audioPlaybackPort: effectiveAudioPort,
            library: models.MediaLibrary(
              id: libraryId,
              name: libraryName,
              type: models.MediaLibraryType.music,
              serverUrl: sessionController.currentSession?.serverUrl ?? '',
            ),
          );
        },
      ),
      // 专辑详情页
      GoRoute(
        path: '/music/albums/:albumId',
        builder: (context, state) {
          final albumId = state.pathParameters['albumId']!;
          return AlbumDetailRoutePage(
            gateway: effectiveGateway,
            audioPlaybackPort: effectiveAudioPort,
            albumId: albumId,
          );
        },
      ),
      // 艺术家详情页
      GoRoute(
        path: '/music/artists/:artistId',
        builder: (context, state) {
          final artistId = state.pathParameters['artistId']!;
          return ArtistDetailRoutePage(
            gateway: effectiveGateway,
            audioPlaybackPort: effectiveAudioPort,
            artistId: artistId,
          );
        },
      ),
      // 电影详情页
      GoRoute(
        path: '/movies/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return MovieDetailRoutePage(
            gateway: effectiveGateway,
            itemId: itemId,
          );
        },
      ),
      // 通用媒体详情页
      GoRoute(
        path: '/media/items/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return MediaDetailRoutePage(
            gateway: effectiveGateway,
            itemId: itemId,
          );
        },
      ),
      // 剧集季列表
      GoRoute(
        path: '/series/:seriesId/seasons',
        builder: (context, state) {
          final seriesId = state.pathParameters['seriesId']!;
          return SeriesSeasonsRoutePage(
            gateway: effectiveGateway,
            seriesId: seriesId,
          );
        },
      ),
      // 剧集集列表
      GoRoute(
        path: '/series/:seriesId/seasons/:seasonId/episodes',
        builder: (context, state) {
          final seriesId = state.pathParameters['seriesId']!;
          final seasonId = state.pathParameters['seasonId']!;
          return SeriesEpisodesRoutePage(
            gateway: effectiveGateway,
            seriesId: seriesId,
            seasonId: seasonId,
          );
        },
      ),
      // 视频播放
      GoRoute(
        path: '/playback/video/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return VideoPlaybackRoutePage(
            gateway: effectiveGateway,
            itemId: itemId,
          );
        },
      ),
      // 音乐播放详情页
      GoRoute(
        path: '/playback/music',
        builder: (context, state) {
          if (effectiveAudioPort == null) {
            return const Scaffold(body: Center(child: Text('播放器未初始化')));
          }
          return MusicPlayerPage(playbackPort: effectiveAudioPort);
        },
      ),
    ],
  );
}

/// 测试用空 gateway（无 gateway 时不抛错）
class _StubGateway implements JellyfinGateway {
  @override
  Future<AppSession> login({required String serverUrl, required String username, required String password}) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<void> register({required String serverUrl, required String adminUsername, required String adminPassword, required String username, required String password}) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<void> logout() async {}

  @override
  Future<List<models.MediaLibrary>> getMediaLibraries() async => [];

  @override
  Future<List<models.MediaItem>> getContinueWatching({int limit = 10}) async => [];

  @override
  Future<models.MediaItem> getMediaItemDetail(String itemId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<models.SeasonListResult> getSeasons(String seriesId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<models.EpisodeListResult> getEpisodes({required String seasonId, required String seriesId}) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<movies.MovieFilterResult> fetchMovies(movies.MovieFilter filter) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<models.MediaItemListResult> fetchMediaItems({
    required String parentId,
    bool recursive = true,
    int? limit,
  }) async {
    return models.MediaItemListResult(items: []);
  }

  @override
  Future<music.MusicAlbumListResult> fetchAlbums({
    required String parentId,
    int? startIndex,
    int? limit,
    String? sortBy,
  }) async {
    return const music.MusicAlbumListResult(albums: []);
  }

  @override
  Future<music.MusicArtistListResult> fetchArtists({
    required String parentId,
    int? startIndex,
    int? limit,
  }) async {
    return const music.MusicArtistListResult(artists: []);
  }

  @override
  Future<music.MusicSongListResult> fetchSongs({
    required String parentId,
    int? startIndex,
    int? limit,
  }) async {
    return const music.MusicSongListResult(songs: []);
  }

  @override
  Future<music.MusicAlbum> getAlbumDetail(String albumId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<music.MusicSongListResult> getAlbumSongs(String albumId) async {
    return const music.MusicSongListResult(songs: []);
  }

  @override
  Future<music.MusicArtist> getArtistDetail(String artistId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<music.MusicAlbumListResult> getArtistAlbums(String artistId) async {
    return const music.MusicAlbumListResult(albums: []);
  }
}
