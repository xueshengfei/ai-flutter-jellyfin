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
}
