import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_app/src/app/app_router.dart';
import 'package:jellyfin_app/src/session/app_session.dart';
import 'package:jellyfin_app/src/session/app_session_controller.dart';

void main() {
  group('resolveAuthRedirect', () {
    test('未登录 + 非 login → 重定向到 /login', () {
      expect(
        resolveAuthRedirect(isLoggedIn: false, matchedLocation: '/libraries'),
        '/login',
      );
    });

    test('已登录 + login → 重定向到 /libraries', () {
      expect(
        resolveAuthRedirect(isLoggedIn: true, matchedLocation: '/login'),
        '/libraries',
      );
    });

    test('已登录 + 非 login → 不重定向', () {
      expect(
        resolveAuthRedirect(isLoggedIn: true, matchedLocation: '/libraries'),
        isNull,
      );
    });

    test('未登录 + login → 不重定向', () {
      expect(
        resolveAuthRedirect(isLoggedIn: false, matchedLocation: '/login'),
        isNull,
      );
    });
  });

  group('createAppRouter', () {
    late AppSessionController sessionController;

    setUp(() {
      sessionController = AppSessionController();
    });

    tearDown(() {
      sessionController.dispose();
    });

    testWidgets('未登录应重定向到 /login', (tester) async {
      final router = createAppRouter(sessionController: sessionController);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('服务器地址'), findsOneWidget);
    });

    testWidgets('已登录访问 /login 应重定向到 /libraries', (tester) async {
      sessionController.setSession(const AppSession(
        serverUrl: 'http://test',
        accessToken: 'token',
        userId: 'u1',
        username: 'tester',
      ));

      final router = createAppRouter(
        sessionController: sessionController,
        initialLocation: '/login',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('媒体库'), findsOneWidget);
    });
  });

  group('路由注册验证', () {
    /// 验证路由表包含指定路径
    List<String> collectPaths(GoRouter router) {
      final paths = <String>[];
      void collect(List<RouteBase> routes) {
        for (final route in routes) {
          if (route is GoRoute) {
            paths.add(route.path);
            collect(route.routes);
          }
        }
      }
      collect(router.configuration.routes);
      return paths;
    }

    test('媒体与播放路由已注册', () {
      final sessionController = AppSessionController();
      addTearDown(sessionController.dispose);

      final router = createAppRouter(sessionController: sessionController);
      addTearDown(router.dispose);

      final paths = collectPaths(router);

      expect(paths, contains('/libraries/:libraryId/movies'));
      expect(paths, contains('/libraries/:libraryId/series'));
      expect(paths, contains('/libraries/:libraryId/music'));
      expect(paths, contains('/movies/:itemId'));
      expect(paths, contains('/media/items/:itemId'));
      expect(paths, contains('/series/:seriesId/seasons'));
      expect(paths, contains('/series/:seriesId/seasons/:seasonId/episodes'));
      expect(paths, contains('/music/albums/:albumId'));
      expect(paths, contains('/music/artists/:artistId'));
      expect(paths, contains('/playback/video/:itemId'));
    });
  });
}
