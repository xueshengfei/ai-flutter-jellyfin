import 'package:flutter/material.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:jellyfin_music/src/models/music_models.dart';
import 'package:jellyfin_music/src/services/audio_playback_port.dart';

/// 音乐库页面（三 Tab：专辑 / 艺术家 / 歌曲）
///
/// 不依赖 go_router、JellyfinGateway、just_audio。
/// 通过回调函数注入数据获取，导航通过 [AppNavigator] 完成。
class MusicLibraryPage extends StatefulWidget {
  final String libraryName;
  final String libraryId;

  // 数据注入
  final AlbumsFetcher fetchAlbums;
  final ArtistsFetcher fetchArtists;
  final SongsFetcher fetchSongs;

  // 播放回调（数据操作，保留）
  final OnPlayTracks? onPlayTracks;

  /// 是否启用搜索按钮
  final bool enableSearch;

  /// 是否启用个人中心按钮
  final bool enablePersonal;

  const MusicLibraryPage({
    super.key,
    required this.libraryName,
    required this.libraryId,
    required this.fetchAlbums,
    required this.fetchArtists,
    required this.fetchSongs,
    this.onPlayTracks,
    this.enableSearch = false,
    this.enablePersonal = false,
  });

  @override
  State<MusicLibraryPage> createState() => _MusicLibraryPageState();
}

class _MusicLibraryPageState extends State<MusicLibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 同步 TabController 状态到 GlassTabBar 的 selectedIndex
    // 滑动 TabBarView 时让 GlassTabBar 的指示器跟随
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.index != _currentIndex) {
      setState(() => _currentIndex = _tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.libraryName),
        actions: [
          if (widget.enableSearch)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                final navigator = ServiceRegistry.get<AppNavigator>(context);
                navigator.pushIntent(
                  JellyfinRouteIntents.musicSearch(
                    libraryId: widget.libraryId,
                  ),
                );
              },
              tooltip: '搜索',
            ),
          if (widget.enablePersonal)
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                final navigator = ServiceRegistry.get<AppNavigator>(context);
                navigator.pushIntent(JellyfinRouteIntents.profile());
              },
              tooltip: '个人中心',
            ),
        ],
      ),
      body: Column(
        children: [
          // Liquid Glass 风格浮动 Tab 栏（替代原 Material TabBar）
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GlassTabBar(
              useOwnLayer: true,
              height: 56,
              borderRadius: BorderRadius.circular(28),
              indicatorBorderRadius: BorderRadius.circular(24),
              tabs: const [
                GlassTab(icon: Icon(Icons.album), label: '专辑'),
                GlassTab(icon: Icon(Icons.person), label: '艺术家'),
                GlassTab(icon: Icon(Icons.music_note), label: '歌曲'),
              ],
              selectedIndex: _currentIndex,
              onTabSelected: (index) {
                // 点击 GlassTabBar → 驱动 TabBarView 切换
                _tabController.animateTo(index);
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AlbumsTab(
                  fetchAlbums: widget.fetchAlbums,
                  libraryId: widget.libraryId,
                ),
                _ArtistsTab(
                  fetchArtists: widget.fetchArtists,
                  libraryId: widget.libraryId,
                ),
                _SongsTab(
                  fetchSongs: widget.fetchSongs,
                  libraryId: widget.libraryId,
                  onPlayTracks: widget.onPlayTracks,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 专辑 Tab ───

class _AlbumsTab extends StatefulWidget {
  final AlbumsFetcher fetchAlbums;
  final String libraryId;

  const _AlbumsTab({
    required this.fetchAlbums,
    required this.libraryId,
  });

  @override
  State<_AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<_AlbumsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PaginatedList<MusicAlbum>(
      refreshKey: widget.libraryId,
      pageSize: 100,
      padding: const EdgeInsets.all(16),
      fetcher: ({required startIndex, required limit}) async {
        final result = await widget.fetchAlbums(
          parentId: widget.libraryId,
          startIndex: startIndex,
          limit: limit,
        );
        return PagedResult(
          items: result.albums,
          totalCount: result.totalCount ?? result.albums.length,
        );
      },
      emptyBuilder: (context) =>
          const _EmptyBody(icon: '💿', message: '没有找到专辑'),
      errorBuilder: (context, error, retry) =>
          _ErrorBody(error: error, onRetry: retry),
      contentBuilder: (context, page) {
        return GridView.builder(
          padding: page.padding,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.67,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: page.items.length,
          itemBuilder: (context, index) =>
              page.itemBuilder(context, page.items[index], index),
        );
      },
      itemBuilder: (context, album, index) => _AlbumCard(
        album: album,
        onTap: () {
          final navigator = ServiceRegistry.get<AppNavigator>(context);
          navigator.pushIntent(
            JellyfinRouteIntents.musicAlbum(albumId: album.id),
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ─── 艺术家 Tab ───

class _ArtistsTab extends StatefulWidget {
  final ArtistsFetcher fetchArtists;
  final String libraryId;

  const _ArtistsTab({
    required this.fetchArtists,
    required this.libraryId,
  });

  @override
  State<_ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends State<_ArtistsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PaginatedList<MusicArtist>(
      refreshKey: widget.libraryId,
      pageSize: 100,
      padding: const EdgeInsets.all(16),
      fetcher: ({required startIndex, required limit}) async {
        final result = await widget.fetchArtists(
          parentId: widget.libraryId,
          startIndex: startIndex,
          limit: limit,
        );
        return PagedResult(
          items: result.artists,
          totalCount: result.totalCount ?? result.artists.length,
        );
      },
      emptyBuilder: (context) =>
          const _EmptyBody(icon: '🎤', message: '没有找到艺术家'),
      errorBuilder: (context, error, retry) =>
          _ErrorBody(error: error, onRetry: retry),
      contentBuilder: (context, page) {
        return GridView.builder(
          padding: page.padding,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: page.items.length,
          itemBuilder: (context, index) =>
              page.itemBuilder(context, page.items[index], index),
        );
      },
      itemBuilder: (context, artist, index) {
        return InkWell(
          onTap: () {
            final navigator = ServiceRegistry.get<AppNavigator>(context);
            navigator.pushIntent(
              JellyfinRouteIntents.musicArtist(artistId: artist.id),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: CircleAvatar(
                  radius: double.infinity,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  child: artist.hasImage
                      ? ClipOval(
                          child: JellyfinImage(
                            itemId: artist.id,
                            imageTag: artist.primaryImageTag,
                            fillWidth: 300,
                            fillHeight: 300,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artist.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (artist.albumCount != null)
                Text(
                  '${artist.albumCount} 张专辑',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ─── 歌曲 Tab ───

class _SongsTab extends StatefulWidget {
  final SongsFetcher fetchSongs;
  final String libraryId;
  final OnPlayTracks? onPlayTracks;

  const _SongsTab({
    required this.fetchSongs,
    required this.libraryId,
    this.onPlayTracks,
  });

  @override
  State<_SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<_SongsTab>
    with AutomaticKeepAliveClientMixin {
  /// 当前页歌曲缓存，用于批量播放
  List<MusicSong> _currentSongs = [];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PaginatedList<MusicSong>(
      refreshKey: widget.libraryId,
      pageSize: 100,
      fetcher: ({required startIndex, required limit}) async {
        final result = await widget.fetchSongs(
          parentId: widget.libraryId,
          startIndex: startIndex,
          limit: limit,
        );
        _currentSongs = result.songs;
        return PagedResult(
          items: result.songs,
          totalCount: result.totalCount ?? result.songs.length,
        );
      },
      emptyBuilder: (context) =>
          const _EmptyBody(icon: '🎵', message: '没有找到歌曲'),
      errorBuilder: (context, error, retry) =>
          _ErrorBody(error: error, onRetry: retry),
      itemBuilder: (context, song, index) {
        return ListTile(
          onTap: () {
            // 在页面内部将 MusicSong 转为 AudioTrack，
            // 通过 onPlayTracks 回调抛给 App 层
            final tracks = _currentSongs
                .map(
                  (s) => AudioTrack(
                    id: s.id,
                    name: s.name,
                    streamUrl: s.getStreamUrl(),
                    coverUrl: s.getAlbumCoverUrl(
                      fillWidth: 480,
                      fillHeight: 480,
                    ),
                    artistText: s.artistText,
                    duration: s.runTimeSeconds != null
                        ? Duration(seconds: s.runTimeSeconds!)
                        : null,
                    albumName: s.albumName,
                    trackNumber: s.trackNumber,
                    isFavorite: s.isFavorite,
                    path: s.path,
                  ),
                )
                .toList();
            widget.onPlayTracks?.call(context, tracks, index);
          },
          leading: song.albumId != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: JellyfinImage(
                      itemId: song.albumId!,
                      imageTag: song.albumPrimaryImageTag,
                      fillWidth: 96,
                      fillHeight: 96,
                      fit: BoxFit.cover,
                      errorWidget: const Icon(Icons.music_note),
                    ),
                  ),
                )
              : const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.music_note),
                ),
          title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${song.artistText}${song.albumName != null ? " · ${song.albumName}" : ""}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          trailing: song.durationText.isNotEmpty
              ? Text(
                  song.durationText,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                )
              : null,
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ─── 共享组件 ───

class _AlbumCard extends StatelessWidget {
  final MusicAlbum album;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: album.hasCoverImage
                  ? JellyfinImage(
                      itemId: album.id,
                      imageTag: album.primaryImageTag,
                      fillWidth: 300,
                      fillHeight: 300,
                      fit: BoxFit.cover,
                      errorWidget: Center(
                        child: Icon(
                          Icons.album,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    )
                  : Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.album,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    album.artistText,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorBody({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  final String icon;
  final String message;

  const _EmptyBody({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
