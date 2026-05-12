import 'package:flutter/material.dart';
import 'package:jellyfin_service/src/app_shell/app_session.dart';
import 'package:jellyfin_service/src/app_shell/movie_filter_adapter.dart';
import 'package:jellyfin_service/src/app_shell/playback_delegate_factory.dart';
import 'package:jellyfin_service/src/app_shell/music_playback_adapter.dart';
import 'package:jellyfin_service/src/models/media_library_models.dart';
import 'package:jellyfin_service/src/models/media_item_models.dart' as local;
import 'package:jellyfin_service/src/models/music_models.dart';
import 'package:jellyfin_service/src/ui/services/audio_playback_manager.dart';
import 'package:jellyfin_service/src/ui/services/jellyfin_client_image_provider.dart';
import 'package:jellyfin_service/src/ui/widgets/media_list_builder.dart';
import 'package:jellyfin_service/src/ui/models/view_mode_models.dart';
import 'package:jellyfin_service/src/adapters/media_item_mapper.dart';
import 'package:jellyfin_service/src/ui/pages/music_library_page.dart';
import 'package:jellyfin_playback/jellyfin_playback_pages.dart' as playback_pages;
import 'package:jellyfin_music/jellyfin_music.dart' as music;
import 'package:jellyfin_music/jellyfin_music_pages.dart' as music_pages;
import 'package:jellyfin_series/jellyfin_series_pages.dart' as series_pages;
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;
import 'package:jellyfin_movies/jellyfin_movies_pages.dart' as movies_pages;
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_media/jellyfin_media_pages.dart' as media_pages;
import 'package:jellyfin_media/jellyfin_media_models.dart' as media_models;
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'package:jellyfin_ai_recommendation/jellyfin_ai_recommendation.dart';

/// 特性页面工厂 — 统一编排所有 feature 页面的构建
///
/// 接收 [AppSession] 构造参数，内部使用 [MovieFilterAdapter]，
/// [PlaybackDelegateFactory]，[MediaItemMapper] 等工具类完成
/// 根包模型 → feature 模块模型的转换和页面组装。
class FeaturePageFactory {
  final AppSession _session;
  late final PlaybackDelegateFactory _playbackFactory;

  FeaturePageFactory(this._session) {
    _playbackFactory = PlaybackDelegateFactory(_session.client);
  }

  // ==================== 分派方法 ====================

  /// 根据媒体库类型返回对应页面
  Widget pageForLibrary(MediaLibrary library) {
    if (library.type == MediaLibraryType.movies) {
      return movieFilterPage(library);
    } else if (library.type == MediaLibraryType.music) {
      return MusicLibraryPage(
        client: _session.client,
        libraryId: library.id,
        libraryName: library.name,
      );
    } else {
      return mediaItemsPage(library);
    }
  }

  // ==================== 电影模块页面 ====================

  /// 构建 jellyfin_movies::MovieFilterPage
  Widget movieFilterPage(MediaLibrary library) {
    return movies_pages.MovieFilterPage(
      libraryId: library.id,
      libraryName: library.name,
      fetchMovies: (filter) async {
        final rootFilter = MovieFilterAdapter.convert(filter);
        final result = await _session.client.mediaLibrary.getMovies(rootFilter);
        return movies.MovieFilterResult(
          movies: result.items.map((item) => MediaItemMapper.toShared(item,
            serverUrl: _session.serverUrl,
            accessToken: _session.accessToken,
          )).toList(),
          totalCount: result.totalCount,
          startIndex: result.startIndex,
        );
      },
      onNavigateToMovie: (ctx, item) {
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            movieDetailPage(item)));
      },
      listBuilder: ({required items, required onTap}) {
        return SizedBox(
          height: _calculateMovieListHeight(items.length),
          child: MediaListBuilder(
            client: _session.client,
            items: items.map((i) => MediaItemMapper.toLocal(i)).toList(),
            config: const ViewModeConfig(),
            onTap: (localItem) {
              final shared = MediaItemMapper.toShared(localItem,
                serverUrl: _session.serverUrl,
                accessToken: _session.accessToken);
              onTap(shared);
            },
          ),
        );
      },
    );
  }

  /// 构建 jellyfin_movies::MovieDetailPage
  Widget movieDetailPage(models.MediaItem item) {
    return movies_pages.MovieDetailPage(
      movie: item,
      fetchDetail: (itemId) async {
        final src = await _session.client.mediaLibrary.getMediaItemDetail(itemId);
        return MediaItemMapper.toShared(src,
          serverUrl: _session.serverUrl,
          accessToken: _session.accessToken,
        );
      },
      onStartPlayback: (ctx, movie) {
        final localItem = MediaItemMapper.toLocal(movie);
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            playback_pages.VideoPlayerPage(
              item: movie,
              playback: _playbackFactory.create(localItem),
            )));
      },
    );
  }

  double _calculateMovieListHeight(int count) {
    if (count == 0) return 400;
    return count * 300.0 + 32;
  }

  // ==================== 通用媒体模块页面 ====================

  /// 构建 jellyfin_media::MediaItemsPage
  Widget mediaItemsPage(MediaLibrary library) {
    final sharedLibrary = models.MediaLibrary(
      id: library.id,
      name: library.name,
      type: models.MediaLibraryType.values.firstWhere(
        (t) => t.name == library.type.name,
        orElse: () => models.MediaLibraryType.unknown,
      ),
      serverUrl: _session.serverUrl,
      primaryImageTag: library.primaryImageTag,
      itemCount: library.itemCount,
      accessToken: _session.accessToken,
    );

    return media_pages.MediaItemsPage(
      library: sharedLibrary,
      fetchMediaItems: ({required parentId, recursive = true, limit}) async {
        final result = await _session.client.mediaLibrary.getMediaItems(
          parentId: parentId,
          recursive: recursive,
          limit: limit,
        );
        return models.MediaItemListResult(
          items: result.items.map((item) => MediaItemMapper.toShared(item,
            serverUrl: _session.serverUrl,
            accessToken: _session.accessToken,
          )).toList(),
          totalCount: result.totalCount,
          startIndex: result.startIndex,
        );
      },
      onNavigateToMediaItem: (ctx, item) {
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            mediaItemDetailPage(item)));
      },
    );
  }

  /// 构建 jellyfin_media::MediaItemDetailPage
  Widget mediaItemDetailPage(models.MediaItem item) {
    return media_pages.MediaItemDetailPage(
      item: item,
      fetchDetail: (itemId) async {
        final src = await _session.client.mediaLibrary.getMediaItemDetail(itemId);
        return MediaItemMapper.toShared(src,
          serverUrl: _session.serverUrl,
          accessToken: _session.accessToken,
        );
      },
      fetchSeasons: (seriesId) async {
        final result = await _session.client.mediaLibrary.getSeasons(seriesId);
        return models.SeasonListResult(
          seasons: result.seasons.map((s) => models.Season(
            id: s.id,
            seriesId: s.seriesId,
            name: s.name,
            indexNumber: s.indexNumber,
            serverUrl: s.serverUrl,
            primaryImageTag: s.primaryImageTag,
            overview: s.overview,
            episodeCount: s.episodeCount,
            accessToken: s.accessToken,
          )).toList(),
          totalCount: result.totalCount,
        );
      },
      onNavigateToPerson: (ctx, personId, personName, personType) {
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            personDetailPage(personId, personName, personType)));
      },
      onNavigateToEpisodes: (ctx, series, season) {
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            episodesPage(series, season)));
      },
      onStartPlayback: (ctx, item) {
        final localItem = MediaItemMapper.toLocal(item);
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            playback_pages.VideoPlayerPage(
              item: item,
              playback: _playbackFactory.create(localItem),
            )));
      },
    );
  }

  /// 构建 jellyfin_media::PersonDetailPage
  Widget personDetailPage(String personId, String personName, String personType) {
    final personKind = jellyfin_dart.PersonKind.values.firstWhere(
      (k) => k.name.toLowerCase() == personType.toLowerCase(),
      orElse: () => jellyfin_dart.PersonKind.actor,
    );

    return media_pages.PersonDetailPage(
      personId: personId,
      personName: personName,
      personType: personType,
      fetchPersonDetail: (pId, pType) async {
        final src = await _session.client.mediaLibrary.getPersonDetail(pId, personKind);
        return MediaItemMapper.toSharedPerson(src);
      },
      fetchPersonCredits: (pId, {includeItemTypes}) async {
        final result = await _session.client.mediaLibrary.getPersonCredits(personId: pId);
        return media_models.PersonCreditsResult(
          items: result.items.map((item) => MediaItemMapper.toShared(item,
            serverUrl: _session.serverUrl,
            accessToken: _session.accessToken,
          )).toList(),
          totalCount: result.totalCount,
        );
      },
      imageProvider: JellyfinClientImageProvider(_session.client),
      onNavigateToMediaItem: (ctx, item) {
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            mediaItemDetailPage(item)));
      },
    );
  }

  // ==================== 剧集模块页面 ====================

  /// 构建 jellyfin_series::EpisodesPage
  Widget episodesPage(models.MediaItem series, models.Season season) {
    return series_pages.EpisodesPage(
      series: series,
      season: season,
      fetchEpisodes: ({required seasonId, required seriesId}) async {
        final result = await _session.client.mediaLibrary.getEpisodes(
          seasonId: seasonId,
          seriesId: seriesId,
        );
        return MediaItemMapper.toSharedEpisodeListResult(result);
      },
      onStartPlayback: (ctx, episode) {
        final localItem = local.MediaItem(
          id: episode.id,
          name: episode.name,
          type: 'Episode',
          primaryImageTag: episode.primaryImageTag,
          runTimeTicks: episode.runTimeTicks,
          runTimeMinutes: episode.runTimeMinutes,
          overview: episode.overview,
          serverUrl: episode.serverUrl,
        );
        final sharedItem = models.MediaItem(
          id: episode.id,
          name: episode.name,
          type: 'Episode',
          serverUrl: episode.serverUrl,
          primaryImageTag: episode.primaryImageTag,
          runTimeTicks: episode.runTimeTicks,
          runTimeMinutes: episode.runTimeMinutes,
          overview: episode.overview,
          playedPercentage: episode.playedPercentage,
        );
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            playback_pages.VideoPlayerPage(
              item: sharedItem,
              playback: _playbackFactory.create(localItem),
            )));
      },
    );
  }

  // ==================== 音乐模块页面 ====================

  /// 构建 jellyfin_music::AlbumDetailPage
  Widget albumDetailPage(music.MusicAlbum album) {
    return music_pages.AlbumDetailPage(
      album: album,
      fetchAlbumDetail: (id) async {
        final rootAlbum = await _session.client.music.getAlbumDetail(id);
        return MusicPlaybackAdapter.toMusicAlbum(rootAlbum);
      },
      fetchAlbumSongs: (id) async {
        final rootResult = await _session.client.music.getAlbumSongs(id);
        return MusicPlaybackAdapter.toMusicSongListResult(rootResult);
      },
      onPlaySong: (ctx, song, playlist, index) {
        MusicPlaybackAdapter.playMusicSongs(
          playlist, index, _session.client, AudioPlaybackManager.instance,
        );
      },
    );
  }

  /// 构建 jellyfin_music::ArtistDetailPage
  Widget artistDetailPage(music.MusicArtist artist) {
    return music_pages.ArtistDetailPage(
      artist: artist,
      fetchArtistDetail: (id) async {
        final rootArtist = await _session.client.music.getArtistDetail(id);
        return MusicPlaybackAdapter.toMusicArtist(rootArtist);
      },
      fetchArtistAlbums: (id) async {
        final rootResult = await _session.client.music.getArtistAlbums(id);
        return MusicPlaybackAdapter.toMusicAlbumListResult(rootResult);
      },
      onNavigateToAlbum: (ctx, album) {
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            albumDetailPage(album)));
      },
    );
  }

  // ==================== AI 推荐页面 ====================

  /// 构建 AI 推荐页面
  Widget aiRecommendPage() {
    return AiRecommendPage(
      aiServiceUrl: _session.client.configuration.resolvedAiServiceUrl,
      imageProvider: JellyfinClientImageProvider(_session.client),
      fetchMediaItemDetail: (itemId) async {
        final src = await _session.client.mediaLibrary.getMediaItemDetail(itemId);
        return MediaItemMapper.toShared(src,
          serverUrl: _session.serverUrl,
          accessToken: _session.accessToken,
        );
      },
      onNavigateToMediaItem: (ctx, item) {
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            mediaItemDetailPage(item)));
      },
      onNavigateToAlbum: (ctx, item) {
        final musicAlbum = music.MusicAlbum(
          id: item.id,
          name: item.name,
          serverUrl: _session.serverUrl,
          primaryImageTag: item.primaryImageTag,
          accessToken: _session.accessToken,
          productionYear: item.productionYear,
          communityRating: item.communityRating,
          genres: item.genres,
        );
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            albumDetailPage(musicAlbum)));
      },
      onNavigateToArtist: (ctx, item) {
        final musicArtist = music.MusicArtist(
          id: item.id,
          name: item.name,
          serverUrl: _session.serverUrl,
          primaryImageTag: item.primaryImageTag,
          accessToken: _session.accessToken,
          communityRating: item.communityRating,
          genres: item.genres,
        );
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            artistDetailPage(musicArtist)));
      },
      onPlaySong: (ctx, item) async {
        try {
          final musicSong = MusicSong(
            id: item.id,
            name: item.name,
            serverUrl: _session.serverUrl,
            accessToken: _session.accessToken,
            runTimeTicks: item.runTimeTicks,
            genres: item.genres,
            communityRating: item.communityRating,
          );
          final manager = AudioPlaybackManager.instance;
          await manager.play([musicSong], 0, _session.client);
        } catch (e) {
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('播放失败: $e')),
            );
          }
        }
      },
    );
  }
}
