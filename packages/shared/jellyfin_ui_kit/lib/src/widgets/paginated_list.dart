import 'package:flutter/material.dart';

import '../models/paged_result.dart';
import 'pagination_nav_bar.dart';

typedef PaginatedItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
);

typedef PaginatedContentBuilder<T> = Widget Function(
  BuildContext context,
  PaginatedPage<T> page,
);

/// Immutable snapshot for rendering the currently loaded page.
class PaginatedPage<T> {
  final List<T> items;
  final int startIndex;
  final int pageSize;
  final int totalCount;
  final bool isLoading;
  final EdgeInsets padding;
  final PaginatedItemBuilder<T> itemBuilder;

  const PaginatedPage({
    required this.items,
    required this.startIndex,
    required this.pageSize,
    required this.totalCount,
    required this.isLoading,
    required this.padding,
    required this.itemBuilder,
  });
}

/// 分页列表组件
///
/// 自动管理分页状态：顶部和底部各一条 [PaginationNavBar]，
/// 数据量 <= [pageSize] 时自动隐藏导航条。
///
/// 使用方式：
/// ```dart
/// PaginatedList<MyItem>(
///   fetcher: ({required startIndex, required limit}) async {
///     final result = await api.fetch(startIndex: startIndex, limit: limit);
///     return PagedResult(items: result.items, totalCount: result.totalCount);
///   },
///   itemBuilder: (context, item, index) => ListTile(title: Text(item.name)),
/// )
/// ```
class PaginatedList<T> extends StatefulWidget {
  /// 数据获取回调
  final PagedFetcher<T> fetcher;

  /// 每页条数，默认 100
  final int pageSize;

  /// 列表项构建器
  final PaginatedItemBuilder<T> itemBuilder;

  /// Builds the current page content from pagination state.
  ///
  /// This keeps pagination state and navigation inside [PaginatedList], while
  /// letting callers choose list, grid, or domain-specific media layouts.
  final PaginatedContentBuilder<T>? contentBuilder;

  /// Explicit key for query changes that should reset the list to page one.
  ///
  /// When set, ordinary parent rebuilds and new closure instances for [fetcher]
  /// do not trigger reloads. Change this value when filters or library ids
  /// change.
  final Object? refreshKey;

  /// 加载中占位组件
  final WidgetBuilder? loadingBuilder;

  /// 错误占位组件（附带重试回调）
  final Widget Function(BuildContext context, String error, VoidCallback retry)?
      errorBuilder;

  /// 空数据占位组件
  final WidgetBuilder? emptyBuilder;

  /// 列表内容外层 padding
  final EdgeInsets padding;

  const PaginatedList({
    super.key,
    required this.fetcher,
    required this.itemBuilder,
    this.contentBuilder,
    this.refreshKey,
    this.pageSize = 100,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<PaginatedList<T>> createState() => PaginatedListState<T>();
}

/// 暴露 [refresh] 方法供外部筛选变化时重置到第一页
class PaginatedListState<T> extends State<PaginatedList<T>> {
  int _startIndex = 0;
  List<T> _items = [];
  int _totalCount = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPage();
  }

  @override
  void didUpdateWidget(covariant PaginatedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final usesExplicitRefreshKey =
        oldWidget.refreshKey != null || widget.refreshKey != null;
    final shouldRefresh = usesExplicitRefreshKey
        ? oldWidget.refreshKey != widget.refreshKey
        : oldWidget.fetcher != widget.fetcher;
    if (shouldRefresh) {
      refresh();
    }
  }

  /// 重置到第一页并重新加载
  void refresh() {
    _startIndex = 0;
    _fetchPage();
  }

  Future<void> _fetchPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.fetcher(
        startIndex: _startIndex,
        limit: widget.pageSize,
      );
      if (mounted) {
        setState(() {
          _items = result.items;
          _totalCount = result.totalCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '$e';
          _isLoading = false;
        });
      }
    }
  }

  void _goPrevious() {
    if (_startIndex <= 0) return;
    _startIndex = (_startIndex - widget.pageSize).clamp(0, _totalCount);
    _fetchPage();
  }

  void _goNext() {
    if (_startIndex + widget.pageSize >= _totalCount) return;
    _startIndex += widget.pageSize;
    _fetchPage();
  }

  bool get _showNavBar => _totalCount > widget.pageSize;

  @override
  Widget build(BuildContext context) {
    // 初始加载中
    if (_isLoading && _items.isEmpty) {
      return widget.loadingBuilder != null
          ? widget.loadingBuilder!(context)
          : const Center(child: CircularProgressIndicator());
    }

    // 错误
    if (_errorMessage != null && _items.isEmpty) {
      return widget.errorBuilder != null
          ? widget.errorBuilder!(context, _errorMessage!, refresh)
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: refresh, child: const Text('重试')),
                ],
              ),
            );
    }

    // 空数据
    if (_items.isEmpty) {
      return widget.emptyBuilder != null
          ? widget.emptyBuilder!(context)
          : const SizedBox.shrink();
    }

    // 内容
    return Column(
      children: [
        // 顶部导航条
        if (_showNavBar)
          PaginationNavBar(
            startIndex: _startIndex,
            pageSize: widget.pageSize,
            totalCount: _totalCount,
            onPrevious: _goPrevious,
            onNext: _goNext,
            isLoading: _isLoading,
          ),
        // 列表内容
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => refresh(),
            child: _buildPageContent(context),
          ),
        ),
        // 底部导航条
        if (_showNavBar)
          PaginationNavBar(
            startIndex: _startIndex,
            pageSize: widget.pageSize,
            totalCount: _totalCount,
            onPrevious: _goPrevious,
            onNext: _goNext,
            isLoading: _isLoading,
          ),
      ],
    );
  }

  Widget _buildPageContent(BuildContext context) {
    final page = PaginatedPage<T>(
      items: List<T>.unmodifiable(_items),
      startIndex: _startIndex,
      pageSize: widget.pageSize,
      totalCount: _totalCount,
      isLoading: _isLoading,
      padding: widget.padding,
      itemBuilder: widget.itemBuilder,
    );

    final contentBuilder = widget.contentBuilder;
    if (contentBuilder != null) {
      return contentBuilder(context, page);
    }

    return ListView.builder(
      padding: page.padding,
      itemCount: page.items.length,
      itemBuilder: (context, index) =>
          page.itemBuilder(context, page.items[index], index),
    );
  }
}
