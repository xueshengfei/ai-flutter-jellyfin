import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_download_example/main.dart';

void main() {
  testWidgets('renders the download example app', (tester) async {
    await tester.pumpWidget(const JellyfinDownloadExampleApp());

    expect(find.text('下载管理'), findsOneWidget);
    expect(find.text('下载中'), findsOneWidget);
    expect(find.text('已缓存'), findsOneWidget);
  });
}
