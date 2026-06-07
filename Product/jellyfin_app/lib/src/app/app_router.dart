import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_auth/jellyfin_auth.dart';
import 'package:jellyfin_download/jellyfin_download.dart';
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_music/jellyfin_music.dart' as music;
import 'package:jellyfin_music/jellyfin_music_pages.dart';
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:rvc_flutter/rvc_flutter.dart';
import '../data/jellyfin_gateway.dart';
import '../features/ai/ai_route_page.dart';
import '../features/home/media_libraries_page.dart';
import '../features/media/media_route_pages.dart';
import '../features/music/music_route_pages.dart';
import '../features/personal/personal_route_page.dart';
import '../features/personal/personal_settings_route_page.dart';
import '../features/personal/personal_stats_route_page.dart';
import '../features/playback/playback_route_page.dart';
import '../features/rvc/rvc_route_page.dart';
import '../session/app_session.dart';
import '../session/app_session_controller.dart';
import '../ui/jellyfin_app_image_provider.dart';

/// ? Jellyfin ???????? IP ?????????
///
/// ?: deriveServiceUrl('http://192.168.1.100:8096', 5005)
///   ? 'http://192.168.1.100:5005'
String deriveServiceUrl(String serverUrl, int port) {
  final uri = Uri.parse(serverUrl);
  return '${uri.scheme}://${uri.host}:$port';
}

/// ????????
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

String _buildMediaDownloadUrl({
  required AppSession session,
  required models.MediaItem item,
}) {
  final serverUrl = session.serverUrl.replaceFirst(RegExp(r'/$'), '');
  final itemId = Uri.encodeComponent(item.id);
  final token = Uri.encodeQueryComponent(session.accessToken);
  return '$serverUrl/Items/$itemId/Download?api_key=$token';
}

/// ?? App ???
GoRouter createAppRouter({
  required AppSessionController sessionController,
  JellyfinGateway? gateway,
  PersonalRepository? personalRepository,
  music.AudioPlaybackPort? audioPlaybackPort,
  RvcTaskController? rvcTaskController,
  ServerDiscoveryService? discoveryService,
  String initialLocation = '/login',
}) {
  final effectiveGateway = gateway ?? _StubGateway();
  final effectiveAudioPort = audioPlaybackPort;
  final downloadController = DownloadController();

  Future<void> startMediaDownload(
    BuildContext context,
    models.MediaItem item,
  ) async {
    final session = sessionController.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('????????')));
      return;
    }

    final downloadUrl = _buildMediaDownloadUrl(session: session, item: item);

    downloadController.startListening();
    await downloadController.startDownload(
      downloadUrl,
      title: item.name,
      mediaItemId: item.id,
      imageItemId: item.id,
      imageTag: item.primaryImageTag,
    );

    if (!context.mounted) return;
    context.push('/downloads');
  }

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
          discoveryService: discoveryService,
          onLogin:
              ({
                required serverUrl,
                required username,
                required password,
              }) async {
                try {
                  final session = await effectiveGateway.login(
                    serverUrl: serverUrl,
                    username: username,
                    password: password,
                  );
                  sessionController.setSession(session);
                  return null;
                } catch (e) {
                  return '????: $e';
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
            imageProvider: JellyfinAppImageProvider(
              serverUrl: session?.serverUrl ?? '',
              accessToken: session?.accessToken ?? '',
            ),
            onLibraryTap: (library) {
              switch (library.type) {
                case models.MediaLibraryType.movies:
                  context.push(
                    '/libraries/${library.id}/movies?name=${Uri.encodeComponent(library.name)}',
                  );
                case models.MediaLibraryType.tvshows:
                  context.push('/libraries/${library.id}/series');
                case models.MediaLibraryType.music:
                  context.push('/libraries/${library.id}/music');
                default:
                  context.push(
                    '/libraries/${library.id}/movies?name=${Uri.encodeComponent(library.name)}',
                  );
              }
            },
            onContinueWatchingTap: (item) {
              context.push('/media/items/${item.id}');
            },
            onLogout: () => sessionController.clearSession(),
            onOpenPersonal: () => context.push('/personal'),
            onOpenAiRecommendation: () => context.push('/ai'),
          );
        },
      ),
      // ?????
      GoRoute(
        path: '/libraries/:libraryId/movies',
        builder: (context, state) {
          final libraryId = state.pathParameters['libraryId']!;
          final libraryName = state.uri.queryParameters['name'] ?? '???';
          final session = sessionController.currentSession;
          return MoviesRoutePage(
            gateway: effectiveGateway,
            libraryId: libraryId,
            libraryName: libraryName,
            imageProvider: JellyfinAppImageProvider(
              serverUrl: session?.serverUrl ?? '',
              accessToken: session?.accessToken ?? '',
            ),
          );
        },
      ),
      // ?????
      GoRoute(
        path: '/libraries/:libraryId/series',
        builder: (context, state) {
          final libraryId = state.pathParameters['libraryId']!;
          final libraryName = state.uri.queryParameters['name'] ?? '??';
          final session = sessionController.currentSession;
          return SeriesListRoutePage(
            gateway: effectiveGateway,
            library: models.MediaLibrary(
              id: libraryId,
              name: libraryName,
              type: models.MediaLibraryType.tvshows,
              serverUrl: session?.serverUrl ?? '',
            ),
            imageProvider: JellyfinAppImageProvider(
              serverUrl: session?.serverUrl ?? '',
              accessToken: session?.accessToken ?? '',
            ),
          );
        },
      ),
      // ??????
      GoRoute(
        path: '/libraries/:libraryId/music',
        builder: (context, state) {
          final libraryId = state.pathParameters['libraryId']!;
          final libraryName = state.uri.queryParameters['name'] ?? '??';
          final session = sessionController.currentSession;
          return MusicLibraryRoutePage(
            gateway: effectiveGateway,
            audioPlaybackPort: effectiveAudioPort,
            imageProvider: JellyfinAppImageProvider(
              serverUrl: session?.serverUrl ?? '',
              accessToken: session?.accessToken ?? '',
            ),
            library: models.MediaLibrary(
              id: libraryId,
              name: libraryName,
              type: models.MediaLibraryType.music,
              serverUrl: sessionController.currentSession?.serverUrl ?? '',
            ),
          );
        },
      ),
      // ?????
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
      // ??????
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
      // ?????
      GoRoute(
        path: '/libraries/:libraryId/music/search',
        builder: (context, state) {
          final libraryId = state.pathParameters['libraryId']!;
          return MusicSearchRoutePage(
            gateway: effectiveGateway,
            audioPlaybackPort: effectiveAudioPort,
            libraryId: libraryId,
          );
        },
      ),
      // ???
      GoRoute(
        path: '/music/lyrics',
        builder: (context, state) {
          if (effectiveAudioPort == null) {
            return const Scaffold(body: Center(child: Text('???????')));
          }
          final track = effectiveAudioPort.currentTrack;
          return LyricsPage(
            playbackPort: effectiveAudioPort,
            fetchLyrics: effectiveGateway.getLyrics,
            searchRemoteLyrics: effectiveGateway.searchRemoteLyrics,
            downloadRemoteLyrics: ({required itemId, required lyricId}) =>
                effectiveGateway.downloadRemoteLyrics(
                  itemId: itemId,
                  lyricId: lyricId,
                ),
            albumCoverUrl: track?.coverUrl,
          );
        },
      ),
      // ?????
      GoRoute(
        path: '/movies/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          final session = sessionController.currentSession;
          return MovieDetailRoutePage(
            gateway: effectiveGateway,
            itemId: itemId,
            imageProvider: JellyfinAppImageProvider(
              serverUrl: session?.serverUrl ?? '',
              accessToken: session?.accessToken ?? '',
            ),
            onStartDownload: startMediaDownload,
          );
        },
      ),
      // ???????
      GoRoute(
        path: '/media/items/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          final session = sessionController.currentSession;
          return MediaDetailRoutePage(
            gateway: effectiveGateway,
            itemId: itemId,
            imageProvider: JellyfinAppImageProvider(
              serverUrl: session?.serverUrl ?? '',
              accessToken: session?.accessToken ?? '',
            ),
            onStartDownload: startMediaDownload,
          );
        },
      ),
      // ?????
      GoRoute(
        path: '/series/:seriesId/seasons',
        builder: (context, state) {
          final seriesId = state.pathParameters['seriesId']!;
          final session = sessionController.currentSession;
          return SeriesSeasonsRoutePage(
            gateway: effectiveGateway,
            seriesId: seriesId,
            imageProvider: JellyfinAppImageProvider(
              serverUrl: session?.serverUrl ?? '',
              accessToken: session?.accessToken ?? '',
            ),
          );
        },
      ),
      // ?????
      GoRoute(
        path: '/series/:seriesId/seasons/:seasonId/episodes',
        builder: (context, state) {
          final seriesId = state.pathParameters['seriesId']!;
          final seasonId = state.pathParameters['seasonId']!;
          final session = sessionController.currentSession;
          return SeriesEpisodesRoutePage(
            gateway: effectiveGateway,
            seriesId: seriesId,
            seasonId: seasonId,
            imageProvider: JellyfinAppImageProvider(
              serverUrl: session?.serverUrl ?? '',
              accessToken: session?.accessToken ?? '',
            ),
          );
        },
      ),
      // ????
      GoRoute(
        path: '/playback/video/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          final serverUrl = sessionController.currentSession?.serverUrl;
          return VideoPlaybackRoutePage(
            gateway: effectiveGateway,
            itemId: itemId,
            aiServiceUrl: serverUrl != null && serverUrl.isNotEmpty
                ? deriveServiceUrl(serverUrl, 5005)
                : null,
            onStartDownload: startMediaDownload,
          );
        },
      ),
      // ???????
      GoRoute(
        path: '/playback/music',
        builder: (context, state) {
          if (effectiveAudioPort == null) {
            return const Scaffold(body: Center(child: Text('???????')));
          }
          return MusicPlayerPage(
            playbackPort: effectiveAudioPort,
            onOpenLyrics: () => context.push('/music/lyrics'),
            onOpenRvc: () {
              final audioPath = effectiveAudioPort.currentTrack?.path;
              final location = audioPath != null && audioPath.isNotEmpty
                  ? '/rvc?audioPath=${Uri.encodeComponent(audioPath)}'
                  : '/rvc';
              context.push(location);
            },
            fetchLyrics: effectiveGateway.getLyrics,
          );
        },
      ),
      // RVC ????
      GoRoute(
        path: '/rvc',
        builder: (context, state) {
          if (rvcTaskController == null) {
            return const Scaffold(body: Center(child: Text('RVC ?????')));
          }
          final audioPath = state.uri.queryParameters['audioPath'];
          return RvcRoutePage(
            controller: rvcTaskController,
            audioPath: audioPath,
          );
        },
      ),
      GoRoute(
        path: '/downloads',
        builder: (context, state) {
          final session = sessionController.currentSession;
          return DownloadsPage(
            controller: downloadController,
            imageProvider: session != null
                ? JellyfinAppImageProvider(
                    serverUrl: session.serverUrl,
                    accessToken: session.accessToken,
                  )
                : null,
            onOpenCompletedTask: (context, task) {
              final mediaItemId = task.mediaItemId;
              if (mediaItemId == null || mediaItemId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('???????????? id')),
                );
                return;
              }
              context.push('/playback/video/$mediaItemId');
            },
          );
        },
      ),
      // ????
      GoRoute(
        path: '/personal',
        builder: (context, state) {
          final repository = personalRepository;
          if (repository == null) {
            return const Scaffold(body: Center(child: Text('???????')));
          }
          return PersonalRoutePage(
            repository: repository,
            sessionController: sessionController,
          );
        },
      ),
      // ????
      GoRoute(
        path: '/personal/settings',
        builder: (context, state) {
          final repository = personalRepository;
          if (repository == null) {
            return const Scaffold(body: Center(child: Text('???????')));
          }
          return PersonalSettingsRoutePage(
            repository: repository,
            sessionController: sessionController,
          );
        },
      ),
      // ????
      GoRoute(
        path: '/personal/stats',
        builder: (context, state) {
          final repository = personalRepository;
          if (repository == null) {
            return const Scaffold(body: Center(child: Text('???????')));
          }
          return PersonalStatsRoutePage(
            repository: repository,
            sessionController: sessionController,
          );
        },
      ),
      // AI ??
      GoRoute(
        path: '/ai',
        builder: (context, state) {
          final session = sessionController.currentSession;
          final serverUrl = session?.serverUrl;
          if (serverUrl == null || serverUrl.isEmpty) {
            return const Scaffold(body: Center(child: Text('???')));
          }
          return AiRecommendRoutePage(
            gateway: effectiveGateway,
            aiServiceUrl: deriveServiceUrl(serverUrl, 5005),
            audioPlaybackPort: effectiveAudioPort,
            imageProvider: JellyfinAppImageProvider(
              serverUrl: serverUrl,
              accessToken: session?.accessToken ?? '',
            ),
          );
        },
      ),
    ],
  );
}

/// ???? gateway?? gateway ?????
class _StubGateway implements JellyfinGateway {
  @override
  Future<AppSession> login({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<void> register({
    required String serverUrl,
    required String adminUsername,
    required String adminPassword,
    required String username,
    required String password,
  }) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<void> logout() async {}

  @override
  Future<List<models.MediaLibrary>> getMediaLibraries() async => [];

  @override
  Future<List<models.MediaItem>> getContinueWatching({int limit = 10}) async =>
      [];

  @override
  Future<models.MediaItem> getMediaItemDetail(String itemId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<models.SeasonListResult> getSeasons(String seriesId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<models.EpisodeListResult> getEpisodes({
    required String seasonId,
    required String seriesId,
  }) {
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
    int? startIndex,
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

  @override
  Future<music.MusicSearchResult> searchMusic({
    required String searchTerm,
    String? parentId,
    int? limit,
  }) async {
    return const music.MusicSearchResult();
  }

  @override
  Future<music.LyricsData?> getLyrics(String itemId) async => null;

  @override
  Future<List<music.RemoteLyricsInfo>> searchRemoteLyrics(
    String itemId,
  ) async => [];

  @override
  Future<music.LyricsData> downloadRemoteLyrics({
    required String itemId,
    required String lyricId,
  }) {
    throw UnimplementedError('No gateway configured');
  }
}
