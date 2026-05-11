import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_service/src/adapters/media_item_mapper.dart';
import 'package:jellyfin_service/src/models/media_item_models.dart' as local;

void main() {
  group('MediaItemMapper', () {
    test('toShared: 完整字段映射', () {
      final localItem = local.MediaItem(
        id: 'item1',
        name: '测试电影',
        type: 'movie',
        serverUrl: 'http://localhost:8096',
        primaryImageTag: 'img-tag-123',
        backdropImageTag: 'bg-tag-456',
        productionYear: 2024,
        genres: ['动作', '科幻'],
        communityRating: 8.5,
        voteCount: 1000,
        officialRating: 'PG-13',
        runTimeTicks: 7200000000,
        runTimeMinutes: 120,
        overview: '测试剧情',
        studios: ['测试工作室'],
        directors: ['张导演'],
        writers: ['李编剧'],
        actors: ['王演员'],
        actorInfos: [const local.ActorInfo(name: '王演员', role: '主角', imageUrl: 'http://img.jpg', id: 'a1')],
        directorInfos: [const local.ActorInfo(name: '张导演', role: '导演', id: 'd1')],
        writerInfos: [const local.ActorInfo(name: '李编剧', role: '编剧', id: 'w1')],
        parentId: 'parent1',
        accessToken: 'token123',
        isFavorite: true,
        played: false,
        playedPercentage: 45.5,
      );

      final shared = MediaItemMapper.toShared(localItem);

      expect(shared.id, 'item1');
      expect(shared.name, '测试电影');
      expect(shared.type, 'movie');
      expect(shared.serverUrl, 'http://localhost:8096');
      expect(shared.primaryImageTag, 'img-tag-123');
      expect(shared.backdropImageTag, 'bg-tag-456');
      expect(shared.productionYear, 2024);
      expect(shared.genres, ['动作', '科幻']);
      expect(shared.communityRating, 8.5);
      expect(shared.voteCount, 1000);
      expect(shared.officialRating, 'PG-13');
      expect(shared.runTimeTicks, 7200000000);
      expect(shared.runTimeMinutes, 120);
      expect(shared.overview, '测试剧情');
      expect(shared.studios, ['测试工作室']);
      expect(shared.directors, ['张导演']);
      expect(shared.writers, ['李编剧']);
      expect(shared.actors, ['王演员']);
      expect(shared.parentId, 'parent1');
      expect(shared.accessToken, 'token123');
      expect(shared.isFavorite, true);
      expect(shared.played, false);
      expect(shared.playedPercentage, 45.5);

      // ActorInfo 映射
      expect(shared.actorInfos?.length, 1);
      expect(shared.actorInfos?.first.name, '王演员');
      expect(shared.actorInfos?.first.role, '主角');
      expect(shared.actorInfos?.first.imageUrl, 'http://img.jpg');
      expect(shared.actorInfos?.first.id, 'a1');

      expect(shared.directorInfos?.length, 1);
      expect(shared.directorInfos?.first.name, '张导演');

      expect(shared.writerInfos?.length, 1);
      expect(shared.writerInfos?.first.name, '李编剧');
    });

    test('toShared: 覆盖 serverUrl 和 accessToken', () {
      final localItem = local.MediaItem(
        id: 'item1',
        name: '测试',
        type: 'movie',
        serverUrl: 'http://old-server',
        accessToken: 'old-token',
      );

      final shared = MediaItemMapper.toShared(localItem,
        serverUrl: 'http://new-server',
        accessToken: 'new-token',
      );

      expect(shared.serverUrl, 'http://new-server');
      expect(shared.accessToken, 'new-token');
    });

    test('toShared: 空值字段正确处理', () {
      final localItem = local.MediaItem(
        id: 'item1',
        name: '测试',
        type: 'movie',
        serverUrl: 'http://localhost',
      );

      final shared = MediaItemMapper.toShared(localItem);

      expect(shared.primaryImageTag, isNull);
      expect(shared.genres, isNull);
      expect(shared.actorInfos, isNull);
      expect(shared.communityRating, isNull);
    });

    test('toLocal: 完整字段映射', () {
      final sharedItem = models.MediaItem(
        id: 'item1',
        name: '测试电影',
        type: 'movie',
        serverUrl: 'http://localhost:8096',
        primaryImageTag: 'img-tag',
        productionYear: 2024,
        genres: ['动作'],
        communityRating: 9.0,
        actorInfos: [const models.ActorInfo(name: '王演员', role: '主角', id: 'a1')],
        accessToken: 'token123',
      );

      final localItem = MediaItemMapper.toLocal(sharedItem);

      expect(localItem.id, 'item1');
      expect(localItem.name, '测试电影');
      expect(localItem.type, 'movie');
      expect(localItem.serverUrl, 'http://localhost:8096');
      expect(localItem.primaryImageTag, 'img-tag');
      expect(localItem.productionYear, 2024);
      expect(localItem.genres, ['动作']);
      expect(localItem.communityRating, 9.0);
      expect(localItem.actorInfos?.length, 1);
      expect(localItem.actorInfos?.first.name, '王演员');
      expect(localItem.actorInfos?.first.id, 'a1');
      expect(localItem.accessToken, 'token123');
    });

    test('toShared ↔ toLocal: 双向转换一致性', () {
      final original = local.MediaItem(
        id: 'item1',
        name: '测试电影',
        type: 'series',
        serverUrl: 'http://localhost:8096',
        primaryImageTag: 'tag1',
        backdropImageTag: 'tag2',
        productionYear: 2024,
        genres: ['科幻', '动作'],
        communityRating: 8.5,
        voteCount: 500,
        officialRating: 'R',
        runTimeTicks: 3600000000,
        runTimeMinutes: 60,
        overview: '测试简介',
        studios: ['工作室A'],
        directors: ['导演A'],
        writers: ['编剧A'],
        actors: ['演员A'],
        actorInfos: [const local.ActorInfo(name: '演员A', role: '主角', id: 'a1')],
        directorInfos: [const local.ActorInfo(name: '导演A', id: 'd1')],
        writerInfos: [const local.ActorInfo(name: '编剧A', id: 'w1')],
        parentId: 'parent1',
        accessToken: 'token',
        isFavorite: true,
        played: true,
        playedPercentage: 88.0,
      );

      final shared = MediaItemMapper.toShared(original);
      final roundTrip = MediaItemMapper.toLocal(shared);

      expect(roundTrip.id, original.id);
      expect(roundTrip.name, original.name);
      expect(roundTrip.type, original.type);
      expect(roundTrip.serverUrl, original.serverUrl);
      expect(roundTrip.primaryImageTag, original.primaryImageTag);
      expect(roundTrip.backdropImageTag, original.backdropImageTag);
      expect(roundTrip.productionYear, original.productionYear);
      expect(roundTrip.genres, original.genres);
      expect(roundTrip.communityRating, original.communityRating);
      expect(roundTrip.overview, original.overview);
      expect(roundTrip.studios, original.studios);
      expect(roundTrip.directors, original.directors);
      expect(roundTrip.writers, original.writers);
      expect(roundTrip.actors, original.actors);
      expect(roundTrip.accessToken, original.accessToken);
      expect(roundTrip.isFavorite, original.isFavorite);
      expect(roundTrip.played, original.played);
      expect(roundTrip.playedPercentage, original.playedPercentage);

      // ActorInfo 保持一致
      expect(roundTrip.actorInfos?.length, 1);
      expect(roundTrip.actorInfos?.first.name, '演员A');
      expect(roundTrip.actorInfos?.first.role, '主角');
      expect(roundTrip.actorInfos?.first.id, 'a1');
    });
  });
}
