import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_auth/jellyfin_auth.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;
import 'package:jellyfin_personal/jellyfin_personal.dart';

import '../data/jellyfin_gateway.dart';
import '../features/home/video_home_page.dart';
import '../features/media/media_route_pages.dart';
import '../features/playback/playback_route_page.dart';
import '../features/personal/personal_route_page.dart';
import '../features/personal/personal_settings_route_page.dart';
import '../features/personal/personal_stats_route_page.dart';
import '../session/app_session.dart';
import '../session/app_session_controller.dart';
import '../ui/jellyfin_video_image_provider.dart';

/// 认证重定向
String? resolveAuthRedirect({
  required bool isLoggedIn,
  required String matchedLocation,
  String loginPath = '/login',
  String homePath = '/home',
}) {
  final isLogin = matchedLocation == loginPath;
  if (!isLoggedIn && !isLogin) return loginPath;
  if (isLoggedIn && isLogin) return homePath;
  return null;
}

/// 创建视频 App 路由表
GoRouter createAppRouter({
  required AppSessionController sessionController,
  JellyfinGateway? gateway,
  PersonalRepository? personalRepository,
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
      // 登录页
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
      // 首页（腾讯视频风格）
      GoRoute(
        path: '/home',
        builder: (context, state) => _VideoHomeWrapper(
          gateway: effectiveGateway,
          sessionController: sessionController,
        ),
      ),
      // 电影详情页
      GoRoute(
        path: '/movies/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          final session = sessionController.currentSession;
          return MovieDetailRoutePage(
            gateway: effectiveGateway,
            itemId: itemId,
            imageProvider: session != null
                ? JellyfinVideoImageProvider.fromSession(session)
                : null,
          );
        },
      ),
      // 通用媒体详情页
      GoRoute(
        path: '/media/items/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          final session = sessionController.currentSession;
          return MediaDetailRoutePage(
            gateway: effectiveGateway,
            itemId: itemId,
            imageProvider: session != null
                ? JellyfinVideoImageProvider.fromSession(session)
                : null,
          );
        },
      ),
      // 剧集季列表
      GoRoute(
        path: '/series/:seriesId/seasons',
        builder: (context, state) {
          final seriesId = state.pathParameters['seriesId']!;
          final session = sessionController.currentSession;
          return SeriesSeasonsRoutePage(
            gateway: effectiveGateway,
            seriesId: seriesId,
            imageProvider: session != null
                ? JellyfinVideoImageProvider.fromSession(session)
                : null,
          );
        },
      ),
      // 剧集集列表
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
            imageProvider: session != null
                ? JellyfinVideoImageProvider.fromSession(session)
                : null,
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

/// 首页包装器，注入 imageProvider
class _VideoHomeWrapper extends StatelessWidget {
  final JellyfinGateway gateway;
  final AppSessionController sessionController;

  const _VideoHomeWrapper({
    required this.gateway,
    required this.sessionController,
  });

  @override
  Widget build(BuildContext context) {
    final session = sessionController.currentSession;
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('登录态不存在')),
      );
    }

    return VideoHomePage(
      gateway: gateway,
      imageProvider: JellyfinVideoImageProvider.fromSession(session),
      onLogout: () => sessionController.clearSession(),
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
  Future<models.MediaItemListResult> fetchMediaItems({
    required String parentId,
    bool recursive = true,
    int? startIndex,
    int? limit,
  }) async {
    return const models.MediaItemListResult(items: []);
  }

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
  Future<List<models.MediaItem>> getLatestMediaItems(
    String parentId, {
    int limit = 12,
  }) async =>
      [];

  @override
  Future<movies.MovieFilterResult> fetchMovies(movies.MovieFilter filter) {
    throw UnimplementedError('No gateway configured');
  }
}
