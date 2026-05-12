import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_app/src/session/app_session.dart';
import 'package:jellyfin_app/src/session/app_session_controller.dart';

void main() {
  group('AppSession', () {
    test('有效 session 的 isValid 为 true', () {
      const session = AppSession(
        serverUrl: 'http://server',
        accessToken: 'token',
        userId: 'user-1',
        username: 'tester',
      );
      expect(session.isValid, isTrue);
    });

    test('空字段的 session 的 isValid 为 false', () {
      const session = AppSession(
        serverUrl: '',
        accessToken: '',
        userId: '',
        username: '',
      );
      expect(session.isValid, isFalse);
    });
  });

  group('AppSessionController', () {
    test('setSession 标记为已登录', () {
      final controller = AppSessionController();
      controller.setSession(const AppSession(
        serverUrl: 'http://server',
        accessToken: 'token',
        userId: 'user-1',
        username: 'tester',
      ));

      expect(controller.isLoggedIn, isTrue);
      expect(controller.currentSession?.userId, 'user-1');
    });

    test('clearSession 标记为未登录', () {
      final controller = AppSessionController();
      controller.setSession(const AppSession(
        serverUrl: 'http://server',
        accessToken: 'token',
        userId: 'user-1',
        username: 'tester',
      ));

      controller.clearSession();

      expect(controller.isLoggedIn, isFalse);
      expect(controller.currentSession, isNull);
    });

    test('初始状态为未登录', () {
      final controller = AppSessionController();
      expect(controller.isLoggedIn, isFalse);
      expect(controller.currentSession, isNull);
    });
  });
}
