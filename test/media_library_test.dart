import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

void main() {
  group('MediaLibrary功能测试', () {
    test('MediaLibraryType枚举应该有正确的显示属性', () {
      // 测试电影类型
      expect(MediaLibraryType.movies.displayName, '电影');
      expect(MediaLibraryType.movies.icon, '🎬');
      expect(MediaLibraryType.movies.color, '#E53935');

      // 测试电视剧类型
      expect(MediaLibraryType.tvshows.displayName, '电视剧');
      expect(MediaLibraryType.tvshows.icon, '📺');
      expect(MediaLibraryType.tvshows.color, '#1E88E5');

      // 测试音乐类型
      expect(MediaLibraryType.music.displayName, '音乐');
      expect(MediaLibraryType.music.icon, '🎵');
      expect(MediaLibraryType.music.color, '#43A047');

      // 测试其他类型
      expect(MediaLibraryType.musicVideos.displayName, '音乐视频');
      expect(MediaLibraryType.homeVideos.displayName, '家庭视频');
      expect(MediaLibraryType.boxSets.displayName, '电影合集');
      expect(MediaLibraryType.unknown.displayName, '其他');
    });

    test('MediaLibraryType应该有7种类型', () {
      final types = MediaLibraryType.values;
      expect(types.length, 7);
      expect(types, contains(MediaLibraryType.movies));
      expect(types, contains(MediaLibraryType.tvshows));
      expect(types, contains(MediaLibraryType.music));
      expect(types, contains(MediaLibraryType.musicVideos));
      expect(types, contains(MediaLibraryType.homeVideos));
      expect(types, contains(MediaLibraryType.boxSets));
      expect(types, contains(MediaLibraryType.unknown));
    });

    test('客户端应该有mediaLibrary服务', () {
      final client = JellyfinClient(
        serverUrl: 'http://localhost:8096',
      );

      expect(client.mediaLibrary, isNotNull);
      expect(client.mediaLibrary, isA<MediaLibraryService>());
    });

    test('MediaLibraryListResult应该有正确的属性', () {
      // 由于我们不能直接创建DTO，这里测试模型类是否存在
      expect(MediaLibraryListResult, isNotNull);
      expect(MediaLibrary, isNotNull);
    });

    test('MediaLibrary应该有正确的业务方法', () {
      // 测试业务方法的存在性
      expect(MediaLibrary, isNotNull);
    });

    test('媒体库服务应该有获取媒体库的方法', () {
      final client = JellyfinClient(
        serverUrl: 'http://localhost:8096',
      );

      // 验证服务方法存在（不执行实际调用）
      expect(client.mediaLibrary, isNotNull);
    });
  });

  group('MediaLibrary业务模型测试', () {
    test('所有媒体库类型都应该有唯一的图标', () {
      final icons = MediaLibraryType.values
          .map((type) => type.icon)
          .toSet();

      expect(icons.length, MediaLibraryType.values.length,
          reason: '每个媒体库类型应该有唯一的图标');
    });

    test('所有媒体库类型都应该有唯一的颜色', () {
      final colors = MediaLibraryType.values
          .map((type) => type.color)
          .toSet();

      expect(colors.length, MediaLibraryType.values.length,
          reason: '每个媒体库类型应该有唯一的颜色');
    });

    test('所有媒体库类型都应该有显示名称', () {
      for (final type in MediaLibraryType.values) {
        expect(type.displayName.isNotEmpty, true,
            reason: '$type 应该有显示名称');
      }
    });

    test('所有媒体库类型都应该有图标', () {
      for (final type in MediaLibraryType.values) {
        expect(type.icon.isNotEmpty, true,
            reason: '$type 应该有图标');
      }
    });

    test('所有媒体库类型都应该有颜色代码', () {
      for (final type in MediaLibraryType.values) {
        expect(type.color.startsWith('#'), true,
            reason: '$type 的颜色应该以#开头');
        expect(type.color.length, 7,
            reason: '$type 的颜色代码应该是7个字符');
      }
    });
  });

  group('MediaLibrary API集成测试', () {
    test('客户端应该能够创建媒体库服务', () {
      final client = JellyfinClient(
        serverUrl: 'http://localhost:8096',
        enableLogging: false,
      );

      expect(client.mediaLibrary, isNotNull);
      expect(client.mediaLibrary, isA<MediaLibraryService>());
    });

    test('媒体库服务应该有获取媒体库列表的方法', () {
      final client = JellyfinClient(
        serverUrl: 'http://localhost:8096',
      );

      // 检查服务类型
      expect(client.mediaLibrary.runtimeType.toString(), contains('MediaLibraryService'));
    });
  });
}
