import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'music_library_page.dart';

/// 专辑详情页
///
/// 显示专辑信息 + 歌曲列表，点击歌曲直接播放
class AlbumDetailPage extends StatefulWidget {
  final JellyfinClient client;
  final MusicAlbum album;

  const AlbumDetailPage({
    super.key,
    required this.client,
    required this.album,
  });

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  late Future<MusicAlbum> _albumFuture;
  late Future<MusicSongListResult> _songsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _albumFuture = widget.client.music.getAlbumDetail(widget.album.id);
      _songsFuture = widget.client.music.getAlbumSongs(widget.album.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.album.name,
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                ),
              ),
              background: _buildHeader(),
            ),
            actions: [
              // 播放全部按钮
              IconButton(
                icon: const Icon(Icons.play_circle_filled),
                onPressed: () => _playAll(),
                tooltip: '播放全部',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
              ),
            ],
          ),

          // 专辑信息
          SliverToBoxAdapter(
            child: FutureBuilder<MusicAlbum>(
              future: _albumFuture,
              builder: (context, snapshot) {
                final album = snapshot.data ?? widget.album;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题和艺术家
                      Text(
                        album.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        album.artistText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 12),

                      // 信息行
                      Wrap(
                        spacing: 8,
                        children: [
                          if (album.productionYear != null)
                            Chip(label: Text('${album.productionYear}'), visualDensity: VisualDensity.compact),
                          if (album.songCount != null)
                            Chip(
                              label: Text('${album.songCount} 首'),
                              avatar: const Icon(Icons.music_note, size: 14),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (album.genres != null)
                            ...album.genres!.map(
                              (g) => Chip(label: Text(g), visualDensity: VisualDensity.compact),
                            ),
                        ],
                      ),

                      // 简介
                      if (album.overview != null && album.overview!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(album.overview!, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
                      ],

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // 歌曲列表标题
                      Row(
                        children: [
                          Text('歌曲', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: () => _playAll(),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('播放全部'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),

          // 歌曲列表
          FutureBuilder<MusicSongListResult>(
            future: _songsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('加载失败: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  ),
                );
              }

              final songs = snapshot.data?.songs ?? [];
              if (songs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('暂无歌曲')),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = songs[index];
                    return ListTile(
                      leading: SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            '${song.trackNumber ?? index + 1}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: song.artistText != '未知艺术家'
                          ? Text(song.artistText, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                          : null,
                      trailing: Text(song.durationText,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AudioPlayerPage(
                              client: widget.client,
                              song: song,
                              playlist: songs,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount: songs.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.album.hasCoverImage)
          Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.album.getCoverImageUrl(fillWidth: 500, fillHeight: 500)!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.tertiaryContainer),
              ),
              // 毛玻璃模糊效果 - 用半透明遮罩代替
              Container(color: Colors.black.withValues(alpha: 0.5)),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.album.getCoverImageUrl(fillWidth: 300, fillHeight: 300)!,
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 180,
                      height: 180,
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      child: const Icon(Icons.album, size: 60, color: Colors.white38),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.tertiary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
              ),
            ),
            child: const Center(child: Icon(Icons.album, size: 80, color: Colors.white38)),
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

  void _playAll() async {
    final songsResult = await _songsFuture;
    if (songsResult.songs.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioPlayerPage(
          client: widget.client,
          song: songsResult.songs.first,
          playlist: songsResult.songs,
        ),
      ),
    );
  }
}
