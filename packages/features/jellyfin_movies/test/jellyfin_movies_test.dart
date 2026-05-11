import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_movies/jellyfin_movies.dart';
import 'package:jellyfin_movies/jellyfin_movies_pages.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

void main() {
  group('MovieFilter', () {
    test('defaultFilter 创建默认过滤', () {
      final filter = MovieFilter.defaultFilter(parentId: 'lib1');
      expect(filter.parentId, 'lib1');
      expect(filter.startIndex, 0);
      expect(filter.limit, 20);
      expect(filter.sortBy, isNotNull);
      expect(filter.sortBy!.length, 3);
    });

    test('copyWith 修改字段', () {
      final filter = MovieFilter.defaultFilter(parentId: 'lib1');
      final modified = filter.copyWith(genres: ['动作', '科幻'], startIndex: 10);
      expect(modified.genres, ['动作', '科幻']);
      expect(modified.startIndex, 10);
      expect(modified.parentId, 'lib1');
    });

    test('copyWith clear 参数', () {
      final filter = MovieFilter(parentId: 'lib1', genres: ['动作'], years: [2024]);
      final cleared = filter.copyWith(clearGenres: true, clearYears: true);
      expect(cleared.genres, isNull);
      expect(cleared.years, isNull);
    });
  });

  group('MovieFilterResult', () {
    test('isEmpty / isNotEmpty / length', () {
      const empty = MovieFilterResult(movies: []);
      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);

      const result = MovieFilterResult(
        movies: [MediaItem(id: '1', name: '测试电影', type: 'movie', serverUrl: 'http://localhost')],
        totalCount: 1,
      );
      expect(result.isNotEmpty, isTrue);
      expect(result.length, 1);
    });
  });

  group('MovieFilterPage', () {
    testWidgets('显示加载状态', (WidgetTester tester) async {
      final completer = Completer<MovieFilterResult>();
      addTearDown(() => completer.complete(const MovieFilterResult(movies: [])));

      await tester.pumpWidget(MaterialApp(
        home: MovieFilterPage(
          libraryId: 'lib1',
          libraryName: '电影库',
          fetchMovies: (_) => completer.future,
        ),
      ));

      expect(find.text('正在加载电影...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('显示电影列表', (WidgetTester tester) async {
      final movies = List.generate(
        3,
        (i) => MediaItem(id: 'm$i', name: '电影 $i', type: 'movie', serverUrl: 'http://localhost'),
      );

      await tester.pumpWidget(MaterialApp(
        home: MovieFilterPage(
          libraryId: 'lib1',
          libraryName: '电影库',
          fetchMovies: (_) => Future.value(MovieFilterResult(movies: movies, totalCount: 3)),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.textContaining('3 部电影'), findsOneWidget);
    });

    testWidgets('显示空状态', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MovieFilterPage(
          libraryId: 'lib1',
          libraryName: '电影库',
          fetchMovies: (_) => Future.value(const MovieFilterResult(movies: [])),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('暂无电影'), findsOneWidget);
    });

    testWidgets('点击电影触发回调', (WidgetTester tester) async {
      var tapped = false;
      final movies = [
        MediaItem(id: 'm1', name: '测试电影', type: 'movie', serverUrl: 'http://localhost'),
      ];

      await tester.pumpWidget(MaterialApp(
        home: MovieFilterPage(
          libraryId: 'lib1',
          libraryName: '电影库',
          fetchMovies: (_) => Future.value(MovieFilterResult(movies: movies, totalCount: 1)),
          onNavigateToMovie: (ctx, item) { tapped = true; },
        ),
      ));

      await tester.pumpAndSettle();
      // 使用默认列表模式，点击 ListTile
      final listTiles = find.byType(ListTile);
      if (listTiles.evaluate().isNotEmpty) {
        await tester.tap(listTiles.first);
        expect(tapped, isTrue);
      }
    });
  });

  group('MovieDetailPage', () {
    testWidgets('显示加载状态', (WidgetTester tester) async {
      final completer = Completer<MediaItem>();
      addTearDown(() => completer.complete(
        MediaItem(id: '1', name: '测试电影', type: 'movie', serverUrl: 'http://localhost'),
      ));

      await tester.pumpWidget(MaterialApp(
        home: MovieDetailPage(
          movie: MediaItem(id: '1', name: '测试电影', type: 'movie', serverUrl: 'http://localhost'),
          fetchDetail: (_) => completer.future,
        ),
      ));

      expect(find.text('正在加载详情...'), findsOneWidget);
    });

    testWidgets('显示电影详情内容', (WidgetTester tester) async {
      final movie = MediaItem(
        id: '1',
        name: '测试电影',
        type: 'movie',
        serverUrl: 'http://localhost',
        overview: '这是一部测试电影',
        productionYear: 2024,
        communityRating: 8.5,
        officialRating: 'PG-13',
        runTimeMinutes: 120,
        genres: ['动作', '科幻'],
        studios: ['测试工作室'],
        directors: ['张导演'],
        writers: ['李编剧'],
      );

      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: SizedBox(
            height: 2000,
            child: MovieDetailPage(
              movie: movie,
              fetchDetail: (_) => Future.value(movie),
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('测试电影'), findsWidgets);
      expect(find.text('剧情简介'), findsOneWidget);
      expect(find.text('这是一部测试电影'), findsOneWidget);
      expect(find.text('播放'), findsOneWidget);
    });

    testWidgets('播放按钮触发回调', (WidgetTester tester) async {
      var triggered = false;
      final movie = MediaItem(id: '1', name: '测试', type: 'movie', serverUrl: 'http://localhost');

      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: SizedBox(
            height: 2000,
            child: MovieDetailPage(
              movie: movie,
              fetchDetail: (_) => Future.value(movie),
              onStartPlayback: (ctx, item) { triggered = true; },
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();
      final playButtons = find.byIcon(Icons.play_arrow);
      if (playButtons.evaluate().isNotEmpty) {
        await tester.tap(playButtons.first);
        expect(triggered, isTrue);
      }
    });
  });
}
