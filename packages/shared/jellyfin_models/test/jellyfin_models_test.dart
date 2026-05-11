import 'package:test/test.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

void main() {
  group('UserProfile', () {
    test('应正确创建并比较', () {
      const user1 = UserProfile(id: '1', name: 'test', serverUrl: 'http://localhost');
      const user2 = UserProfile(id: '1', name: 'test', serverUrl: 'http://localhost');
      expect(user1, equals(user2));
    });

    test('管理员标识正确', () {
      const admin = UserProfile(id: '1', name: 'admin', serverUrl: 'http://localhost', isAdmin: true);
      expect(admin.isAdmin, isTrue);
    });
  });

  group('MediaLibrary', () {
    test('应正确构建封面URL', () {
      const lib = MediaLibrary(
        id: 'lib-1',
        name: '电影',
        type: MediaLibraryType.movies,
        serverUrl: 'http://localhost:8096',
        primaryImageTag: 'abc123',
      );
      final url = lib.getCoverImageUrl();
      expect(url, contains('/Items/lib-1/Images/Primary'));
      expect(url, contains('tag=abc123'));
    });

    test('MediaLibraryType 应有正确的显示名称', () {
      expect(MediaLibraryType.movies.displayName, '电影');
      expect(MediaLibraryType.tvshows.displayName, '电视剧');
      expect(MediaLibraryType.music.displayName, '音乐');
    });
  });

  group('MediaItem', () {
    test('应正确计算时长文本', () {
      const item1 = MediaItem(
        id: '1', name: 'Test', type: 'Movie',
        serverUrl: 'http://localhost', runTimeMinutes: 120,
      );
      expect(item1.durationText, '2小时0分钟');

      const item2 = MediaItem(
        id: '2', name: 'Short', type: 'Movie',
        serverUrl: 'http://localhost', runTimeMinutes: 45,
      );
      expect(item2.durationText, '45分钟');
    });

    test('typeDisplayName 应正确映射', () {
      const movie = MediaItem(id: '1', name: 'T', type: 'Movie', serverUrl: 'http://x');
      expect(movie.typeDisplayName, '电影');

      const series = MediaItem(id: '2', name: 'T', type: 'Series', serverUrl: 'http://x');
      expect(series.typeDisplayName, '剧集');
    });
  });

  group('DiscoveredServer', () {
    test('fromJson 应正确解析 UDP 响应', () {
      final server = DiscoveredServer.fromJson({
        'Id': 'server-1',
        'Name': 'My Server',
        'Address': 'http://192.168.1.100:8096',
      });
      expect(server.id, 'server-1');
      expect(server.name, 'My Server');
      expect(server.version, isNull);
    });

    test('mergeWith 应合并信息', () {
      const udp = DiscoveredServer(
        id: '1', name: 'Server', address: 'http://192.168.1.100:8096',
      );
      const info = DiscoveredServer(
        id: '1', name: 'Server', address: 'http://192.168.1.100:8096',
        version: '10.9.11',
      );
      final merged = udp.mergeWith(info);
      expect(merged.version, '10.9.11');
    });
  });
}
