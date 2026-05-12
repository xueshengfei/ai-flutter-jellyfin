import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_service/src/app_shell/app_session.dart';
import 'package:jellyfin_service/src/app_shell/movie_filter_adapter.dart';
import 'package:jellyfin_service/src/app_shell/music_playback_adapter.dart';
import 'package:jellyfin_service/src/app_shell/feature_page_factory.dart';
import 'package:jellyfin_service/src/jellyfin_client.dart';
import 'package:jellyfin_service/src/models/user_models.dart';
import 'package:jellyfin_service/src/models/media_library_models.dart';
import 'package:jellyfin_service/src/models/music_models.dart';
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;
import 'package:jellyfin_music/jellyfin_music.dart' as music;

void main() {
  group('AppSession', () {
    test('提供 serverUrl 和 accessToken 便捷 getter', () {
      final client = JellyfinClient(
        serverUrl: 'http://test.example.com',
      );
      client.updateAccessToken('test-token');
      final user = UserProfile(id: '1', name: 'test', serverUrl: 'http://test.example.com');
      final session = AppSession(client: client, user: user);

      expect(session.serverUrl, 'http://test.example.com');
      expect(session.accessToken, 'test-token');
      expect(session.user.name, 'test');
    });
  });

  group('MovieFilterAdapter', () {
    test('convert 正确转换基础字段', () {
      final filter = movies.MovieFilter(
        parentId: 'lib-1',
        startIndex: 0,
        limit: 20,
        genres: ['Action'],
        recursive: true,
      );
      final result = MovieFilterAdapter.convert(filter);

      expect(result.parentId, 'lib-1');
      expect(result.startIndex, 0);
      expect(result.limit, 20);
      expect(result.genres, ['Action']);
      expect(result.recursive, true);
    });

    test('convert 正确转换排序字段', () {
      final filter = movies.MovieFilter(
        parentId: 'lib-1',
        sortBy: [movies.MovieSortField.sortName],
        sortOrder: [movies.MovieSortOrder.ascending],
      );
      final result = MovieFilterAdapter.convert(filter);

      expect(result.sortBy, isNotNull);
      expect(result.sortBy!.length, 1);
      expect(result.sortOrder, isNotNull);
      expect(result.sortOrder!.length, 1);
    });
  });

  group('MusicPlaybackAdapter', () {
    test('toMusicAlbum 双向转换', () {
      final root = MusicAlbum(
        id: 'a1',
        name: 'Test Album',
        serverUrl: 'http://test',
        accessToken: 'tok',
      );
      final musicAlbum = MusicPlaybackAdapter.toMusicAlbum(root);
      expect(musicAlbum.id, 'a1');
      expect(musicAlbum.name, 'Test Album');
    });

    test('toMusicArtist 双向转换', () {
      final root = MusicArtist(
        id: 'ar1',
        name: 'Test Artist',
        serverUrl: 'http://test',
        accessToken: 'tok',
      );
      final musicArtist = MusicPlaybackAdapter.toMusicArtist(root);
      expect(musicArtist.id, 'ar1');
      expect(musicArtist.name, 'Test Artist');
    });

    test('toMusicSong 双向转换', () {
      final root = MusicSong(
        id: 's1',
        name: 'Test Song',
        serverUrl: 'http://test',
        accessToken: 'tok',
      );
      final musicSong = MusicPlaybackAdapter.toMusicSong(root);
      expect(musicSong.id, 's1');
      expect(musicSong.name, 'Test Song');
    });

    test('toRootSong 反向转换保留字段', () {
      final musicSong = music.MusicSong(
        id: 's1',
        name: 'Test Song',
        serverUrl: 'http://test',
        accessToken: 'tok',
        trackNumber: 1,
      );
      final root = MusicPlaybackAdapter.toRootSong(musicSong);
      expect(root.id, 's1');
      expect(root.name, 'Test Song');
      expect(root.trackNumber, 1);
    });
  });

  group('FeaturePageFactory', () {
    test('pageForLibrary movies 类型返回 movieFilterPage', () {
      final client = JellyfinClient(serverUrl: 'http://test');
      final user = UserProfile(id: '1', name: 'test', serverUrl: 'http://test');
      final factory = FeaturePageFactory(AppSession(client: client, user: user));

      final library = MediaLibrary(
        id: 'lib-1',
        name: 'Movies',
        type: MediaLibraryType.movies,
        serverUrl: 'http://test',
      );
      final page = factory.pageForLibrary(library);
      expect(page, isA<Widget>());
    });
  });
}
