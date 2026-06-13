import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_app/src/app/app_router.dart';
import 'package:jellyfin_app/src/session/app_session_controller.dart';

void main() {
  testWidgets('app router builds a Material app', (WidgetTester tester) async {
    final sessionController = AppSessionController();
    final router = createAppRouter(sessionController: sessionController);
    addTearDown(router.dispose);
    addTearDown(sessionController.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
