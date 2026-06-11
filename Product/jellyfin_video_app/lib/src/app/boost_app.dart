import 'package:flutter/material.dart';
import 'package:flutter_boost/flutter_boost.dart';
import 'package:jellyfin_auth/jellyfin_auth.dart';
import 'package:jellyfin_personal/jellyfin_personal.dart';

import '../data/jellyfin_gateway.dart';
import '../data/personal_repository_adapter.dart';
import '../features/home/video_home_page.dart';
import '../features/media/media_route_pages.dart';
import '../features/playback/playback_route_page.dart';
import '../features/personal/personal_route_page.dart';
import '../features/personal/personal_settings_route_page.dart';
import '../features/personal/personal_stats_route_page.dart';
import '../session/app_session.dart';
import '../session/app_session_controller.dart';
import '../ui/jellyfin_video_image_provider.dart';
import '../data/legacy_jellyfin_gateway.dart';

/// FlutterBoost 版 Jellyfin 视频 App
class BoostVideoApp extends StatefulWidget {
  const BoostVideoApp({super.key});

  @override
  State<BoostVideoApp> createState() => _BoostVideoAppState();
}

class _BoostVideoAppState extends State<BoostVideoApp> {
  final _sessionController = AppSessionController();
  final _gateway = LegacyJellyfinGateway();

  /// 静态实例引用，供路由工厂访问依赖
  static late _BoostVideoAppState _instance;

  JellyfinPersonalRepositoryAdapter? get _personalRepository =>
      JellyfinPersonalRepositoryAdapter(
        gateway: _gateway,
        sessionController: _sessionController,
      );

  /// FlutterBoost 5.x 路由工厂 (RouteSettings, String?) -> Route?
  Route<dynamic>? _routeFactory(RouteSettings settings, String? uniqueId) {
    _instance = this;

    final name = settings.name ?? '';
    final args = settings.arguments as Map<dynamic, dynamic>? ?? {};

    switch (name) {
      // 登录页
      case 'login':
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (_, __, ___) => _LoginPageWrapper(
            gateway: _instance._gateway,
            sessionController: _instance._sessionController,
          ),
        );

      // 视频首页
      case 'home':
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (_, __, ___) => _VideoHomeWrapper(
            gateway: _instance._gateway,
            sessionController: _instance._sessionController,
          ),
        );

      // 电影详情
      case 'movie_detail':
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (_, __, ___) {
            final session = _instance._sessionController.currentSession;
            return MovieDetailRoutePage(
              gateway: _instance._gateway,
              itemId: args['itemId'] as String? ?? '',
              imageProvider: session != null
                  ? JellyfinVideoImageProvider.fromSession(session)
                  : null,
            );
          },
        );

      // 媒体详情
      case 'media_detail':
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (_, __, ___) {
            final session = _instance._sessionController.currentSession;
            return MediaDetailRoutePage(
              gateway: _instance._gateway,
              itemId: args['itemId'] as String? ?? '',
              imageProvider: session != null
                  ? JellyfinVideoImageProvider.fromSession(session)
                  : null,
            );
          },
        );

      // 剧集季列表
      case 'series_seasons':
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (_, __, ___) {
            final session = _instance._sessionController.currentSession;
            return SeriesSeasonsRoutePage(
              gateway: _instance._gateway,
              seriesId: args['seriesId'] as String? ?? '',
              imageProvider: session != null
                  ? JellyfinVideoImageProvider.fromSession(session)
                  : null,
            );
          },
        );

      // 剧集集列表
      case 'series_episodes':
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (_, __, ___) {
            final session = _instance._sessionController.currentSession;
            return SeriesEpisodesRoutePage(
              gateway: _instance._gateway,
              seriesId: args['seriesId'] as String? ?? '',
              seasonId: args['seasonId'] as String? ?? '',
              imageProvider: session != null
                  ? JellyfinVideoImageProvider.fromSession(session)
                  : null,
            );
          },
        );

      // 视频播放
      case 'playback':
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (_, __, ___) => VideoPlaybackRoutePage(
            gateway: _instance._gateway,
            itemId: args['itemId'] as String? ?? '',
          ),
        );

      // 个人中心
      case 'personal':
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (_, __, ___) {
            final repository = _instance._personalRepository;
            if (repository == null) {
              return const Scaffold(
                body: Center(child: Text('个人模块未配置')),
              );
            }
            return PersonalRoutePage(
              repository: repository,
              sessionController: _instance._sessionController,
            );
          },
        );

      // 个人设置
      case 'personal_settings':
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (_, __, ___) {
            final repository = _instance._personalRepository;
            if (repository == null) {
              return const Scaffold(
                body: Center(child: Text('个人模块未配置')),
              );
            }
            return PersonalSettingsRoutePage(
              repository: repository,
              sessionController: _instance._sessionController,
            );
          },
        );

      // 个人统计
      case 'personal_stats':
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (_, __, ___) {
            final repository = _instance._personalRepository;
            if (repository == null) {
              return const Scaffold(
                body: Center(child: Text('个人模块未配置')),
              );
            }
            return PersonalStatsRoutePage(
              repository: repository,
              sessionController: _instance._sessionController,
            );
          },
        );

      default:
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (_, __, ___) => Scaffold(
            body: Center(child: Text('未知页面: $name')),
          ),
        );
    }
  }

  @override
  void dispose() {
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterBoostApp(
      _routeFactory,
      appBuilder: (child) => MaterialApp(
        home: child,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// 登录页包装器
class _LoginPageWrapper extends StatelessWidget {
  final JellyfinGateway gateway;
  final AppSessionController sessionController;

  const _LoginPageWrapper({
    required this.gateway,
    required this.sessionController,
  });

  @override
  Widget build(BuildContext context) {
    return LoginPage(
      discoveryService: ServerDiscoveryService(),
      onLogin: ({required serverUrl, required username, required password}) async {
        try {
          final session = await gateway.login(
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
    );
  }
}

/// 视频首页包装器
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
