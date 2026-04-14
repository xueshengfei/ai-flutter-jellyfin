import 'package:flutter/material.dart';
import 'package:jellyfin_service/src/jellyfin_client.dart';
import 'package:jellyfin_service/src/models/user_models.dart';
import 'package:jellyfin_service/src/models/media_library_models.dart';
import 'package:jellyfin_service/src/models/media_item_models.dart';
import 'package:jellyfin_service/src/models/book_models.dart';
import 'package:jellyfin_service/src/ui/services/audio_playback_manager.dart';
import 'package:jellyfin_service/src/ui/pages/login_page.dart';
import 'package:jellyfin_service/src/ui/pages/personal_page.dart';
import 'package:jellyfin_service/src/ui/pages/test_api_page.dart';
import 'package:jellyfin_service/src/ui/pages/movie_filter_page.dart';
import 'package:jellyfin_service/src/ui/pages/music_library_page.dart';
import 'package:jellyfin_service/src/ui/pages/book_library_page.dart';
import 'package:jellyfin_service/src/ui/pages/epub_reader_page.dart';
import 'package:jellyfin_service/src/ui/pages/media_items_page.dart';
import 'package:jellyfin_service/src/ui/widgets/library_card.dart';
import 'package:jellyfin_service/src/ui/widgets/continue_watching_card.dart';
import 'package:jellyfin_service/src/ui/widgets/mini_player_card.dart';
import 'package:jellyfin_service/src/ui/pages/ai_recommend_page.dart';

/// 媒体库列表页面 - 登录后展示所有媒体库，点击进入对应类型的页面
class MediaLibrariesPage extends StatefulWidget {
  final JellyfinClient client;
  final UserProfile user;

  const MediaLibrariesPage({super.key, required this.client, required this.user});

  @override
  State<MediaLibrariesPage> createState() => _MediaLibrariesPageState();
}

class _MediaLibrariesPageState extends State<MediaLibrariesPage> {
  List<MediaLibrary> _mediaLibraries = [];
  List<MediaItem> _continueWatching = [];
  List<Book> _continueReadingBooks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        widget.client.mediaLibrary.getMediaLibraries(),
        widget.client.user.getContinueWatching(limit: 10),
      ]);
      if (mounted) {
        final allContinueItems = (results[1] as MediaItemListResult).items;
        // 分离视频/音频类和书籍类
        final videoItems = <MediaItem>[];
        final bookItems = <Book>[];
        for (final item in allContinueItems) {
          if (item.type.toLowerCase() == 'book') {
            bookItems.add(Book(
              id: item.id,
              name: item.name,
              serverUrl: item.serverUrl,
              primaryImageTag: item.primaryImageTag,
              accessToken: item.accessToken,
              parentId: item.parentId,
              playedPercentage: item.playedPercentage,
            ));
          } else {
            videoItems.add(item);
          }
        }
        setState(() {
          _mediaLibraries = (results[0] as MediaLibraryListResult).libraries;
          _continueWatching = videoItems;
          _continueReadingBooks = bookItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        actions: [
          // AI 推荐入口（胶囊动画按钮）
          _AiRecommendPill(onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AiRecommendPage(client: widget.client)));
          }),
          IconButton(icon: const Icon(Icons.person), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PersonalPage(client: widget.client)));
          }, tooltip: '个人中心'),
          IconButton(icon: const Icon(Icons.bug_report), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TestApiPage(client: widget.client)));
          }, tooltip: 'API测试'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Center(child: Text(widget.user.name, style: const TextStyle(fontWeight: FontWeight.bold)))),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await widget.client.auth.logout();
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
          }, tooltip: '登出'),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
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

  Widget _buildBody() {
    if (_isLoading) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在加载...')]));
    if (_errorMessage != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 64, color: Colors.red), const SizedBox(height: 16), Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: _loadAll, child: const Text('重试'))]));

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 媒体库
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('媒体库', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _mediaLibraries.map((lib) => LibraryCard(
              client: widget.client,
              library: lib,
              onTap: () => _navigateToLibrary(lib),
            )).toList(),
          ),
          // 继续观看
          if (_continueWatching.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('继续观看', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _continueWatching.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    ContinueWatchingCard(item: _continueWatching[index], client: widget.client),
              ),
            ),
          ],
          // 继续阅读
          if (_continueReadingBooks.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('继续阅读', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _continueReadingBooks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final book = _continueReadingBooks[index];
                  return _ContinueReadingCard(
                    book: book,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => EpubReaderPage(client: widget.client, book: book),
                    )),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToLibrary(MediaLibrary library) {
    Widget page;
    if (library.type == MediaLibraryType.movies) {
      page = MovieFilterPage(client: widget.client, libraryId: library.id, libraryName: library.name);
    } else if (library.type == MediaLibraryType.music) {
      page = MusicLibraryPage(client: widget.client, libraryId: library.id, libraryName: library.name);
    } else if (library.type == MediaLibraryType.books) {
      page = BookLibraryPage(client: widget.client, libraryId: library.id, libraryName: library.name);
    } else {
      page = MediaItemsPage(client: widget.client, library: library);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

/// 继续阅读卡片
class _ContinueReadingCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _ContinueReadingCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = (book.playedPercentage ?? 0) / 100;
    final coverUrl = book.getCoverImageUrl(fillWidth: 200, fillHeight: 300);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面 + 进度条
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: coverUrl != null
                        ? Image.network(coverUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                            errorBuilder: (_, __, ___) => _placeholder(context))
                        : _placeholder(context),
                  ),
                  // 底部进度条
                  if (progress > 0)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // 标题
            Text(
              book.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            if (book.playedPercentage != null && book.playedPercentage! > 0)
              Text(
                '已读 ${book.playedPercentage!.toStringAsFixed(0)}%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: Icon(Icons.menu_book, size: 32, color: Colors.white54)),
  );
}

// ═══════════════════════════════════════════════════════════
// AI 推荐胶囊动画按钮
// 圆形图标 → 展开胶囊 → 显示文字 → 6秒后收回 → 循环
// ═══════════════════════════════════════════════════════════

class _AiRecommendPill extends StatefulWidget {
  final VoidCallback onPressed;
  const _AiRecommendPill({required this.onPressed});

  @override
  State<_AiRecommendPill> createState() => _AiRecommendPillState();
}

class _AiRecommendPillState extends State<_AiRecommendPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// 总周期 9 秒：
  /// 0.0–0.06  (0–0.5s)   展开圆形 → 胶囊
  /// 0.06–0.72 (0.5–6.5s) 胶囊态展示「AI 推荐」
  /// 0.72–0.78 (6.5–7s)   收回胶囊 → 圆形
  /// 0.78–1.0  (7–9s)     圆形静止等待
  static const _totalMs = 9000;
  static const _expandEnd = 0.06;
  static const _holdEnd = 0.72;
  static const _shrinkEnd = 0.78;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 展开/收回进度 0→1→0
  double _widthProgress(double t) {
    if (t < _expandEnd) {
      return Curves.easeOutCubic.transform(t / _expandEnd);
    } else if (t < _holdEnd) {
      return 1.0;
    } else if (t < _shrinkEnd) {
      return 1.0 - Curves.easeInCubic.transform((t - _holdEnd) / (_shrinkEnd - _holdEnd));
    }
    return 0.0;
  }

  /// 文字透明度：展开后半段淡入，收回前半段淡出
  double _textOpacity(double t) {
    if (t < _expandEnd * 0.6) return 0.0;
    if (t < _expandEnd) {
      return Curves.easeOut.transform((t - _expandEnd * 0.6) / (_expandEnd * 0.4));
    }
    if (t < _holdEnd) return 1.0;
    if (t < _holdEnd + (_shrinkEnd - _holdEnd) * 0.4) {
      return 1.0 - Curves.easeIn.transform(
        (t - _holdEnd) / ((_shrinkEnd - _holdEnd) * 0.4),
      );
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final wp = _widthProgress(t);
        final tp = _textOpacity(t);

        // 圆形 36px → 胶囊 110px
        final width = 36.0 + (110.0 - 36.0) * wp;
        final radius = 18.0 + 2.0 * wp; // 18→20

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                height: 36,
                width: width,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withAlpha(200)],
                  ),
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withAlpha(50),
                      blurRadius: 4 + wp * 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: onPrimary),
                    if (tp > 0.01) ...[
                      SizedBox(width: 6 * wp),
                      Flexible(
                        child: Opacity(
                          opacity: tp.clamp(0.0, 1.0),
                          child: Text(
                            'AI 推荐',
                            style: TextStyle(
                              color: onPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
