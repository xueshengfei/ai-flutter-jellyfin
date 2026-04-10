import 'dart:async' show Timer, StreamSubscription;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
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
    if (_isLoading) return _buildGridShimmer(context);
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
        heroTag: 'artist_${artist.id}',
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
        heroTag: 'artist_${artist.id}',
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
    if (_isLoading) return _buildGridShimmer(context);
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
        heroTag: 'album_${album.id}',
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
        heroTag: 'album_${album.id}',
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
    if (_isLoading) return _buildListShimmer(context);
    if (_error != null) return _buildError(_error!, () => _load());
    if (_songs.isEmpty) return const Center(child: Text('暂无歌曲'));

    final sorted = _sortedSongs;
    final showPlayCount = _sortField == SongSortField.playCount;

    return Column(
      children: [
        // 工具栏
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              // 上一百首
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _startIndex > 0
                    ? () => _load(startIndex: _startIndex - _pageSize)
                    : null,
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: '上一百首',
              ),
              Text('${_songs.length} 首', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              // 下一百首
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _hasMore
                    ? () => _load(startIndex: _startIndex + _pageSize)
                    : null,
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: '下一百首',
              ),
              const Spacer(),
              // 排序方式
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
              // 随机
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
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final song = sorted[index];
                return _MusicFlatItem(
                  coverUrl: song.getAlbumCoverUrl(fillWidth: 100, fillHeight: 100),
                  hasImage: song.getAlbumCoverUrl() != null,
                  title: song.name,
                  subtitle: '${song.artistText}${song.albumName != null ? ' · ${song.albumName}' : ''}',
                  placeholderIcon: Icons.music_note,
                  trailingText: song.durationText,
                  isFavorite: song.isFavorite,
                  onFavoriteTap: () => _toggleFavorite(song),
                  playCount: song.playCount,
                  showPlayCount: showPlayCount,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AudioPlayerPage(
                      client: widget.client, song: song, playlist: sorted, initialIndex: index,
                    ),
                  )),
                )
                .animate()
                .fadeIn(duration: 200.ms, delay: (20 * (index % 20)).ms)
                .slideY(begin: 0.1, end: 0);
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleFavorite(MusicSong song) async {
    final newState = !(song.isFavorite ?? false);
    // 立即更新 UI
    setState(() {
      final idx = _songs.indexWhere((s) => s.id == song.id);
      if (idx >= 0) {
        _songs[idx] = MusicSong(
          id: song.id, name: song.name, serverUrl: song.serverUrl,
          sortName: song.sortName, albumId: song.albumId, albumName: song.albumName,
          albumPrimaryImageTag: song.albumPrimaryImageTag, artists: song.artists,
          artistRefs: song.artistRefs, trackNumber: song.trackNumber,
          discNumber: song.discNumber, runTimeTicks: song.runTimeTicks,
          runTimeSeconds: song.runTimeSeconds, genres: song.genres,
          communityRating: song.communityRating, parentId: song.parentId,
          isFavorite: newState, played: song.played, playCount: song.playCount,
          accessToken: song.accessToken,
        );
      }
    });
    try {
      await widget.client.user.markFavorite(itemId: song.id, isFavorite: newState);
    } catch (e) {
      // 失败时恢复
      if (mounted) {
        setState(() {
          final idx = _songs.indexWhere((s) => s.id == song.id);
          if (idx >= 0) {
            _songs[idx] = MusicSong(
              id: song.id, name: song.name, serverUrl: song.serverUrl,
              sortName: song.sortName, albumId: song.albumId, albumName: song.albumName,
              albumPrimaryImageTag: song.albumPrimaryImageTag, artists: song.artists,
              artistRefs: song.artistRefs, trackNumber: song.trackNumber,
              discNumber: song.discNumber, runTimeTicks: song.runTimeTicks,
              runTimeSeconds: song.runTimeSeconds, genres: song.genres,
              communityRating: song.communityRating, parentId: song.parentId,
              isFavorite: song.isFavorite, played: song.played, playCount: song.playCount,
              accessToken: song.accessToken,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
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

class _AudioPlayerPageState extends State<AudioPlayerPage>
    with SingleTickerProviderStateMixin {
  final _manager = AudioPlaybackManager.instance;
  late final AnimationController _vinylController;
  double _vinylAngle = 0;

  // Web 端歌词展开状态
  bool _showWebLyrics = false;
  // 歌词相关
  LyricsData? _lyricsData;
  bool _lyricsLoading = false;
  int _currentLineIndex = -1;
  bool _isUserScrolling = false;
  Timer? _scrollResumeTimer;
  final ScrollController _lyricsScrollController = ScrollController();
  static const double _lyricItemHeight = 56.0;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addListener(() => setState(() => _vinylAngle = _vinylController.value * 2 * 3.14159265));
    final current = _manager.currentSong;
    if (current == null || current.id != widget.song.id) {
      _manager.play(widget.playlist, widget.initialIndex, widget.client);
    }
  }

  @override
  void dispose() {
    _vinylController.dispose();
    _lyricsScrollController.dispose();
    _positionSub?.cancel();
    _scrollResumeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    if (_lyricsData != null || _lyricsLoading) return;
    setState(() => _lyricsLoading = true);
    try {
      final data = await widget.client.music.getLyrics(_manager.currentSong!.id);
      if (mounted) {
        setState(() { _lyricsData = data; _lyricsLoading = false; });
        _startPositionTracking();
      }
    } catch (e) {
      if (mounted) setState(() => _lyricsLoading = false);
    }
  }

  void _startPositionTracking() {
    _positionSub?.cancel();
    _positionSub = _manager.onPositionChanged.listen((p) {
      if (!mounted) return;
      _updateCurrentLine(p);
    });
  }

  void _updateCurrentLine(Duration position) {
    final lines = _lyricsData?.lines;
    if (lines == null || lines.isEmpty || !_lyricsData!.isSynced) return;
    final positionTicks = position.inMicroseconds * 10;
    int newIndex = -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].startTicks != null && lines[i].startTicks! <= positionTicks) {
        newIndex = i;
        break;
      }
    }
    if (newIndex != _currentLineIndex) {
      setState(() => _currentLineIndex = newIndex);
      if (!_isUserScrolling) _scrollToLine(newIndex);
    }
  }

  void _scrollToLine(int index) {
    if (!_lyricsScrollController.hasClients || index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_lyricsScrollController.hasClients) return;
      final target = (index * _lyricItemHeight) + (_lyricItemHeight / 2);
      final max = _lyricsScrollController.position.maxScrollExtent;
      _lyricsScrollController.animateTo(
        target.clamp(0.0, max),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _onUserScroll() {
    _isUserScrolling = true;
    _scrollResumeTimer?.cancel();
    _scrollResumeTimer = Timer(const Duration(seconds: 3), () => _isUserScrolling = false);
  }

  Future<void> _onLineTap(int index) async {
    final lines = _lyricsData?.lines;
    if (lines == null || index >= lines.length) return;
    final startTime = lines[index].startTime;
    if (startTime != null) await _manager.seek(startTime);
  }

  Future<void> _toggleFavorite() async {
    final song = _manager.currentSong;
    if (song == null) return;
    final newState = !(song.isFavorite ?? false);
    // 乐观更新
    setState(() {});
    try {
      await widget.client.user.markFavorite(itemId: song.id, isFavorite: newState);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _onLyricsTap() {
    final isWide = MediaQuery.of(context).size.width > 700;
    if (isWide) {
      // Web/桌面端：内嵌展开歌词面板
      setState(() => _showWebLyrics = !_showWebLyrics);
      if (_showWebLyrics) _loadLyrics();
    } else {
      // 移动端：跳转独立歌词页面
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => LyricsPage(
          client: widget.client,
          currentSong: _manager.currentSong!,
          albumCoverUrl: _manager.currentSong!.getAlbumCoverUrl(fillWidth: 600, fillHeight: 600),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        // 同步唱片旋转状态
        if (_manager.isPlaying) {
          if (!_vinylController.isAnimating) _vinylController.repeat();
        } else {
          _vinylController.stop();
        }
        final song = _manager.currentSong;
        if (song == null) return const Scaffold(body: SizedBox.shrink());

        final isWide = MediaQuery.of(context).size.width > 700;

        return Scaffold(
          appBar: AppBar(title: const Text('正在播放')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 非唱片区域固定高度约 220（歌名50 + 间距76 + 进度条50 + 控制64 + 底部~16）
                  final fixedHeight = 230.0;
                  final maxVinyl = (constraints.maxHeight - fixedHeight).clamp(120.0, 240.0);
                  return isWide
                      ? _buildWideLayout(context, song, maxVinyl)
                      : _buildNarrowLayout(context, song, maxVinyl);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 移动端布局（窄屏）— 紧凑一屏展示
  Widget _buildNarrowLayout(BuildContext context, MusicSong song, double vinylSize) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildVinyl(context, song, vinylSize),
        const SizedBox(height: 12),
        _buildSongInfo(context, song, isWide: false),
        const SizedBox(height: 16),
        _buildProgressBar(context),
        const SizedBox(height: 8),
        _buildControls(context, song),
        if (_manager.error != null)
          Padding(padding: const EdgeInsets.all(8),
            child: Text(_manager.error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),
        const SizedBox(height: 2),
        Text('${_manager.currentIndex + 1} / ${_manager.playlistLength}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }

  /// Web/桌面端布局（宽屏）— 支持歌词分栏
  Widget _buildWideLayout(BuildContext context, MusicSong song, double vinylSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final lyricsWidth = (screenWidth - vinylSize - 32 - 32).clamp(200.0, 600.0);
    // 歌词面板高度 = 唱片大小（不超出）
    final lyricsHeight = vinylSize * 1.6;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 唱片 + 歌词分栏区
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildVinyl(context, song, vinylSize),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: _showWebLyrics ? lyricsWidth : 0,
              height: lyricsHeight,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showWebLyrics ? 1.0 : 0.0,
                curve: Curves.easeIn,
                child: _showWebLyrics
                    ? _buildWebLyricsContent(context, lyricsWidth, lyricsHeight)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSongInfo(context, song, isWide: true),
        const SizedBox(height: 16),
        _buildProgressBar(context),
        const SizedBox(height: 8),
        _buildControls(context, song),
        if (_manager.error != null)
          Padding(padding: const EdgeInsets.all(8),
            child: Text(_manager.error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),
        const SizedBox(height: 2),
        Text('${_manager.currentIndex + 1} / ${_manager.playlistLength}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }

  /// Web 端歌词内容（不含外层尺寸限制）
  Widget _buildWebLyricsContent(BuildContext context, double width, double height) {
    if (_lyricsLoading) {
      return SizedBox(
        width: width, height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final lines = _lyricsData?.lines;
    if (lines == null || lines.isEmpty) {
      return SizedBox(
        width: width, height: height,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lyrics_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('暂无歌词', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      width: width, height: height,
      child: Padding(
        padding: const EdgeInsets.only(left: 32),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) { if (n is UserScrollNotification) _onUserScroll(); return false; },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final vPadding = constraints.maxHeight / 2;
              return ListView.builder(
                controller: _lyricsScrollController,
                padding: EdgeInsets.symmetric(vertical: vPadding),
                itemCount: lines.length,
                itemExtent: _lyricItemHeight,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  final isCurrent = index == _currentLineIndex;
                  final isPast = _currentLineIndex >= 0 && index < _currentLineIndex;
                  return GestureDetector(
                    onTap: () => _onLineTap(index),
                    behavior: HitTestBehavior.translucent,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: isCurrent ? 20 : 15,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : isPast
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                          height: 1.4,
                        ),
                        child: Text(line.text ?? '', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// 黑胶唱片
  Widget _buildVinyl(BuildContext context, MusicSong song, double size) {
    return Transform.rotate(
      angle: _vinylAngle,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
          gradient: song.getAlbumCoverUrl(fillWidth: 480, fillHeight: 480) != null
              ? null
              : LinearGradient(
                  colors: [Colors.grey.shade700, Colors.grey.shade900],
                  stops: const [0.6, 1.0],
                ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.all(size * 0.067),
              child: ClipOval(
                child: song.getAlbumCoverUrl(fillWidth: 480, fillHeight: 480) != null
                    ? Image.network(song.getAlbumCoverUrl(fillWidth: 480, fillHeight: 480)!, fit: BoxFit.cover,
                        width: size * 0.867, height: size * 0.867,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            Container(
              width: size * 0.083, height: size * 0.083,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border.all(color: Colors.grey.shade600, width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 歌曲信息行 — 歌名一行 + 歌手·专辑 歌词按钮 同一行
  Widget _buildSongInfo(BuildContext context, MusicSong song, {required bool isWide}) {
    return Column(
      children: [
        Text(song.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        // 歌手 + 歌词按钮 同一行
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: GestureDetector(
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: song.artistRefs?.isNotEmpty == true
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 6),
            _LyricsChip(
              isActive: _showWebLyrics,
              onTap: _onLyricsTap,
            ),
          ],
        ),
      ],
    );
  }

  /// 进度条
  Widget _buildProgressBar(BuildContext context) {
    return Padding(
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
    );
  }

  /// 控制栏: [PlayMode] [Prev] [Play/Pause] [Next] [Favorite]
  Widget _buildControls(BuildContext context, MusicSong song) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
      // 收藏按钮（替换原歌词按钮位置）
      SizedBox(
        width: 48, height: 48,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _toggleFavorite,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                song.isFavorite == true ? Icons.favorite : Icons.favorite_border,
                size: 22,
                color: song.isFavorite == true ? Colors.red.shade400 : null,
              ),
              Text('藏', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _placeholder() => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
  final String? heroTag;

  const _MediaCard({
    required this.imageUrl,
    required this.hasImage,
    required this.title,
    this.subtitle,
    this.isCircle = false,
    required this.placeholderIcon,
    required this.onTap,
    this.heroTag,
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
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: hasImage && imageUrl != null
            ? Image.network(imageUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ph(context))
            : _ph(context),
      ),
    );
    if (heroTag != null) {
      return Hero(tag: heroTag!, child: child);
    }
    return child;
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
  final bool? isFavorite;
  final VoidCallback? onFavoriteTap;
  final int? playCount;
  final bool showPlayCount;
  final String? heroTag;

  const _MusicFlatItem({
    required this.coverUrl,
    required this.hasImage,
    required this.title,
    this.subtitle,
    required this.placeholderIcon,
    required this.onTap,
    this.trailingText,
    this.isFavorite,
    this.onFavoriteTap,
    this.playCount,
    this.showPlayCount = false,
    this.heroTag,
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
              // 播放次数
              if (showPlayCount && playCount != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, size: 14, color: Colors.grey.shade400),
                      Text('$playCount', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
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
              // 收藏按钮（弹跳动画）
              if (onFavoriteTap != null)
                _FavoriteButton(
                  isFavorite: isFavorite == true,
                  onTap: onFavoriteTap!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context, double w, double h, double radius) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: w, height: h,
        child: hasImage && coverUrl != null
            ? Image.network(coverUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context))
            : _placeholder(context),
      ),
    );
    if (heroTag != null) {
      return Hero(tag: heroTag!, child: child);
    }
    return child;
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

/// 网格骨架屏（用于艺术家/专辑 Tab）
Widget _buildGridShimmer(BuildContext context) {
  return Shimmer.fromColors(
    baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    highlightColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 6),
          Container(height: 12, width: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 4),
          Container(height: 10, width: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
        ],
      ),
    ),
  );
}

/// 列表骨架屏（用于歌曲 Tab）
Widget _buildListShimmer(BuildContext context) {
  return Shimmer.fromColors(
    baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    highlightColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 10,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(height: 10, width: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              ],
            )),
          ],
        ),
      ),
    ),
  );
}

/// 收藏按钮 — 点击时弹跳缩放动画
class _FavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  const _FavoriteButton({required this.isFavorite, required this.onTap});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool _animating = false;

  void _handleTap() {
    setState(() => _animating = true);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(
          widget.isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: widget.isFavorite ? Colors.red.shade400 : Colors.grey.shade400,
        ),
      ),
    )
    .animate(target: _animating ? 1.0 : 0.0)
    .scale(
      begin: const Offset(1.0, 1.0),
      end: const Offset(1.4, 1.4),
      duration: 100.ms,
    )
    .then()
    .scale(
      begin: const Offset(1.4, 1.4),
      end: const Offset(0.9, 0.9),
      duration: 80.ms,
    )
    .then()
    .scale(
      begin: const Offset(0.9, 0.9),
      end: const Offset(1.0, 1.0),
      duration: 60.ms,
    )
    .callback(callback: (_) => setState(() => _animating = false));
  }
}

/// 歌词小标签按钮（放在歌手行右侧）
class _LyricsChip extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _LyricsChip({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined, size: 14,
              color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade500),
            const SizedBox(width: 3),
            Text('词',
              style: TextStyle(fontSize: 11,
                color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
