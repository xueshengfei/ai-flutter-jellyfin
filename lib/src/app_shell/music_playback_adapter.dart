import 'package:jellyfin_service/src/jellyfin_client.dart';
import 'package:jellyfin_service/src/models/music_models.dart';
import 'package:jellyfin_music/jellyfin_music.dart' as music;
import 'package:jellyfin_service/src/ui/services/audio_playback_manager.dart';

/// 根包音乐模型 ↔ music 模块模型的双向转换 + 播放委托
class MusicPlaybackAdapter {
  /// 根包 MusicAlbum → music 模块 MusicAlbum
  static music.MusicAlbum toMusicAlbum(MusicAlbum root) => music.MusicAlbum(
    id: root.id, name: root.name, serverUrl: root.serverUrl,
    sortName: root.sortName, productionYear: root.productionYear,
    artists: root.artists, genres: root.genres, songCount: root.songCount,
    communityRating: root.communityRating, overview: root.overview,
    primaryImageTag: root.primaryImageTag, backdropImageTag: root.backdropImageTag,
    accessToken: root.accessToken, parentId: root.parentId,
  );

  /// 根包 MusicArtist → music 模块 MusicArtist
  static music.MusicArtist toMusicArtist(MusicArtist root) => music.MusicArtist(
    id: root.id, name: root.name, serverUrl: root.serverUrl,
    sortName: root.sortName, albumCount: root.albumCount, songCount: root.songCount,
    overview: root.overview, genres: root.genres,
    communityRating: root.communityRating, primaryImageTag: root.primaryImageTag,
    backdropImageTag: root.backdropImageTag, accessToken: root.accessToken,
  );

  /// 根包 MusicSong → music 模块 MusicSong
  static music.MusicSong toMusicSong(MusicSong root) => music.MusicSong(
    id: root.id, name: root.name, serverUrl: root.serverUrl,
    sortName: root.sortName, albumId: root.albumId, albumName: root.albumName,
    albumPrimaryImageTag: root.albumPrimaryImageTag, artists: root.artists,
    artistRefs: root.artistRefs?.map((r) => music.ArtistRef(id: r.id, name: r.name)).toList(),
    trackNumber: root.trackNumber, discNumber: root.discNumber,
    runTimeTicks: root.runTimeTicks, runTimeSeconds: root.runTimeSeconds,
    genres: root.genres, communityRating: root.communityRating,
    parentId: root.parentId, isFavorite: root.isFavorite,
    played: root.played, playCount: root.playCount,
    accessToken: root.accessToken, path: root.path,
  );

  /// 根包 MusicSongListResult → music 模块 MusicSongListResult
  static music.MusicSongListResult toMusicSongListResult(MusicSongListResult root) =>
    music.MusicSongListResult(
      songs: root.songs.map(toMusicSong).toList(),
      totalCount: root.totalCount, startIndex: root.startIndex,
    );

  /// 根包 MusicAlbumListResult → music 模块 MusicAlbumListResult
  static music.MusicAlbumListResult toMusicAlbumListResult(MusicAlbumListResult root) =>
    music.MusicAlbumListResult(
      albums: root.albums.map(toMusicAlbum).toList(),
      totalCount: root.totalCount, startIndex: root.startIndex,
    );

  /// music 模块 MusicSong → 根包 MusicSong
  static MusicSong toRootSong(music.MusicSong s) => MusicSong(
    id: s.id, name: s.name, serverUrl: s.serverUrl,
    accessToken: s.accessToken, albumId: s.albumId, albumName: s.albumName,
    albumPrimaryImageTag: s.albumPrimaryImageTag, artists: s.artists,
    trackNumber: s.trackNumber, discNumber: s.discNumber,
    runTimeTicks: s.runTimeTicks, runTimeSeconds: s.runTimeSeconds,
    genres: s.genres, communityRating: s.communityRating,
    parentId: s.parentId, isFavorite: s.isFavorite,
    played: s.played, playCount: s.playCount, path: s.path,
  );

  /// 播放歌曲列表（转换回根包 MusicSong 供 AudioPlaybackManager 使用）
  static void playMusicSongs(
    List<music.MusicSong> musicPlaylist,
    int index,
    JellyfinClient client,
    AudioPlaybackManager manager,
  ) {
    final rootPlaylist = musicPlaylist.map(toRootSong).toList();
    manager.play(rootPlaylist, index, client);
  }
}
