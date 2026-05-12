/// 音乐路由页面
///
/// 音乐库入口 → 专辑列表 → 专辑详情（歌曲列表）
/// 艺术家详情（专辑列表）
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_music/jellyfin_music.dart' as music;
import 'package:jellyfin_music/jellyfin_music_pages.dart';

import '../../data/jellyfin_gateway.dart';

// ──────────────────────────── 音乐库列表页（专辑网格） ────────────────────────────

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

class _MusicLibraryRoutePageState extends State<MusicLibraryRoutePage> {
  late Future<music.MusicAlbumListResult> _albumsFuture;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  void _loadAlbums() {
    setState(() {
      _albumsFuture = widget.gateway.fetchAlbums(parentId: widget.library.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.library.name)),
      body: FutureBuilder<music.MusicAlbumListResult>(
        future: _albumsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _loadAlbums, child: const Text('重试')),
                ],
              ),
            );
          }
          final albums = snapshot.data?.albums ?? [];
          if (albums.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎵', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text('${widget.library.name} 中没有找到专辑',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _loadAlbums(),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.67,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return InkWell(
                  onTap: () => context.push('/music/albums/${album.id}'),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: album.hasCoverImage
                              ? Image.network(
                                  album.getCoverImageUrl(fillWidth: 300, fillHeight: 300)!,
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
              },
            ),
          );
        },
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
