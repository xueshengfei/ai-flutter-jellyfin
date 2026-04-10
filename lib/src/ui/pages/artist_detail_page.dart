import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 艺术家详情页
///
/// 移动端布局：顶部艺术家头像+信息 → 专辑网格
/// 参考 NetEase Cloud Music 风格
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
  MusicArtist? _loadedArtist;

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
          // 顶部艺术家信息区
          SliverToBoxAdapter(
            child: _buildArtistHeader(context),
          ),

          // 专辑列表标题
          SliverToBoxAdapter(
            child: FutureBuilder<MusicAlbumListResult>(
              future: _albumsFuture,
              builder: (context, snapshot) {
                final count = snapshot.data?.albums.length;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        '专辑',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // 专辑网格
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
                    child: Text('加载失败: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)),
                  ),
                );
              }

              final albums = snapshot.data?.albums ?? [];
              if (albums.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('暂无专辑'),
                  )),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
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

          // 底部留白给 MiniPlayer
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  /// 艺术家头部信息区
  Widget _buildArtistHeader(BuildContext context) {
    return FutureBuilder<MusicArtist>(
      future: _artistFuture,
      builder: (context, snapshot) {
        final artist = snapshot.data ?? _loadedArtist ?? widget.artist;

        return Container(
          padding: const EdgeInsets.only(top: 48, left: 20, right: 20, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像
              _buildAvatar(artist),
              const SizedBox(width: 20),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 艺术家名
                    Text(
                      artist.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 统计 chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (artist.albumCount != null)
                          _infoChip(Icons.album, '${artist.albumCount} 张专辑'),
                        if (artist.songCount != null)
                          _infoChip(Icons.music_note, '${artist.songCount} 首歌曲'),
                      ],
                    ),
                    // 类型标签
                    if (artist.genres != null && artist.genres!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: artist.genres!.map((g) => Chip(
                              label: Text(g, style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                            )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(MusicArtist artist) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 120,
        height: 120,
        child: artist.hasImage
            ? Image.network(
                artist.getPrimaryImageUrl(
                    fillWidth: 240, fillHeight: 240)!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarPlaceholder(),
              )
            : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.tertiary,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, size: 48, color: Colors.white38),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

/// 专辑卡片 - 正方形封面 + 标题 + 艺术家
class _AlbumCard extends StatelessWidget {
  final MusicAlbum album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 正方形封面
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: album.hasCoverImage
                  ? Image.network(
                      album.getCoverImageUrl(
                          fillWidth: 200, fillHeight: 200)!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
          ),
          const SizedBox(height: 6),
          // 专辑名
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          // 艺术家
          Text(
            album.artistText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
          child: Icon(Icons.album, size: 36, color: Colors.white.withValues(alpha: 0.3))),
    );
  }
}
