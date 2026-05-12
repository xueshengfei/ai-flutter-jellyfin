import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_auth/jellyfin_auth_pages.dart';

void main() {
  group('LoginPage', () {
    testWidgets('登录成功回调返回 null', (tester) async {
      String? capturedServer;
      String? capturedUser;
      String? result;

      await tester.pumpWidget(MaterialApp(
        home: LoginPage(
          onLogin: ({required serverUrl, required username, required password}) async {
            capturedServer = serverUrl;
            capturedUser = username;
            return result;
          },
        ),
      ));

      // 清空默认值，输入测试数据
      await tester.enterText(find.widgetWithText(TextField, '服务器地址'), 'http://test');
      await tester.enterText(find.widgetWithText(TextField, '用户名'), 'tester');
      await tester.enterText(find.widgetWithText(TextField, '密码'), 'pass');
      await tester.tap(find.widgetWithText(FilledButton, '登录'));
      await tester.pump();

      expect(capturedServer, 'http://test');
      expect(capturedUser, 'tester');
    });

    testWidgets('登录失败显示错误信息', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginPage(
          onLogin: ({required serverUrl, required username, required password}) async {
            return '认证失败';
          },
        ),
      ));

      await tester.tap(find.widgetWithText(FilledButton, '登录'));
      await tester.pumpAndSettle();

      expect(find.text('认证失败'), findsOneWidget);
    });

    testWidgets('默认值已填充', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginPage(
          onLogin: ({required serverUrl, required username, required password}) async => null,
        ),
      ));

      expect(find.text('http://localhost:8096'), findsOneWidget);
      expect(find.text('xue13'), findsOneWidget);
      expect(find.text('123456'), findsOneWidget);
    });
  });
}
