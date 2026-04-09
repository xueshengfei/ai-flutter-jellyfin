import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

// ==================== 音乐媒体库页面 ====================

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
  final ViewModeManager _viewModeManager = ViewModeManager();
  ViewModeConfig _viewModeConfig = const ViewModeConfig();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadViewModeConfig();
  }

  Future<void> _loadViewModeConfig() async {
    final config = await _viewModeManager.getViewModeConfig(widget.libraryId);
    if (mounted) setState(() => _viewModeConfig = config);
  }

  Future<void> _saveViewModeConfig(ViewModeConfig config) async {
    await _viewModeManager.saveViewModeConfig(widget.libraryId, config);
    if (mounted) setState(() => _viewModeConfig = config);
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
        actions: [
          ViewModeSelector(
            libraryId: widget.libraryId,
            onViewModeChanged: _saveViewModeConfig,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MusicSearchPage(
                client: widget.client,
                libraryId: widget.libraryId,
              ),
            )),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '艺术家', icon: Icon(Icons.person)),
            Tab(text: '专辑', icon: Icon(Icons.album)),
            Tab(text: '歌曲', icon: Icon(Icons.music_note)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ArtistsTab(client: widget.client, libraryId: widget.libraryId, config: _viewModeConfig),
                _AlbumsTab(client: widget.client, libraryId: widget.libraryId, config: _viewModeConfig),
                _SongsTab(client: widget.client, libraryId: widget.libraryId, config: _viewModeConfig),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: AudioPlaybackManager.instance,
            builder: (context, _) {
              if (!AudioPlaybackManager.instance.hasPlaylist) return const SizedBox.shrink();
              return MiniPlayerCard(client: widget.client);
            },
          ),
        ],
      ),
    );
  }
}

// ==================== 艺术家 Tab ====================

class _ArtistsTab extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  final ViewModeConfig config;
  const _ArtistsTab({required this.client, required this.libraryId, required this.config});
  @override
  State<_ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends State<_ArtistsTab> {
  List<MusicArtist> _artists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

    return MediaGroupedScrollView<MusicArtist>(
      config: widget.config,
      items: _artists,
      onRefresh: _load,
      getSortName: (a) => a.sortName,
      getName: (a) => a.name,
      gridItemBuilder: (context, artist) => _AvatarCard(
        imageUrl: artist.getPrimaryImageUrl(fillWidth: 200, fillHeight: 200),
        hasImage: artist.hasImage,
        title: artist.name,
        subtitle: artist.albumCount != null ? '${artist.albumCount} 张专辑' : null,
        placeholderIcon: Icons.person,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ArtistDetailPage(client: widget.client, artist: artist),
        )),
      ),
      flatItemBuilder: (context, artist, index) => _MusicFlatItem(
        coverUrl: artist.getPrimaryImageUrl(fillWidth: 144, fillHeight: 144),
        hasImage: artist.hasImage,
        title: artist.name,
        subtitle: artist.albumCount != null ? '${artist.albumCount} 张专辑' : null,
        placeholderIcon: Icons.person,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ArtistDetailPage(client: widget.client, artist: artist),
        )),
      ),
    );
  }
}

// ==================== 专辑 Tab ====================

class _AlbumsTab extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  final ViewModeConfig config;
  const _AlbumsTab({required this.client, required this.libraryId, required this.config});
  @override
  State<_AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<_AlbumsTab> {
  List<MusicAlbum> _albums = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

    return MediaGroupedScrollView<MusicAlbum>(
      config: widget.config,
      items: _albums,
      onRefresh: _load,
      getSortName: (a) => a.sortName,
      getName: (a) => a.name,
      gridChildAspectRatio: 0.7,
      gridItemBuilder: (context, album) => _AvatarCard(
        imageUrl: album.getCoverImageUrl(fillWidth: 200, fillHeight: 200),
        hasImage: album.hasCoverImage,
        title: album.name,
        subtitle: album.artistText,
        placeholderIcon: Icons.album,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AlbumDetailPage(client: widget.client, album: album),
        )),
      ),
      flatItemBuilder: (context, album, index) => _MusicFlatItem(
        coverUrl: album.getCoverImageUrl(fillWidth: 144, fillHeight: 144),
        hasImage: album.hasCoverImage,
        title: album.name,
        subtitle: album.artistText,
        placeholderIcon: Icons.album,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AlbumDetailPage(client: widget.client, album: album),
        )),
      ),
    );
  }
}

// ==================== 歌曲 Tab ====================

class _SongsTab extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  final ViewModeConfig config;
  const _SongsTab({required this.client, required this.libraryId, required this.config});
  @override
  State<_SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<_SongsTab> {
  List<MusicSong> _songs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

    return MediaGroupedScrollView<MusicSong>(
      config: widget.config,
      items: _songs,
      onRefresh: _load,
      getSortName: (s) => s.sortName,
      getName: (s) => s.name,
      gridItemBuilder: (context, song) {
        final songIndex = _songs.indexOf(song);
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
              client: widget.client, song: song, playlist: _songs, initialIndex: songIndex,
            ),
          )),
        );
      },
      flatItemBuilder: (context, song, index) => _MusicFlatItem(
        coverUrl: song.getAlbumCoverUrl(fillWidth: 100, fillHeight: 100),
        hasImage: song.getAlbumCoverUrl() != null,
        title: song.name,
        subtitle: '${song.artistText}${song.albumName != null ? ' · ${song.albumName}' : ''}',
        placeholderIcon: Icons.music_note,
        trailingText: song.durationText,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AudioPlayerPage(
            client: widget.client, song: song, playlist: _songs, initialIndex: index,
          ),
        )),
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
  final _manager = AudioPlaybackManager.instance;

  @override
  void initState() {
    super.initState();
    // 仅当 manager 未在播放同一首歌时才启动新播放
    final current = _manager.currentSong;
    if (current == null || current.id != widget.song.id) {
      _manager.play(widget.playlist, widget.initialIndex, widget.client);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        final song = _manager.currentSong;
        if (song == null) return const Scaffold(body: SizedBox.shrink());

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
                  // 歌手名可点击跳转
                  GestureDetector(
                    onTap: () {
                      if (song.artistRefs?.isNotEmpty == true) {
                        final ref = song.artistRefs!.first;
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ArtistDetailPage(
                            client: widget.client,
                            artist: MusicArtist(
                              id: ref.id, name: ref.name,
                              serverUrl: widget.client.configuration.serverUrl,
                              accessToken: widget.client.configuration.accessToken,
                            ),
                          ),
                        ));
                      }
                    },
                    child: Text('${song.artistText}${song.albumName != null ? ' · ${song.albumName}' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: song.artistRefs?.isNotEmpty == true
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 32),

                  // 进度条
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      Slider(
                        value: _manager.displayDuration.inMilliseconds > 0
                            ? (_manager.position.inMilliseconds / _manager.displayDuration.inMilliseconds).clamp(0, 1)
                            : 0,
                        onChanged: (v) => _manager.seek(Duration(milliseconds: (_manager.displayDuration.inMilliseconds * v).round())),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(_fmt(_manager.position), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        Text(_fmt(_manager.displayDuration), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // 控制: [Shuffle] [Prev] [Play/Pause] [Next] [Repeat] [Lyrics]
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    // Shuffle
                    IconButton(
                      onPressed: () => _manager.toggleShuffle(),
                      icon: const Icon(Icons.shuffle, size: 28),
                      color: _manager.shuffleMode ? Theme.of(context).colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    // Previous
                    IconButton(
                      onPressed: () => _manager.playPrevious(),
                      icon: const Icon(Icons.skip_previous, size: 40),
                    ),
                    const SizedBox(width: 12),
                    // Play/Pause
                    _manager.isLoading
                        ? const SizedBox(width: 56, height: 56, child: CircularProgressIndicator())
                        : IconButton.filled(
                            onPressed: () => _manager.isPlaying ? _manager.pause() : _manager.resume(),
                            icon: Icon(_manager.isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
                            style: IconButton.styleFrom(minimumSize: const Size(64, 64))),
                    const SizedBox(width: 12),
                    // Next
                    IconButton(
                      onPressed: () => _manager.playNext(),
                      icon: const Icon(Icons.skip_next, size: 40),
                    ),
                    const SizedBox(width: 8),
                    // Repeat
                    IconButton(
                      onPressed: () => _manager.cycleRepeatMode(),
                      icon: Icon(
                        _manager.repeatMode == RepeatMode.repeatOne ? Icons.repeat_one : Icons.repeat,
                        size: 28,
                      ),
                      color: _manager.repeatMode != RepeatMode.off ? Theme.of(context).colorScheme.primary : null,
                    ),
                    const SizedBox(width: 16),
                    // Lyrics
                    IconButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => LyricsPage(
                          client: widget.client,
                          currentSong: song,
                          albumCoverUrl: song.getAlbumCoverUrl(fillWidth: 600, fillHeight: 600),
                        ),
                      )),
                      icon: const Icon(Icons.lyrics_outlined, size: 28),
                      tooltip: '歌词',
                    ),
                  ]),
                  const SizedBox(height: 16),

                  if (_manager.error != null)
                    Padding(padding: const EdgeInsets.all(16),
                      child: Text(_manager.error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),

                  Text('${_manager.currentIndex + 1} / ${_manager.playlistLength}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
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

/// 扁平列表/横幅的单行组件
class _MusicFlatItem extends StatelessWidget {
  final String? coverUrl;
  final bool hasImage;
  final String title;
  final String? subtitle;
  final IconData placeholderIcon;
  final VoidCallback onTap;
  final String? trailingText;

  const _MusicFlatItem({
    required this.coverUrl,
    required this.hasImage,
    required this.title,
    this.subtitle,
    required this.placeholderIcon,
    required this.onTap,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: trailingText != null,
        leading: _buildCover(context, 50, 50, 6),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle != null
            ? Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
            : null,
        trailing: trailingText != null
            ? Text(trailingText!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildCover(BuildContext context, double w, double h, double radius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: w, height: h,
        child: hasImage && coverUrl != null
            ? Image.network(coverUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context))
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Center(child: Icon(placeholderIcon, color: Colors.white54)),
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
