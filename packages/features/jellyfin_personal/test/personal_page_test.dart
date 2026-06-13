import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';
import 'package:jellyfin_personal/src/widgets/personal_media_card.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

void main() {
  testWidgets('history card tap opens detail instead of playback', (
    tester,
  ) async {
    final navigator = _RecordingAppNavigator();

    await tester.pumpWidget(
      MaterialApp(
        home: ServiceRegistry(
          services: {AppNavigator: navigator},
          child: PersonalPage(
            repository: _FakeRepository(),
            config: const PersonalModuleConfig.full(),
            imageProvider: _FakeImageProvider(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Zootopia').first);
    await tester.pump();

    // 验证发出了 mediaDetail 导航意图
    expect(navigator.pushIntentCalls, hasLength(1));
    final intent = navigator.pushIntentCalls.first as RouteNavigationIntent;
    expect(intent.routeName, JellyfinRouteNames.mediaDetail);
    expect(intent.arguments['itemId'], 'movie-1');
  });

  testWidgets('personal sections use compact cards without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ServiceRegistry(
          services: {AppNavigator: _RecordingAppNavigator()},
          child: PersonalPage(
            repository: _FakeRepository(),
            config: const PersonalModuleConfig.full(),
            imageProvider: _FakeImageProvider(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final cardSize = tester.getSize(find.byType(PersonalMediaCard).first);
    expect(cardSize.width, inInclusiveRange(168, 220));
    expect(cardSize.height, lessThanOrEqualTo(224));
    expect(tester.takeException(), isNull);
  });
}

/// 记录导航意图的测试 Navigator
final class _RecordingAppNavigator implements AppNavigator {
  final List<NavigationIntent> pushIntentCalls = [];

  @override
  Future<T?> push<T>(String routeName, {Map<String, Object?>? arguments}) =>
      Future<T?>.value();

  @override
  Future<T?> pushIntent<T>(NavigationIntent intent) {
    pushIntentCalls.add(intent);
    return Future<T?>.value();
  }

  @override
  void pop<T extends Object?>([T? result]) {}

  @override
  Future<T?> replace<T>(String routeName, {Map<String, Object?>? arguments}) =>
      Future<T?>.value();
}

final class _FakeRepository implements PersonalRepository {
  @override
  Future<models.UserProfile> getProfile() async {
    return const models.UserProfile(
      id: 'u1',
      name: 'tester',
      serverUrl: 'http://server',
    );
  }

  @override
  Future<models.MediaItemListResult> getContinueWatching(
    PersonalMediaQuery query,
  ) async {
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<models.MediaItemListResult> getFavorites(
    PersonalMediaQuery query,
  ) async {
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<models.MediaItemListResult> getHistory(
    PersonalMediaQuery query,
  ) async {
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<void> setFavorite({
    required String itemId,
    required bool isFavorite,
  }) async {}

  @override
  Future<void> setPlayed({
    required String itemId,
    required bool isPlayed,
  }) async {}

  @override
  Future<PersonalStats> getStats(PersonalMediaQuery query) async {
    return const PersonalStats();
  }
}

final class _FakeImageProvider implements JellyfinImageProvider {
  @override
  Map<String, String>? get authHeaders => null;

  @override
  String buildImageUrl({
    required String itemId,
    JellyfinImageType imageType = JellyfinImageType.primary,
    String? imageTag,
    int? fillWidth,
    int? fillHeight,
  }) {
    return 'http://server/Items/$itemId/Images/${imageType.pathSegment}';
  }

  @override
  Future<Uint8List> getImage({
    required String itemId,
    JellyfinImageType imageType = JellyfinImageType.primary,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  }) async {
    throw Exception('No image in widget test');
  }
}

const _item = models.MediaItem(
  id: 'movie-1',
  name: 'Zootopia',
  type: 'Movie',
  serverUrl: 'http://server',
  isFavorite: true,
  played: true,
);
