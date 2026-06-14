import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_auth/jellyfin_auth.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_download/jellyfin_download.dart';
import 'package:jellyfin_ai_recommendation/jellyfin_ai_recommendation.dart';
import 'package:jellyfin_media/jellyfin_media_pages.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;
import 'package:jellyfin_movies/jellyfin_movies_pages.dart';
import 'package:jellyfin_music/jellyfin_music.dart' as music;
import 'package:jellyfin_music/jellyfin_music_pages.dart';
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';
import 'package:jellyfin_playback/jellyfin_playback_pages.dart';
import 'package:jellyfin_series/jellyfin_series_pages.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';
import 'package:rvc_flutter/rvc_flutter.dart';

import '../data/jellyfin_gateway.dart';
import '../data/playback_adapter.dart';
import '../data/watch_assist_client.dart';
import '../features/home/media_libraries_page.dart';
import '../session/app_session.dart';
import '../session/app_session_controller.dart';

/// 从 Jellyfin 服务器地址推导同 IP 不同端口的服务地址
String deriveServiceUrl(String serverUrl, int port) {
  final uri = Uri.parse(serverUrl);
  return '${uri.scheme}://${uri.host}:$port';
}

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

/// 拼出 Jellyfin 原文件下载地址
String _buildMediaDownloadUrl({
  required AppSession session,
  required models.MediaItem item,
}) {
  final serverUrl = session.serverUrl.replaceFirst(RegExp(r'/$'), '');
  final itemId = Uri.encodeComponent(item.id);
  final token = Uri.encodeQueryComponent(session.accessToken);
  return '$serverUrl/Items/$itemId/Download?api_key=$token';
}

/// MusicSong → AudioTrack
music.AudioTrack _songToTrack(music.MusicSong song) {
  return music.AudioTrack(
    id: song.id,
    name: song.name,
    streamUrl: song.getStreamUrl(),
    coverUrl: song.getAlbumCoverUrl(fillWidth: 480, fillHeight: 480),
    artistText: song.artistText,
    duration: song.runTimeSeconds != null
        ? Duration(seconds: song.runTimeSeconds!)
        : null,
    albumName: song.albumName,
    trackNumber: song.trackNumber,
    isFavorite: song.isFavorite,
    path: song.path,
  );
}

List<music.AudioTrack> _songsToTracks(List<music.MusicSong> songs) {
  return songs.map(_songToTrack).toList();
}

/// 创建 App 路由表
///
/// 采用 Feature 模块自注册模式：各 feature 包注册自己的路由，
/// Product App 负责注入 ServiceRegistry 和 App 专用路由。
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
  final goRouterNavigator = GoRouterAppNavigator();

  // ──────────── 统一下载入口 ────────────
  Future<void> startMediaDownload(
    BuildContext context,
    models.MediaItem item,
  ) async {
    final session = sessionController.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先登录后再下载')));
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

  // ──────────── 服务注册表 ────────────
  Map<Type, Object> buildServices(AppSession? session) {
    return <Type, Object>{
      AppNavigator: goRouterNavigator,
      JellyfinGateway: effectiveGateway,
      if (personalRepository != null)
        PersonalRepository: personalRepository,
      if (effectiveAudioPort != null)
        music.AudioPlaybackPort: effectiveAudioPort,
      if (rvcTaskController != null) RvcTaskController: rvcTaskController,
      PersonalModuleConfig: const PersonalModuleConfig.full(),
      LogoutAction: LogoutAction(() => sessionController.clearSession()),
    };
  }

  /// 构建 ServiceRegistry（图片 Scope 已在 JellyfinApp 根层 ListenableBuilder 内包裹）
  Widget wrapWithServices(AppSession? session, {required Widget child}) {
    return ServiceRegistry(
      services: buildServices(session),
      child: child,
    );
  }

  // ──────────── Feature 模块路由 ────────────
  final featureRoutes = <GoRoute>[
    // ─── 个人中心 ───
    GoRoute(
      path: '/personal',
      name: JellyfinRouteNames.profile,
      builder: (context, state) {
        if (personalRepository == null) {
          return const Scaffold(body: Center(child: Text('个人模块未配置')));
        }
        final session = sessionController.currentSession;
        if (session == null) {
          return const Scaffold(body: Center(child: Text('登录态不存在')));
        }
        return wrapWithServices(
          session,
          child: Builder(builder: (context) {
            return PersonalPage(
              repository: personalRepository,
              config: const PersonalModuleConfig.full(),
              onLogout: () => sessionController.clearSession(),
            );
          }),
        );
      },
    ),
    GoRoute(
      path: '/personal/settings',
      name: JellyfinRouteNames.profileSettings,
      builder: (context, state) {
        if (personalRepository == null) {
          return const Scaffold(body: Center(child: Text('个人模块未配置')));
        }
        final session = sessionController.currentSession;
        if (session == null) {
          return const Scaffold(body: Center(child: Text('登录态不存在')));
        }
        return wrapWithServices(
          session,
          child: Builder(builder: (context) {
            return PersonalSettingsPage(
              repository: personalRepository,
              onLogout: () => sessionController.clearSession(),
            );
          }),
        );
      },
    ),
    GoRoute(
      path: '/personal/stats',
      name: JellyfinRouteNames.profileStats,
      builder: (context, state) {
        if (personalRepository == null) {
          return const Scaffold(body: Center(child: Text('个人模块未配置')));
        }
        final session = sessionController.currentSession;
        if (session == null) {
          return const Scaffold(body: Center(child: Text('登录态不存在')));
        }
        return wrapWithServices(
          session,
          child: Builder(builder: (context) {
            return PersonalStatsPage(
              repository: personalRepository,
              config: const PersonalModuleConfig.full(),
            );
          }),
        );
      },
    ),

    // ─── 电影筛选 ───
    GoRoute(
      path: '/libraries/:libraryId/movies',
      builder: (context, state) {
        final libraryId = state.pathParameters['libraryId']!;
        final libraryName = state.uri.queryParameters['name'] ?? '媒体库';
        final session = sessionController.currentSession;
        return wrapWithServices(
          session,
          child: Builder(builder: (context) {
            return _MoviesRouteContent(
              gateway: effectiveGateway,
              libraryId: libraryId,
              libraryName: libraryName,
            );
          }),
        );
      },
    ),

    // ─── 剧集列表 ───
    GoRoute(
      path: '/libraries/:libraryId/series',
      builder: (context, state) {
        final libraryId = state.pathParameters['libraryId']!;
        final libraryName = state.uri.queryParameters['name'] ?? '剧集';
        final session = sessionController.currentSession;
        return wrapWithServices(
          session,
          child: Builder(builder: (context) {
            return _SeriesListRouteContent(
              gateway: effectiveGateway,
              library: models.MediaLibrary(
                id: libraryId,
                name: libraryName,
                type: models.MediaLibraryType.tvshows,
                serverUrl: session?.serverUrl ?? '',
              ),
            );
          }),
        );
      },
    ),

    // ─── 电影详情 ───
    GoRoute(
      path: '/movies/:itemId',
      name: JellyfinRouteNames.movieDetail,
      builder: (context, state) {
        final itemId = state.pathParameters['itemId']!;
        final session = sessionController.currentSession;
        return wrapWithServices(
          session,
          child: Builder(builder: (context) {
            return _MovieDetailRouteContent(
              gateway: effectiveGateway,
              itemId: itemId,
              onStartDownload: startMediaDownload,
            );
          }),
        );
      },
    ),

    // ─── 通用媒体详情 ───
    GoRoute(
      path: '/media/items/:itemId',
      name: JellyfinRouteNames.mediaDetail,
      builder: (context, state) {
        final itemId = state.pathParameters['itemId']!;
        final session = sessionController.currentSession;
        return wrapWithServices(
          session,
          child: Builder(builder: (context) {
            return _MediaDetailRouteContent(
              gateway: effectiveGateway,
              itemId: itemId,
              onStartDownload: startMediaDownload,
            );
          }),
        );
      },
    ),

    // ─── 剧集季列表 ───
    GoRoute(
      path: '/series/:seriesId/seasons',
      name: JellyfinRouteNames.seriesSeasons,
      builder: (context, state) {
        final seriesId = state.pathParameters['seriesId']!;
        final session = sessionController.currentSession;
        return wrapWithServices(
          session,
          child: Builder(builder: (context) {
            return _SeasonsRouteContent(
              gateway: effectiveGateway,
              seriesId: seriesId,
            );
          }),
        );
      },
    ),

    // ─── 剧集集列表 ───
    GoRoute(
      path: '/series/:seriesId/seasons/:seasonId/episodes',
      name: JellyfinRouteNames.seriesEpisodes,
      builder: (context, state) {
        final seriesId = state.pathParameters['seriesId']!;
        final seasonId = state.pathParameters['seasonId']!;
        final session = sessionController.currentSession;
        return wrapWithServices(
          session,
          child: Builder(builder: (context) {
            return _EpisodesRouteContent(
              gateway: effectiveGateway,
              seriesId: seriesId,
              seasonId: seasonId,
            );
          }),
        );
      },
    ),

    // ─── 视频播放 ───
    GoRoute(
      path: '/playback/video/:itemId',
      name: JellyfinRouteNames.playbackVideo,
      builder: (context, state) {
        final itemId = state.pathParameters['itemId']!;
        final serverUrl = sessionController.currentSession?.serverUrl;
        return wrapWithServices(
          sessionController.currentSession,
          child: Builder(builder: (context) {
            return _PlaybackRouteContent(
              gateway: effectiveGateway,
              itemId: itemId,
              aiServiceUrl: serverUrl != null && serverUrl.isNotEmpty
                  ? deriveServiceUrl(serverUrl, 5005)
                  : null,
              onStartDownload: startMediaDownload,
            );
          }),
        );
      },
    ),

    // ─── 音乐库 ───
    GoRoute(
      path: '/libraries/:libraryId/music',
      name: JellyfinRouteNames.musicLibrary,
      builder: (context, state) {
        final libraryId = state.pathParameters['libraryId']!;
        final libraryName = state.uri.queryParameters['name'] ?? '音乐';
        return wrapWithServices(
          sessionController.currentSession,
          child: Builder(builder: (context) {
            return _MusicLibraryRouteContent(
              gateway: effectiveGateway,
              audioPlaybackPort: effectiveAudioPort,
              library: models.MediaLibrary(
                id: libraryId,
                name: libraryName,
                type: models.MediaLibraryType.music,
                serverUrl:
                    sessionController.currentSession?.serverUrl ?? '',
              ),
            );
          }),
        );
      },
    ),

    // ─── 专辑详情 ───
    GoRoute(
      path: '/music/albums/:albumId',
      name: JellyfinRouteNames.musicAlbum,
      builder: (context, state) {
        final albumId = state.pathParameters['albumId']!;
        return wrapWithServices(
          sessionController.currentSession,
          child: Builder(builder: (context) {
            return _AlbumDetailRouteContent(
              gateway: effectiveGateway,
              audioPlaybackPort: effectiveAudioPort,
              albumId: albumId,
            );
          }),
        );
      },
    ),

    // ─── 艺术家详情 ───
    GoRoute(
      path: '/music/artists/:artistId',
      name: JellyfinRouteNames.musicArtist,
      builder: (context, state) {
        final artistId = state.pathParameters['artistId']!;
        return wrapWithServices(
          sessionController.currentSession,
          child: Builder(builder: (context) {
            return _ArtistDetailRouteContent(
              gateway: effectiveGateway,
              audioPlaybackPort: effectiveAudioPort,
              artistId: artistId,
            );
          }),
        );
      },
    ),

    // ─── 音乐搜索 ───
    GoRoute(
      path: '/libraries/:libraryId/music/search',
      name: JellyfinRouteNames.musicSearch,
      builder: (context, state) {
        final libraryId = state.pathParameters['libraryId']!;
        return wrapWithServices(
          sessionController.currentSession,
          child: Builder(builder: (context) {
            return _MusicSearchRouteContent(
              gateway: effectiveGateway,
              audioPlaybackPort: effectiveAudioPort,
              libraryId: libraryId,
            );
          }),
        );
      },
    ),

    // ─── 歌词页 ───
    GoRoute(
      path: '/music/lyrics',
      name: JellyfinRouteNames.musicLyrics,
      builder: (context, state) {
        if (effectiveAudioPort == null) {
          return const Scaffold(body: Center(child: Text('播放器未初始化')));
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

    // ─── 音乐播放详情 ───
    GoRoute(
      path: '/playback/music',
      name: JellyfinRouteNames.playbackMusic,
      builder: (context, state) {
        if (effectiveAudioPort == null) {
          return const Scaffold(body: Center(child: Text('播放器未初始化')));
        }
        return wrapWithServices(
          sessionController.currentSession,
          child: Builder(builder: (context) {
            return MusicPlayerPage(
              playbackPort: effectiveAudioPort,
              fetchLyrics: effectiveGateway.getLyrics,
            );
          }),
        );
      },
    ),

    // ─── RVC ───
    GoRoute(
      path: '/rvc',
      name: JellyfinRouteNames.rvc,
      builder: (context, state) {
        if (rvcTaskController == null) {
          return const Scaffold(body: Center(child: Text('RVC 服务未配置')));
        }
        final audioPath = state.uri.queryParameters['audioPath'];
        return RvcPage(
          controller: rvcTaskController,
          audioPath: audioPath,
        );
      },
    ),

    // ─── 下载管理 ───
    GoRoute(
      path: '/downloads',
      name: JellyfinRouteNames.downloads,
      builder: (context, state) {
        return DownloadsPage(
          controller: downloadController,
          onOpenCompletedTask: (context, task) {
            final mediaItemId = task.mediaItemId;
            if (mediaItemId == null || mediaItemId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('这个缓存任务没有绑定媒体 id')),
              );
              return;
            }
            context.push('/playback/video/$mediaItemId');
          },
        );
      },
    ),

    // ─── AI 推荐 ───
    GoRoute(
      path: '/ai',
      name: JellyfinRouteNames.aiRecommend,
      builder: (context, state) {
        final session = sessionController.currentSession;
        final serverUrl = session?.serverUrl;
        if (serverUrl == null || serverUrl.isEmpty) {
          return const Scaffold(body: Center(child: Text('未登录')));
        }
        return wrapWithServices(
          session,
          child: Builder(builder: (context) {
            return _AiRecommendRouteContent(
              gateway: effectiveGateway,
              aiServiceUrl: deriveServiceUrl(serverUrl, 5005),
              audioPlaybackPort: effectiveAudioPort,
            );
          }),
        );
      },
    ),
  ];

  // ──────────── App 专用路由（非 feature 模块） ────────────
  final appRoutes = <GoRoute>[
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginPage(
        discoveryService: discoveryService,
        onLogin: ({
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
  ];

  final router = GoRouter(
    initialLocation: initialLocation,
    refreshListenable: sessionController,
    redirect: (context, state) => resolveAuthRedirect(
      isLoggedIn: sessionController.isLoggedIn,
      matchedLocation: state.matchedLocation,
    ),
    routes: [...appRoutes, ...featureRoutes],
  );

  goRouterNavigator.attach(router);
  return router;
}

// ══════════════════════════ 内部路由内容 Widget ══════════════════════════
// 这些 Widget 替代原来的 *_route_page.dart，提供 Feature 页面
// 所需的数据注入。Feature 页面内部通过 ServiceRegistry 获取 AppNavigator。

// ─── 电影筛选页内容 ───
class _MoviesRouteContent extends StatefulWidget {
  final JellyfinGateway gateway;
  final String libraryId;
  final String libraryName;

  const _MoviesRouteContent({
    required this.gateway,
    required this.libraryId,
    required this.libraryName,
  });

  @override
  State<_MoviesRouteContent> createState() => _MoviesRouteContentState();
}

class _MoviesRouteContentState extends State<_MoviesRouteContent> {
  ViewModeConfig _viewModeConfig = const ViewModeConfig();

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final config =
        await ViewModeManager().getViewModeConfig(widget.libraryId);
    if (mounted) {
      setState(() => _viewModeConfig = config);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MovieFilterPage(
      libraryId: widget.libraryId,
      libraryName: widget.libraryName,
      fetchMovies: widget.gateway.fetchMovies,
      appBarActions: [
        ViewModeSelector(
          libraryId: widget.libraryId,
          onViewModeChanged: (config) {
            setState(() => _viewModeConfig = config);
          },
        ),
      ],
      listBuilder: ({required items, required onTap}) {
        return MediaListBuilder(
          items: items,
          config: _viewModeConfig,
          onTap: onTap,
        );
      },
    );
  }
}

// ─── 剧集列表页内容 ───
class _SeriesListRouteContent extends StatefulWidget {
  final JellyfinGateway gateway;
  final models.MediaLibrary library;

  const _SeriesListRouteContent({
    required this.gateway,
    required this.library,
  });

  @override
  State<_SeriesListRouteContent> createState() =>
      _SeriesListRouteContentState();
}

class _SeriesListRouteContentState extends State<_SeriesListRouteContent> {
  ViewModeConfig _viewModeConfig = const ViewModeConfig();

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final config =
        await ViewModeManager().getViewModeConfig(widget.library.id);
    if (mounted) {
      setState(() => _viewModeConfig = config);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaItemsPage(
      library: widget.library,
      fetchMediaItems: widget.gateway.fetchMediaItems,
      onNavigateToMediaItem: (context, item) {
        ServiceRegistry.get<AppNavigator>(context).pushIntent(
          JellyfinRouteIntents.seriesSeasons(seriesId: item.id),
        );
      },
      appBarActions: [
        ViewModeSelector(
          libraryId: widget.library.id,
          onViewModeChanged: (config) {
            setState(() => _viewModeConfig = config);
          },
        ),
      ],
      listBuilder: (items, onTap) {
        return MediaListBuilder(
          items: items,
          config: _viewModeConfig,
          onTap: onTap,
        );
      },
    );
  }
}

// ─── 电影详情页内容 ───
class _MovieDetailRouteContent extends StatefulWidget {
  final JellyfinGateway gateway;
  final String itemId;
  final void Function(BuildContext context, models.MediaItem movie)?
      onStartDownload;

  const _MovieDetailRouteContent({
    required this.gateway,
    required this.itemId,
    this.onStartDownload,
  });

  @override
  State<_MovieDetailRouteContent> createState() =>
      _MovieDetailRouteContentState();
}

class _MovieDetailRouteContentState extends State<_MovieDetailRouteContent> {
  /// 在 initState 缓存 future，避免父级重建时重复发起请求
  /// （FutureBuilder 反模式：build 里创建 future 会随每次 rebuild 重新触发）
  late final Future<models.MediaItem> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.gateway.getMediaItemDetail(widget.itemId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.MediaItem>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _ErrorScaffold(error: '${snapshot.error}');
        }
        return MovieDetailPage(
          movie: snapshot.data!,
          fetchDetail: widget.gateway.getMediaItemDetail,
          onStartDownload: widget.onStartDownload,
        );
      },
    );
  }
}

// ─── 通用媒体详情页内容 ───
class _MediaDetailRouteContent extends StatefulWidget {
  final JellyfinGateway gateway;
  final String itemId;
  final void Function(BuildContext context, models.MediaItem item)?
      onStartDownload;

  const _MediaDetailRouteContent({
    required this.gateway,
    required this.itemId,
    this.onStartDownload,
  });

  @override
  State<_MediaDetailRouteContent> createState() =>
      _MediaDetailRouteContentState();
}

class _MediaDetailRouteContentState extends State<_MediaDetailRouteContent> {
  /// 在 initState 缓存 future，避免父级重建时重复发起请求
  late final Future<models.MediaItem> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.gateway.getMediaItemDetail(widget.itemId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.MediaItem>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _ErrorScaffold(error: '${snapshot.error}');
        }
        final item = snapshot.data!;
        return MediaItemDetailPage(
          item: item,
          fetchDetail: widget.gateway.getMediaItemDetail,
          fetchSeasons: item.type.toLowerCase() == 'series'
              ? widget.gateway.getSeasons
              : null,
          onStartDownload: widget.onStartDownload,
        );
      },
    );
  }
}

// ─── 季列表页内容 ───
class _SeasonsRouteContent extends StatefulWidget {
  final JellyfinGateway gateway;
  final String seriesId;

  const _SeasonsRouteContent({
    required this.gateway,
    required this.seriesId,
  });

  @override
  State<_SeasonsRouteContent> createState() => _SeasonsRouteContentState();
}

class _SeasonsRouteContentState extends State<_SeasonsRouteContent> {
  /// 在 initState 缓存 future，避免父级重建时重复发起请求
  late final Future<models.MediaItem> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.gateway.getMediaItemDetail(widget.seriesId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.MediaItem>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _ErrorScaffold(error: '${snapshot.error}');
        }
        return SeasonsPage(
          series: snapshot.data!,
          fetchSeasons: widget.gateway.getSeasons,
        );
      },
    );
  }
}

// ─── 集列表页内容 ───
class _EpisodesRouteContent extends StatefulWidget {
  final JellyfinGateway gateway;
  final String seriesId;
  final String seasonId;

  const _EpisodesRouteContent({
    required this.gateway,
    required this.seriesId,
    required this.seasonId,
  });

  @override
  State<_EpisodesRouteContent> createState() => _EpisodesRouteContentState();
}

class _EpisodesRouteContentState extends State<_EpisodesRouteContent> {
  /// 在 initState 缓存两个 future（季列表 + 剧集详情），避免父级重建时重复发起请求
  late final Future<models.SeasonListResult> _seasonsFuture;
  late final Future<models.MediaItem> _seriesFuture;

  @override
  void initState() {
    super.initState();
    _seasonsFuture = widget.gateway.getSeasons(widget.seriesId);
    _seriesFuture = widget.gateway.getMediaItemDetail(widget.seriesId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.SeasonListResult>(
      future: _seasonsFuture,
      builder: (context, seasonsSnapshot) {
        if (seasonsSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (seasonsSnapshot.hasError) {
          return _ErrorScaffold(error: '${seasonsSnapshot.error}');
        }

        return FutureBuilder<models.MediaItem>(
          future: _seriesFuture,
          builder: (context, seriesSnapshot) {
            if (seriesSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final series = seriesSnapshot.data ??
                models.MediaItem(
                  id: widget.seriesId,
                  name: '',
                  type: 'Series',
                  serverUrl: '',
                );
            final seasons = seasonsSnapshot.data?.seasons ?? [];
            final season = seasons.firstWhere(
              (s) => s.id == widget.seasonId,
              orElse: () => models.Season(
                id: widget.seasonId,
                seriesId: widget.seriesId,
                name: '',
                indexNumber: 0,
                serverUrl: '',
              ),
            );
            return EpisodesPage(
              series: series,
              season: season,
              fetchEpisodes: widget.gateway.getEpisodes,
            );
          },
        );
      },
    );
  }
}

// ─── 视频播放页内容 ───
class _PlaybackRouteContent extends StatefulWidget {
  final JellyfinGateway gateway;
  final String itemId;
  final String? aiServiceUrl;
  final void Function(BuildContext context, models.MediaItem item)?
      onStartDownload;

  const _PlaybackRouteContent({
    required this.gateway,
    required this.itemId,
    this.aiServiceUrl,
    this.onStartDownload,
  });

  @override
  State<_PlaybackRouteContent> createState() => _PlaybackRouteContentState();
}

class _PlaybackRouteContentState extends State<_PlaybackRouteContent> {
  /// 在 initState 缓存 future，避免父级重建时重复发起请求
  late final Future<models.MediaItem> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.gateway.getMediaItemDetail(widget.itemId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.MediaItem>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: const Text('播放错误',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          );
        }

        final item = snapshot.data!;
        final apiClient = _getApiClient(widget.gateway);
        if (apiClient == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text('播放器未就绪', style: TextStyle(color: Colors.white)),
            ),
          );
        }

        final adapter = PlaybackAdapter(apiClient);
        final delegate = adapter.createDelegate();
        final watchAssistClient = widget.aiServiceUrl != null &&
                widget.aiServiceUrl!.isNotEmpty
            ? WatchAssistClient(aiServiceUrl: widget.aiServiceUrl!)
            : null;

        final viewModel = VideoPlayerViewModel(
          item: item,
          playback: delegate,
        );

        return VideoPlayerPage(
          viewModel: viewModel,
          fetchWatchAssist: watchAssistClient?.fetchWatchAssist,
          onStartDownload: widget.onStartDownload,
        );
      },
    );
  }

  static dynamic _getApiClient(JellyfinGateway gateway) {
    // ignore: avoid_dynamic_calls
    return (gateway as dynamic).apiClient;
  }
}

// ─── 音乐库页内容 ───
class _MusicLibraryRouteContent extends StatelessWidget {
  final JellyfinGateway gateway;
  final music.AudioPlaybackPort? audioPlaybackPort;
  final models.MediaLibrary library;

  const _MusicLibraryRouteContent({
    required this.gateway,
    this.audioPlaybackPort,
    required this.library,
  });

  @override
  Widget build(BuildContext context) {
    final port = audioPlaybackPort;
    final page = MusicLibraryPage(
      libraryName: library.name,
      libraryId: library.id,
      fetchAlbums: ({required parentId, startIndex, limit, sortBy}) =>
          gateway.fetchAlbums(
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
        sortBy: sortBy,
      ),
      fetchArtists: ({required parentId, startIndex, limit}) =>
          gateway.fetchArtists(
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
      ),
      fetchSongs: ({required parentId, startIndex, limit}) =>
          gateway.fetchSongs(
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
      ),
      onPlayTracks: (context, tracks, initialIndex) {
        if (port == null) return;
        port.playSong(tracks[initialIndex], tracks, initialIndex);
        context.push('/playback/music');
      },
    );

    if (port == null) return page;
    return MusicAreaShell(
      audioPlaybackPort: port,
      onOpenMusicPlayer: () => context.push('/playback/music'),
      child: page,
    );
  }
}

// ─── 专辑详情页内容 ───
class _AlbumDetailRouteContent extends StatefulWidget {
  final JellyfinGateway gateway;
  final music.AudioPlaybackPort? audioPlaybackPort;
  final String albumId;

  const _AlbumDetailRouteContent({
    required this.gateway,
    this.audioPlaybackPort,
    required this.albumId,
  });

  @override
  State<_AlbumDetailRouteContent> createState() =>
      _AlbumDetailRouteContentState();
}

class _AlbumDetailRouteContentState extends State<_AlbumDetailRouteContent> {
  /// 在 initState 缓存 future，避免父级重建时重复发起请求
  late final Future<dynamic> _albumFuture;

  @override
  void initState() {
    super.initState();
    _albumFuture = widget.gateway.getAlbumDetail(widget.albumId);
  }

  @override
  Widget build(BuildContext context) {
    final port = widget.audioPlaybackPort;
    final futurePage = FutureBuilder<dynamic>(
      future: _albumFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _ErrorScaffold(error: '${snapshot.error}');
        }
        return AlbumDetailPage(
          album: snapshot.data!,
          fetchAlbumDetail: widget.gateway.getAlbumDetail,
          fetchAlbumSongs: widget.gateway.getAlbumSongs,
          onPlaySong: (context, song, playlist, initialIndex) {
            if (port == null) return;
            final tracks = _songsToTracks(playlist);
            port.playSong(tracks[initialIndex], tracks, initialIndex);
            context.push('/playback/music');
          },
        );
      },
    );

    if (port == null) return futurePage;
    return MusicAreaShell(
      audioPlaybackPort: port,
      onOpenMusicPlayer: () => context.push('/playback/music'),
      child: futurePage,
    );
  }
}

// ─── 艺术家详情页内容 ───
class _ArtistDetailRouteContent extends StatefulWidget {
  final JellyfinGateway gateway;
  final music.AudioPlaybackPort? audioPlaybackPort;
  final String artistId;

  const _ArtistDetailRouteContent({
    required this.gateway,
    this.audioPlaybackPort,
    required this.artistId,
  });

  @override
  State<_ArtistDetailRouteContent> createState() =>
      _ArtistDetailRouteContentState();
}

class _ArtistDetailRouteContentState extends State<_ArtistDetailRouteContent> {
  /// 在 initState 缓存 future，避免父级重建时重复发起请求
  late final Future<dynamic> _artistFuture;

  @override
  void initState() {
    super.initState();
    _artistFuture = widget.gateway.getArtistDetail(widget.artistId);
  }

  @override
  Widget build(BuildContext context) {
    final port = widget.audioPlaybackPort;
    final futurePage = FutureBuilder<dynamic>(
      future: _artistFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _ErrorScaffold(error: '${snapshot.error}');
        }
        return ArtistDetailPage(
          artist: snapshot.data!,
          fetchArtistDetail: widget.gateway.getArtistDetail,
          fetchArtistAlbums: widget.gateway.getArtistAlbums,
        );
      },
    );

    if (port == null) return futurePage;
    return MusicAreaShell(
      audioPlaybackPort: port,
      onOpenMusicPlayer: () => context.push('/playback/music'),
      child: futurePage,
    );
  }
}

// ─── 音乐搜索页内容 ───
class _MusicSearchRouteContent extends StatelessWidget {
  final JellyfinGateway gateway;
  final music.AudioPlaybackPort? audioPlaybackPort;
  final String libraryId;

  const _MusicSearchRouteContent({
    required this.gateway,
    this.audioPlaybackPort,
    required this.libraryId,
  });

  @override
  Widget build(BuildContext context) {
    final port = audioPlaybackPort;
    final page = MusicSearchPage(
      libraryId: libraryId,
      search: ({required searchTerm, parentId, limit}) =>
          gateway.searchMusic(
        searchTerm: searchTerm,
        parentId: parentId,
        limit: limit,
      ),
    );

    if (port == null) return page;
    return MusicAreaShell(
      audioPlaybackPort: port,
      onOpenMusicPlayer: () => context.push('/playback/music'),
      child: page,
    );
  }
}

// ─── AI 推荐页内容 ───
class _AiRecommendRouteContent extends StatelessWidget {
  final JellyfinGateway gateway;
  final String aiServiceUrl;
  final music.AudioPlaybackPort? audioPlaybackPort;

  const _AiRecommendRouteContent({
    required this.gateway,
    required this.aiServiceUrl,
    this.audioPlaybackPort,
  });

  @override
  Widget build(BuildContext context) {
    return AiRecommendPage(
      aiServiceUrl: aiServiceUrl,
      fetchMediaItemDetail: gateway.getMediaItemDetail,
    );
  }
}

// ─── 错误页面 ───
class _ErrorScaffold extends StatelessWidget {
  final String error;
  const _ErrorScaffold({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('错误')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 测试用空 gateway
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
  Future<music.MusicAlbumListResult> getArtistAlbums(
      String artistId) async {
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
      String itemId) async => [];

  @override
  Future<music.LyricsData> downloadRemoteLyrics({
    required String itemId,
    required String lyricId,
  }) {
    throw UnimplementedError('No gateway configured');
  }
}
