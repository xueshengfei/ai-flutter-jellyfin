import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

// ==================== 阅读主题 ====================

/// 阅读主题枚举
enum ReadingTheme {
  dark,
  sepia,
  light;

  Color get textColor {
    switch (this) {
      case ReadingTheme.dark:
        return const Color(0xFFD8DADC);
      case ReadingTheme.sepia:
        return const Color(0xFFD8A262);
      case ReadingTheme.light:
        return const Color(0xFF000000);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ReadingTheme.dark:
        return const Color(0xFF1A1A1A);
      case ReadingTheme.sepia:
        return const Color(0xFF2A2118);
      case ReadingTheme.light:
        return const Color(0xFFFFFFFF);
    }
  }

  IconData get icon {
    switch (this) {
      case ReadingTheme.dark:
        return Icons.dark_mode;
      case ReadingTheme.sepia:
        return Icons.auto_fix_high;
      case ReadingTheme.light:
        return Icons.light_mode;
    }
  }

  String get displayName {
    switch (this) {
      case ReadingTheme.dark:
        return '深色';
      case ReadingTheme.sepia:
        return '护眼';
      case ReadingTheme.light:
        return '浅色';
    }
  }

  ReadingTheme get next => ReadingTheme.values[(index + 1) % ReadingTheme.values.length];
}

// ==================== EPUB 阅读器页面 ====================

/// EPUB 电子书阅读器页面
///
/// 加载策略（类似起点）：
/// 1. 下载 EPUB 文件
/// 2. Isolate 解析 ZIP → 只提取目录（标题 + HTML 原文），不做文本转换
/// 3. 立即展示阅读器（第一章按需渲染）
/// 4. 翻页时按需转换当前 ±2 章的 HTML→纯文本，其余后台预读
class EpubReaderPage extends StatefulWidget {
  final JellyfinClient client;
  final Book book;

  const EpubReaderPage({
    super.key,
    required this.client,
    required this.book,
  });

  @override
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage> {
  EpubBook? _epubBook;
  bool _isLoading = true;
  String? _error;
  double _loadProgress = 0;
  String _loadStage = '准备中...';

  List<_FlatChapter> _chapters = [];
  int _currentChapterIndex = 0;

  double _fontSize = 18.0;
  ReadingTheme _theme = ReadingTheme.light;
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _theme = brightness == Brightness.dark ? ReadingTheme.dark : ReadingTheme.light;
    _loadEpub();
  }

  @override
  void dispose() {
    _reportProgressSync();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== 加载流程 ====================

  /// 下载 → 解析目录 → 立即展示
  Future<void> _loadEpub() async {
    setState(() { _isLoading = true; _error = null; _loadProgress = 0; _loadStage = '下载中...'; });

    try {
      final downloadUrl = widget.book.getDownloadUrl();

      // 1. 下载 EPUB（节流进度）
      var lastProgressTime = DateTime.now();
      final response = await Dio().get<List<int>>(
        downloadUrl,
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final now = DateTime.now();
            if (now.difference(lastProgressTime).inMilliseconds > 200) {
              lastProgressTime = now;
              setState(() => _loadProgress = received / total * 0.8);
            }
          }
        },
      );

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('下载的文件为空');
      }

      setState(() { _loadProgress = 0.8; _loadStage = '解析目录...'; });

      // 2. Isolate 解析 → 只提取目录结构，不做 HTML→文本转换
      final bytes = Uint8List.fromList(response.data!);
      _ParseResult result;
      try {
        result = await Isolate.run(() => _parseEpubStructure(bytes));
      } on UnsupportedError {
        result = await _parseEpubStructure(bytes);
      }

      // 3. 立即展示阅读器（不等文本转换）
      setState(() {
        _epubBook = result.epubBook;
        _chapters = result.chapters;
        _isLoading = false;
      });

      // 4. 恢复上次位置，然后预读邻居章节
      _restoreReadingPosition();
      _precomputeAdjacent();
      _precomputeRemainingInBackground();
    } catch (e) {
      if (mounted) {
        setState(() { _error = '$e'; _isLoading = false; });
      }
    }
  }

  // ==================== 按需预读 ====================

  /// 预读当前章节 ± 2 章（同步，通常 < 100ms）
  void _precomputeAdjacent() {
    if (_chapters.isEmpty) return;
    final lo = (_currentChapterIndex - 2).clamp(0, _chapters.length);
    final hi = (_currentChapterIndex + 3).clamp(0, _chapters.length);
    for (var i = lo; i < hi; i++) {
      _chapters[i].ensurePlainText();
    }
  }

  /// 后台预读全部剩余章节（每 3 章让一次事件循环）
  void _precomputeRemainingInBackground() async {
    for (var i = 0; i < _chapters.length; i++) {
      if (!_chapters[i].isReady) {
        _chapters[i].ensurePlainText();
        if (i % 3 == 0) await Future.delayed(Duration.zero);
      }
    }
  }

  // ==================== 进度恢复 & 上报 ====================

  void _restoreReadingPosition() {
    final pct = widget.book.playedPercentage;
    if (pct == null || pct <= 0 || _chapters.isEmpty) return;

    final target = (pct / 100 * _chapters.length).floor().clamp(0, _chapters.length - 1);
    _currentChapterIndex = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pageController.jumpToPage(target);
    });
  }

  void _reportProgress() {
    if (_chapters.isEmpty) return;
    final pct = (_currentChapterIndex + 1) / _chapters.length * 100;
    widget.client.user.updateUserItemData(
      itemId: widget.book.id,
      playedPercentage: pct,
    ).catchError((_) {});
  }

  void _reportProgressSync() {
    if (_chapters.isEmpty) return;
    final pct = (_currentChapterIndex + 1) / _chapters.length * 100;
    widget.client.user.updateUserItemData(
      itemId: widget.book.id,
      playedPercentage: pct,
    ).catchError((_) {});
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _epubBook?.Title ?? widget.book.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: Icon(_theme.icon),
          tooltip: '主题: ${_theme.displayName}',
          onPressed: () => setState(() => _theme = _theme.next),
        ),
        IconButton(
          icon: const Icon(Icons.list),
          tooltip: '目录',
          onPressed: _epubBook != null ? _showChapterList : null,
        ),
        IconButton(
          icon: const Icon(Icons.text_fields),
          tooltip: '字体大小',
          onPressed: _epubBook != null ? _showFontSizeDialog : null,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoading();
    if (_error != null) return _buildError();
    if (_chapters.isEmpty) return const Center(child: Text('此书无可用内容'));

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _chapters.length,
            onPageChanged: (index) {
              setState(() => _currentChapterIndex = index);
              _precomputeAdjacent();
              _reportProgress();
            },
            itemBuilder: (context, index) => _ChapterView(
              chapter: _chapters[index],
              fontSize: _fontSize,
              theme: _theme,
              scrollController: index == _currentChapterIndex ? _scrollController : null,
            ),
          ),
        ),
        _buildProgress(),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_loadStage),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _loadProgress > 0 ? _loadProgress : null),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadEpub, child: const Text('重试')),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              _chapters.isNotEmpty ? '${_currentChapterIndex + 1} / ${_chapters.length}' : '',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LinearProgressIndicator(
                value: _chapters.isNotEmpty ? (_currentChapterIndex + 1) / _chapters.length : 0,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _chapters.isNotEmpty ? _chapters[_currentChapterIndex].title : '',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示章节目录
  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('目录', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${_chapters.length} 章', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _chapters.length,
                itemBuilder: (context, index) {
                  final chapter = _chapters[index];
                  final isCurrent = index == _currentChapterIndex;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.only(
                      left: 16.0 + chapter.level * 16.0,
                      right: 16,
                    ),
                    selected: isCurrent,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    leading: isCurrent
                        ? const Icon(Icons.play_arrow, size: 18)
                        : Text('${index + 1}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    title: Text(
                      chapter.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      _pageController.jumpToPage(index);
                      setState(() => _currentChapterIndex = index);
                      _precomputeAdjacent();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示字体大小调节对话框
  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('字体大小'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('示例文字', style: TextStyle(fontSize: _fontSize)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.text_decrease),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 12,
                      max: 32,
                      divisions: 10,
                      label: _fontSize.round().toString(),
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                  const Icon(Icons.text_increase),
                ],
              ),
              Text('${_fontSize.round()}px', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => setState(() => _fontSize = 18.0),
              child: const Text('默认'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                this.setState(() {});
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Isolate 解析：只提取结构 ====================

/// Isolate 中运行 — 只提取目录 + HTML 原文，不做文本转换
Future<_ParseResult> _parseEpubStructure(Uint8List bytes) async {
  final epubBook = await EpubReader.readBook(bytes);

  final chapters = <_FlatChapter>[];

  void flatten(List<EpubChapter> chs, int level) {
    for (final ch in chs) {
      if (ch.HtmlContent != null && ch.HtmlContent!.trim().isNotEmpty) {
        chapters.add(_FlatChapter(
          title: ch.Title ?? '未命名章节',
          htmlContent: ch.HtmlContent!,
          level: level,
        ));
      }
      if (ch.SubChapters?.isNotEmpty == true) {
        flatten(ch.SubChapters!, level + 1);
      }
    }
  }

  flatten(epubBook.Chapters ?? [], 0);

  if (chapters.isEmpty) {
    final htmlFiles = epubBook.Content?.Html;
    if (htmlFiles != null && htmlFiles.isNotEmpty) {
      for (final entry in htmlFiles.entries) {
        final text = entry.value.Content;
        if (text != null && text.trim().isNotEmpty) {
          chapters.add(_FlatChapter(
            title: entry.key.replaceAll('.html', '').replaceAll('.xhtml', ''),
            htmlContent: text,
            level: 0,
          ));
        }
      }
    }
  }

  return _ParseResult(epubBook: epubBook, chapters: chapters);
}

// ==================== HTML → 纯文本 ====================

String _htmlToPlainText(String html) {
  var t = html;
  t = t.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
  t = t.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');

  for (final tag in const ['p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'tr']) {
    t = t.replaceAll(RegExp('</\\s*$tag\\s*>', caseSensitive: false), '\n');
  }
  t = t.replaceAll(RegExp('<br\\s*/?\\s*>', caseSensitive: false), '\n');
  t = t.replaceAll(RegExp('<hr\\s*/?\\s*>', caseSensitive: false), '\n———\n');
  t = t.replaceAll(RegExp(r'<[^>]+>'), '');

  t = t.replaceAll('&nbsp;', ' ');
  t = t.replaceAll('&amp;', '&');
  t = t.replaceAll('&lt;', '<');
  t = t.replaceAll('&gt;', '>');
  t = t.replaceAll('&quot;', '"');
  t = t.replaceAll('&#39;', "'");
  t = t.replaceAll('&mdash;', '——');
  t = t.replaceAll('&ndash;', '–');
  t = t.replaceAll('&hellip;', '…');

  t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
  t = t.replaceAll(RegExp(r'\n[ \t]+'), '\n');
  t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return t.trim();
}

// ==================== 章节视图 ====================

class _ChapterView extends StatelessWidget {
  final _FlatChapter chapter;
  final double fontSize;
  final ReadingTheme theme;
  final ScrollController? scrollController;

  const _ChapterView({
    required this.chapter,
    required this.fontSize,
    required this.theme,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final text = chapter.plainText; // 首次访问按需转换，之后命中缓存

    return Container(
      color: theme.backgroundColor,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chapter.title.isNotEmpty && chapter.level == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  chapter.title,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textColor),
                ),
              ),
            SelectableText(
              text,
              style: TextStyle(fontSize: fontSize, height: 1.8, letterSpacing: 0.3, color: theme.textColor),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ==================== 数据类 ====================

class _ParseResult {
  final EpubBook epubBook;
  final List<_FlatChapter> chapters;
  const _ParseResult({required this.epubBook, required this.chapters});
}

/// 扁平化章节 — 纯文本懒加载（首次访问时才转换，缓存复用）
class _FlatChapter {
  final String title;
  final String htmlContent;
  final int level;

  /// 纯文本缓存（null = 尚未转换）
  String? _plainText;

  _FlatChapter({
    required this.title,
    required this.htmlContent,
    required this.level,
  });

  /// 是否已转换
  bool get isReady => _plainText != null;

  /// 获取纯文本（懒加载：首次调用转换，之后返回缓存）
  String get plainText => _plainText ??= _htmlToPlainText(htmlContent);

  /// 预计算（后台调用，不阻塞首次渲染）
  void ensurePlainText() {
    _plainText ??= _htmlToPlainText(htmlContent);
  }
}
