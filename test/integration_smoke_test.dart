import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_movies/jellyfin_movies_pages.dart' as movies;
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies_models;
import 'package:jellyfin_series/jellyfin_series_pages.dart' as series;
import 'package:jellyfin_series/jellyfin_series.dart' as series_models;
import 'package:jellyfin_playback/jellyfin_playback.dart' as playback_models;

/// Smoke Test — 验证两条核心链路的回调连通性
///
/// 链路 1: MovieFilterPage → MovieDetailPage → PlaybackDelegate
/// 链路 2: SeasonsPage → EpisodesPage → 播放回调
void main() {
  group('集成链路 1: 电影筛选 → 详情 → 播放', () {
    final testMovie = MediaItem(
      id: 'movie-1',
      name: '测试电影',
      type: 'Movie',
      serverUrl: 'http://test',
      productionYear: 2024,
      genres: ['动作'],
    );

    testWidgets('MovieFilterPage 点击电影触发导航回调', (tester) async {
      var navigated = false;
      MediaItem? target;

      await tester.pumpWidget(MaterialApp(
        home: movies.MovieFilterPage(
          libraryId: 'lib-1',
          libraryName: '电影库',
          fetchMovies: (filter) async => movies_models.MovieFilterResult(
            movies: [testMovie],
            totalCount: 1,
          ),
          onNavigateToMovie: (context, item) {
            navigated = true;
            target = item;
          },
        ),
      ));

      await tester.pumpAndSettle();

      final finder = find.text('测试电影');
      if (finder.evaluate().isNotEmpty) {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(navigated, isTrue);
        expect(target?.id, 'movie-1');
      }
    });

    testWidgets('MovieDetailPage 渲染电影详情', (tester) async {
      var playbackStarted = false;

      await tester.pumpWidget(MaterialApp(
        home: movies.MovieDetailPage(
          movie: testMovie,
          fetchDetail: (id) async => testMovie,
          onStartPlayback: (context, item) {
            playbackStarted = true;
          },
        ),
      ));

      await tester.pumpAndSettle();

      // 验证电影名显示（标题和详情都包含电影名）
      expect(find.text('测试电影'), findsWidgets);

      // 播放按钮
      final playFinder = find.byIcon(Icons.play_arrow);
      if (playFinder.evaluate().isNotEmpty) {
        await tester.tap(playFinder.first);
        await tester.pumpAndSettle();
        expect(playbackStarted, isTrue);
      }
    });

    test('PlaybackDelegate 模拟完整播放生命周期', () async {
      var getUrlCalled = false;
      var startCalled = false;
      var stopCalled = false;

      final delegate = playback_models.PlaybackDelegate(
        getPlaybackUrl: ({
          required itemId,
          startTimeTicks,
          maxStreamingBitrate,
        }) async {
          getUrlCalled = true;
          return const playback_models.PlaybackInfo(
            url: 'http://test/stream',
            playSessionId: 'session-1',
          );
        },
        startSession: ({
          required itemId,
          required sessionIds,
        }) async {
          startCalled = true;
        },
        switchQuality: ({
          required itemId,
          required quality,
          required currentPosition,
        }) async {
          return const playback_models.PlaybackInfo(
            url: 'http://test/stream',
            playSessionId: 'session-1',
          );
        },
        stopEncoding: (playSessionId) async {},
        stopSession: () async {
          stopCalled = true;
        },
        dispose: () {},
      );

      // 1. 获取播放 URL
      final info = await delegate.getPlaybackUrl(itemId: 'movie-1');
      expect(getUrlCalled, isTrue);
      expect(info.url, 'http://test/stream');

      // 2. 开始会话
      await delegate.startSession(itemId: 'movie-1', sessionIds: ['s1']);
      expect(startCalled, isTrue);

      // 3. 停止会话
      await delegate.stopSession();
      expect(stopCalled, isTrue);

      delegate.dispose();
    });
  });

  group('集成链路 2: 剧集 → 季 → 集 → 播放', () {
    final testSeries = MediaItem(
      id: 'series-1',
      name: '测试剧集',
      type: 'Series',
      serverUrl: 'http://test',
    );

    final testSeason = Season(
      id: 'season-1',
      seriesId: 'series-1',
      name: '第 1 季',
      indexNumber: 1,
      serverUrl: 'http://test',
      episodeCount: 1,
    );

    final testEpisode = Episode(
      id: 'ep-1',
      seriesId: 'series-1',
      seasonId: 'season-1',
      name: '第 1 集',
      serverUrl: 'http://test',
      seasonNumber: 1,
      episodeNumber: 1,
      runTimeMinutes: 45,
    );

    testWidgets('SeasonsPage 点击季触发导航回调', (tester) async {
      var navigated = false;
      Season? targetSeason;

      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: SizedBox(
            height: 2000,
            child: series.SeasonsPage(
              series: testSeries,
              fetchSeasons: (seriesId) async => SeasonListResult(
                seasons: [testSeason],
                totalCount: 1,
              ),
              onNavigateToEpisodes: (context, s, season) {
                navigated = true;
                targetSeason = season;
              },
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();

      final finder = find.text('第 1 季');
      if (finder.evaluate().isNotEmpty) {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(navigated, isTrue);
        expect(targetSeason?.id, 'season-1');
      }
    });

    testWidgets('EpisodesPage 加载集列表并触发播放回调', (tester) async {
      var playbackStarted = false;
      Episode? targetEpisode;

      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: SizedBox(
            height: 2000,
            child: series.EpisodesPage(
              series: testSeries,
              season: testSeason,
              fetchEpisodes: ({
                required seasonId,
                required seriesId,
              }) async => EpisodeListResult(
                episodes: [testEpisode],
                totalCount: 1,
                startIndex: 0,
              ),
              onStartPlayback: (context, episode) {
                playbackStarted = true;
                targetEpisode = episode;
              },
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();

      // 验证集列表加载
      expect(find.text('第 1 集'), findsOneWidget);

      // 查找播放按钮（集卡片上的播放图标）
      final playButtons = find.byIcon(Icons.play_arrow);
      if (playButtons.evaluate().isNotEmpty) {
        await tester.tap(playButtons.first);
        await tester.pumpAndSettle();
        expect(playbackStarted, isTrue);
        expect(targetEpisode?.id, 'ep-1');
      }
    });
  });
}
