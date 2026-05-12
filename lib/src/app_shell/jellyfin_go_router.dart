import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_playback/jellyfin_playback_pages.dart'
    as playback_pages;
import 'package:jellyfin_series/jellyfin_series_pages.dart' as series_pages;
import 'package:jellyfin_service/src/adapters/media_item_mapper.dart';
import 'package:jellyfin_service/src/app_shell/app_session.dart';
import 'package:jellyfin_service/src/app_shell/app_session_controller.dart';
import 'package:jellyfin_service/src/app_shell/feature_page_factory.dart';
import 'package:jellyfin_service/src/app_shell/playback_delegate_factory.dart';
import 'package:jellyfin_service/src/models/media_library_models.dart';
import 'package:jellyfin_service/src/models/media_item_models.dart' as local;
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_service/src/ui/pages/login_page.dart';
import 'package:jellyfin_service/src/ui/pages/media_libraries_page.dart';
import 'package:jellyfin_service/src/ui/pages/personal_page.dart';

/// Creates the single app-owned go_router instance.
///
/// Routes are registered manually here. Feature modules should not import
/// go_router or other feature pages directly; they should emit route intents.
GoRouter createJellyfinGoRouter({
  required AppSessionController sessionController,
  required AppNavigator appNavigator,
  String initialLocation = '/login',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: sessionController,
    redirect: (context, state) {
      final isLoggedIn = sessionController.isLoggedIn;
      final isLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLogin) return '/login';
      if (isLoggedIn && isLogin) return '/libraries';
      return null;
    },
    routes: [
      GoRoute(
        name: JellyfinRouteNames.login,
        path: '/login',
        builder: (context, state) =>
            LoginPage(onLoginSuccess: sessionController.setSession),
      ),
      GoRoute(
        name: JellyfinRouteNames.libraries,
        path: '/libraries',
        builder: (context, state) {
          final session = _requireSession(sessionController);
          return MediaLibrariesPage(
            client: session.client,
            user: session.user,
            navigator: appNavigator,
            onLogout: sessionController.logout,
          );
        },
      ),
      GoRoute(
        name: JellyfinRouteNames.library,
        path: '/libraries/:libraryId',
        builder: (context, state) {
          final session = _requireSession(sessionController);
          final libraryId = state.pathParameters['libraryId']!;
          final library = _extraValue<MediaLibrary>(state.extra, 'library');
          return _LibraryRoutePage(
            session: session,
            libraryId: libraryId,
            initialLibrary: library,
            navigator: appNavigator,
          );
        },
      ),
      GoRoute(
        name: JellyfinRouteNames.aiRecommend,
        path: '/ai/recommend',
        builder: (context, state) {
          final session = _requireSession(sessionController);
          return FeaturePageFactory(session, navigator: appNavigator).aiRecommendPage();
        },
      ),
      GoRoute(
        name: JellyfinRouteNames.profile,
        path: '/profile',
        builder: (context, state) {
          final session = _requireSession(sessionController);
          return PersonalPage(client: session.client);
        },
      ),
      GoRoute(
        name: JellyfinRouteNames.playbackVideo,
        path: '/playback/video/:itemId',
        builder: (context, state) {
          final session = _requireSession(sessionController);
          return _PlaybackRoutePage(
            session: session,
            itemId: state.pathParameters['itemId']!,
          );
        },
      ),
      GoRoute(
        name: JellyfinRouteNames.movieDetail,
        path: '/movies/:itemId',
        builder: (context, state) {
          final session = _requireSession(sessionController);
          return _MovieDetailRoutePage(
            session: session,
            itemId: state.pathParameters['itemId']!,
            navigator: appNavigator,
          );
        },
      ),
      GoRoute(
        name: JellyfinRouteNames.mediaDetail,
        path: '/media/items/:itemId',
        builder: (context, state) {
          final session = _requireSession(sessionController);
          return _MediaDetailRoutePage(
            session: session,
            itemId: state.pathParameters['itemId']!,
            navigator: appNavigator,
          );
        },
      ),
      GoRoute(
        name: JellyfinRouteNames.seriesSeasons,
        path: '/series/:seriesId/seasons',
        builder: (context, state) {
          final session = _requireSession(sessionController);
          return _SeriesSeasonsRoutePage(
            session: session,
            seriesId: state.pathParameters['seriesId']!,
            navigator: appNavigator,
          );
        },
      ),
      GoRoute(
        name: JellyfinRouteNames.seriesEpisodes,
        path: '/series/:seriesId/seasons/:seasonId/episodes',
        builder: (context, state) {
          final session = _requireSession(sessionController);
          return _EpisodesRoutePage(
            session: session,
            seriesId: state.pathParameters['seriesId']!,
            seasonId: state.pathParameters['seasonId']!,
            navigator: appNavigator,
          );
        },
      ),
    ],
  );
}

AppSession _requireSession(AppSessionController controller) {
  final session = controller.currentSession;
  if (session == null) {
    throw StateError('A logged-in AppSession is required for this route');
  }
  return session;
}

T? _extraValue<T>(Object? extra, String key) {
  if (extra is Map<String, Object?>) {
    final value = extra[key];
    if (value is T) return value;
  }
  return null;
}

class _LibraryRoutePage extends StatelessWidget {
  final AppSession session;
  final String libraryId;
  final MediaLibrary? initialLibrary;
  final AppNavigator? navigator;

  const _LibraryRoutePage({
    required this.session,
    required this.libraryId,
    this.initialLibrary,
    this.navigator,
  });

  @override
  Widget build(BuildContext context) {
    final library = initialLibrary;
    if (library != null) {
      return FeaturePageFactory(session, navigator: navigator).pageForLibrary(library);
    }

    return FutureBuilder<MediaLibraryListResult>(
      future: session.client.mediaLibrary.getMediaLibraries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _RouteLoadingPage();
        }
        if (snapshot.hasError) {
          return _RouteErrorPage(message: '${snapshot.error}');
        }

        final libraries = snapshot.data?.libraries ?? const <MediaLibrary>[];
        final matches = libraries.where((item) => item.id == libraryId);
        if (matches.isEmpty) {
          return _RouteErrorPage(
            message: 'Media library not found: $libraryId',
          );
        }
        return FeaturePageFactory(session, navigator: navigator).pageForLibrary(matches.first);
      },
    );
  }
}

class _PlaybackRoutePage extends StatelessWidget {
  final AppSession session;
  final String itemId;

  const _PlaybackRoutePage({required this.session, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<local.MediaItem>(
      future: session.client.mediaLibrary.getMediaItemDetail(itemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _RouteLoadingPage();
        }
        if (snapshot.hasError) {
          return _RouteErrorPage(message: '${snapshot.error}');
        }

        final item = snapshot.data;
        if (item == null) {
          return _RouteErrorPage(message: 'Media item not found: $itemId');
        }

        final sharedItem = MediaItemMapper.toShared(
          item,
          serverUrl: session.serverUrl,
          accessToken: session.accessToken,
        );
        return playback_pages.VideoPlayerPage(
          item: sharedItem,
          playback: PlaybackDelegateFactory(session.client).create(item),
        );
      },
    );
  }
}

class _MovieDetailRoutePage extends StatelessWidget {
  final AppSession session;
  final String itemId;
  final AppNavigator? navigator;

  const _MovieDetailRoutePage({
    required this.session,
    required this.itemId,
    this.navigator,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<local.MediaItem>(
      future: session.client.mediaLibrary.getMediaItemDetail(itemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _RouteLoadingPage();
        }
        if (snapshot.hasError) {
          return _RouteErrorPage(message: '${snapshot.error}');
        }

        final item = snapshot.data;
        if (item == null) {
          return _RouteErrorPage(message: 'Media item not found: $itemId');
        }

        final sharedItem = MediaItemMapper.toShared(
          item,
          serverUrl: session.serverUrl,
          accessToken: session.accessToken,
        );
        return FeaturePageFactory(session, navigator: navigator)
            .movieDetailPage(sharedItem);
      },
    );
  }
}

class _MediaDetailRoutePage extends StatelessWidget {
  final AppSession session;
  final String itemId;
  final AppNavigator? navigator;

  const _MediaDetailRoutePage({
    required this.session,
    required this.itemId,
    this.navigator,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<local.MediaItem>(
      future: session.client.mediaLibrary.getMediaItemDetail(itemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _RouteLoadingPage();
        }
        if (snapshot.hasError) {
          return _RouteErrorPage(message: '${snapshot.error}');
        }

        final item = snapshot.data;
        if (item == null) {
          return _RouteErrorPage(message: 'Media item not found: $itemId');
        }

        final sharedItem = MediaItemMapper.toShared(
          item,
          serverUrl: session.serverUrl,
          accessToken: session.accessToken,
        );
        return FeaturePageFactory(session, navigator: navigator)
            .mediaItemDetailPage(sharedItem);
      },
    );
  }
}

class _SeriesSeasonsRoutePage extends StatelessWidget {
  final AppSession session;
  final String seriesId;
  final AppNavigator? navigator;

  const _SeriesSeasonsRoutePage({
    required this.session,
    required this.seriesId,
    this.navigator,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<local.MediaItem>(
      future: session.client.mediaLibrary.getMediaItemDetail(seriesId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _RouteLoadingPage();
        }
        if (snapshot.hasError) {
          return _RouteErrorPage(message: '${snapshot.error}');
        }

        final item = snapshot.data;
        if (item == null) {
          return _RouteErrorPage(message: 'Series not found: $seriesId');
        }

        final sharedItem = MediaItemMapper.toShared(
          item,
          serverUrl: session.serverUrl,
          accessToken: session.accessToken,
        );
        return series_pages.SeasonsPage(
          series: sharedItem,
          fetchSeasons: (sId) async {
            final result = await session.client.mediaLibrary.getSeasons(sId);
            return models.SeasonListResult(
              seasons: result.seasons.map((s) => models.Season(
                id: s.id,
                seriesId: s.seriesId,
                name: s.name,
                indexNumber: s.indexNumber,
                serverUrl: s.serverUrl,
                primaryImageTag: s.primaryImageTag,
                overview: s.overview,
                episodeCount: s.episodeCount,
                accessToken: s.accessToken,
              )).toList(),
              totalCount: result.totalCount,
            );
          },
          onNavigateToEpisodes: (ctx, series, season) {
            final nav = navigator;
            if (nav != null) {
              nav.push(JellyfinRouteNames.seriesEpisodes,
                  arguments: {'seriesId': series.id, 'seasonId': season.id});
              return;
            }
          },
        );
      },
    );
  }
}

class _EpisodesRoutePage extends StatelessWidget {
  final AppSession session;
  final String seriesId;
  final String seasonId;
  final AppNavigator? navigator;

  const _EpisodesRoutePage({
    required this.session,
    required this.seriesId,
    required this.seasonId,
    this.navigator,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(local.MediaItem, local.SeasonListResult)>(
      future: Future.wait([
        session.client.mediaLibrary.getMediaItemDetail(seriesId),
        session.client.mediaLibrary.getSeasons(seriesId),
      ]).then((results) => (
        results[0] as local.MediaItem,
        results[1] as local.SeasonListResult,
      )),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _RouteLoadingPage();
        }
        if (snapshot.hasError) {
          return _RouteErrorPage(message: '${snapshot.error}');
        }

        final data = snapshot.data;
        if (data == null) {
          return _RouteErrorPage(message: 'Failed to load series/season data');
        }

        final (seriesItem, seasonResult) = data;
        final matchingSeasons = seasonResult.seasons.where((s) => s.id == seasonId);
        if (matchingSeasons.isEmpty) {
          return _RouteErrorPage(message: 'Season not found: $seasonId');
        }

        final rootSeason = matchingSeasons.first;
        final sharedSeries = MediaItemMapper.toShared(
          seriesItem,
          serverUrl: session.serverUrl,
          accessToken: session.accessToken,
        );
        final sharedSeason = models.Season(
          id: rootSeason.id,
          seriesId: rootSeason.seriesId,
          name: rootSeason.name,
          indexNumber: rootSeason.indexNumber,
          serverUrl: rootSeason.serverUrl,
          primaryImageTag: rootSeason.primaryImageTag,
          overview: rootSeason.overview,
          episodeCount: rootSeason.episodeCount,
          accessToken: rootSeason.accessToken,
        );

        return FeaturePageFactory(session, navigator: navigator)
            .episodesPage(sharedSeries, sharedSeason);
      },
    );
  }
}

class _RouteLoadingPage extends StatelessWidget {
  const _RouteLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _RouteErrorPage extends StatelessWidget {
  final String message;

  const _RouteErrorPage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}
