import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_auth/jellyfin_auth_pages.dart';
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;
import 'package:jellyfin_models/jellyfin_models.dart' as models;

import '../data/jellyfin_gateway.dart';
import '../features/media/movie_route_pages.dart';
import '../session/app_session.dart';
import '../session/app_session_controller.dart';

/// 认证重定向
String? resolveAuthRedirect({
  required bool isLoggedIn,
  required String matchedLocation,
  String loginPath = '/login',
  String homePath = '/movies',
}) {
  final isLogin = matchedLocation == loginPath;
  if (!isLoggedIn && !isLogin) return loginPath;
  if (isLoggedIn && isLogin) return homePath;
  return null;
}

/// 创建电影 App 路由表
///
/// 登录后自动查找第一个电影库 → 进入电影列表页
GoRouter createAppRouter({
  required AppSessionController sessionController,
  JellyfinGateway? gateway,
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
      // 电影列表页（登录后自动进入）
      GoRoute(
        path: '/movies',
        builder: (context, state) => _AutoMovieLibraryPage(
          gateway: effectiveGateway,
          onLogout: () => sessionController.clearSession(),
        ),
      ),
      // 电影列表页（指定库 ID）
      GoRoute(
        path: '/libraries/:libraryId/movies',
        builder: (context, state) {
          final libraryId = state.pathParameters['libraryId']!;
          final libraryName = state.uri.queryParameters['name'] ?? '电影';
          return MoviesRoutePage(
            gateway: effectiveGateway,
            libraryId: libraryId,
            libraryName: libraryName,
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
      // 视频播放（占位，后续接入 playback）
      GoRoute(
        path: '/playback/video/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return Scaffold(
            appBar: AppBar(title: const Text('播放')),
            body: Center(child: Text('视频播放: $itemId（待接入）')),
          );
        },
      ),
    ],
  );
}

/// 自动查找电影库并跳转的中间页
class _AutoMovieLibraryPage extends StatefulWidget {
  final JellyfinGateway gateway;
  final VoidCallback onLogout;

  const _AutoMovieLibraryPage({
    required this.gateway,
    required this.onLogout,
  });

  @override
  State<_AutoMovieLibraryPage> createState() => _AutoMovieLibraryPageState();
}

class _AutoMovieLibraryPageState extends State<_AutoMovieLibraryPage> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _findMovieLibrary();
  }

  Future<void> _findMovieLibrary() async {
    try {
      final libraries = await widget.gateway.getMediaLibraries();

      // 优先找 movies 类型的库
      final movieLib = libraries.where(
        (lib) => lib.type == models.MediaLibraryType.movies,
      ).toList();

      if (movieLib.isNotEmpty) {
        if (mounted) {
          // 找到电影库，直接替换到电影列表页
          context.go(
            '/libraries/${movieLib.first.id}/movies?name=${Uri.encodeComponent(movieLib.first.name)}',
          );
        }
        return;
      }

      // 没有电影类型的库，找第一个库当作电影库
      if (libraries.isNotEmpty) {
        if (mounted) {
          context.go(
            '/libraries/${libraries.first.id}/movies?name=${Uri.encodeComponent(libraries.first.name)}',
          );
        }
        return;
      }

      // 完全没有库
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '没有找到媒体库，请在 Jellyfin 服务端添加电影库';
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
              Text('正在查找电影库...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Jellyfin 电影')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_outlined, size: 64),
            const SizedBox(height: 24),
            Text(
              _error ?? '没有找到电影库',
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
                _findMovieLibrary();
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
  Future<movies.MovieFilterResult> fetchMovies(movies.MovieFilter filter) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<models.MediaItem> getMediaItemDetail(String itemId) {
    throw UnimplementedError('No gateway configured');
  }
}
