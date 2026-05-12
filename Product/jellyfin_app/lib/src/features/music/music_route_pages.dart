/// 音乐路由页面
///
/// 音乐库入口 → 三 Tab（专辑 / 艺术家 / 歌曲）
/// 专辑详情（歌曲列表）/ 艺术家详情（专辑列表）
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_music/jellyfin_music.dart' as music;
import 'package:jellyfin_music/jellyfin_music_pages.dart';

import '../../data/jellyfin_gateway.dart';

// ──────────────────────────── 音乐库列表页（三 Tab） ────────────────────────────

class MusicLibraryRoutePage extends StatefulWidget {
  final JellyfinGateway gateway;
  final models.MediaLibrary library;

  const MusicLibraryRoutePage({
    super.key,
    required this.gateway,
    required this.library,
  });

  @override
  State<MusicLibraryRoutePage> createState() => _MusicLibraryRoutePageState();
}

class _MusicLibraryRoutePageState extends State<MusicLibraryRoutePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.library.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '专辑', icon: Icon(Icons.album)),
            Tab(text: '艺术家', icon: Icon(Icons.person)),
            Tab(text: '歌曲', icon: Icon(Icons.music_note)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AlbumsTab(gateway: widget.gateway, libraryId: widget.library.id),
          _ArtistsTab(gateway: widget.gateway, libraryId: widget.library.id),
          _SongsTab(gateway: widget.gateway, libraryId: widget.library.id),
        ],
      ),
    );
  }
}

// ─── 专辑 Tab ───

class _AlbumsTab extends StatefulWidget {
  final JellyfinGateway gateway;
  final String libraryId;

  const _AlbumsTab({required this.gateway, required this.libraryId});

  @override
  State<_AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<_AlbumsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<music.MusicAlbumListResult> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = widget.gateway.fetchAlbums(parentId: widget.libraryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<music.MusicAlbumListResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorBody(error: '${snapshot.error}', onRetry: _load);
        }
        final albums = snapshot.data?.albums ?? [];
        if (albums.isEmpty) {
          return const _EmptyBody(icon: '💿', message: '没有找到专辑');
        }
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.67,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) => _AlbumCard(
              album: albums[index],
              onTap: () => context.push('/music/albums/${albums[index].id}'),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ─── 艺术家 Tab ───

class _ArtistsTab extends StatefulWidget {
  final JellyfinGateway gateway;
  final String libraryId;

  const _ArtistsTab({required this.gateway, required this.libraryId});

  @override
  State<_ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends State<_ArtistsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<music.MusicArtistListResult> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = widget.gateway.fetchArtists(parentId: widget.libraryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<music.MusicArtistListResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorBody(error: '${snapshot.error}', onRetry: _load);
        }
        final artists = snapshot.data?.artists ?? [];
        if (artists.isEmpty) {
          return const _EmptyBody(icon: '🎤', message: '没有找到艺术家');
        }
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return InkWell(
                onTap: () => context.push('/music/artists/${artist.id}'),
                child: Column(
                  children: [
                    Expanded(
                      child: CircleAvatar(
                        radius: double.infinity,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                        backgroundImage: artist.hasImage
                            ? NetworkImage(
                                artist.getPrimaryImageUrl(
                                    fillWidth: 300, fillHeight: 300)!)
                            : null,
                        child: !artist.hasImage
                            ? Icon(Icons.person, size: 40,
                                color: Colors.grey.shade400)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(artist.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                    if (artist.albumCount != null)
                      Text('${artist.albumCount} 张专辑',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            },
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
  final JellyfinGateway gateway;
  final String libraryId;

  const _SongsTab({required this.gateway, required this.libraryId});

  @override
  State<_SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<_SongsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<music.MusicSongListResult> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = widget.gateway.fetchSongs(parentId: widget.libraryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<music.MusicSongListResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorBody(error: '${snapshot.error}', onRetry: _load);
        }
        final songs = snapshot.data?.songs ?? [];
        if (songs.isEmpty) {
          return const _EmptyBody(icon: '🎵', message: '没有找到歌曲');
        }
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                leading: song.albumId != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 48, height: 48,
                          child: song.getAlbumCoverUrl() != null
                              ? Image.network(song.getAlbumCoverUrl()!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.music_note))
                              : const Icon(Icons.music_note),
                        ),
                      )
                    : const SizedBox(
                        width: 48, height: 48,
                        child: Icon(Icons.music_note)),
                title: Text(song.name, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${song.artistText}${song.albumName != null ? " · ${song.albumName}" : ""}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                trailing: song.durationText.isNotEmpty
                    ? Text(song.durationText,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400))
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ─── 共享组件 ───

class _AlbumCard extends StatelessWidget {
  final music.MusicAlbum album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

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
                  ? Image.network(
                      album.getCoverImageUrl(
                          fillWidth: 300, fillHeight: 300)!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.album, size: 40,
                            color: Colors.grey.shade400),
                      ),
                    )
                  : Container(
                      color: Theme.of(context)
                          .colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(Icons.album, size: 40,
                            color: Colors.grey.shade400),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(album.artistText,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
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
          Text(error, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
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

// ──────────────────────────── 专辑详情页 ────────────────────────────

class AlbumDetailRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String albumId;

  const AlbumDetailRoutePage({
    super.key,
    required this.gateway,
    required this.albumId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: gateway.getAlbumDetail(albumId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('错误')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          );
        }

        final album = snapshot.data!;
        return AlbumDetailPage(
          album: album,
          fetchAlbumDetail: gateway.getAlbumDetail,
          fetchAlbumSongs: gateway.getAlbumSongs,
          onPlaySong: (context, song, playlist, initialIndex) {
            // TODO: 接入音乐播放
          },
        );
      },
    );
  }
}

// ──────────────────────────── 艺术家详情页 ────────────────────────────

class ArtistDetailRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String artistId;

  const ArtistDetailRoutePage({
    super.key,
    required this.gateway,
    required this.artistId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: gateway.getArtistDetail(artistId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('错误')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          );
        }

        final artist = snapshot.data!;
        return ArtistDetailPage(
          artist: artist,
          fetchArtistDetail: gateway.getArtistDetail,
          fetchArtistAlbums: gateway.getArtistAlbums,
          onNavigateToAlbum: (context, album) {
            context.push('/music/albums/${album.id}');
          },
        );
      },
    );
  }
}
