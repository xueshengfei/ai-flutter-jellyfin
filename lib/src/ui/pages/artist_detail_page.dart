import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 艺术家详情页
///
/// 显示艺术家信息 + 专辑列表
class ArtistDetailPage extends StatefulWidget {
  final JellyfinClient client;
  final MusicArtist artist;

  const ArtistDetailPage({
    super.key,
    required this.client,
    required this.artist,
  });

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  late Future<MusicArtist> _artistFuture;
  late Future<MusicAlbumListResult> _albumsFuture;
  MusicArtist? _loadedArtist; // API 返回的完整艺术家信息（含图片）

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _artistFuture = widget.client.music.getArtistDetail(widget.artist.id);
    _albumsFuture = widget.client.music.getArtistAlbums(widget.artist.id);
    _artistFuture.then((artist) {
      if (mounted) setState(() => _loadedArtist = artist);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar with artist info
          SliverAppBar(
            expandedHeight: 250,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.artist.name,
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                ),
              ),
              background: _buildHeader(),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: FutureBuilder<MusicArtist>(
              future: _artistFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final artist = snapshot.data ?? _loadedArtist ?? widget.artist;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 基本信息
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (artist.albumCount != null)
                            Chip(
                              label: Text('${artist.albumCount} 张专辑'),
                              avatar: const Icon(Icons.album, size: 16),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (artist.songCount != null)
                            Chip(
                              label: Text('${artist.songCount} 首歌曲'),
                              avatar: const Icon(Icons.music_note, size: 16),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (artist.genres != null)
                            ...artist.genres!.map(
                              (g) => Chip(label: Text(g), visualDensity: VisualDensity.compact),
                            ),
                        ],
                      ),
                    ),

                    // 简介
                    if (artist.overview != null && artist.overview!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          artist.overview!,
                          style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // 专辑列表标题
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '专辑',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 专辑列表
          FutureBuilder<MusicAlbumListResult>(
            future: _albumsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Text('加载失败: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  ),
                );
              }

              final albums = snapshot.data?.albums ?? [];
              if (albums.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('暂无专辑'),
                  )),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final album = albums[index];
                      return _AlbumCard(
                        album: album,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailPage(
                                client: widget.client,
                                album: album,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: albums.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final artist = _loadedArtist ?? widget.artist;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (artist.hasImage)
          Image.network(
            artist.getPrimaryImageUrl(fillWidth: 500, fillHeight: 300)!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.primaryContainer),
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.tertiary,
                ],
              ),
            ),
            child: const Center(
              child: Icon(Icons.person, size: 80, color: Colors.white38),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final MusicAlbum album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: album.hasCoverImage
                  ? Image.network(
                      album.getCoverImageUrl(fillWidth: 200, fillHeight: 200)!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${album.artistText}${album.productionYear != null ? ' · ${album.productionYear}' : ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: const Center(child: Icon(Icons.album, size: 40, color: Colors.white38)),
    );
  }
}
