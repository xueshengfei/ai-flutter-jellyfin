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

/// 完整字母表 A-Z + #
const _fullAlphabet = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#',
];

// ==================== 分组滚动视图 ====================

/// 泛型分组滚动视图
///
/// 支持 poster/card 模式下的字母分组网格 + 侧边字母索引，
/// 支持 list/banner 模式下的扁平列表。
/// 字母索引始终显示完整 A-Z + #，无数据的字母灰显。
///
/// 点击字母时通过 [onLetterFilter] 回调通知父组件重新请求数据（服务端过滤），
/// 再次点击同一字母取消过滤。
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

  /// 点击字母时的服务端过滤回调
  /// 传入 null 表示取消过滤（加载全部），传入字母表示按该字母过滤
  final Future<void> Function(String? letter)? onLetterFilter;

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
    this.onLetterFilter,
  });

  @override
  State<MediaGroupedScrollView<T>> createState() =>
      _MediaGroupedScrollViewState<T>();
}

class _MediaGroupedScrollViewState<T>
    extends State<MediaGroupedScrollView<T>> {
  late ScrollController _scrollController;
  String _activeLetter = '';
  Set<String> _activeLetters = {}; // 有数据的字母集合
  String? _filterLetter; // null = 显示全部，非 null = 服务端已过滤到该字母
  Map<String, List<T>> _grouped = {};
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
    _activeLetters = _grouped.keys.toSet();
    _headerKeys.clear();
    for (final letter in _fullAlphabet) {
      _headerKeys[letter] = GlobalKey();
    }
    if (_activeLetters.isNotEmpty && _activeLetter.isEmpty) {
      _activeLetter = _activeLetters.first;
    }
  }

  /// 获取某个分组头的屏幕 Y 坐标，不可见返回 null
  double? _headerY(String letter) {
    final key = _headerKeys[letter];
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero, ancestor: null).dy;
  }

  /// 二分查找当前可见的分组字母
  void _onScroll() {
    if (_grouped.isEmpty || _filterLetter != null) return;
    final visibleLetters = _grouped.keys.where((l) => _activeLetters.contains(l)).toList();
    if (visibleLetters.isEmpty) return;
    int lo = 0, hi = visibleLetters.length - 1;
    String? found;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final dy = _headerY(visibleLetters[mid]);
      if (dy == null) {
        if (found != null) break;
        return;
      }
      if (dy <= _headerHeight) {
        found = visibleLetters[mid];
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (found != null && found != _activeLetter && mounted) {
      setState(() => _activeLetter = found!);
    }
  }

  /// 点击字母：通过回调通知父组件进行服务端过滤
  void _onLetterTap(String letter) {
    if (widget.onLetterFilter != null) {
      // 服务端过滤模式
      final newFilter = _filterLetter == letter ? null : letter;
      setState(() {
        _filterLetter = newFilter;
        _activeLetter = letter;
      });
      widget.onLetterFilter!(newFilter);
    } else {
      // 本地过滤模式（无回调时的 fallback）
      setState(() {
        if (_filterLetter == letter) {
          _filterLetter = null;
        } else {
          _filterLetter = letter;
        }
        _activeLetter = letter;
      });
    }
  }

  /// 取消过滤
  void _clearFilter() {
    setState(() => _filterLetter = null);
    if (widget.onLetterFilter != null) {
      widget.onLetterFilter!(null);
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
            // 过滤指示器
            if (_filterLetter != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 40, 4),
                  child: Row(
                    children: [
                      Chip(
                        label: Text('$_filterLetter'),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: _clearFilter,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.items.length} 项',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            // 服务端过滤模式：所有数据都匹配当前字母，直接显示网格
            if (_filterLetter != null)
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
                      return widget.gridItemBuilder(context, widget.items[index]);
                    },
                    childCount: widget.items.length,
                  ),
                ),
              )
            else
              // 非过滤模式：按字母分组显示
              for (final letter in _grouped.keys.where((l) => _activeLetters.contains(l)).toList()) ...[
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
          letters: _fullAlphabet,
          availableLetters: _fullAlphabet.toSet(), // 服务端过滤模式下所有字母都可点击
          activeLetter: _activeLetter,
          onLetterTap: _onLetterTap,
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
