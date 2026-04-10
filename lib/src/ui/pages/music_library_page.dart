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

  Future<void> _load({String? nameStartsWith}) async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.music.getAlbumArtists(
        parentId: widget.libraryId,
        limit: 100,
        nameStartsWith: nameStartsWith,
      );
      if (mounted) setState(() { _artists = result.artists; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, () => _load());
    if (_artists.isEmpty) return const Center(child: Text('暂无艺术家'));

    return MediaGroupedScrollView<MusicArtist>(
      config: widget.config,
      items: _artists,
      onRefresh: () => _load(),
      getSortName: (a) => a.sortName,
      getName: (a) => a.name,
      onLetterFilter: (letter) => _load(nameStartsWith: letter == '#' ? null : letter),
      gridItemBuilder: (context, artist) => _MediaCard(
        imageUrl: artist.getPrimaryImageUrl(fillWidth: 200, fillHeight: 200),
        hasImage: artist.hasImage,
        title: artist.name,
        subtitle: artist.albumCount != null ? '${artist.albumCount} 张专辑' : null,
        isCircle: false,
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

  Future<void> _load({String? nameStartsWith}) async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.music.getAlbums(
        parentId: widget.libraryId,
        limit: 100,
        nameStartsWith: nameStartsWith,
      );
      if (mounted) setState(() { _albums = result.albums; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, () => _load());
    if (_albums.isEmpty) return const Center(child: Text('暂无专辑'));

    return MediaGroupedScrollView<MusicAlbum>(
      config: widget.config,
      items: _albums,
      onRefresh: () => _load(),
      getSortName: (a) => a.sortName,
      getName: (a) => a.name,
      onLetterFilter: (letter) => _load(nameStartsWith: letter == '#' ? null : letter),
      gridChildAspectRatio: 0.68,
      gridItemBuilder: (context, album) => _MediaCard(
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

enum SongSortField {
  name('曲目名称', Icons.sort_by_alpha),
  album('专辑', Icons.album),
  artist('艺术家', Icons.person),
  playCount('播放次数', Icons.play_circle_outline),
  duration('时长', Icons.timer),
  random('随机', Icons.shuffle);

  final String label;
  final IconData icon;
  const SongSortField(this.label, this.icon);
}

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
  SongSortField _sortField = SongSortField.name;
  bool _sortAscending = true;
  int _startIndex = 0;
  int _pageSize = 100;
  bool _hasMore = true;
  bool _isRandom = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? startIndex, bool random = false}) async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final si = startIndex ?? 0;
      final result = await widget.client.music.getLatestSongs(
        parentId: widget.libraryId,
        limit: _pageSize,
        nameStartsWith: random ? null : null,
      );
      if (mounted) setState(() {
        if (random) {
          _songs = List.from(result.songs)..shuffle();
        } else {
          _songs = result.songs;
        }
        _startIndex = si;
        _isRandom = random;
        _hasMore = result.songs.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  Future<void> _loadRandom() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.music.getLatestSongs(
        parentId: widget.libraryId,
        limit: _pageSize,
      );
      if (mounted) setState(() {
        _songs = List.from(result.songs)..shuffle();
        _startIndex = 0;
        _isRandom = true;
        _hasMore = false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  List<MusicSong> get _sortedSongs {
    final list = List<MusicSong>.from(_songs);
    int compare(MusicSong a, MusicSong b) {
      int cmp;
      switch (_sortField) {
        case SongSortField.name:
          cmp = a.name.compareTo(b.name);
        case SongSortField.album:
          cmp = (a.albumName ?? '').compareTo(b.albumName ?? '');
        case SongSortField.artist:
          cmp = a.artistText.compareTo(b.artistText);
        case SongSortField.playCount:
          cmp = (b.playCount ?? 0).compareTo(a.playCount ?? 0);
        case SongSortField.duration:
          cmp = (a.runTimeTicks ?? 0).compareTo(b.runTimeTicks ?? 0);
        case SongSortField.random:
          return 0; // 随机不在这里处理
      }
      return _sortAscending ? cmp : -cmp;
    }
    if (_sortField == SongSortField.random) {
      list.shuffle();
    } else {
      list.sort(compare);
    }
    return list;
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Text('排序方式', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.only(top: 8),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 排序字段
                ...SongSortField.values.map((field) => ListTile(
                      dense: true,
                      leading: Icon(field.icon, size: 20,
                          color: _sortField == field
                              ? Theme.of(context).colorScheme.primary
                              : null),
                      title: Text(field.label, style: const TextStyle(fontSize: 14)),
                      trailing: _sortField == field
                          ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        setDialogState(() => _sortField = field);
                        setState(() => _sortField = field);
                      },
                    )),
                const Divider(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('排序顺序', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.arrow_upward, size: 20,
                      color: _sortAscending
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  title: const Text('升序', style: TextStyle(fontSize: 14)),
                  trailing: _sortAscending
                      ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setDialogState(() => _sortAscending = true);
                    setState(() => _sortAscending = true);
                  },
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.arrow_downward, size: 20,
                      color: !_sortAscending
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  title: const Text('降序', style: TextStyle(fontSize: 14)),
                  trailing: !_sortAscending
                      ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setDialogState(() => _sortAscending = false);
                    setState(() => _sortAscending = false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, () => _load());
    if (_songs.isEmpty) return const Center(child: Text('暂无歌曲'));

    final sorted = _sortedSongs;

    return Column(
      children: [
        // 工具栏
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text('${_songs.length} 首', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              const Spacer(),
              // 排序方式按钮（固定文字）
              TextButton.icon(
                onPressed: _showSortDialog,
                icon: Icon(Icons.sort, size: 18, color: Colors.grey.shade600),
                label: Text('排序方式', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ),
              // 排序方向
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _sortAscending = !_sortAscending),
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18, color: Colors.grey.shade600,
                ),
                tooltip: _sortAscending ? '升序' : '降序',
              ),
              // 随机按钮
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _loadRandom,
                icon: Icon(Icons.shuffle, size: 18,
                    color: _isRandom ? Theme.of(context).colorScheme.primary : Colors.grey.shade600),
                tooltip: '随机100首',
              ),
            ],
          ),
        ),
        // 歌曲列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: sorted.length + 1, // +1 for bottom pagination
              itemBuilder: (context, index) {
                if (index == sorted.length) {
                  // 分页控制
                  return _buildPagination();
                }
                final song = sorted[index];
                return _MusicFlatItem(
                  coverUrl: song.getAlbumCoverUrl(fillWidth: 100, fillHeight: 100),
                  hasImage: song.getAlbumCoverUrl() != null,
                  title: song.name,
                  subtitle: '${song.artistText}${song.albumName != null ? ' · ${song.albumName}' : ''}',
                  placeholderIcon: Icons.music_note,
                  trailingText: song.durationText,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AudioPlayerPage(
                      client: widget.client, song: song, playlist: sorted, initialIndex: index,
                    ),
                  )),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一百首
          OutlinedButton.icon(
            onPressed: _startIndex > 0
                ? () => _load(startIndex: _startIndex - _pageSize)
                : null,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('上一百首'),
          ),
          const SizedBox(width: 16),
          // 页码
          Text('第 ${(_startIndex ~/ _pageSize) + 1} 页',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(width: 16),
          // 下一百首
          OutlinedButton.icon(
            onPressed: _hasMore
                ? () => _load(startIndex: _startIndex + _pageSize)
                : null,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('下一百首'),
          ),
        ],
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
                        value: _manager.duration.inMilliseconds > 0
                            ? (_manager.position.inMilliseconds / _manager.duration.inMilliseconds).clamp(0, 1)
                            : 0,
                        onChanged: (v) => _manager.seek(Duration(milliseconds: (_manager.duration.inMilliseconds * v).round())),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(_fmt(_manager.position), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        Text(_fmt(_manager.duration), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // 控制: [PlayMode] [Prev] [Play/Pause] [Next] [Lyrics]
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    // 播放模式
                    IconButton(
                      onPressed: () => _manager.cyclePlayMode(),
                      icon: Icon(switch (_manager.playMode) {
                        PlayMode.sequential => Icons.trending_flat,
                        PlayMode.shuffle => Icons.shuffle,
                        PlayMode.repeatOne => Icons.repeat_one,
                      }, size: 28),
                      color: _manager.playMode != PlayMode.sequential
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      tooltip: switch (_manager.playMode) {
                        PlayMode.sequential => '顺序播放',
                        PlayMode.shuffle => '随机播放',
                        PlayMode.repeatOne => '单曲循环',
                      },
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
                    // 歌词按钮（图标+词字）
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => LyricsPage(
                            client: widget.client,
                            currentSong: song,
                            albumCoverUrl: song.getAlbumCoverUrl(fillWidth: 600, fillHeight: 600),
                          ),
                        )),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lyrics_outlined, size: 22),
                            Text('词', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
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

/// 网格模式卡片 - 正方形封面 + 标题 + 副标题
/// 支持圆形模式（艺术家头像）和方形模式（专辑封面）
class _MediaCard extends StatelessWidget {
  final String? imageUrl;
  final bool hasImage;
  final String title;
  final String? subtitle;
  final bool isCircle;
  final IconData placeholderIcon;
  final VoidCallback onTap;

  const _MediaCard({
    required this.imageUrl,
    required this.hasImage,
    required this.title,
    this.subtitle,
    this.isCircle = false,
    required this.placeholderIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: isCircle
                ? _buildCircleAvatar(context)
                : _buildSquareCover(context),
          ),
          const SizedBox(height: 6),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          if (subtitle != null)
            Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildCircleAvatar(BuildContext context) {
    return ClipOval(
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: hasImage && imageUrl != null
            ? Image.network(imageUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ph(context))
            : _ph(context),
      ),
    );
  }

  Widget _buildSquareCover(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: hasImage && imageUrl != null
            ? Image.network(imageUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ph(context))
            : _ph(context),
      ),
    );
  }

  Widget _ph(BuildContext context) => Center(
    child: Icon(placeholderIcon, size: 36, color: Colors.white.withValues(alpha: 0.3)),
  );
}

/// 扁平列表单行组件
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              // 封面缩略图
              _buildCover(context, 48, 48, 6),
              const SizedBox(width: 12),
              // 文字信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    if (subtitle != null)
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              // 时长/尾部文字
              if (trailingText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(trailingText!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ),
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
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(child: Icon(placeholderIcon, size: 20, color: Colors.white.withValues(alpha: 0.3))),
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
