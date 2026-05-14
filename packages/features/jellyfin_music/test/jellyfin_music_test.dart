import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_music/jellyfin_music.dart';
import 'package:jellyfin_music/jellyfin_music_pages.dart';

void main() {
  group('MusicAlbum', () {
    test('构造和字段访问', () {
      const album = MusicAlbum(
        id: 'a1',
        name: '测试专辑',
        serverUrl: 'http://test',
        productionYear: 2024,
        songCount: 10,
        artists: ['艺术家A'],
      );
      expect(album.id, 'a1');
      expect(album.name, '测试专辑');
      expect(album.productionYear, 2024);
      expect(album.songCount, 10);
      expect(album.artists, ['艺术家A']);
    });

    test('getCoverImageUrl', () {
      const album = MusicAlbum(
        id: 'a1',
        name: '专辑',
        serverUrl: 'http://test',
        primaryImageTag: 'tag123',
      );
      expect(
        album.getCoverImageUrl(),
        'http://test/Items/a1/Images/Primary?tag=tag123',
      );
      expect(
        album.getCoverImageUrl(fillWidth: 200),
        'http://test/Items/a1/Images/Primary?tag=tag123&fillWidth=200',
      );
    });

    test('hasCoverImage', () {
      const withImage = MusicAlbum(
        id: 'a1',
        name: 'A',
        serverUrl: 'http://t',
        primaryImageTag: 'tag',
      );
      const withoutImage = MusicAlbum(
        id: 'a2',
        name: 'B',
        serverUrl: 'http://t',
      );
      expect(withImage.hasCoverImage, true);
      expect(withoutImage.hasCoverImage, false);
    });

    test('artistText', () {
      const withArtists = MusicAlbum(
        id: 'a1',
        name: 'A',
        serverUrl: 'http://t',
        artists: ['X', 'Y'],
      );
      const without = MusicAlbum(id: 'a2', name: 'B', serverUrl: 'http://t');
      expect(withArtists.artistText, 'X / Y');
      expect(without.artistText, '未知艺术家');
    });

    test('Equatable', () {
      const a = MusicAlbum(id: 'a1', name: 'A', serverUrl: 'http://t');
      const b = MusicAlbum(id: 'a1', name: 'A', serverUrl: 'http://t');
      const c = MusicAlbum(id: 'a2', name: 'B', serverUrl: 'http://t');
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('MusicArtist', () {
    test('构造和字段访问', () {
      const artist = MusicArtist(
        id: 'ar1',
        name: '测试艺术家',
        serverUrl: 'http://test',
        albumCount: 5,
        songCount: 50,
      );
      expect(artist.id, 'ar1');
      expect(artist.albumCount, 5);
      expect(artist.songCount, 50);
    });

    test('hasImage', () {
      const withImg = MusicArtist(
        id: 'ar1',
        name: 'A',
        serverUrl: 'http://t',
        primaryImageTag: 'tag',
      );
      const without = MusicArtist(id: 'ar2', name: 'B', serverUrl: 'http://t');
      expect(withImg.hasImage, true);
      expect(without.hasImage, false);
    });
  });

  group('MusicSong', () {
    test('构造和字段访问', () {
      const song = MusicSong(
        id: 's1',
        name: '测试歌曲',
        serverUrl: 'http://test',
        trackNumber: 1,
        runTimeSeconds: 195,
        artists: ['艺术家A'],
      );
      expect(song.id, 's1');
      expect(song.trackNumber, 1);
      expect(song.runTimeSeconds, 195);
    });

    test('durationText', () {
      const song = MusicSong(
        id: 's1',
        name: 'A',
        serverUrl: 'http://t',
        runTimeSeconds: 195,
      );
      expect(song.durationText, '3:15');
    });

    test('getStreamUrl', () {
      const song = MusicSong(
        id: 's1',
        name: 'A',
        serverUrl: 'http://t',
        accessToken: 'key123',
      );
      // 默认使用 universal 端点
      final url = song.getStreamUrl();
      expect(url, contains('/Audio/s1/universal'));
      expect(url, contains('container=mp3,aac'));
      expect(url, contains('audioCodec=mp3'));
      expect(url, contains('api_key=key123'));
      // transcode: false 走原始流
      final rawUrl = song.getStreamUrl(transcode: false);
      expect(rawUrl, contains('/Audio/s1/stream'));
      expect(rawUrl, contains('api_key=key123'));
    });

    test('artistText', () {
      const withArtists = MusicSong(
        id: 's1',
        name: 'A',
        serverUrl: 'http://t',
        artists: ['X'],
      );
      const without = MusicSong(id: 's2', name: 'B', serverUrl: 'http://t');
      expect(withArtists.artistText, 'X');
      expect(without.artistText, '未知艺术家');
    });
  });

  group('列表结果', () {
    test('MusicAlbumListResult', () {
      const result = MusicAlbumListResult(albums: [], totalCount: 0);
      expect(result.isEmpty, true);
      expect(result.length, 0);
    });

    test('MusicSongListResult isNotEmpty', () {
      const result = MusicSongListResult(
        songs: [MusicSong(id: 's1', name: 'A', serverUrl: 'http://t')],
        totalCount: 1,
      );
      expect(result.isNotEmpty, true);
      expect(result.length, 1);
    });
  });

  group('MusicLibraryPage playback mapping', () {
    testWidgets('preserves song file path when building tracks from song tab', (
      tester,
    ) async {
      List<AudioTrack>? playedTracks;
      int? playedIndex;

      const song = MusicSong(
        id: 'song-with-path',
        name: 'Path Song',
        serverUrl: 'http://test',
        path: '/media/music/path-song.flac',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MusicLibraryPage(
            libraryName: 'Library',
            libraryId: 'library-id',
            fetchAlbums:
                ({required parentId, startIndex, limit, sortBy}) async =>
                    const MusicAlbumListResult(albums: [], totalCount: 0),
            fetchArtists: ({required parentId, startIndex, limit}) async =>
                const MusicArtistListResult(artists: [], totalCount: 0),
            fetchSongs: ({required parentId, startIndex, limit}) async =>
                const MusicSongListResult(songs: [song], totalCount: 1),
            onPlayTracks: (context, tracks, index) {
              playedTracks = tracks;
              playedIndex = index;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.music_note).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Path Song'));

      expect(playedIndex, 0);
      expect(playedTracks, isNotNull);
      expect(playedTracks!.single.path, '/media/music/path-song.flac');
    });
  });

  group('ArtistRef', () {
    test('Equatable', () {
      const a = ArtistRef(id: 'ar1', name: 'A');
      const b = ArtistRef(id: 'ar1', name: 'A');
      const c = ArtistRef(id: 'ar2', name: 'B');
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('MusicGenre', () {
    test('构造', () {
      const genre = MusicGenre(id: 'g1', name: 'Pop', serverUrl: 'http://t');
      expect(genre.name, 'Pop');
    });
  });

  group('AlbumDetailPage', () {
    testWidgets('显示专辑名和歌曲列表', (tester) async {
      final songs = List.generate(
        3,
        (i) => MusicSong(
          id: 's$i',
          name: '歌曲 $i',
          serverUrl: 'http://test',
          trackNumber: i + 1,
          runTimeSeconds: 180 + i * 30,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlbumDetailPage(
            album: const MusicAlbum(
              id: 'a1',
              name: '测试专辑',
              serverUrl: 'http://test',
            ),
            fetchAlbumDetail: (_) async => const MusicAlbum(
              id: 'a1',
              name: '测试专辑',
              serverUrl: 'http://test',
              songCount: 3,
            ),
            fetchAlbumSongs: (_) async =>
                MusicSongListResult(songs: songs, totalCount: 3),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('测试专辑'), findsOneWidget);
      expect(find.text('歌曲 0'), findsOneWidget);
      expect(find.text('歌曲 1'), findsOneWidget);
      expect(find.text('歌曲 2'), findsOneWidget);
    });

    testWidgets('点击歌曲触发 onPlaySong 回调', (tester) async {
      var playCalled = false;
      MusicSong? playedSong;

      final songs = [
        const MusicSong(
          id: 's1',
          name: '点击测试',
          serverUrl: 'http://test',
          trackNumber: 1,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AlbumDetailPage(
            album: const MusicAlbum(
              id: 'a1',
              name: '专辑',
              serverUrl: 'http://test',
            ),
            fetchAlbumDetail: (_) async => const MusicAlbum(
              id: 'a1',
              name: '专辑',
              serverUrl: 'http://test',
            ),
            fetchAlbumSongs: (_) async =>
                MusicSongListResult(songs: songs, totalCount: 1),
            onPlaySong: (ctx, song, playlist, index) {
              playCalled = true;
              playedSong = song;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('点击测试'));
      expect(playCalled, true);
      expect(playedSong?.id, 's1');
    });

    testWidgets('显示加载中', (tester) async {
      final completer = Completer<MusicSongListResult>();
      await tester.pumpWidget(
        MaterialApp(
          home: AlbumDetailPage(
            album: const MusicAlbum(
              id: 'a1',
              name: '加载专辑',
              serverUrl: 'http://test',
            ),
            fetchAlbumDetail: (_) async => const MusicAlbum(
              id: 'a1',
              name: '加载专辑',
              serverUrl: 'http://test',
            ),
            fetchAlbumSongs: (_) => completer.future,
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 完成未来以避免挂起计时器
      completer.complete(const MusicSongListResult(songs: [], totalCount: 0));
      await tester.pumpAndSettle();
    });
  });

  group('ArtistDetailPage', () {
    testWidgets('显示艺术家名和专辑网格', (tester) async {
      final albums = List.generate(
        2,
        (i) => MusicAlbum(
          id: 'al$i',
          name: '专辑 $i',
          serverUrl: 'http://test',
          primaryImageTag: 'tag$i',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDetailPage(
            artist: const MusicArtist(
              id: 'ar1',
              name: '测试艺术家',
              serverUrl: 'http://test',
            ),
            fetchArtistDetail: (_) async => const MusicArtist(
              id: 'ar1',
              name: '测试艺术家',
              serverUrl: 'http://test',
              albumCount: 2,
            ),
            fetchArtistAlbums: (_) async =>
                MusicAlbumListResult(albums: albums, totalCount: 2),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('测试艺术家'), findsOneWidget);
      expect(find.text('专辑 0'), findsOneWidget);
      expect(find.text('专辑 1'), findsOneWidget);
    });

    testWidgets('点击专辑触发 onNavigateToAlbum 回调', (tester) async {
      var navigated = false;
      MusicAlbum? targetAlbum;

      final albums = [
        const MusicAlbum(id: 'al1', name: '目标专辑', serverUrl: 'http://test'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDetailPage(
            artist: const MusicArtist(
              id: 'ar1',
              name: '艺术家',
              serverUrl: 'http://test',
            ),
            fetchArtistDetail: (_) async => const MusicArtist(
              id: 'ar1',
              name: '艺术家',
              serverUrl: 'http://test',
            ),
            fetchArtistAlbums: (_) async =>
                MusicAlbumListResult(albums: albums, totalCount: 1),
            onNavigateToAlbum: (ctx, album) {
              navigated = true;
              targetAlbum = album;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      // 专辑可能不在视口中，使用 ensureVisible 滚动到可见
      final albumFinder = find.text('目标专辑');
      await tester.ensureVisible(albumFinder);
      await tester.pumpAndSettle();
      await tester.tap(albumFinder);
      await tester.pumpAndSettle();
      expect(navigated, true);
      expect(targetAlbum?.id, 'al1');
    });

    testWidgets('无专辑显示空状态', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistDetailPage(
            artist: const MusicArtist(
              id: 'ar1',
              name: '空艺术家',
              serverUrl: 'http://test',
            ),
            fetchArtistDetail: (_) async => const MusicArtist(
              id: 'ar1',
              name: '空艺术家',
              serverUrl: 'http://test',
            ),
            fetchArtistAlbums: (_) async =>
                const MusicAlbumListResult(albums: [], totalCount: 0),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('暂无专辑'), findsOneWidget);
    });
  });

  group('AudioTrack', () {
    test('构造和字段访问', () {
      const track = AudioTrack(
        id: 't1',
        name: '测试歌曲',
        streamUrl: 'http://test/Audio/t1/stream',
        coverUrl: 'http://test/cover.jpg',
        artistText: '艺术家A',
        duration: Duration(minutes: 3, seconds: 30),
        albumName: '专辑名',
        trackNumber: 1,
        isFavorite: true,
      );
      expect(track.id, 't1');
      expect(track.name, '测试歌曲');
      expect(track.streamUrl, 'http://test/Audio/t1/stream');
      expect(track.coverUrl, 'http://test/cover.jpg');
      expect(track.artistText, '艺术家A');
      expect(track.duration, const Duration(minutes: 3, seconds: 30));
      expect(track.albumName, '专辑名');
      expect(track.trackNumber, 1);
      expect(track.isFavorite, true);
    });

    test('Equatable', () {
      const a = AudioTrack(id: 't1', name: 'A', streamUrl: 'http://test/s1');
      const b = AudioTrack(id: 't1', name: 'A', streamUrl: 'http://test/s1');
      const c = AudioTrack(id: 't2', name: 'B', streamUrl: 'http://test/s2');
      expect(a, b);
      expect(a, isNot(c));
    });

    test('可选字段为 null', () {
      const track = AudioTrack(
        id: 't1',
        name: '无封面歌曲',
        streamUrl: 'http://test/Audio/t1/stream',
      );
      expect(track.coverUrl, isNull);
      expect(track.artistText, isNull);
      expect(track.duration, isNull);
      expect(track.albumName, isNull);
      expect(track.trackNumber, isNull);
      expect(track.isFavorite, isNull);
    });
  });

  group('AudioPlaybackPort', () {
    test('是一个抽象类，继承 ChangeNotifier', () {
      // 验证 AudioPlaybackPort 是 abstract
      // 无法直接实例化，必须通过子类实现
      expect(() => _FakePlaybackPort(), returnsNormally);
    });

    test('AudioTrack props 包含关键字段', () {
      const track1 = AudioTrack(id: 't1', name: 'A', streamUrl: 'http://s1');
      const track2 = AudioTrack(
        id: 't1',
        name: 'A',
        streamUrl: 'http://s1',
        coverUrl: 'http://cover.jpg',
      );
      // track2 有额外字段但 props 只看 id+name+streamUrl
      expect(track1, track2);
    });
  });

  group('MusicPlayerPage RVC action', () {
    testWidgets('keeps a static RVC button and opens RVC on tap', (
      tester,
    ) async {
      final port = _FakePlaybackPort();
      await port.playSong(
        const AudioTrack(id: 't1', name: 'Track', streamUrl: 'http://test/t1'),
        const [
          AudioTrack(id: 't1', name: 'Track', streamUrl: 'http://test/t1'),
        ],
        0,
      );
      var opened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MusicPlayerPage(
            playbackPort: port,
            onOpenRvc: () => opened = true,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 4));

      expect(find.text('RVC'), findsOneWidget);
      expect(find.text('AI翻唱'), findsNothing);

      await tester.tap(find.text('RVC'));
      expect(opened, true);
    });
  });
}

/// 用于测试的 AudioPlaybackPort 最小实现
class _FakePlaybackPort extends AudioPlaybackPort {
  final List<AudioTrack> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  final bool _isLoading = false;
  String? _error;
  Duration _position = Duration.zero;
  final Duration _duration = Duration.zero;
  PlayMode _playMode = PlayMode.sequential;
  final _positionController = StreamController<Duration>.broadcast();

  @override
  AudioTrack? get currentTrack =>
      _playlist.isNotEmpty ? _playlist[_currentIndex] : null;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  bool get hasPlaylist => _playlist.isNotEmpty;

  @override
  List<AudioTrack> get playlist => List.unmodifiable(_playlist);

  @override
  int get playlistLength => _playlist.length;

  @override
  int get currentIndex => _currentIndex;

  @override
  PlayMode get playMode => _playMode;

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Future<void> playSong(
    AudioTrack track,
    List<AudioTrack> playlist,
    int startIndex,
  ) async {
    _playlist
      ..clear()
      ..addAll(playlist);
    _currentIndex = startIndex;
    _isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> resume() async {
    _isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    notifyListeners();
  }

  @override
  Future<void> playNext() async {}

  @override
  Future<void> playPrevious() async {}

  @override
  void toggleShuffle() {}

  @override
  void cycleRepeatMode() {}

  @override
  void cyclePlayMode() {
    _playMode = switch (_playMode) {
      PlayMode.sequential => PlayMode.shuffle,
      PlayMode.shuffle => PlayMode.repeatOne,
      PlayMode.repeatOne => PlayMode.sequential,
    };
    notifyListeners();
  }

  @override
  void updateTrackFavorite(String trackId, bool isFavorite) {}
}
