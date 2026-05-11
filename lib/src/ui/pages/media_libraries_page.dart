import 'package:flutter/material.dart';
import 'package:jellyfin_service/src/jellyfin_client.dart';
import 'package:jellyfin_service/src/models/user_models.dart';
import 'package:jellyfin_service/src/models/media_library_models.dart';
import 'package:jellyfin_service/src/models/media_item_models.dart' as local;
import 'package:jellyfin_service/src/models/music_models.dart';
import 'package:jellyfin_service/src/ui/services/audio_playback_manager.dart';
import 'package:jellyfin_service/src/ui/pages/login_page.dart';
import 'package:jellyfin_service/src/ui/pages/personal_page.dart';
import 'package:jellyfin_service/src/ui/pages/movie_filter_page.dart';
import 'package:jellyfin_service/src/ui/pages/music_library_page.dart';
import 'package:jellyfin_service/src/ui/pages/media_items_page.dart';
import 'package:jellyfin_service/src/ui/pages/media_item_detail_page.dart';
import 'package:jellyfin_service/src/ui/pages/album_detail_page.dart';
import 'package:jellyfin_service/src/ui/pages/artist_detail_page.dart';
import 'package:jellyfin_service/src/ui/widgets/library_card.dart';
import 'package:jellyfin_service/src/ui/widgets/continue_watching_card.dart';
import 'package:jellyfin_service/src/ui/widgets/mini_player_card.dart';
import 'package:jellyfin_service/src/ui/services/jellyfin_client_image_provider.dart';
import 'package:jellyfin_ai_recommendation/jellyfin_ai_recommendation.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;

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
            // 根包 MediaItem → jellyfin_models MediaItem 适配器
            models.MediaItem toModelsMediaItem(local.MediaItem src) =>
              models.MediaItem(
                id: src.id,
                name: src.name,
                type: src.type,
                serverUrl: widget.client.configuration.serverUrl,
                primaryImageTag: src.primaryImageTag,
                backdropImageTag: src.backdropImageTag,
                productionYear: src.productionYear,
                genres: src.genres,
                communityRating: src.communityRating,
                runTimeTicks: src.runTimeTicks,
                accessToken: widget.client.configuration.accessToken,
              );

            Navigator.push(context, MaterialPageRoute(builder: (_) => AiRecommendPage(
              aiServiceUrl: widget.client.configuration.resolvedAiServiceUrl,
              imageProvider: JellyfinClientImageProvider(widget.client),
              fetchMediaItemDetail: (itemId) async {
                final src = await widget.client.mediaLibrary.getMediaItemDetail(itemId);
                return toModelsMediaItem(src);
              },
              onNavigateToMediaItem: (ctx, item) {
                // jellyfin_models.MediaItem → 根包 MediaItem 用于本地页面
                final localItem = local.MediaItem(
                  id: item.id,
                  name: item.name,
                  type: item.type,
                  serverUrl: item.serverUrl,
                  primaryImageTag: item.primaryImageTag,
                  productionYear: item.productionYear,
                  communityRating: item.communityRating,
                  genres: item.genres,
                  runTimeTicks: item.runTimeTicks,
                  overview: item.overview,
                  backdropImageTag: item.backdropImageTag,
                  officialRating: item.officialRating,
                  studios: item.studios,
                  actors: item.actors,
                  accessToken: item.accessToken,
                );
                Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
                    MediaItemDetailPage(client: widget.client, item: localItem)));
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
      page = MovieFilterPage(client: widget.client, libraryId: library.id, libraryName: library.name);
    } else if (library.type == MediaLibraryType.music) {
      page = MusicLibraryPage(client: widget.client, libraryId: library.id, libraryName: library.name);
    } else {
      page = MediaItemsPage(client: widget.client, library: library);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
