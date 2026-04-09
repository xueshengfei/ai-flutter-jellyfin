import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

// ==================== 分组工具函数 ====================

/// 提取首字母：A-Z 或 "#"（非字母归入 #）
String _getSortLetter(String? sortName, String? name) {
  final text = (sortName ?? name ?? '').trim();
  if (text.isEmpty) return '#';
  final upper = text.toUpperCase();
  final codeUnit = upper.codeUnitAt(0);
  if (codeUnit >= 65 && codeUnit <= 90) return upper[0];
  return '#';
}

/// 按首字母分组并排序
Map<String, List<T>> _groupByFirstLetter<T>(
  List<T> items,
  String? Function(T) getSortName,
  String? Function(T) getName,
) {
  final map = <String, List<T>>{};
  for (final item in items) {
    final letter = _getSortLetter(getSortName(item), getName(item));
    (map[letter] ??= []).add(item);
  }
  final sortedKeys = map.keys.toList()
    ..sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });
  return {for (final k in sortedKeys) k: map[k]!};
}

// ==================== 分组滚动视图 ====================

/// 泛型分组滚动视图
///
/// 支持 poster/card 模式下的字母分组网格 + 侧边字母索引，
/// 支持 list/banner 模式下的扁平列表。
class MediaGroupedScrollView<T> extends StatefulWidget {
  final ViewModeConfig config;
  final List<T> items;
  final Future<void> Function() onRefresh;

  // 分组回调
  final String? Function(T) getSortName;
  final String? Function(T) getName;

  /// poster/card 网格模式：每个 item 构建一个卡片
  final Widget Function(BuildContext context, T item) gridItemBuilder;

  /// list/banner 扁平模式：每个 item 构建一行
  final Widget Function(BuildContext context, T item, int index) flatItemBuilder;

  /// 网格模式 childAspectRatio，默认 0.75
  final double gridChildAspectRatio;

  const MediaGroupedScrollView({
    super.key,
    required this.config,
    required this.items,
    required this.onRefresh,
    required this.getSortName,
    required this.getName,
    required this.gridItemBuilder,
    required this.flatItemBuilder,
    this.gridChildAspectRatio = 0.75,
  });

  @override
  State<MediaGroupedScrollView<T>> createState() =>
      _MediaGroupedScrollViewState<T>();
}

class _MediaGroupedScrollViewState<T>
    extends State<MediaGroupedScrollView<T>> {
  late ScrollController _scrollController;
  String _activeLetter = '';
  Map<String, List<T>> _grouped = {};
  List<String> _letters = [];
  final Map<String, GlobalKey> _headerKeys = {};
  static const double _headerHeight = 48.0;

  bool get _useIndex =>
      widget.config.viewMode == ViewMode.poster ||
      widget.config.viewMode == ViewMode.card;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _rebuildGroups();
  }

  @override
  void didUpdateWidget(covariant MediaGroupedScrollView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items ||
        oldWidget.getSortName != widget.getSortName ||
        oldWidget.getName != widget.getName) {
      _rebuildGroups();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuildGroups() {
    _grouped = _groupByFirstLetter(
      widget.items,
      widget.getSortName,
      widget.getName,
    );
    _letters = _grouped.keys.toList();
    _headerKeys.clear();
    for (final letter in _letters) {
      _headerKeys[letter] = GlobalKey();
    }
    if (_letters.isNotEmpty) _activeLetter = _letters.first;
  }

  /// 获取某个分组头的屏幕 Y 坐标，不可见返回 null
  double? _headerY(String letter) {
    final key = _headerKeys[letter];
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero, ancestor: null).dy;
  }

  /// 二分查找当前可见的分组字母
  ///
  /// letters 的 header Y 坐标随下标单调递增，
  /// 找最后一个 dy <= _headerHeight 的即为当前激活分组。
  void _onScroll() {
    if (_letters.isEmpty) return;
    int lo = 0, hi = _letters.length - 1;
    String? found;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final dy = _headerY(_letters[mid]);
      if (dy == null) {
        // 该分组头尚未布局，跳过
        // 尝试向两边查找
        if (found != null) break;
        return;
      }
      if (dy <= _headerHeight) {
        found = _letters[mid];
        lo = mid + 1; // 继续向右找更大的匹配
      } else {
        hi = mid - 1;
      }
    }
    if (found != null && found != _activeLetter && mounted) {
      setState(() => _activeLetter = found!);
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

  @override
  Widget build(BuildContext context) {
    if (!_useIndex) return _buildFlatList();
    return _buildGroupedGrid();
  }

  Widget _buildGroupedGrid() {
    return Stack(children: [
      RefreshIndicator(
        onRefresh: widget.onRefresh,
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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.config.crossAxisCount,
                    childAspectRatio: widget.gridChildAspectRatio,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _grouped[letter]![index];
                      return widget.gridItemBuilder(context, item);
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
        child: AlphabetIndexBar(
          letters: _letters,
          activeLetter: _activeLetter,
          onLetterTap: _scrollToLetter,
        ),
      ),
    ]);
  }

  Widget _buildFlatList() {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          return widget.flatItemBuilder(context, widget.items[index], index);
        },
      ),
    );
  }
}
