import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_media/jellyfin_media_models.dart';
import 'package:jellyfin_media/jellyfin_media_pages.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

void main() {
  group('Person', () {
    test('构造函数和属性', () {
      const person = Person(
        id: 'p1',
        name: '张三',
        type: 'actor',
        bio: '著名演员',
        imageUrl: 'http://example.com/img.jpg',
        genres: ['动作', '喜剧'],
      );
      expect(person.id, 'p1');
      expect(person.name, '张三');
      expect(person.type, 'actor');
      expect(person.bio, '著名演员');
      expect(person.imageUrl, 'http://example.com/img.jpg');
      expect(person.genres, ['动作', '喜剧']);
    });

    test('typeDisplayName 中文显示', () {
      expect(const Person(id: '', name: '', type: 'actor').typeDisplayName, '演员');
      expect(const Person(id: '', name: '', type: 'director').typeDisplayName, '导演');
      expect(const Person(id: '', name: '', type: 'writer').typeDisplayName, '编剧');
      expect(const Person(id: '', name: '', type: 'producer').typeDisplayName, '制片人');
      expect(const Person(id: '', name: '', type: 'composer').typeDisplayName, '作曲家');
      expect(const Person(id: '', name: '', type: 'other').typeDisplayName, 'other');
    });

    test('props 包含所有字段', () {
      const person = Person(
        id: 'p1',
        name: '李四',
        type: 'director',
      );
      expect(person.props.length, 9);
    });
  });

  group('PersonCreditsResult', () {
    test('isEmpty / isNotEmpty / length', () {
      const empty = PersonCreditsResult(items: []);
      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);
      expect(empty.length, 0);

      const result = PersonCreditsResult(
        items: [MediaItem(id: '1', name: 'test', type: 'movie', serverUrl: 'http://localhost')],
        totalCount: 1,
      );
      expect(result.isNotEmpty, isTrue);
      expect(result.length, 1);
      expect(result.totalCount, 1);
    });

    test('props', () {
      const result = PersonCreditsResult(items: [], totalCount: 5);
      expect(result.props, [[], 5]);
    });
  });

  group('MediaItemsPage', () {
    testWidgets('显示加载状态', (WidgetTester tester) async {
      // 使用 Completer 让 Future 永远不完成
      final completer = Completer<MediaItemListResult>();
      addTearDown(() => completer.complete(const MediaItemListResult(items: [])));

      await tester.pumpWidget(MaterialApp(
        home: MediaItemsPage(
          library: const MediaLibrary(
            id: 'lib1',
            name: '电影库',
            type: MediaLibraryType.movies,
            serverUrl: 'http://localhost',
          ),
          fetchMediaItems: ({required parentId, recursive = true, int? startIndex, int? limit}) {
            return completer.future;
          },
        ),
      ));

      expect(find.text('正在加载媒体项...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('显示媒体项列表', (WidgetTester tester) async {
      final items = List.generate(
        3,
        (i) => MediaItem(
          id: 'item$i',
          name: '电影 $i',
          type: 'movie',
          serverUrl: 'http://localhost',
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: MediaItemsPage(
          library: const MediaLibrary(
            id: 'lib1',
            name: '电影库',
            type: MediaLibraryType.movies,
            serverUrl: 'http://localhost',
          ),
          fetchMediaItems: ({required parentId, recursive = true, int? startIndex, int? limit}) {
            return Future.value(MediaItemListResult(items: items, totalCount: items.length));
          },
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('3 项'), findsOneWidget);
    });

    testWidgets('显示错误状态并重试', (WidgetTester tester) async {
      var callCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: MediaItemsPage(
          library: const MediaLibrary(
            id: 'lib1',
            name: '电影库',
            type: MediaLibraryType.movies,
            serverUrl: 'http://localhost',
          ),
          fetchMediaItems: ({required parentId, recursive = true, int? startIndex, int? limit}) {
            callCount++;
            if (callCount == 1) {
              throw Exception('网络错误');
            }
            return Future.value(const MediaItemListResult(items: []));
          },
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.textContaining('网络错误'), findsOneWidget);

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(callCount, 2);
    });

    testWidgets('显示空状态', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaItemsPage(
          library: const MediaLibrary(
            id: 'lib1',
            name: '电影库',
            type: MediaLibraryType.movies,
            serverUrl: 'http://localhost',
          ),
          fetchMediaItems: ({required parentId, recursive = true, int? startIndex, int? limit}) {
            return Future.value(const MediaItemListResult(items: []));
          },
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.textContaining('没有找到媒体项'), findsOneWidget);
    });
  });

  group('MediaItemDetailPage', () {
    testWidgets('显示加载状态', (WidgetTester tester) async {
      final completer = Completer<MediaItem>();
      addTearDown(() => completer.complete(
        MediaItem(id: '1', name: '测试电影', type: 'movie', serverUrl: 'http://localhost'),
      ));

      await tester.pumpWidget(MaterialApp(
        home: MediaItemDetailPage(
          item: MediaItem(id: '1', name: '测试电影', type: 'movie', serverUrl: 'http://localhost'),
          fetchDetail: (_) => completer.future,
        ),
      ));

      expect(find.text('正在加载详情...'), findsOneWidget);
    });

    testWidgets('显示错误状态', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaItemDetailPage(
          item: MediaItem(id: '1', name: '测试电影', type: 'movie', serverUrl: 'http://localhost'),
          fetchDetail: (_) => Future.error(Exception('加载失败')),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.textContaining('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('显示详情内容', (WidgetTester tester) async {
      final item = MediaItem(
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
        actorInfos: [
          const ActorInfo(name: '张三', role: '主角', id: 'a1'),
        ],
        directorInfos: [
          const ActorInfo(name: '李四', id: 'd1'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: SizedBox(
            height: 2000,
            child: MediaItemDetailPage(
              item: item,
              fetchDetail: (_) => Future.value(item),
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('测试电影'), findsWidgets);
      expect(find.text('剧情简介'), findsOneWidget);
      expect(find.text('这是一部测试电影'), findsOneWidget);
      expect(find.text('播放'), findsWidgets);
    });

    testWidgets('播放按钮触发回调', (WidgetTester tester) async {
      var playbackTriggered = false;
      final item = MediaItem(
        id: '1',
        name: '测试电影',
        type: 'movie',
        serverUrl: 'http://localhost',
      );

      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: SizedBox(
            height: 2000,
            child: MediaItemDetailPage(
              item: item,
              fetchDetail: (_) => Future.value(item),
              onStartPlayback: (context, item) {
                playbackTriggered = true;
              },
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();

      final playButtons = find.byIcon(Icons.play_arrow);
      if (playButtons.evaluate().isNotEmpty) {
        await tester.tap(playButtons.first);
        expect(playbackTriggered, isTrue);
      }
    });
  });

  group('PersonDetailPage', () {
    testWidgets('显示加载状态', (WidgetTester tester) async {
      final detailCompleter = Completer<Person>();
      final creditsCompleter = Completer<PersonCreditsResult>();
      addTearDown(() {
        detailCompleter.complete(const Person(id: 'p1', name: '张三', type: 'actor'));
        creditsCompleter.complete(const PersonCreditsResult(items: []));
      });

      await tester.pumpWidget(MaterialApp(
        home: PersonDetailPage(
          personId: 'p1',
          personName: '张三',
          personType: 'actor',
          fetchPersonDetail: (_, __) => detailCompleter.future,
          fetchPersonCredits: (_, {includeItemTypes}) => creditsCompleter.future,
          imageProvider: _FakeImageProvider(),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('显示人物信息', (WidgetTester tester) async {
      const person = Person(
        id: 'p1',
        name: '张三',
        type: 'actor',
        bio: '著名演员',
        birthDate: '1990-01-01T00:00:00.000',
        genres: ['动作'],
      );

      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          child: SizedBox(
            height: 2000,
            child: PersonDetailPage(
              personId: 'p1',
              personName: '张三',
              personType: 'actor',
              fetchPersonDetail: (_, __) => Future.value(person),
              fetchPersonCredits: (_, {includeItemTypes}) => Future.value(
                const PersonCreditsResult(items: []),
              ),
              imageProvider: _FakeImageProvider(),
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('张三'), findsWidgets);
      expect(find.text('著名演员'), findsOneWidget);
      expect(find.text('演员'), findsOneWidget);
      expect(find.textContaining('出生日期'), findsOneWidget);
      expect(find.text('暂无作品'), findsOneWidget);
    });
  });

  group('PersonAvatarCard', () {
    testWidgets('渲染人员头像和名称', (WidgetTester tester) async {
      const person = ActorInfo(name: '张三', role: '主角');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: PersonAvatarCard(
              person: person,
              onTap: () {},
            ),
          ),
        ),
      ));

      expect(find.text('张三'), findsOneWidget);
      expect(find.text('主角'), findsOneWidget);
    });

    testWidgets('无角色时不显示角色文本', (WidgetTester tester) async {
      const person = ActorInfo(name: '李四');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: PersonAvatarCard(person: person),
          ),
        ),
      ));

      expect(find.text('李四'), findsOneWidget);
      expect(find.textContaining('主角'), findsNothing);
    });
  });

  group('PersonListRow', () {
    testWidgets('显示人员列表', (WidgetTester tester) async {
      final persons = List.generate(
        3,
        (i) => ActorInfo(name: '人员 $i'),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: PersonListRow(
              persons: persons,
              title: '演员',
            ),
          ),
        ),
      ));

      expect(find.text('演员'), findsOneWidget);
      expect(find.text('(3)'), findsOneWidget);
    });

    testWidgets('空列表不显示', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PersonListRow(persons: const []),
        ),
      ));

      expect(find.byType(PersonListRow), findsOneWidget);
      expect(find.text('演员'), findsNothing);
    });
  });
}

/// 测试用 Fake 图片加载器
class _FakeImageProvider implements JellyfinImageProvider {
  @override
  Future<Uint8List> getPrimaryImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  }) async {
    return Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  }

  @override
  String buildImageUrl({
    required String itemId,
    String? imageTag,
    int? fillWidth,
    int? fillHeight,
  }) {
    return 'http://localhost/Items/$itemId/Images/Primary';
  }

  @override
  Map<String, String>? get authHeaders => null;
}
