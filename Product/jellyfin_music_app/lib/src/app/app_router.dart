import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_auth/jellyfin_auth.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_music/jellyfin_music.dart' as music;
import 'package:jellyfin_personal/jellyfin_personal.dart';

import '../data/jellyfin_gateway.dart';
import '../features/music/music_route_pages.dart';
import '../features/personal/personal_route_page.dart';
import '../features/personal/personal_settings_route_page.dart';
import '../features/personal/personal_stats_route_page.dart';
import '../session/app_session.dart';
import '../session/app_session_controller.dart';
import '../ui/jellyfin_music_image_provider.dart';

/// 认证重定向
String? resolveAuthRedirect({
  required bool isLoggedIn,
  required String matchedLocation,
  String loginPath = '/login',
  String homePath = '/music',
}) {
  final isLogin = matchedLocation == loginPath;
  if (!isLoggedIn && !isLogin) return loginPath;
  if (isLoggedIn && isLogin) return homePath;
  return null;
}

/// 创建音乐 App 路由表
///
/// 登录后自动查找第一个音乐库 → 进入音乐库列表页
GoRouter createAppRouter({
  required AppSessionController sessionController,
  JellyfinGateway? gateway,
  PersonalRepository? personalRepository,
  music.AudioPlaybackPort? audioPlaybackPort,
  ServerDiscoveryService? discoveryService,
  String initialLocation = '/login',
}) {
  final effectiveGateway = gateway ?? _StubGateway();

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: sessionController,
    redirect: (context, state) => resolveAuthRedirect(
      isLoggedIn: sessionController.isLoggedIn,
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      // 登录页（复用 jellyfin_auth）
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          discoveryService: discoveryService,
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
      // 音乐库中间页（自动查找音乐库）
      GoRoute(
        path: '/music',
        builder: (context, state) => _AutoMusicLibraryPage(
          gateway: effectiveGateway,
          audioPlaybackPort: audioPlaybackPort,
          sessionController: sessionController,
          onLogout: () => sessionController.clearSession(),
        ),
      ),
      // 音乐库列表页（指定库 ID）
      GoRoute(
        path: '/libraries/:libraryId/music',
        builder: (context, state) {
          final libraryId = state.pathParameters['libraryId']!;
          final libraryName = state.uri.queryParameters['name'] ?? '音乐';
          final session = sessionController.currentSession;
          return MusicLibraryRoutePage(
            gateway: effectiveGateway,
            audioPlaybackPort: audioPlaybackPort,
            libraryId: libraryId,
            libraryName: libraryName,
            imageProvider: session != null
                ? JellyfinMusicImageProvider.fromSession(session)
                : null,
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
            audioPlaybackPort: audioPlaybackPort,
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
            audioPlaybackPort: audioPlaybackPort,
            artistId: artistId,
          );
        },
      ),
      // 音乐搜索页
      GoRoute(
        path: '/libraries/:libraryId/music/search',
        builder: (context, state) {
          final libraryId = state.pathParameters['libraryId']!;
          return MusicSearchRoutePage(
            gateway: effectiveGateway,
            audioPlaybackPort: audioPlaybackPort,
            libraryId: libraryId,
          );
        },
      ),
      // 音乐播放页
      GoRoute(
        path: '/playback/music',
        builder: (context, state) {
          if (audioPlaybackPort == null) {
            return const Scaffold(
              body: Center(child: Text('播放器未初始化')),
            );
          }
          return MusicPlayerRoutePage(
            audioPlaybackPort: audioPlaybackPort,
            gateway: effectiveGateway,
          );
        },
      ),
      // 歌词页
      GoRoute(
        path: '/music/lyrics',
        builder: (context, state) {
          if (audioPlaybackPort == null) {
            return const Scaffold(
              body: Center(child: Text('播放器未初始化')),
            );
          }
          return LyricsRoutePage(
            gateway: effectiveGateway,
            audioPlaybackPort: audioPlaybackPort,
          );
        },
      ),
      // 个人中心
      GoRoute(
        path: '/personal',
        builder: (context, state) {
          final repository = personalRepository;
          if (repository == null) {
            return const Scaffold(
              body: Center(child: Text('个人模块未配置')),
            );
          }
          return PersonalRoutePage(
            repository: repository,
            sessionController: sessionController,
          );
        },
      ),
      // 个人设置
      GoRoute(
        path: '/personal/settings',
        builder: (context, state) {
          final repository = personalRepository;
          if (repository == null) {
            return const Scaffold(
              body: Center(child: Text('个人模块未配置')),
            );
          }
          return PersonalSettingsRoutePage(
            repository: repository,
            sessionController: sessionController,
          );
        },
      ),
      // 个人统计
      GoRoute(
        path: '/personal/stats',
        builder: (context, state) {
          final repository = personalRepository;
          if (repository == null) {
            return const Scaffold(
              body: Center(child: Text('个人模块未配置')),
            );
          }
          return PersonalStatsRoutePage(
            repository: repository,
            sessionController: sessionController,
          );
        },
      ),
    ],
  );
}

/// 自动查找音乐库并跳转的中间页
class _AutoMusicLibraryPage extends StatefulWidget {
  final JellyfinGateway gateway;
  final music.AudioPlaybackPort? audioPlaybackPort;
  final AppSessionController sessionController;
  final VoidCallback onLogout;

  const _AutoMusicLibraryPage({
    required this.gateway,
    this.audioPlaybackPort,
    required this.sessionController,
    required this.onLogout,
  });

  @override
  State<_AutoMusicLibraryPage> createState() => _AutoMusicLibraryPageState();
}

class _AutoMusicLibraryPageState extends State<_AutoMusicLibraryPage> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _findMusicLibrary();
  }

  Future<void> _findMusicLibrary() async {
    try {
      final libraries = await widget.gateway.getMediaLibraries();

      // 优先找 music 类型的库
      final musicLib = libraries.where(
        (lib) => lib.type == models.MediaLibraryType.music,
      ).toList();

      if (musicLib.isNotEmpty) {
        if (mounted) {
          context.go(
            '/libraries/${musicLib.first.id}/music?name=${Uri.encodeComponent(musicLib.first.name)}',
          );
        }
        return;
      }

      // 没有音乐类型的库，找第一个库当作音乐库
      if (libraries.isNotEmpty) {
        if (mounted) {
          context.go(
            '/libraries/${libraries.first.id}/music?name=${Uri.encodeComponent(libraries.first.name)}',
          );
        }
        return;
      }

      // 完全没有库
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '没有找到媒体库，请在 Jellyfin 服务端添加音乐库';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '加载失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在查找音乐库...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jellyfin 音乐'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: '个人中心',
            onPressed: () => context.push('/personal'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_music_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              _error ?? '没有找到音乐库',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _findMusicLibrary();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('切换账号'),
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
  Future<music.MusicAlbumListResult> fetchAlbums({
    required String parentId,
    int? startIndex,
    int? limit,
    String? sortBy,
  }) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<music.MusicArtistListResult> fetchArtists({
    required String parentId,
    int? startIndex,
    int? limit,
  }) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<music.MusicSongListResult> fetchSongs({
    required String parentId,
    int? startIndex,
    int? limit,
  }) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<music.MusicAlbum> getAlbumDetail(String albumId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<music.MusicSongListResult> getAlbumSongs(String albumId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<music.MusicArtist> getArtistDetail(String artistId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<music.MusicAlbumListResult> getArtistAlbums(String artistId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<music.MusicSearchResult> searchMusic({
    required String searchTerm,
    String? parentId,
    int? limit,
  }) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<music.LyricsData?> getLyrics(String itemId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<List<music.RemoteLyricsInfo>> searchRemoteLyrics(String itemId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<music.LyricsData> downloadRemoteLyrics({
    required String itemId,
    required String lyricId,
  }) {
    throw UnimplementedError('No gateway configured');
  }
}
