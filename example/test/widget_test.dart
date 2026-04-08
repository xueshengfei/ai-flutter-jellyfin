import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_service_example/main.dart';

void main() {
  testWidgets('Jellyfin app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JellyfinExampleApp());

    // Verify that login page is displayed
    expect(find.text('Jellyfin Example'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}
