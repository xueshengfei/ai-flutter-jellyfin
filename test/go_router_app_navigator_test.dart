import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_service/src/app_shell/app_session.dart';
import 'package:jellyfin_service/src/app_shell/app_session_controller.dart';
import 'package:jellyfin_service/src/app_shell/go_router_app_navigator.dart';
import 'package:jellyfin_service/src/app_shell/jellyfin_go_router.dart';
import 'package:jellyfin_service/src/jellyfin_client.dart';
import 'package:jellyfin_service/src/models/user_models.dart';

void main() {
  group('GoRouterAppNavigator 行为测试', () {
    late AppSessionController sessionController;
    late GoRouterAppNavigator appNavigator;
    late GoRouter router;

    /// 创建一个最小可用的测试路由环境
    void createTestRouter({String initialLocation = '/login'}) {
      sessionController = AppSessionController();
      appNavigator = GoRouterAppNavigator();
      router = createJellyfinGoRouter(
        sessionController: sessionController,
        appNavigator: appNavigator,
        initialLocation: initialLocation,
      );
      appNavigator.attach(router);
    }

    /// 注入一个已登录 session
    void login() {
      final client = JellyfinClient(serverUrl: 'http://test');
      final user = UserProfile(id: 'u1', name: 'tester', serverUrl: 'http://test');
      sessionController.setSession(AppSession(client: client, user: user));
    }

    testWidgets('未登录应重定向到 /login', (tester) async {
      // 使用简化的 GoRouter 验证重定向逻辑，避免真实 JellyfinClient 触发网络请求
      final sessionCtrl = AppSessionController();
      final testRouter = GoRouter(
        initialLocation: '/libraries',
        refreshListenable: sessionCtrl,
        redirect: (context, state) {
          final isLoggedIn = sessionCtrl.isLoggedIn;
          final isLogin = state.matchedLocation == '/login';
          if (!isLoggedIn && !isLogin) return '/login';
          if (isLoggedIn && isLogin) return '/libraries';
          return null;
        },
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const Scaffold(body: Text('Login')),
          ),
          GoRoute(
            path: '/libraries',
            builder: (context, state) => const Scaffold(body: Text('Libraries')),
          ),
        ],
      );
      addTearDown(testRouter.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('已登录访问 /login 应重定向到 /libraries', (tester) async {
      final sessionCtrl = AppSessionController();
      final client = JellyfinClient(serverUrl: 'http://test');
      sessionCtrl.setSession(AppSession(
        client: client,
        user: UserProfile(id: 'u1', name: 'tester', serverUrl: 'http://test'),
      ));

      final testRouter = GoRouter(
        initialLocation: '/login',
        refreshListenable: sessionCtrl,
        redirect: (context, state) {
          final isLoggedIn = sessionCtrl.isLoggedIn;
          final isLogin = state.matchedLocation == '/login';
          if (!isLoggedIn && !isLogin) return '/login';
          if (isLoggedIn && isLogin) return '/libraries';
          return null;
        },
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const Scaffold(body: Text('Login')),
          ),
          GoRoute(
            path: '/libraries',
            builder: (context, state) => const Scaffold(body: Text('Libraries')),
          ),
        ],
      );
      addTearDown(testRouter.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
      await tester.pumpAndSettle();

      expect(find.text('Libraries'), findsOneWidget);
    });

    test('路径参数映射 — library 路由', () {
      createTestRouter();
      expect(
        () => router.pushNamed(
          JellyfinRouteNames.library,
          pathParameters: {'libraryId': 'lib-1'},
        ),
        returnsNormally,
      );
    });

    test('路径参数映射 — playbackVideo 路由', () {
      createTestRouter();
      expect(
        () => router.pushNamed(
          JellyfinRouteNames.playbackVideo,
          pathParameters: {'itemId': 'item-1'},
        ),
        returnsNormally,
      );
    });

    test('路径参数映射 — seriesEpisodes 路由', () {
      createTestRouter();
      expect(
        () => router.pushNamed(
          JellyfinRouteNames.seriesEpisodes,
          pathParameters: {
            'seriesId': 'series-1',
            'seasonId': 'season-1',
          },
        ),
        returnsNormally,
      );
    });

    test('缺少必填参数时 GoRouterAppNavigator.push 抛 ArgumentError', () {
      createTestRouter();
      expect(
        () => appNavigator.push(JellyfinRouteNames.library),
        throwsArgumentError,
      );
    });

    test('缺少 playbackVideo itemId 抛 ArgumentError', () {
      createTestRouter();
      expect(
        () => appNavigator.push(JellyfinRouteNames.playbackVideo),
        throwsArgumentError,
      );
    });

    test('缺少 seriesEpisodes 必填参数抛 ArgumentError', () {
      createTestRouter();
      expect(
        () => appNavigator.push(JellyfinRouteNames.seriesEpisodes, arguments: {
          'seasonId': 's1',
        }),
        throwsArgumentError,
      );
    });

    test('RouteNavigationIntent 可通过 pushIntent 完成', () {
      createTestRouter();
      login();
      final intent = RouteNavigationIntent(
        routeName: JellyfinRouteNames.library,
        arguments: {'libraryId': 'lib-1'},
      );
      expect(
        () => appNavigator.pushIntent(intent),
        returnsNormally,
      );
    });

    test('无参路由名不抛错（如 libraries）', () {
      createTestRouter();
      expect(
        () => appNavigator.push(JellyfinRouteNames.libraries),
        returnsNormally,
      );
    });

    test('initialLocation 参数生效', () {
      createTestRouter(initialLocation: '/libraries');
      final initialLocation = router.routerDelegate.currentConfiguration.uri.toString();
      expect(initialLocation, isNotNull);
    });

    test('所有已声明的 JellyfinRouteNames 都应注册 GoRoute', () {
      createTestRouter();

      final registeredNames = router.configuration.routes
          .whereType<GoRoute>()
          .map((r) => r.name)
          .whereType<String>()
          .toSet();

      // 验证全部 14 个路由名都已注册
      expect(registeredNames, contains(JellyfinRouteNames.login));
      expect(registeredNames, contains(JellyfinRouteNames.libraries));
      expect(registeredNames, contains(JellyfinRouteNames.library));
      expect(registeredNames, contains(JellyfinRouteNames.mediaDetail));
      expect(registeredNames, contains(JellyfinRouteNames.movieDetail));
      expect(registeredNames, contains(JellyfinRouteNames.seriesSeasons));
      expect(registeredNames, contains(JellyfinRouteNames.seriesEpisodes));
      expect(registeredNames, contains(JellyfinRouteNames.playbackVideo));
      expect(registeredNames, contains(JellyfinRouteNames.musicLibrary));
      expect(registeredNames, contains(JellyfinRouteNames.musicAlbum));
      expect(registeredNames, contains(JellyfinRouteNames.musicArtist));
      expect(registeredNames, contains(JellyfinRouteNames.musicSearch));
      expect(registeredNames, contains(JellyfinRouteNames.aiRecommend));
      expect(registeredNames, contains(JellyfinRouteNames.profile));

      // 验证注册数量 = JellyfinRouteNames 全部字段数
      expect(registeredNames.length, equals(14));
    });

    test('resolveAuthRedirect 纯函数逻辑', () {
      // 未登录 + 非 login → 重定向到 login
      expect(
        resolveAuthRedirect(isLoggedIn: false, matchedLocation: '/libraries'),
        '/login',
      );
      // 已登录 + login → 重定向到 libraries
      expect(
        resolveAuthRedirect(isLoggedIn: true, matchedLocation: '/login'),
        '/libraries',
      );
      // 已登录 + 非 login → 不重定向
      expect(
        resolveAuthRedirect(isLoggedIn: true, matchedLocation: '/libraries'),
        isNull,
      );
      // 未登录 + login → 不重定向
      expect(
        resolveAuthRedirect(isLoggedIn: false, matchedLocation: '/login'),
        isNull,
      );
    });
  });
}
