import 'package:test/test.dart';
import 'package:jellyfin_testing/jellyfin_testing.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

void main() {
  group('FakeAppNavigator', () {
    late FakeAppNavigator navigator;

    setUp(() {
      navigator = FakeAppNavigator();
    });

    test('push 应记录调用', () async {
      await navigator.push('/movies', arguments: {'id': '123'});
      expect(navigator.pushCalls.length, 1);
      expect(navigator.pushCalls.first.routeName, '/movies');
      expect(navigator.pushCalls.first.arguments?['id'], '123');
    });

    test('pushIntent 应记录意图', () async {
      const intent = GenericNavigationIntent(action: 'open_media_item', arguments: {'itemId': 'abc'});
      await navigator.pushIntent(intent);
      expect(navigator.pushIntentCalls.length, 1);
      expect(navigator.pushIntentCalls.first, isA<GenericNavigationIntent>());
    });

    test('pop 应记录调用', () {
      navigator.pop('result');
      expect(navigator.popCalls.length, 1);
      expect(navigator.popCalls.first, 'result');
    });

    test('hasIntentAction 应正确检测', () async {
      await navigator.pushIntent(
        const GenericNavigationIntent(action: 'open_album'),
      );
      expect(navigator.hasIntentAction('open_album'), isTrue);
      expect(navigator.hasIntentAction('play_song'), isFalse);
    });

    test('clear 应清除所有记录', () async {
      await navigator.push('/test');
      await navigator.pushIntent(const GenericNavigationIntent(action: 'test'));
      navigator.clear();
      expect(navigator.pushCalls, isEmpty);
      expect(navigator.pushIntentCalls, isEmpty);
    });
  });

  group('FakeJellyfinConfiguration', () {
    test('默认配置应有合理默认值', () {
      final config = fakeJellyfinConfiguration();
      expect(config.serverUrl, 'http://test-server:8096');
      expect(config.isAuthenticated, isFalse);
      expect(config.enableLogging, isFalse);
    });

    test('认证配置应有 token', () {
      final config = fakeAuthenticatedConfig();
      expect(config.isAuthenticated, isTrue);
      expect(config.accessToken, 'test-access-token');
    });
  });

  group('Fixtures', () {
    test('testUserProfile 应有正确的字段', () {
      expect(testUserProfile.id, 'user-001');
      expect(testUserProfile.name, '测试用户');
      expect(testUserProfile.isAdmin, isFalse);
    });

    test('testMovieLibrary 应有正确的类型', () {
      expect(testMovieLibrary.type, MediaLibraryType.movies);
      expect(testMovieLibrary.itemCount, 100);
    });

    test('testLibraryList 应包含 3 个库', () {
      expect(testLibraryList.length, 3);
    });

    test('testMovieItem 应有正确的类型和字段', () {
      expect(testMovieItem.type, 'Movie');
      expect(testMovieItem.productionYear, 2024);
      expect(testMovieItem.communityRating, 8.5);
      expect(testMovieItem.runTimeMinutes, 120);
    });

    test('testEpisode 应有正确的集号', () {
      expect(testEpisode.episodeNumber, 1);
      expect(testEpisode.seasonNumber, 1);
      expect(testEpisode.episodeNumberText, 'S01E01');
    });
  });
}
