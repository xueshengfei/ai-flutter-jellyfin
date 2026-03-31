import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'artist_detail_page.dart';
import 'album_detail_page.dart';
import 'music_search_page.dart';

// ==================== 首字母索引工具函数 ====================

/// 提取首字母：A-Z 或 "#"（非字母归入 #）
String getSortLetter(String? sortName, String? name) {
  final text = (sortName ?? name ?? '').trim();
  if (text.isEmpty) return '#';
  final upper = text.toUpperCase();
  final codeUnit = upper.codeUnitAt(0);
  if (codeUnit >= 65 && codeUnit <= 90) return upper[0]; // A-Z
  return '#';
}

/// 按首字母分组并排序
Map<String, List<T>> groupByFirstLetter<T>(
  List<T> items,
  String? Function(T) getSortName,
  String? Function(T) getName,
) {
  final map = <String, List<T>>{};
  for (final item in items) {
    final letter = getSortLetter(getSortName(item), getName(item));
    (map[letter] ??= []).add(item);
  }
  // 排序 key：字母 A-Z 在前，# 在最后
  final sortedKeys = map.keys.toList()
    ..sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });
  return {for (final k in sortedKeys) k: map[k]!};
}

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
        actions: [
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

// ==================== 字母索引条 Widget ====================

class _AlphabetIndexBar extends StatefulWidget {
  final List<String> letters;
  final String activeLetter;
  final ValueChanged<String> onLetterTap;

  const _AlphabetIndexBar({
    required this.letters,
    required this.activeLetter,
    required this.onLetterTap,
  });

  @override
  State<_AlphabetIndexBar> createState() => _AlphabetIndexBarState();
}

class _AlphabetIndexBarState extends State<_AlphabetIndexBar> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (widget.letters.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onVerticalDragStart: (_) => setState(() => _isDragging = true),
      onVerticalDragEnd: (_) => setState(() => _isDragging = false),
      onVerticalDragUpdate: (details) => _handleDrag(details.localPosition.dy),
      onTapUp: (details) => _handleTap(details.localPosition.dy),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _isDragging ? 36 : 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: _isDragging ? 0.3 : 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: widget.letters.map((letter) {
            final isActive = letter == widget.activeLetter;
            return Expanded(
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: _isDragging ? 12 : 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _handleTap(double dy) {
    final index = (dy / (context.size!.height / widget.letters.length))
        .floor()
        .clamp(0, widget.letters.length - 1);
    widget.onLetterTap(widget.letters[index]);
  }

  void _handleDrag(double dy) {
    final index = (dy / (context.size!.height / widget.letters.length))
        .floor()
        .clamp(0, widget.letters.length - 1);
    widget.onLetterTap(widget.letters[index]);
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
  late ScrollController _scrollController;
  String _activeLetter = '';
  Map<String, List<MusicArtist>> _grouped = {};
  List<String> _letters = [];
  final Map<String, GlobalKey> _headerKeys = {};
  static const double _headerHeight = 40.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuildGroups() {
    _grouped = groupByFirstLetter(
      _artists,
      (a) => a.sortName,
      (a) => a.name,
    );
    _letters = _grouped.keys.toList();
    _headerKeys.clear();
    for (final letter in _letters) {
      _headerKeys[letter] = GlobalKey();
    }
    if (_letters.isNotEmpty) _activeLetter = _letters.first;
  }

  void _onScroll() {
    for (final letter in _letters) {
      final key = _headerKeys[letter];
      if (key?.currentContext != null) {
        final box = key!.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero, ancestor: null);
          if (pos.dy <= _headerHeight) {
            if (_activeLetter != letter && mounted) {
              setState(() => _activeLetter = letter);
            }
            return;
          }
        }
      }
    }
  }

  void _scrollToLetter(String letter) {
    final key = _headerKeys[letter];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.0,
      );
    }
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.music.getAlbumArtists(parentId: widget.libraryId, limit: 100);
      if (mounted) {
        setState(() {
          _artists = result.artists;
          _isLoading = false;
        });
        _rebuildGroups();
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, _load);
    if (_artists.isEmpty) return const Center(child: Text('暂无艺术家'));

    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            for (final letter in _letters) ...[
              SliverToBoxAdapter(
                child: Container(
                  key: _headerKeys[letter],
                  padding: const EdgeInsets.fromLTRB(16, 12, 40, 4),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 40, 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, childAspectRatio: 0.75,
                    crossAxisSpacing: 12, mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final artist = _grouped[letter]![index];
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
                    childCount: _grouped[letter]!.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      Positioned(
        right: 2,
        top: 0,
        bottom: 0,
        width: 28,
        child: _AlphabetIndexBar(
          letters: _letters,
          activeLetter: _activeLetter,
          onLetterTap: _scrollToLetter,
        ),
      ),
    ]);
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
  late ScrollController _scrollController;
  String _activeLetter = '';
  Map<String, List<MusicAlbum>> _grouped = {};
  List<String> _letters = [];
  final Map<String, GlobalKey> _headerKeys = {};
  static const double _headerHeight = 40.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuildGroups() {
    _grouped = groupByFirstLetter(
      _albums,
      (a) => a.sortName,
      (a) => a.name,
    );
    _letters = _grouped.keys.toList();
    _headerKeys.clear();
    for (final letter in _letters) {
      _headerKeys[letter] = GlobalKey();
    }
    if (_letters.isNotEmpty) _activeLetter = _letters.first;
  }

  void _onScroll() {
    for (final letter in _letters) {
      final key = _headerKeys[letter];
      if (key?.currentContext != null) {
        final box = key!.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero, ancestor: null);
          if (pos.dy <= _headerHeight) {
            if (_activeLetter != letter && mounted) {
              setState(() => _activeLetter = letter);
            }
            return;
          }
        }
      }
    }
  }

  void _scrollToLetter(String letter) {
    final key = _headerKeys[letter];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.0,
      );
    }
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.music.getAlbums(parentId: widget.libraryId, limit: 100);
      if (mounted) {
        setState(() {
          _albums = result.albums;
          _isLoading = false;
        });
        _rebuildGroups();
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, _load);
    if (_albums.isEmpty) return const Center(child: Text('暂无专辑'));

    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            for (final letter in _letters) ...[
              SliverToBoxAdapter(
                child: Container(
                  key: _headerKeys[letter],
                  padding: const EdgeInsets.fromLTRB(16, 12, 40, 4),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 40, 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, childAspectRatio: 0.7,
                    crossAxisSpacing: 12, mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final album = _grouped[letter]![index];
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
                    childCount: _grouped[letter]!.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      Positioned(
        right: 2,
        top: 0,
        bottom: 0,
        width: 28,
        child: _AlphabetIndexBar(
          letters: _letters,
          activeLetter: _activeLetter,
          onLetterTap: _scrollToLetter,
        ),
      ),
    ]);
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
  late ScrollController _scrollController;
  String _activeLetter = '';
  Map<String, List<MusicSong>> _grouped = {};
  List<String> _letters = [];
  final Map<String, GlobalKey> _headerKeys = {};
  static const double _headerHeight = 48.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuildGroups() {
    _grouped = groupByFirstLetter(
      _songs,
      (s) => s.sortName,
      (s) => s.name,
    );
    _letters = _grouped.keys.toList();
    _headerKeys.clear();
    for (final letter in _letters) {
      _headerKeys[letter] = GlobalKey();
    }
    if (_letters.isNotEmpty) _activeLetter = _letters.first;
  }

  void _onScroll() {
    for (final letter in _letters) {
      final key = _headerKeys[letter];
      if (key?.currentContext != null) {
        final box = key!.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero, ancestor: null);
          if (pos.dy <= _headerHeight) {
            if (_activeLetter != letter && mounted) {
              setState(() => _activeLetter = letter);
            }
            return;
          }
        }
      }
    }
  }

  void _scrollToLetter(String letter) {
    final key = _headerKeys[letter];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.0,
      );
    }
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.music.getLatestSongs(parentId: widget.libraryId, limit: 100);
      if (mounted) {
        setState(() {
          _songs = result.songs;
          _isLoading = false;
        });
        _rebuildGroups();
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, _load);
    if (_songs.isEmpty) return const Center(child: Text('暂无歌曲'));

    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            for (final letter in _letters) ...[
              SliverToBoxAdapter(
                child: Container(
                  key: _headerKeys[letter],
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _grouped[letter]![index];
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
                  childCount: _grouped[letter]!.length,
                ),
              ),
            ],
          ],
        ),
      ),
      Positioned(
        right: 2,
        top: 0,
        bottom: 0,
        width: 28,
        child: _AlphabetIndexBar(
          letters: _letters,
          activeLetter: _activeLetter,
          onLetterTap: _scrollToLetter,
        ),
      ),
    ]);
  }
}

// ==================== 音频播放页 ====================

enum RepeatMode { off, repeatAll, repeatOne }

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

  // Shuffle / Repeat
  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffleMode = false;
  List<int> _shuffleOrder = [];
  int _shufflePosition = 0;

  MusicSong get _currentSong => widget.playlist[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initShuffleOrder();
    _setupListeners();
    _playSong();
  }

  void _initShuffleOrder() {
    _shuffleOrder = List.generate(widget.playlist.length, (i) => i);
    _shuffleOrder.shuffle();
    // Ensure current song is first in shuffle
    _shuffleOrder.remove(_currentIndex);
    _shuffleOrder.insert(0, _currentIndex);
    _shufflePosition = 0;
  }

  void _setupListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.playing || state == PlayerState.paused || state == PlayerState.completed) {
          _isLoading = false;
        }
      });
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (_repeatMode == RepeatMode.repeatOne) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.resume();
      } else {
        _playNext();
      }
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
    final len = widget.playlist.length;
    if (len <= 1 && _repeatMode != RepeatMode.repeatAll) return;

    if (_shuffleMode) {
      _shufflePosition++;
      if (_shufflePosition >= len) {
        if (_repeatMode == RepeatMode.repeatAll) {
          _initShuffleOrder();
        } else {
          return;
        }
      }
      setState(() => _currentIndex = _shuffleOrder[_shufflePosition]);
    } else {
      if (_currentIndex < len - 1) {
        setState(() => _currentIndex++);
      } else if (_repeatMode == RepeatMode.repeatAll) {
        setState(() => _currentIndex = 0);
      } else {
        return;
      }
    }
    await _playSong();
  }

  Future<void> _playPrevious() async {
    // 播放超过 3 秒先回到开头
    if (_position.inSeconds >= 3) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    final len = widget.playlist.length;
    if (len <= 1) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    if (_shuffleMode) {
      if (_shufflePosition > 0) {
        _shufflePosition--;
      } else {
        _shufflePosition = len - 1;
      }
      setState(() => _currentIndex = _shuffleOrder[_shufflePosition]);
    } else {
      if (_currentIndex > 0) {
        setState(() => _currentIndex--);
      } else {
        setState(() => _currentIndex = len - 1);
      }
    }
    await _playSong();
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

              // 控制: [Shuffle] [Prev] [Play/Pause] [Next] [Repeat]
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                // Shuffle
                IconButton(
                  onPressed: () => setState(() {
                    _shuffleMode = !_shuffleMode;
                    if (_shuffleMode) _initShuffleOrder();
                  }),
                  icon: const Icon(Icons.shuffle, size: 28),
                  color: _shuffleMode ? Theme.of(context).colorScheme.primary : null,
                ),
                const SizedBox(width: 8),
                // Previous
                IconButton(
                  onPressed: _playPrevious,
                  icon: const Icon(Icons.skip_previous, size: 40),
                ),
                const SizedBox(width: 12),
                // Play/Pause
                _isLoading
                    ? const SizedBox(width: 56, height: 56, child: CircularProgressIndicator())
                    : IconButton.filled(
                        onPressed: () async { _isPlaying ? await _audioPlayer.pause() : await _audioPlayer.resume(); },
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
                        style: IconButton.styleFrom(minimumSize: const Size(64, 64))),
                const SizedBox(width: 12),
                // Next
                IconButton(
                  onPressed: _playNext,
                  icon: const Icon(Icons.skip_next, size: 40),
                ),
                const SizedBox(width: 8),
                // Repeat
                IconButton(
                  onPressed: () => setState(() {
                    switch (_repeatMode) {
                      case RepeatMode.off:
                        _repeatMode = RepeatMode.repeatAll;
                      case RepeatMode.repeatAll:
                        _repeatMode = RepeatMode.repeatOne;
                      case RepeatMode.repeatOne:
                        _repeatMode = RepeatMode.off;
                    }
                  }),
                  icon: Icon(
                    _repeatMode == RepeatMode.repeatOne ? Icons.repeat_one : Icons.repeat,
                    size: 28,
                  ),
                  color: _repeatMode != RepeatMode.off ? Theme.of(context).colorScheme.primary : null,
                ),
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
