import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jellyfin_music/src/models/music_models.dart';

/// 专辑详情页（解耦版）
///
/// 通过回调函数注入数据获取和导航操作，不依赖 JellyfinClient。
class AlbumDetailPage extends StatefulWidget {
  final MusicAlbum album;
  final AlbumDetailFetcher fetchAlbumDetail;
  final AlbumSongsFetcher fetchAlbumSongs;
  final OnPlaySong? onPlaySong;

  const AlbumDetailPage({
    super.key,
    required this.album,
    required this.fetchAlbumDetail,
    required this.fetchAlbumSongs,
    this.onPlaySong,
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
      _albumFuture = widget.fetchAlbumDetail(widget.album.id);
      _songsFuture = widget.fetchAlbumSongs(widget.album.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildAlbumHeader(context)),
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
                    child: Text('加载失败: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)),
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
                    return _SongRow(
                      song: song,
                      index: index,
                      onTap: () {
                        widget.onPlaySong?.call(context, song, songs, index);
                      },
                    );
                  },
                  childCount: songs.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildAlbumHeader(BuildContext context) {
    return FutureBuilder<MusicAlbum>(
      future: _albumFuture,
      builder: (context, snapshot) {
        final album = snapshot.data ?? widget.album;
        return Padding(
          padding: const EdgeInsets.only(top: 48, left: 20, right: 20, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCover(album),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(album.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(album.artistText,
                        style: TextStyle(fontSize: 14,
                            color: Theme.of(context).colorScheme.primary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 4,
                      children: [
                        if (album.productionYear != null) _infoChip('${album.productionYear}'),
                        if (album.songCount != null) _infoChip('${album.songCount} 首'),
                        if (album.genres != null)
                          ...album.genres!.map((g) => _infoChip(g)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _playAll(),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('播放全部'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCover(MusicAlbum album) {
    return Hero(
      tag: 'album_${album.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 130, height: 130,
          child: album.hasCoverImage
              ? CachedNetworkImage(
                  imageUrl: album.getCoverImageUrl(fillWidth: 260, fillHeight: 260)!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _coverPlaceholder(),
                  errorWidget: (_, __, ___) => _coverPlaceholder(),
                )
              : _coverPlaceholder(),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.surfaceContainerHigh,
        ]),
      ),
      child: const Center(child: Icon(Icons.album, size: 48, color: Colors.white38)),
    );
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
    );
  }

  void _playAll() async {
    final songsResult = await _songsFuture;
    if (songsResult.songs.isEmpty) return;
    widget.onPlaySong?.call(context, songsResult.songs.first, songsResult.songs, 0);
  }
}

/// 歌曲行
class _SongRow extends StatelessWidget {
  final MusicSong song;
  final int index;
  final VoidCallback onTap;

  const _SongRow({required this.song, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Center(
                child: Text('${song.trackNumber ?? index + 1}',
                    style: TextStyle(color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  if (song.artistText != '未知艺术家')
                    Text(song.artistText, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            if (song.durationText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(song.durationText,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ),
          ],
        ),
      ),
    );
  }
}
