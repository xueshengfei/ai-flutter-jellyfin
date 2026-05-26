import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jellyfin_music/src/models/music_models.dart';
import 'package:jellyfin_music/src/services/audio_playback_port.dart';

/// 音乐搜索页面
///
/// 不依赖 JellyfinClient、go_router。
/// 通过回调函数注入搜索、导航和播放操作。
class MusicSearchPage extends StatefulWidget {
  final String? libraryId;
  final MusicSearchFetcher search;
  final OnOpenAlbum? onOpenAlbum;
  final OnOpenArtist? onOpenArtist;
  final OnPlayTracks? onPlayTracks;

  const MusicSearchPage({
    super.key,
    this.libraryId,
    required this.search,
    this.onOpenAlbum,
    this.onOpenArtist,
    this.onPlayTracks,
  });

  @override
  State<MusicSearchPage> createState() => _MusicSearchPageState();
}

class _MusicSearchPageState extends State<MusicSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  bool _isSearching = false;
  List<MusicArtist> _artists = [];
  List<MusicAlbum> _albums = [];
  List<MusicSong> _songs = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _hasSearched = false;
        _artists = [];
        _albums = [];
        _songs = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query.trim());
    });
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final result = await widget.search(
        searchTerm: query,
        parentId: widget.libraryId,
      );
      if (mounted) {
        setState(() {
          _artists = result.artists;
          _albums = result.albums;
          _songs = result.songs;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _hasSearched = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: const InputDecoration(
            hintText: '搜索歌曲、艺术家、专辑...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (query) {
            _debounce?.cancel();
            if (query.trim().isNotEmpty) _search(query.trim());
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _hasSearched = false;
                  _artists = [];
                  _albums = [];
                  _songs = [];
                });
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '输入关键词搜索音乐',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final hasResults =
        _artists.isNotEmpty || _albums.isNotEmpty || _songs.isNotEmpty;
    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '未找到相关结果',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // 艺术家
        if (_artists.isNotEmpty) ...[
          _SectionHeader(title: '艺术家 (${_artists.length})'),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final artist = _artists[index];
                return _ArtistChip(
                  artist: artist,
                  onTap: () => widget.onOpenArtist?.call(context, artist),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 专辑
        if (_albums.isNotEmpty) ...[
          _SectionHeader(title: '专辑 (${_albums.length})'),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _albums.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final album = _albums[index];
                return _AlbumChip(
                  album: album,
                  onTap: () => widget.onOpenAlbum?.call(context, album),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 歌曲
        if (_songs.isNotEmpty) ...[
          _SectionHeader(title: '歌曲 (${_songs.length})'),
          ...List.generate(_songs.length, (index) {
            final song = _songs[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                child: song.trackNumber != null
                    ? Text(
                        '${song.trackNumber}',
                        style: const TextStyle(fontSize: 12),
                      )
                    : const Icon(Icons.music_note, size: 20),
              ),
              title: Text(
                song.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${song.artistText}${song.albumName != null ? ' · ${song.albumName}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: song.durationText.isNotEmpty
                  ? Text(
                      song.durationText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    )
                  : null,
              onTap: () {
                if (widget.onPlayTracks == null) return;
                final tracks = _songs
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
                widget.onPlayTracks!.call(context, tracks, index);
              },
            );
          }),
        ],
      ],
    );
  }
}

// ==================== 搜索结果组件 ====================

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ArtistChip extends StatelessWidget {
  final MusicArtist artist;
  final VoidCallback onTap;

  const _ArtistChip({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              backgroundImage:
                  artist.hasImage && artist.getPrimaryImageUrl() != null
                  ? NetworkImage(artist.getPrimaryImageUrl()!)
                  : null,
              child: !artist.hasImage
                  ? const Icon(Icons.person, size: 36, color: Colors.white54)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumChip extends StatelessWidget {
  final MusicAlbum album;
  final VoidCallback onTap;

  const _AlbumChip({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1,
                child:
                    album.hasCoverImage &&
                        album.getCoverImageUrl(
                              fillWidth: 200,
                              fillHeight: 200,
                            ) !=
                            null
                    ? Image.network(
                        album.getCoverImageUrl(
                          fillWidth: 200,
                          fillHeight: 200,
                        )!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(context),
                      )
                    : _placeholder(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              album.artistText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(
      child: Icon(Icons.album, size: 36, color: Colors.white54),
    ),
  );
}
