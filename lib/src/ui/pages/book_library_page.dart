import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

// ==================== 书籍媒体库页面 ====================

/// 书籍媒体库页面
///
/// Tab 页：电子书 | 有声书 | 系列
class BookLibraryPage extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  final String libraryName;

  const BookLibraryPage({
    super.key,
    required this.client,
    required this.libraryId,
    required this.libraryName,
  });

  @override
  State<BookLibraryPage> createState() => _BookLibraryPageState();
}

class _BookLibraryPageState extends State<BookLibraryPage>
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
            Tab(text: '电子书', icon: Icon(Icons.menu_book)),
            Tab(text: '有声书', icon: Icon(Icons.headphones)),
            Tab(text: '系列', icon: Icon(Icons.collections_bookmark)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BooksTab(client: widget.client, libraryId: widget.libraryId),
          _AudioBooksTab(client: widget.client, libraryId: widget.libraryId),
          _SeriesTab(client: widget.client, libraryId: widget.libraryId),
        ],
      ),
    );
  }
}

// ==================== 电子书 Tab ====================

class _BooksTab extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  const _BooksTab({required this.client, required this.libraryId});
  @override
  State<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<_BooksTab> with AutomaticKeepAliveClientMixin {
  List<Book> _books = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.book.getBooks(parentId: widget.libraryId, limit: 200);
      if (mounted) setState(() { _books = result.books; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, _load);
    if (_books.isEmpty) return const Center(child: Text('暂无电子书'));

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];
          return _BookCard(
            book: book,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => BookDetailPage(client: widget.client, book: book),
            )),
          );
        },
      ),
    );
  }
}

// ==================== 有声书 Tab ====================

class _AudioBooksTab extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  const _AudioBooksTab({required this.client, required this.libraryId});
  @override
  State<_AudioBooksTab> createState() => _AudioBooksTabState();
}

class _AudioBooksTabState extends State<_AudioBooksTab> with AutomaticKeepAliveClientMixin {
  List<AudioBook> _audioBooks = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.book.getAudioBooks(parentId: widget.libraryId, limit: 200);
      if (mounted) setState(() { _audioBooks = result.audioBooks; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, _load);
    if (_audioBooks.isEmpty) return const Center(child: Text('暂无有声书'));

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _audioBooks.length,
        itemBuilder: (context, index) {
          final audioBook = _audioBooks[index];
          return _AudioBookCard(
            audioBook: audioBook,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AudioBookDetailPage(client: widget.client, audioBook: audioBook),
            )),
          );
        },
      ),
    );
  }
}

// ==================== 系列 Tab ====================

class _SeriesTab extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  const _SeriesTab({required this.client, required this.libraryId});
  @override
  State<_SeriesTab> createState() => _SeriesTabState();
}

class _SeriesTabState extends State<_SeriesTab> with AutomaticKeepAliveClientMixin {
  List<BookSeries> _series = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await widget.client.book.getBookSeries(parentId: widget.libraryId, limit: 100);
      if (mounted) setState(() { _series = result.series; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError(_error!, _load);
    if (_series.isEmpty) return const Center(child: Text('暂无系列'));

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _series.length,
        itemBuilder: (context, index) {
          final series = _series[index];
          return _SeriesCard(
            series: series,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => BookSeriesDetailPage(client: widget.client, series: series),
            )),
          );
        },
      ),
    );
  }
}

// ==================== 书籍详情页 ====================

/// 电子书详情页
class BookDetailPage extends StatelessWidget {
  final JellyfinClient client;
  final Book book;

  const BookDetailPage({super.key, required this.client, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(book.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面 + 基本信息
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面
                Container(
                  width: 120,
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: book.hasCoverImage
                      ? JellyfinImageWithClient(
                          client: client,
                          itemId: book.id,
                          imageTag: book.primaryImageTag,
                          fillWidth: 240,
                          fillHeight: 340,
                          fit: BoxFit.cover,
                          placeholder: _placeholder(context, Icons.menu_book),
                          errorWidget: _placeholder(context, Icons.menu_book),
                        )
                      : _placeholder(context, Icons.menu_book),
                ),
                const SizedBox(width: 16),
                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      if (book.authors?.isNotEmpty == true)
                        _infoRow(context, Icons.person, book.authorText),
                      if (book.publishers?.isNotEmpty == true)
                        _infoRow(context, Icons.business, book.publisherText),
                      if (book.productionYear != null)
                        _infoRow(context, Icons.calendar_today, '${book.productionYear}年'),
                      if (book.genres?.isNotEmpty == true)
                        _infoRow(context, Icons.category, book.genres!.join(' / ')),
                      if (book.communityRating != null)
                        _infoRow(context, Icons.star, book.communityRating!.toStringAsFixed(1)),
                    ],
                  ),
                ),
              ],
            ),

            // 阅读进度
            if (book.playedPercentage != null && book.playedPercentage! > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: book.playedPercentage! / 100),
              const SizedBox(height: 4),
              Text('已读 ${book.playedPercentage!.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],

            // 阅读按钮
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => EpubReaderPage(client: client, book: book),
                )),
                icon: const Icon(Icons.menu_book),
                label: Text(book.playedPercentage != null && book.playedPercentage! > 0 ? '继续阅读' : '开始阅读'),
              ),
            ),

            // 简介
            if (book.overview != null && book.overview!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('简介', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(book.overview!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// 有声书详情页
class AudioBookDetailPage extends StatelessWidget {
  final JellyfinClient client;
  final AudioBook audioBook;

  const AudioBookDetailPage({super.key, required this.client, required this.audioBook});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(audioBook.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面 + 基本信息
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: audioBook.hasCoverImage
                      ? JellyfinImageWithClient(
                          client: client,
                          itemId: audioBook.id,
                          imageTag: audioBook.primaryImageTag,
                          fillWidth: 240,
                          fillHeight: 240,
                          fit: BoxFit.cover,
                          placeholder: _placeholder(context, Icons.headphones),
                          errorWidget: _placeholder(context, Icons.headphones),
                        )
                      : _placeholder(context, Icons.headphones),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(audioBook.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      if (audioBook.authors?.isNotEmpty == true)
                        _infoRow(context, Icons.person, audioBook.authorText),
                      if (audioBook.durationText.isNotEmpty)
                        _infoRow(context, Icons.timer, audioBook.durationText),
                      if (audioBook.productionYear != null)
                        _infoRow(context, Icons.calendar_today, '${audioBook.productionYear}年'),
                    ],
                  ),
                ),
              ],
            ),

            // 播放按钮
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  // 有声书播放：构建播放列表并启动
                  final song = MusicSong(
                    id: audioBook.id,
                    name: audioBook.name,
                    serverUrl: client.configuration.serverUrl,
                    accessToken: client.configuration.accessToken,
                    artists: audioBook.authors,
                    runTimeTicks: audioBook.runTimeTicks,
                  );
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AudioPlayerPage(
                      client: client, song: song, playlist: [song], initialIndex: 0,
                    ),
                  ));
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(audioBook.playedPercentage != null && audioBook.playedPercentage! > 0 ? '继续播放' : '开始播放'),
              ),
            ),

            // 播放进度
            if (audioBook.playedPercentage != null && audioBook.playedPercentage! > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: audioBook.playedPercentage! / 100),
              const SizedBox(height: 4),
              Text('已播放 ${audioBook.playedPercentage!.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],

            // 简介
            if (audioBook.overview != null && audioBook.overview!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('简介', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(audioBook.overview!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// 书籍系列详情页
class BookSeriesDetailPage extends StatefulWidget {
  final JellyfinClient client;
  final BookSeries series;

  const BookSeriesDetailPage({super.key, required this.client, required this.series});
  @override
  State<BookSeriesDetailPage> createState() => _BookSeriesDetailPageState();
}

class _BookSeriesDetailPageState extends State<BookSeriesDetailPage> {
  List<Book> _books = [];
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
      final result = await widget.client.book.getBookSeriesBooks(widget.series.id);
      if (mounted) setState(() { _books = result.books; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.series.name)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(_error!, _load)
              : _books.isEmpty
                  ? const Center(child: Text('系列中暂无书籍'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _books.length,
                      itemBuilder: (context, index) => _BookCard(
                        book: _books[index],
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => BookDetailPage(client: widget.client, book: _books[index]),
                        )),
                      ),
                    ),
    );
  }
}

// ==================== 通用卡片组件 ====================

class _BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _BookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  book.hasCoverImage
                      ? Image.network(
                          book.getCoverImageUrl(fillWidth: 200, fillHeight: 300)!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(context),
                        )
                      : _placeholder(context),
                  // 阅读进度条
                  if (book.playedPercentage != null && book.playedPercentage! > 0)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: LinearProgressIndicator(
                        value: book.playedPercentage! / 100,
                        backgroundColor: Colors.black26,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                ],
              ),
            ),
            // 信息
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  if (book.authors?.isNotEmpty == true)
                    Text(book.authorText,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: const Center(child: Icon(Icons.menu_book, size: 48, color: Colors.white54)),
  );
}

class _AudioBookCard extends StatelessWidget {
  final AudioBook audioBook;
  final VoidCallback onTap;

  const _AudioBookCard({required this.audioBook, required this.onTap});

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
              child: audioBook.hasCoverImage
                  ? Image.network(
                      audioBook.getCoverImageUrl(fillWidth: 200, fillHeight: 200)!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(audioBook.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  if (audioBook.authors?.isNotEmpty == true)
                    Text(audioBook.authorText,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  if (audioBook.durationText.isNotEmpty)
                    Text(audioBook.durationText,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: const Center(child: Icon(Icons.headphones, size: 48, color: Colors.white54)),
  );
}

class _SeriesCard extends StatelessWidget {
  final BookSeries series;
  final VoidCallback onTap;

  const _SeriesCard({required this.series, required this.onTap});

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
              child: series.hasCoverImage
                  ? Image.network(
                      series.getCoverImageUrl(fillWidth: 200, fillHeight: 200)!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(series.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  if (series.bookCount != null)
                    Text('${series.bookCount} 本',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: const Center(child: Icon(Icons.collections_bookmark, size: 48, color: Colors.white54)),
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

Widget _placeholder(BuildContext context, IconData icon) => Container(
  color: Theme.of(context).colorScheme.primaryContainer,
  child: Center(child: Icon(icon, size: 56, color: Colors.white54)),
);
