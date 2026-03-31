import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'artist_detail_page.dart';
import 'album_detail_page.dart';

/// 音乐媒体库页面
///
/// 三级结构：Artist → Album → Song
/// Tab 页：艺术家 | 专辑 | 歌曲
class MusicLibraryPage extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  final String libraryName;

  const MusicLibraryPage({
    super.key,
    required this.client,
    required this.libraryId,
    required this.libraryName,
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
            Tab(text: '艺术家', icon: Icon(Icons.person)),
            Tab(text: '专辑', icon: Icon(Icons.album)),
            Tab(text: '歌曲', icon: Icon(Icons.music_note)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ArtistsTab(client: widget.client, libraryId: widget.libraryId),
          _AlbumsTab(client: widget.client, libraryId: widget.libraryId),
          _SongsTab(client: widget.client, libraryId: widget.libraryId),
        ],
      ),
    );
  }
}

// ==================== 艺术家 Tab ====================

class _ArtistsTab extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  const _ArtistsTab({required this.client, required this.libraryId});
  @override
  State<_ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends State<_ArtistsTab> {
  List<MusicArtist> _artists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.music.getAlbumArtists(parentId: widget.libraryId, limit: 100);
      if (mounted) setState(() { _artists = result.artists; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, _load);
    if (_artists.isEmpty) return const Center(child: Text('暂无艺术家'));
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.75, crossAxisSpacing: 12, mainAxisSpacing: 12,
        ),
        itemCount: _artists.length,
        itemBuilder: (context, index) {
          final artist = _artists[index];
          return _AvatarCard(
            imageUrl: artist.getPrimaryImageUrl(fillWidth: 200, fillHeight: 200),
            hasImage: artist.hasImage,
            title: artist.name,
            subtitle: artist.albumCount != null ? '${artist.albumCount} 张专辑' : null,
            placeholderIcon: Icons.person,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ArtistDetailPage(client: widget.client, artist: artist),
            )),
          );
        },
      ),
    );
  }
}

// ==================== 专辑 Tab ====================

class _AlbumsTab extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  const _AlbumsTab({required this.client, required this.libraryId});
  @override
  State<_AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<_AlbumsTab> {
  List<MusicAlbum> _albums = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.music.getAlbums(parentId: widget.libraryId, limit: 100);
      if (mounted) setState(() { _albums = result.albums; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, _load);
    if (_albums.isEmpty) return const Center(child: Text('暂无专辑'));
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 12, mainAxisSpacing: 12,
        ),
        itemCount: _albums.length,
        itemBuilder: (context, index) {
          final album = _albums[index];
          return _AvatarCard(
            imageUrl: album.getCoverImageUrl(fillWidth: 200, fillHeight: 200),
            hasImage: album.hasCoverImage,
            title: album.name,
            subtitle: album.artistText,
            placeholderIcon: Icons.album,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AlbumDetailPage(client: widget.client, album: album),
            )),
          );
        },
      ),
    );
  }
}

// ==================== 歌曲 Tab ====================

class _SongsTab extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  const _SongsTab({required this.client, required this.libraryId});
  @override
  State<_SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<_SongsTab> {
  List<MusicSong> _songs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.music.getLatestSongs(parentId: widget.libraryId, limit: 100);
      if (mounted) setState(() { _songs = result.songs; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, _load);
    if (_songs.isEmpty) return const Center(child: Text('暂无歌曲'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _songs.length,
        itemBuilder: (context, index) {
          final song = _songs[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: song.trackNumber != null
                  ? Text('${song.trackNumber}', style: const TextStyle(fontSize: 12))
                  : const Icon(Icons.music_note, size: 20),
            ),
            title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${song.artistText}${song.albumName != null ? ' · ${song.albumName}' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Text(song.durationText, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AudioPlayerPage(
                client: widget.client, song: song, playlist: _songs, initialIndex: index,
              ),
            )),
          );
        },
      ),
    );
  }
}

// ==================== 音频播放页 ====================

class AudioPlayerPage extends StatefulWidget {
  final JellyfinClient client;
  final MusicSong song;
  final List<MusicSong> playlist;
  final int initialIndex;

  const AudioPlayerPage({
    super.key,
    required this.client,
    required this.song,
    required this.playlist,
    this.initialIndex = 0,
  });

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  late int _currentIndex;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  String? _error;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  MusicSong get _currentSong => widget.playlist[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _setupListeners();
    _playSong();
  }

  void _setupListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        _isLoading = state == PlayerState.playing && _position == Duration.zero;
      });
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _playNext();
    });
  }

  Future<void> _playSong() async {
    setState(() { _isLoading = true; _error = null; _position = Duration.zero; _duration = Duration.zero; });
    try {
      final url = widget.client.music.getUniversalAudioStreamUrl(
        _currentSong.id,
        container: const ['mp3', 'aac'],
      );
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      if (mounted) setState(() { _error = '播放失败: $e'; _isLoading = false; });
    }
  }

  Future<void> _playNext() async {
    if (_currentIndex < widget.playlist.length - 1) {
      setState(() => _currentIndex++);
      await _playSong();
    }
  }

  Future<void> _playPrevious() async {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      await _playSong();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = _currentSong;
    return Scaffold(
      appBar: AppBar(title: const Text('正在播放')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 封面
              Container(
                width: 240, height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                clipBehavior: Clip.antiAlias,
                child: song.getAlbumCoverUrl(fillWidth: 480, fillHeight: 480) != null
                    ? Image.network(song.getAlbumCoverUrl(fillWidth: 480, fillHeight: 480)!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
              const SizedBox(height: 32),

              // 歌曲信息
              Text(song.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text('${song.artistText}${song.albumName != null ? ' · ${song.albumName}' : ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 32),

              // 进度条
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  Slider(
                    value: _duration.inMilliseconds > 0
                        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0, 1)
                        : 0,
                    onChanged: (v) => _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * v).round())),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(_position), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    Text(_fmt(_duration), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),

              // 控制
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(onPressed: _currentIndex > 0 ? _playPrevious : null, icon: const Icon(Icons.skip_previous, size: 40)),
                const SizedBox(width: 24),
                _isLoading
                    ? const SizedBox(width: 56, height: 56, child: CircularProgressIndicator())
                    : IconButton.filled(
                        onPressed: () async { _isPlaying ? await _audioPlayer.pause() : await _audioPlayer.resume(); },
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
                        style: IconButton.styleFrom(minimumSize: const Size(64, 64))),
                const SizedBox(width: 24),
                IconButton(onPressed: _currentIndex < widget.playlist.length - 1 ? _playNext : null, icon: const Icon(Icons.skip_next, size: 40)),
              ]),
              const SizedBox(height: 16),

              if (_error != null)
                Padding(padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),

              Text('${_currentIndex + 1} / ${widget.playlist.length}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: const Center(child: Icon(Icons.music_note, size: 80, color: Colors.white54)),
  );

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

// ==================== 通用组件 ====================

class _AvatarCard extends StatelessWidget {
  final String? imageUrl;
  final bool hasImage;
  final String title;
  final String? subtitle;
  final IconData placeholderIcon;
  final VoidCallback onTap;

  const _AvatarCard({
    required this.imageUrl,
    required this.hasImage,
    required this.title,
    this.subtitle,
    required this.placeholderIcon,
    required this.onTap,
  });

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
              child: hasImage && imageUrl != null
                  ? Image.network(imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ph(context))
                  : _ph(context),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (subtitle != null)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ph(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Center(child: Icon(placeholderIcon, size: 48, color: Colors.white54)),
  );
}

Widget _buildError(String error, VoidCallback onRetry) => Center(
  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 48, color: Colors.red),
    const SizedBox(height: 16),
    Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
    const SizedBox(height: 16),
    FilledButton(onPressed: onRetry, child: const Text('重试')),
  ]),
);
