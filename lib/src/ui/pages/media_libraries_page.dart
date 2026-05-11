import 'package:flutter/material.dart';
import 'package:jellyfin_service/src/jellyfin_client.dart';
import 'package:jellyfin_service/src/models/user_models.dart';
import 'package:jellyfin_service/src/models/media_library_models.dart';
import 'package:jellyfin_service/src/models/media_item_models.dart' as local;
import 'package:jellyfin_service/src/models/movie_filter_models.dart' as movie_models;
import 'package:jellyfin_service/src/ui/pages/video_player_page.dart';
import 'package:jellyfin_series/jellyfin_series_pages.dart' as series_pages;
import 'package:jellyfin_service/src/models/music_models.dart';
import 'package:jellyfin_service/src/ui/services/audio_playback_manager.dart';
import 'package:jellyfin_service/src/ui/pages/login_page.dart';
import 'package:jellyfin_service/src/ui/pages/personal_page.dart';
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;
import 'package:jellyfin_movies/jellyfin_movies_pages.dart' as movies_pages;
import 'package:jellyfin_service/src/ui/pages/music_library_page.dart';
import 'package:jellyfin_service/src/ui/pages/album_detail_page.dart';
import 'package:jellyfin_service/src/ui/pages/artist_detail_page.dart';
import 'package:jellyfin_service/src/ui/widgets/library_card.dart';
import 'package:jellyfin_service/src/ui/widgets/continue_watching_card.dart';
import 'package:jellyfin_service/src/ui/widgets/mini_player_card.dart';
import 'package:jellyfin_service/src/ui/services/jellyfin_client_image_provider.dart';
import 'package:jellyfin_service/src/ui/widgets/media_list_builder.dart';
import 'package:jellyfin_service/src/ui/models/view_mode_models.dart';
import 'package:jellyfin_service/src/adapters/media_item_mapper.dart';
import 'package:jellyfin_ai_recommendation/jellyfin_ai_recommendation.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_media/jellyfin_media_pages.dart' as media_pages;
import 'package:jellyfin_media/jellyfin_media_models.dart' as media_models;
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;

/// 媒体库列表页面 - 登录后展示所有媒体库，点击进入对应类型的页面
class MediaLibrariesPage extends StatefulWidget {
  final JellyfinClient client;
  final UserProfile user;

  const MediaLibrariesPage({super.key, required this.client, required this.user});

  @override
  State<MediaLibrariesPage> createState() => _MediaLibrariesPageState();
}

class _MediaLibrariesPageState extends State<MediaLibrariesPage> {
  List<MediaLibrary> _mediaLibraries = [];
  List<local.MediaItem> _continueWatching = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        widget.client.mediaLibrary.getMediaLibraries(),
        widget.client.user.getContinueWatching(limit: 10),
      ]);
      if (mounted) {
        setState(() {
          _mediaLibraries = (results[0] as MediaLibraryListResult).libraries;
          _continueWatching = (results[1] as local.MediaItemListResult).items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          // AI 推荐入口（胶囊动画按钮 — 来自独立业务模块）
          AiRecommendPill(onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AiRecommendPage(
              aiServiceUrl: widget.client.configuration.resolvedAiServiceUrl,
              imageProvider: JellyfinClientImageProvider(widget.client),
              fetchMediaItemDetail: (itemId) async {
                final src = await widget.client.mediaLibrary.getMediaItemDetail(itemId);
                return MediaItemMapper.toShared(src,
                  serverUrl: widget.client.configuration.serverUrl,
                  accessToken: widget.client.configuration.accessToken,
                );
              },
              onNavigateToMediaItem: (ctx, item) {
                Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
                    _buildNewMediaItemDetailPage(item)));
              },
              onNavigateToAlbum: (ctx, item) {
                final album = MusicAlbum(
                  id: item.id,
                  name: item.name,
                  serverUrl: widget.client.configuration.serverUrl,
                  primaryImageTag: item.primaryImageTag,
                  accessToken: widget.client.configuration.accessToken,
                  productionYear: item.productionYear,
                  communityRating: item.communityRating,
                  genres: item.genres,
                );
                Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
                    AlbumDetailPage(client: widget.client, album: album)));
              },
              onNavigateToArtist: (ctx, item) {
                final artist = MusicArtist(
                  id: item.id,
                  name: item.name,
                  serverUrl: widget.client.configuration.serverUrl,
                  primaryImageTag: item.primaryImageTag,
                  accessToken: widget.client.configuration.accessToken,
                  communityRating: item.communityRating,
                  genres: item.genres,
                );
                Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
                    ArtistDetailPage(client: widget.client, artist: artist)));
              },
              onPlaySong: (ctx, item) async {
                try {
                  final musicSong = MusicSong(
                    id: item.id,
                    name: item.name,
                    serverUrl: widget.client.configuration.serverUrl,
                    accessToken: widget.client.configuration.accessToken,
                    runTimeTicks: item.runTimeTicks,
                    genres: item.genres,
                    communityRating: item.communityRating,
                  );
                  final manager = AudioPlaybackManager.instance;
                  await manager.play([musicSong], 0, widget.client);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('播放失败: $e')),
                    );
                  }
                }
              },
            )));
          }),
          IconButton(icon: const Icon(Icons.person), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PersonalPage(client: widget.client)));
          }, tooltip: '个人中心'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Center(child: Text(widget.user.name, style: const TextStyle(fontWeight: FontWeight.bold)))),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await widget.client.auth.logout();
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
          }, tooltip: '登出'),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          ListenableBuilder(
            listenable: AudioPlaybackManager.instance,
            builder: (context, _) {
              if (!AudioPlaybackManager.instance.hasPlaylist) return const SizedBox.shrink();
              return MiniPlayerCard(client: widget.client);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在加载...')]));
    if (_errorMessage != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 64, color: Colors.red), const SizedBox(height: 16), Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: _loadAll, child: const Text('重试'))]));

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 媒体库
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('媒体库', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _mediaLibraries.map((lib) => LibraryCard(
              client: widget.client,
              library: lib,
              onTap: () => _navigateToLibrary(lib),
            )).toList(),
          ),
          // 继续观看
          if (_continueWatching.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('继续观看', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _continueWatching.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    ContinueWatchingCard(item: _continueWatching[index], client: widget.client),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToLibrary(MediaLibrary library) {
    Widget page;
    if (library.type == MediaLibraryType.movies) {
      page = _buildNewMovieFilterPage(library);
    } else if (library.type == MediaLibraryType.music) {
      page = MusicLibraryPage(client: widget.client, libraryId: library.id, libraryName: library.name);
    } else {
      // 使用新的 jellyfin_media 模块页面链路
      page = _buildNewMediaItemsPage(library);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // ==================== 新模块页面构建 ====================

  /// 构建 jellyfin_movies::MovieFilterPage
  Widget _buildNewMovieFilterPage(MediaLibrary library) {
    return movies_pages.MovieFilterPage(
      libraryId: library.id,
      libraryName: library.name,
      fetchMovies: (filter) async {
        // 将纯 Dart MovieFilter 转为根包的 MovieFilter（含 jellyfin_dart 类型）
        final rootFilter = _convertMovieFilter(filter);
        final result = await widget.client.mediaLibrary.getMovies(rootFilter);
        return movies.MovieFilterResult(
          movies: result.items.map((item) => MediaItemMapper.toShared(item,
            serverUrl: widget.client.configuration.serverUrl,
            accessToken: widget.client.configuration.accessToken,
          )).toList(),
          totalCount: result.totalCount,
          startIndex: result.startIndex,
        );
      },
      onNavigateToMovie: (ctx, item) {
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            _buildNewMovieDetailPage(item)));
      },
      listBuilder: ({required items, required onTap}) {
        // 注入根包的 MediaListBuilder
        return SizedBox(
          height: _calculateMovieListHeight(items.length),
          child: MediaListBuilder(
            client: widget.client,
            items: items.map((i) => MediaItemMapper.toLocal(i)).toList(),
            config: const ViewModeConfig(),
            onTap: (localItem) {
              final shared = MediaItemMapper.toShared(localItem,
                serverUrl: widget.client.configuration.serverUrl,
                accessToken: widget.client.configuration.accessToken);
              onTap(shared);
            },
          ),
        );
      },
    );
  }

  /// 构建 jellyfin_movies::MovieDetailPage
  Widget _buildNewMovieDetailPage(models.MediaItem item) {
    return movies_pages.MovieDetailPage(
      movie: item,
      fetchDetail: (itemId) async {
        final src = await widget.client.mediaLibrary.getMediaItemDetail(itemId);
        return MediaItemMapper.toShared(src,
          serverUrl: widget.client.configuration.serverUrl,
          accessToken: widget.client.configuration.accessToken,
        );
      },
      onStartPlayback: (ctx, movie) {
        final localItem = MediaItemMapper.toLocal(movie);
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            VideoPlayerPage(client: widget.client, item: localItem)));
      },
    );
  }

  /// 将纯 Dart MovieFilter 转换为根包 MovieFilter（含 jellyfin_dart 类型）
  movie_models.MovieFilter _convertMovieFilter(movies.MovieFilter filter) {
    return movie_models.MovieFilter(
      parentId: filter.parentId,
      startIndex: filter.startIndex,
      limit: filter.limit,
      genres: filter.genres,
      tags: filter.tags,
      years: filter.years,
      nameStartsWith: filter.nameStartsWith,
      studios: filter.studios,
      productionLocations: filter.productionLocations,
      minCommunityRating: filter.minCommunityRating,
      minOfficialRating: filter.minOfficialRating,
      maxOfficialRating: filter.maxOfficialRating,
      isHD: filter.isHD,
      is4K: filter.is4K,
      recursive: filter.recursive,
      filters: filter.isUnplayed == true
          ? const [jellyfin_dart.ItemFilter.isUnplayed]
          : null,
      sortBy: filter.sortBy?.map(_convertSortField).toList(),
      sortOrder: filter.sortOrder?.map(_convertSortOrder).toList(),
      fields: const [
        jellyfin_dart.ItemFields.primaryImageAspectRatio,
        jellyfin_dart.ItemFields.mediaSourceCount,
        jellyfin_dart.ItemFields.genres,
        jellyfin_dart.ItemFields.studios,
        jellyfin_dart.ItemFields.people,
        jellyfin_dart.ItemFields.overview,
        jellyfin_dart.ItemFields.productionLocations,
      ],
    );
  }

  jellyfin_dart.ItemSortBy _convertSortField(movies.MovieSortField field) {
    switch (field) {
      case movies.MovieSortField.dateCreated: return jellyfin_dart.ItemSortBy.dateCreated;
      case movies.MovieSortField.sortName: return jellyfin_dart.ItemSortBy.sortName;
      case movies.MovieSortField.productionYear: return jellyfin_dart.ItemSortBy.productionYear;
      case movies.MovieSortField.premiereDate: return jellyfin_dart.ItemSortBy.premiereDate;
      case movies.MovieSortField.random: return jellyfin_dart.ItemSortBy.random;
      case movies.MovieSortField.communityRating: return jellyfin_dart.ItemSortBy.communityRating;
    }
  }

  jellyfin_dart.SortOrder _convertSortOrder(movies.MovieSortOrder order) {
    switch (order) {
      case movies.MovieSortOrder.ascending: return jellyfin_dart.SortOrder.ascending;
      case movies.MovieSortOrder.descending: return jellyfin_dart.SortOrder.descending;
    }
  }

  double _calculateMovieListHeight(int count) {
    if (count == 0) return 400;
    return count * 300.0 + 32;
  }

  /// 构建 jellyfin_media::MediaItemsPage
  Widget _buildNewMediaItemsPage(MediaLibrary library) {
    final sharedLibrary = models.MediaLibrary(
      id: library.id,
      name: library.name,
      type: models.MediaLibraryType.values.firstWhere(
        (t) => t.name == library.type.name,
        orElse: () => models.MediaLibraryType.unknown,
      ),
      serverUrl: widget.client.configuration.serverUrl,
      primaryImageTag: library.primaryImageTag,
      itemCount: library.itemCount,
      accessToken: widget.client.configuration.accessToken,
    );

    return media_pages.MediaItemsPage(
      library: sharedLibrary,
      fetchMediaItems: ({required parentId, recursive = true, limit}) async {
        final result = await widget.client.mediaLibrary.getMediaItems(
          parentId: parentId,
          recursive: recursive,
          limit: limit,
        );
        return models.MediaItemListResult(
          items: result.items.map((item) => MediaItemMapper.toShared(item,
            serverUrl: widget.client.configuration.serverUrl,
            accessToken: widget.client.configuration.accessToken,
          )).toList(),
          totalCount: result.totalCount,
          startIndex: result.startIndex,
        );
      },
      onNavigateToMediaItem: (ctx, item) {
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            _buildNewMediaItemDetailPage(item)));
      },
    );
  }

  /// 构建 jellyfin_media::MediaItemDetailPage
  Widget _buildNewMediaItemDetailPage(models.MediaItem item) {
    return media_pages.MediaItemDetailPage(
      item: item,
      fetchDetail: (itemId) async {
        final src = await widget.client.mediaLibrary.getMediaItemDetail(itemId);
        return MediaItemMapper.toShared(src,
          serverUrl: widget.client.configuration.serverUrl,
          accessToken: widget.client.configuration.accessToken,
        );
      },
      fetchSeasons: (seriesId) async {
        final result = await widget.client.mediaLibrary.getSeasons(seriesId);
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
            _buildNewPersonDetailPage(personId, personName, personType)));
      },
      onNavigateToEpisodes: (ctx, series, season) {
        // 使用新的 jellyfin_series 模块页面
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            _buildNewEpisodesPage(series, season)));
      },
      onStartPlayback: (ctx, item) {
        final localItem = MediaItemMapper.toLocal(item);
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            VideoPlayerPage(client: widget.client, item: localItem)));
      },
    );
  }

  /// 构建 jellyfin_media::PersonDetailPage
  Widget _buildNewPersonDetailPage(String personId, String personName, String personType) {
    // String personType → jellyfin_dart.PersonKind（仅 API 调用需要）
    final personKind = jellyfin_dart.PersonKind.values.firstWhere(
      (k) => k.name.toLowerCase() == personType.toLowerCase(),
      orElse: () => jellyfin_dart.PersonKind.actor,
    );

    return media_pages.PersonDetailPage(
      personId: personId,
      personName: personName,
      personType: personType,
      fetchPersonDetail: (pId, pType) async {
        final src = await widget.client.mediaLibrary.getPersonDetail(pId, personKind);
        return MediaItemMapper.toSharedPerson(src);
      },
      fetchPersonCredits: (pId, {includeItemTypes}) async {
        final result = await widget.client.mediaLibrary.getPersonCredits(personId: pId);
        return media_models.PersonCreditsResult(
          items: result.items.map((item) => MediaItemMapper.toShared(item,
            serverUrl: widget.client.configuration.serverUrl,
            accessToken: widget.client.configuration.accessToken,
          )).toList(),
          totalCount: result.totalCount,
        );
      },
      imageProvider: JellyfinClientImageProvider(widget.client),
      onNavigateToMediaItem: (ctx, item) {
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            _buildNewMediaItemDetailPage(item)));
      },
    );
  }

  /// 构建 jellyfin_series::EpisodesPage
  Widget _buildNewEpisodesPage(models.MediaItem series, models.Season season) {
    return series_pages.EpisodesPage(
      series: series,
      season: season,
      fetchEpisodes: ({required seasonId, required seriesId}) async {
        final result = await widget.client.mediaLibrary.getEpisodes(
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
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            VideoPlayerPage(client: widget.client, item: localItem)));
      },
    );
  }
}
