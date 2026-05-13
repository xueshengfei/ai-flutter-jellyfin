import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

void main() {
  testWidgets('history card tap opens detail instead of playback',
      (tester) async {
    models.MediaItem? opened;
    models.MediaItem? played;

    await tester.pumpWidget(MaterialApp(
      home: PersonalPage(
        repository: _FakeRepository(),
        config: const PersonalModuleConfig.full(),
        imageProvider: _FakeImageProvider(),
        actions: PersonalActions(
          onOpenMedia: (_, item) => opened = item,
          onPlayMedia: (_, item) => played = item,
        ),
      ),
    ));

    await tester.pumpAndSettle();
    await tester.tap(find.text('Zootopia').first);
    await tester.pump();

    expect(opened?.id, 'movie-1');
    expect(played, isNull);
  });
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
}

final class _FakeImageProvider implements JellyfinImageProvider {
  @override
  Map<String, String>? get authHeaders => null;

  @override
  String buildImageUrl({
    required String itemId,
    String? imageTag,
    int? fillWidth,
    int? fillHeight,
  }) {
    return 'http://server/Items/$itemId/Images/Primary';
  }

  @override
  Future<Uint8List> getPrimaryImage({
    required String itemId,
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
