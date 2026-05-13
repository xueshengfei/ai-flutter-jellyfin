import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_movie_app/src/session/app_session.dart';
import 'package:jellyfin_movie_app/src/session/app_session_controller.dart';
import 'package:jellyfin_movie_app/src/app/app_router.dart';

void main() {
  group('AppSession', () {
    test('isValid 当所有字段非空时返回 true', () {
      final session = AppSession(
        serverUrl: 'http://localhost:8096',
        accessToken: 'token123',
        userId: 'user1',
        username: 'admin',
      );
      expect(session.isValid, true);
    });

    test('isValid 当 accessToken 为空时返回 false', () {
      final session = AppSession(
        serverUrl: 'http://localhost:8096',
        accessToken: '',
        userId: 'user1',
        username: 'admin',
      );
      expect(session.isValid, false);
    });
  });

  group('AppSessionController', () {
    test('初始未登录', () {
      final controller = AppSessionController();
      expect(controller.isLoggedIn, false);
      expect(controller.currentSession, isNull);
      controller.dispose();
    });

    test('setSession 后已登录', () {
      final controller = AppSessionController();
      controller.setSession(AppSession(
        serverUrl: 'http://localhost:8096',
        accessToken: 'token',
        userId: 'user1',
        username: 'admin',
      ));
      expect(controller.isLoggedIn, true);
      controller.dispose();
    });

    test('clearSession 后未登录', () {
      final controller = AppSessionController();
      controller.setSession(AppSession(
        serverUrl: 'http://localhost:8096',
        accessToken: 'token',
        userId: 'user1',
        username: 'admin',
      ));
      controller.clearSession();
      expect(controller.isLoggedIn, false);
      controller.dispose();
    });
  });

  group('resolveAuthRedirect', () {
    test('未登录时重定向到 /login', () {
      final result = resolveAuthRedirect(
        isLoggedIn: false,
        matchedLocation: '/movies',
      );
      expect(result, '/login');
    });

    test('已登录且在 /login 时重定向到 /movies', () {
      final result = resolveAuthRedirect(
        isLoggedIn: true,
        matchedLocation: '/login',
      );
      expect(result, '/movies');
    });

    test('已登录且在 /movies 时不重定向', () {
      final result = resolveAuthRedirect(
        isLoggedIn: true,
        matchedLocation: '/movies',
      );
      expect(result, isNull);
    });
  });
}
