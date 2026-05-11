import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_media/src/models/person_models.dart' as media_person;
import 'package:jellyfin_service/src/models/media_item_models.dart' as local;
import 'package:jellyfin_service/src/models/person_models.dart' as local_person;

/// 统一 MediaItem DTO 映射器
///
/// 将根包的 [local.MediaItem]（含 fromDto 依赖 jellyfin_dart）
/// 转换为 [models.MediaItem]（纯 Dart 共享模型）。
///
/// 所有 feature 模块只接受 [models.MediaItem]，
/// 转换只允许在此处和 API/data adapter 层发生。
class MediaItemMapper {
  /// 根包 MediaItem → 共享 MediaItem
  static models.MediaItem toShared(local.MediaItem src, {
    String? serverUrl,
    String? accessToken,
  }) {
    return models.MediaItem(
      id: src.id,
      name: src.name,
      type: src.type,
      serverUrl: serverUrl ?? src.serverUrl,
      primaryImageTag: src.primaryImageTag,
      backdropImageTag: src.backdropImageTag,
      productionYear: src.productionYear,
      genres: src.genres,
      communityRating: src.communityRating,
      voteCount: src.voteCount,
      officialRating: src.officialRating,
      runTimeTicks: src.runTimeTicks,
      runTimeMinutes: src.runTimeMinutes,
      overview: src.overview,
      studios: src.studios,
      directors: src.directors,
      writers: src.writers,
      actors: src.actors,
      actorInfos: _mapActorInfos(src.actorInfos),
      directorInfos: _mapActorInfos(src.directorInfos),
      writerInfos: _mapActorInfos(src.writerInfos),
      parentId: src.parentId,
      accessToken: accessToken ?? src.accessToken,
      isFavorite: src.isFavorite,
      played: src.played,
      playedPercentage: src.playedPercentage,
    );
  }

  /// 共享 MediaItem → 根包 MediaItem（用于旧页面兼容）
  static local.MediaItem toLocal(models.MediaItem src) {
    return local.MediaItem(
      id: src.id,
      name: src.name,
      type: src.type,
      serverUrl: src.serverUrl,
      primaryImageTag: src.primaryImageTag,
      backdropImageTag: src.backdropImageTag,
      productionYear: src.productionYear,
      genres: src.genres,
      communityRating: src.communityRating,
      voteCount: src.voteCount,
      officialRating: src.officialRating,
      runTimeTicks: src.runTimeTicks,
      runTimeMinutes: src.runTimeMinutes,
      overview: src.overview,
      studios: src.studios,
      directors: src.directors,
      writers: src.writers,
      actors: src.actors,
      actorInfos: _mapLocalActorInfos(src.actorInfos),
      directorInfos: _mapLocalActorInfos(src.directorInfos),
      writerInfos: _mapLocalActorInfos(src.writerInfos),
      parentId: src.parentId,
      accessToken: src.accessToken,
      isFavorite: src.isFavorite,
      played: src.played,
      playedPercentage: src.playedPercentage,
    );
  }

  /// 根包 Person → jellyfin_media Person
  ///
  /// 将 jellyfin_dart.PersonKind 转为 String 类型
  static media_person.Person toSharedPerson(local_person.Person src) {
    return media_person.Person(
      id: src.id,
      name: src.name,
      type: _personKindToString(src.type),
      bio: src.bio,
      imageUrl: src.imageUrl,
      premiereDate: src.premiereDate,
      birthDate: src.birthDate,
      deathDate: src.deathDate,
      genres: src.genres,
    );
  }

  /// PersonKind → String
  static String _personKindToString(jellyfin_dart.PersonKind kind) {
    return kind.name.toLowerCase();
  }

  /// 根包 ActorInfo 列表 → 共享 ActorInfo 列表
  static List<models.ActorInfo>? _mapActorInfos(List<local.ActorInfo>? infos) {
    return infos?.map((a) => models.ActorInfo(
      name: a.name,
      role: a.role,
      imageUrl: a.imageUrl,
      id: a.id,
    )).toList();
  }

  /// 共享 ActorInfo 列表 → 根包 ActorInfo 列表
  static List<local.ActorInfo>? _mapLocalActorInfos(List<models.ActorInfo>? infos) {
    return infos?.map((a) => local.ActorInfo(
      name: a.name,
      role: a.role,
      imageUrl: a.imageUrl,
      id: a.id,
    )).toList();
  }
}
