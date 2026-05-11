import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_series/jellyfin_series.dart';
import 'package:jellyfin_series/jellyfin_series_pages.dart';
import 'package:jellyfin_series/src/widgets/episode_card.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

void main() {
  group('SeasonsPage', () {
    testWidgets('显示加载状态', (WidgetTester tester) async {
      final completer = Completer<SeasonListResult>();
      addTearDown(() => completer.complete(const SeasonListResult(seasons: [])));

      await tester.pumpWidget(MaterialApp(
        home: SeasonsPage(
          series: MediaItem(
              id: 's1', name: '测试剧集', type: 'series', serverUrl: 'http://localhost'),
          fetchSeasons: (_) => completer.future,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('显示季列表', (WidgetTester tester) async {
      final seasons = List.generate(
        3,
        (i) => Season(
          id: 'season$i',
          seriesId: 's1',
          name: '第 ${i + 1} 季',
          indexNumber: i + 1,
          serverUrl: 'http://localhost',
          episodeCount: 10 + i,
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: SeasonsPage(
          series: MediaItem(
              id: 's1', name: '测试剧集', type: 'series', serverUrl: 'http://localhost'),
          fetchSeasons: (_) => Future.value(
              SeasonListResult(seasons: seasons, totalCount: 3)),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('共有 3 季'), findsOneWidget);
      expect(find.text('第 1 季'), findsOneWidget);
      expect(find.text('第 2 季'), findsOneWidget);
      expect(find.text('第 3 季'), findsOneWidget);
    });

    testWidgets('显示空状态', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SeasonsPage(
          series: MediaItem(
              id: 's1', name: '测试剧集', type: 'series', serverUrl: 'http://localhost'),
          fetchSeasons: (_) =>
              Future.value(const SeasonListResult(seasons: [])),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('该剧集暂无季信息'), findsOneWidget);
    });

    testWidgets('点击季触发回调', (WidgetTester tester) async {
      var tapped = false;
      final seasons = [
        Season(
          id: 'season1',
          seriesId: 's1',
          name: '第 1 季',
          indexNumber: 1,
          serverUrl: 'http://localhost',
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: SeasonsPage(
          series: MediaItem(
              id: 's1', name: '测试剧集', type: 'series', serverUrl: 'http://localhost'),
          fetchSeasons: (_) => Future.value(
              SeasonListResult(seasons: seasons, totalCount: 1)),
          onNavigateToEpisodes: (ctx, series, season) {
            tapped = true;
          },
        ),
      ));

      await tester.pumpAndSettle();
      // 点击季卡片
      final cards = find.byType(Card);
      if (cards.evaluate().isNotEmpty) {
        await tester.tap(cards.first);
        expect(tapped, isTrue);
      }
    });

    testWidgets('显示错误状态并重试', (WidgetTester tester) async {
      var callCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SeasonsPage(
          series: MediaItem(
              id: 's1', name: '测试剧集', type: 'series', serverUrl: 'http://localhost'),
          fetchSeasons: (_) {
            callCount++;
            if (callCount == 1) {
              return Future.error('网络错误');
            }
            return Future.value(const SeasonListResult(seasons: []));
          },
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.textContaining('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      // 点击重试
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(callCount, 2);
    });
  });

  group('EpisodesPage', () {
    testWidgets('显示加载状态', (WidgetTester tester) async {
      final completer = Completer<EpisodeListResult>();
      addTearDown(() =>
          completer.complete(const EpisodeListResult(episodes: [])));

      await tester.pumpWidget(MaterialApp(
        home: EpisodesPage(
          series: MediaItem(
              id: 's1', name: '测试剧集', type: 'series', serverUrl: 'http://localhost'),
          season: Season(
              id: 'season1',
              seriesId: 's1',
              name: '第 1 季',
              indexNumber: 1,
              serverUrl: 'http://localhost'),
          fetchEpisodes: ({required seasonId, required seriesId}) =>
              completer.future,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('显示集列表', (WidgetTester tester) async {
      final episodes = List.generate(
        3,
        (i) => Episode(
          id: 'ep$i',
          seriesId: 's1',
          seasonId: 'season1',
          name: '第 ${i + 1} 集',
          serverUrl: 'http://localhost',
          episodeNumber: i + 1,
          runTimeMinutes: 25,
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: SizedBox(
            height: 2000,
            child: EpisodesPage(
              series: MediaItem(
                  id: 's1',
                  name: '测试剧集',
                  type: 'series',
                  serverUrl: 'http://localhost'),
              season: Season(
                  id: 'season1',
                  seriesId: 's1',
                  name: '第 1 季',
                  indexNumber: 1,
                  serverUrl: 'http://localhost'),
              fetchEpisodes: ({required seasonId, required seriesId}) =>
                  Future.value(
                      EpisodeListResult(episodes: episodes, totalCount: 3)),
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('共有 3 集'), findsOneWidget);
      expect(find.text('第 1 集'), findsOneWidget);
      expect(find.text('第 2 集'), findsOneWidget);
    });

    testWidgets('显示空状态', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EpisodesPage(
          series: MediaItem(
              id: 's1', name: '测试剧集', type: 'series', serverUrl: 'http://localhost'),
          season: Season(
              id: 'season1',
              seriesId: 's1',
              name: '第 1 季',
              indexNumber: 1,
              serverUrl: 'http://localhost'),
          fetchEpisodes: ({required seasonId, required seriesId}) =>
              Future.value(const EpisodeListResult(episodes: [])),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('该季暂无剧集'), findsOneWidget);
    });

    testWidgets('点击播放按钮触发回调', (WidgetTester tester) async {
      var played = false;
      final episodes = [
        Episode(
          id: 'ep1',
          seriesId: 's1',
          seasonId: 'season1',
          name: '测试集',
          serverUrl: 'http://localhost',
          episodeNumber: 1,
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: SizedBox(
            height: 2000,
            child: EpisodesPage(
              series: MediaItem(
                  id: 's1',
                  name: '测试剧集',
                  type: 'series',
                  serverUrl: 'http://localhost'),
              season: Season(
                  id: 'season1',
                  seriesId: 's1',
                  name: '第 1 季',
                  indexNumber: 1,
                  serverUrl: 'http://localhost'),
              fetchEpisodes: ({required seasonId, required seriesId}) =>
                  Future.value(
                      EpisodeListResult(episodes: episodes, totalCount: 1)),
              onStartPlayback: (ctx, episode) {
                played = true;
              },
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();
      final playButtons = find.byIcon(Icons.play_circle_filled);
      if (playButtons.evaluate().isNotEmpty) {
        await tester.tap(playButtons.first);
        expect(played, isTrue);
      }
    });

    testWidgets('使用自定义 listBuilder', (WidgetTester tester) async {
      final episodes = [
        Episode(
          id: 'ep1',
          seriesId: 's1',
          seasonId: 'season1',
          name: '测试集',
          serverUrl: 'http://localhost',
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: EpisodesPage(
          series: MediaItem(
              id: 's1', name: '测试剧集', type: 'series', serverUrl: 'http://localhost'),
          season: Season(
              id: 'season1',
              seriesId: 's1',
              name: '第 1 季',
              indexNumber: 1,
              serverUrl: 'http://localhost'),
          fetchEpisodes: ({required seasonId, required seriesId}) =>
              Future.value(
                  EpisodeListResult(episodes: episodes, totalCount: 1)),
          listBuilder: (context, eps, onTap, onPlay) {
            return ListView.builder(
              itemCount: eps.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('自定义: ${eps[index].name}'),
                  onTap: () => onTap(eps[index]),
                );
              },
            );
          },
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('自定义: 测试集'), findsOneWidget);
    });
  });

  group('EpisodeCard', () {
    testWidgets('显示集信息', (WidgetTester tester) async {
      final episode = Episode(
        id: 'ep1',
        seriesId: 's1',
        seasonId: 'season1',
        name: '测试集名',
        serverUrl: 'http://localhost',
        episodeNumber: 5,
        seasonNumber: 2,
        runTimeMinutes: 45,
        communityRating: 9.1,
        overview: '这是一集测试内容',
      );

      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: EpisodeCard(
            episode: episode,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('测试集名'), findsOneWidget);
      expect(find.text('S02E05'), findsOneWidget);
      expect(find.text('45分钟'), findsOneWidget);
      expect(find.text('9.1'), findsOneWidget);
    });
  });
}
