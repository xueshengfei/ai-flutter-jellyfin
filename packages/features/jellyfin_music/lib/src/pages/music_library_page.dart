import 'package:flutter/material.dart';
import 'package:jellyfin_music/src/models/music_models.dart';
import 'package:jellyfin_music/src/services/audio_playback_port.dart';

/// 音乐库页面（三 Tab：专辑 / 艺术家 / 歌曲）
///
/// 不依赖 go_router、JellyfinGateway、just_audio。
/// 通过回调函数注入数据获取和导航操作。
class MusicLibraryPage extends StatefulWidget {
  final String libraryName;
  final String libraryId;

  // 数据注入
  final AlbumsFetcher fetchAlbums;
  final ArtistsFetcher fetchArtists;
  final SongsFetcher fetchSongs;

  // 导航回调
  final OnOpenAlbum? onOpenAlbum;
  final OnOpenArtist? onOpenArtist;
  final OnPlayTracks? onPlayTracks;

  const MusicLibraryPage({
    super.key,
    required this.libraryName,
    required this.libraryId,
    required this.fetchAlbums,
    required this.fetchArtists,
    required this.fetchSongs,
    this.onOpenAlbum,
    this.onOpenArtist,
    this.onPlayTracks,
  });

  @override
  State<MusicLibraryPage> createState() => _MusicLibraryPageState();
}

class _MusicLibraryPageState extends State<MusicLibraryPage>
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
        title: Text(widget.libraryName),
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
          _AlbumsTab(
            fetchAlbums: widget.fetchAlbums,
            libraryId: widget.libraryId,
            onOpenAlbum: widget.onOpenAlbum,
          ),
          _ArtistsTab(
            fetchArtists: widget.fetchArtists,
            libraryId: widget.libraryId,
            onOpenArtist: widget.onOpenArtist,
          ),
          _SongsTab(
            fetchSongs: widget.fetchSongs,
            libraryId: widget.libraryId,
            onPlayTracks: widget.onPlayTracks,
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
  final OnOpenAlbum? onOpenAlbum;

  const _AlbumsTab({
    required this.fetchAlbums,
    required this.libraryId,
    this.onOpenAlbum,
  });

  @override
  State<_AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<_AlbumsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<MusicAlbumListResult> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = widget.fetchAlbums(parentId: widget.libraryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<MusicAlbumListResult>(
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
              onTap: () =>
                  widget.onOpenAlbum?.call(context, albums[index]),
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
  final ArtistsFetcher fetchArtists;
  final String libraryId;
  final OnOpenArtist? onOpenArtist;

  const _ArtistsTab({
    required this.fetchArtists,
    required this.libraryId,
    this.onOpenArtist,
  });

  @override
  State<_ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends State<_ArtistsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<MusicArtistListResult> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = widget.fetchArtists(parentId: widget.libraryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<MusicArtistListResult>(
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
                onTap: () =>
                    widget.onOpenArtist?.call(context, artist),
                child: Column(
                  children: [
                    Expanded(
                      child: CircleAvatar(
                        radius: double.infinity,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        backgroundImage: artist.hasImage
                            ? NetworkImage(artist.getPrimaryImageUrl(
                                fillWidth: 300, fillHeight: 300)!)
                            : null,
                        child: !artist.hasImage
                            ? Icon(Icons.person,
                                size: 40, color: Colors.grey.shade400)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(artist.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                    if (artist.albumCount != null)
                      Text('${artist.albumCount} 张专辑',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
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
  late Future<MusicSongListResult> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = widget.fetchSongs(parentId: widget.libraryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<MusicSongListResult>(
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
                onTap: () {
                  // 在页面内部将 MusicSong 转为 AudioTrack，
                  // 通过 onPlayTracks 回调抛给 App 层
                  final tracks = songs
                      .map((s) => AudioTrack(
                            id: s.id,
                            name: s.name,
                            streamUrl: s.getStreamUrl(),
                            coverUrl: s.getAlbumCoverUrl(
                                fillWidth: 480, fillHeight: 480),
                            artistText: s.artistText,
                            duration: s.runTimeSeconds != null
                                ? Duration(seconds: s.runTimeSeconds!)
                                : null,
                            albumName: s.albumName,
                            trackNumber: s.trackNumber,
                            isFavorite: s.isFavorite,
                          ))
                      .toList();
                  widget.onPlayTracks?.call(context, tracks, index);
                },
                leading: song.albumId != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: song.getAlbumCoverUrl() != null
                              ? Image.network(song.getAlbumCoverUrl()!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.music_note))
                              : const Icon(Icons.music_note),
                        ),
                      )
                    : const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.music_note),
                      ),
                title: Text(song.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${song.artistText}${song.albumName != null ? " · ${song.albumName}" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
  final MusicAlbum album;
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
                        child: Icon(Icons.album,
                            size: 40, color: Colors.grey.shade400),
                      ),
                    )
                  : Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Center(
                        child: Icon(Icons.album,
                            size: 40, color: Colors.grey.shade400),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(album.artistText,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
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
          Text(error,
              textAlign: TextAlign.center,
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
