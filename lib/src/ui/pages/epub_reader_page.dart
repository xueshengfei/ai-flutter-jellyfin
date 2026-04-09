import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

// ==================== EPUB 阅读器页面 ====================

/// EPUB 电子书阅读器页面
///
/// 功能：
/// - 从 Jellyfin 下载 EPUB 并解析
/// - 章节目录导航
/// - 左右滑动翻页
/// - 阅读进度显示
/// - 字体大小调节
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

  // 扁平化的章节列表（含子章节）
  List<_FlatChapter> _chapters = [];
  int _currentChapterIndex = 0;

  // 阅读设置
  double _fontSize = 18.0;
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadEpub();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 下载并解析 EPUB
  Future<void> _loadEpub() async {
    setState(() { _isLoading = true; _error = null; _loadProgress = 0; });

    try {
      final downloadUrl = widget.book.getDownloadUrl();
      final dio = Dio();

      // 下载 EPUB 文件
      final response = await dio.get<List<int>>(
        downloadUrl,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() => _loadProgress = received / total);
          }
        },
      );

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('下载的文件为空');
      }

      setState(() => _loadProgress = 0.5);

      // 解析 EPUB
      final epubBook = await EpubReader.readBook(response.data!);

      setState(() {
        _epubBook = epubBook;
        _loadProgress = 1.0;
      });

      // 扁平化章节
      _flattenChapters(epubBook.Chapters ?? []);

      if (_chapters.isEmpty) {
        // 如果没有章节结构，尝试从 Content 中提取所有 HTML 文件
        _extractFromContent(epubBook);
      }

      setState(() { _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _error = '$e'; _isLoading = false; });
      }
    }
  }

  /// 将嵌套章节扁平化
  void _flattenChapters(List<EpubChapter> chapters, {int level = 0}) {
    for (final chapter in chapters) {
      if (chapter.HtmlContent != null && chapter.HtmlContent!.trim().isNotEmpty) {
        _chapters.add(_FlatChapter(
          title: chapter.Title ?? '未命名章节',
          htmlContent: chapter.HtmlContent!,
          level: level,
        ));
      }
      if (chapter.SubChapters?.isNotEmpty == true) {
        _flattenChapters(chapter.SubChapters!, level: level + 1);
      }
    }
  }

  /// 当没有章节结构时，从 Content 中提取 HTML
  void _extractFromContent(EpubBook epubBook) {
    final content = epubBook.Content;
    if (content == null) return;

    // 从 HTML 文件中提取内容
    final htmlFiles = content.Html;
    if (htmlFiles != null && htmlFiles.isNotEmpty) {
      for (final entry in htmlFiles.entries) {
        final fileName = entry.key;
        final file = entry.value;
        final text = file.Content;
        if (text != null && text.trim().isNotEmpty) {
          _chapters.add(_FlatChapter(
            title: fileName.replaceAll('.html', '').replaceAll('.xhtml', ''),
            htmlContent: text,
            level: 0,
          ));
        }
      }
    }
  }

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
        // 章节目录
        IconButton(
          icon: const Icon(Icons.list),
          tooltip: '目录',
          onPressed: _epubBook != null ? _showChapterList : null,
        ),
        // 字体大小
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
        // 章节内容 - PageView 实现左右翻页
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _chapters.length,
            onPageChanged: (index) {
              setState(() => _currentChapterIndex = index);
            },
            itemBuilder: (context, index) {
              return _ChapterView(
                chapter: _chapters[index],
                fontSize: _fontSize,
                scrollController: index == _currentChapterIndex ? _scrollController : null,
              );
            },
          ),
        ),
        // 底部进度条
        _buildProgress(),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('正在加载电子书...'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: LinearProgressIndicator(value: _loadProgress > 0 ? _loadProgress : null),
          ),
        ],
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
            // 拖拽指示条
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
              onPressed: () {
                setState(() => _fontSize = 18.0);
              },
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

// ==================== 章节视图 ====================

class _ChapterView extends StatelessWidget {
  final _FlatChapter chapter;
  final double fontSize;
  final ScrollController? scrollController;

  const _ChapterView({
    required this.chapter,
    required this.fontSize,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final plainText = _htmlToPlainText(chapter.htmlContent);

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 章节标题
          if (chapter.title.isNotEmpty && chapter.level == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                chapter.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          // 正文
          SelectableText(
            plainText,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.8,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  /// 将 HTML 转为纯文本，保留段落结构
  String _htmlToPlainText(String html) {
    var text = html;

    // 移除 <style> 和 <script> 块
    text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');

    // 将块级元素替换为换行
    final blockTags = ['p', 'div', 'br', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'tr'];
    for (final tag in blockTags) {
      // 自闭合标签 (br, hr)
      if (tag == 'br') {
        text = text.replaceAll(RegExp('<br\s*/?\s*>', caseSensitive: false), '\n');
        continue;
      }
      // 闭合标签加换行
      text = text.replaceAll(RegExp('</\s*$tag\s*>', caseSensitive: false), '\n');
    }

    // 处理水平线
    text = text.replaceAll(RegExp('<hr\s*/?\s*>', caseSensitive: false), '\n———\n');

    // 移除所有剩余 HTML 标签
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // 解码 HTML 实体
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&mdash;', '——');
    text = text.replaceAll('&ndash;', '–');
    text = text.replaceAll('&hellip;', '…');

    // 清理多余空白
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n[ \t]+'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }
}

// ==================== 扁平化章节数据 ====================

class _FlatChapter {
  final String title;
  final String htmlContent;
  final int level;

  const _FlatChapter({
    required this.title,
    required this.htmlContent,
    required this.level,
  });
}
