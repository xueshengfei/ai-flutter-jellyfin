import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_personal/jellyfin_personal.dart';

void main() {
  test('loadAll loads configured sections with configured media kinds', () async {
    final repository = _FakePersonalRepository();
    final controller = PersonalController(
      repository: repository,
      config: const PersonalModuleConfig.moviesOnly(),
    );

    await controller.loadAll();

    expect(repository.continueWatchingCalls, 1);
    expect(repository.favoriteCalls, 1);
    expect(repository.historyCalls, 1);
    expect(
      repository.lastQuery.mediaKinds,
      PersonalMediaKindSets.moviesOnly,
    );
    expect(
      controller.sectionState(PersonalSection.history).items.single.name,
      'Zootopia',
    );
  });

  test('setTypeFilter filters media kinds and reloads', () async {
    final repository = _FakePersonalRepository();
    final controller = PersonalController(
      repository: repository,
      config: const PersonalModuleConfig.full(),
    );

    await controller.loadAll();
    expect(controller.typeFilter, PersonalMediaTypeFilter.all);

    // 切到视频过滤
    await controller.setTypeFilter(PersonalMediaTypeFilter.video);
    expect(controller.typeFilter, PersonalMediaTypeFilter.video);
    expect(
      controller.filteredKinds,
      PersonalMediaKindSets.video,
    );
    // 每个区块重新加载一次
    expect(repository.continueWatchingCalls, 2);

    // 切到音乐过滤
    await controller.setTypeFilter(PersonalMediaTypeFilter.music);
    expect(controller.typeFilter, PersonalMediaTypeFilter.music);
    expect(
      controller.filteredKinds,
      PersonalMediaKindSets.music,
    );
    expect(repository.continueWatchingCalls, 3);
  });

  test('toggleFavorite calls repository and refreshes favorites', () async {
    final repository = _FakePersonalRepository();
    final controller = PersonalController(
      repository: repository,
      config: const PersonalModuleConfig.full(),
    );

    await controller.toggleFavorite('movie-1', false);

    expect(repository.favoriteMutation, ('movie-1', false));
    expect(repository.favoriteCalls, 1);
  });
}

final class _FakePersonalRepository implements PersonalRepository {
  int continueWatchingCalls = 0;
  int favoriteCalls = 0;
  int historyCalls = 0;
  PersonalMediaQuery lastQuery = const PersonalMediaQuery();
  (String, bool)? favoriteMutation;

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
    continueWatchingCalls++;
    lastQuery = query;
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<models.MediaItemListResult> getFavorites(
    PersonalMediaQuery query,
  ) async {
    favoriteCalls++;
    lastQuery = query;
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<models.MediaItemListResult> getHistory(
    PersonalMediaQuery query,
  ) async {
    historyCalls++;
    lastQuery = query;
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<void> setFavorite({
    required String itemId,
    required bool isFavorite,
  }) async {
    favoriteMutation = (itemId, isFavorite);
  }

  @override
  Future<void> setPlayed({
    required String itemId,
    required bool isPlayed,
  }) async {}

  @override
  Future<PersonalStats> getStats(PersonalMediaQuery query) async {
    return const PersonalStats(
      totalWatched: 5,
      totalFavorites: 3,
      continueWatchingCount: 2,
    );
  }
}

const _item = models.MediaItem(
  id: 'movie-1',
  name: 'Zootopia',
  type: 'Movie',
  serverUrl: 'http://server',
);
