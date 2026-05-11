import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_movies/src/models/movie_filter_models.dart';

/// 电影过滤页面
///
/// 通过回调解耦，不依赖 JellyfinClient、ViewModeManager、MediaListBuilder。
/// 列表布局通过 listBuilder 注入。
class MovieFilterPage extends StatefulWidget {
  final String libraryId;
  final String libraryName;

  /// 获取电影列表回调
  final MoviesFetcher fetchMovies;

  /// 点击电影项回调
  final void Function(BuildContext context, MediaItem item)? onNavigateToMovie;

  /// 列表构建器（注入 MediaListBuilder 等外部布局）
  final Widget Function({
    required List<MediaItem> items,
    required ValueChanged<MediaItem> onTap,
  })? listBuilder;

  /// AppBar 右侧额外操作按钮（如 ViewModeSelector）
  final List<Widget>? appBarActions;

  const MovieFilterPage({
    super.key,
    required this.libraryId,
    required this.libraryName,
    required this.fetchMovies,
    this.onNavigateToMovie,
    this.listBuilder,
    this.appBarActions,
  });

  @override
  State<MovieFilterPage> createState() => _MovieFilterPageState();
}

class _MovieFilterPageState extends State<MovieFilterPage> {
  late MovieFilter _filter;
  List<MediaItem> _movies = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int? _totalCount;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _filter = MovieFilter.defaultFilter(parentId: widget.libraryId);
    _loadMovies();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore &&
          _totalCount != null &&
          _movies.length < _totalCount!) {
        _loadMoreMovies();
      }
    }
  }

  Future<void> _loadMovies() async {
    setState(() {
      _isLoading = true;
      _movies = [];
      _filter = _filter.copyWith(startIndex: 0);
    });

    try {
      final result = await widget.fetchMovies(_filter);
      if (mounted) {
        setState(() {
          _movies = result.movies;
          _totalCount = result.totalCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreMovies() async {
    if (_isLoadingMore) return;
    setState(() { _isLoadingMore = true; });

    try {
      final nextFilter = _filter.copyWith(startIndex: _movies.length);
      final result = await widget.fetchMovies(nextFilter);
      if (mounted) {
        setState(() {
          _movies.addAll(result.movies);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingMore = false; });
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MovieFilterSheet(
        filter: _filter,
        onApply: (newFilter) {
          setState(() { _filter = newFilter; });
          _loadMovies();
        },
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索电影'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: '输入首字母...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          maxLength: 1,
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
          onChanged: (value) {
            if (value.isNotEmpty) {
              setState(() {
                _filter = _filter.copyWith(nameStartsWith: value.toUpperCase());
              });
              _loadMovies();
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingWidget()
                : _movies.isEmpty
                    ? _buildEmptyWidget()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.libraryName,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      actions: [
        ...?widget.appBarActions,
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _showSearchDialog,
          tooltip: '搜索',
        ),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterDialog,
          tooltip: '筛选',
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载电影...'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text('暂无电影', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('尝试调整筛选条件', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultHeader(),
        _buildMovieList(),
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildResultHeader() {
    final hasFilters = _hasActiveFilters();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.movie_filter_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '找到 $_totalCount 部电影',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (hasFilters)
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('清除'),
                ),
            ],
          ),
          if (hasFilters) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildFilterChips(),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return (_filter.genres?.isNotEmpty ?? false) ||
        (_filter.years?.isNotEmpty ?? false) ||
        (_filter.nameStartsWith != null) ||
        (_filter.studios?.isNotEmpty ?? false) ||
        (_filter.isUnplayed ?? false) ||
        (_filter.minCommunityRating != null);
  }

  void _clearAllFilters() {
    setState(() {
      _filter = MovieFilter.defaultFilter(
        parentId: widget.libraryId,
        startIndex: 0,
        limit: _filter.limit,
      );
    });
    _loadMovies();
  }

  List<Widget> _buildFilterChips() {
    final chips = <Widget>[];
    if (_filter.genres?.isNotEmpty ?? false) {
      chips.add(_FilterChipWidget(
        label: '类型: ${_filter.genres!.join(", ")}',
        onDeleted: () { setState(() => _filter = _filter.copyWith(clearGenres: true)); _loadMovies(); },
      ));
    }
    if (_filter.years?.isNotEmpty ?? false) {
      chips.add(_FilterChipWidget(
        label: '年份: ${_filter.years!.join(", ")}',
        onDeleted: () { setState(() => _filter = _filter.copyWith(clearYears: true)); _loadMovies(); },
      ));
    }
    if (_filter.nameStartsWith != null) {
      chips.add(_FilterChipWidget(
        label: '首字母: ${_filter.nameStartsWith}',
        onDeleted: () { setState(() => _filter = _filter.copyWith(nameStartsWith: null)); _loadMovies(); },
      ));
    }
    if (_filter.studios?.isNotEmpty ?? false) {
      chips.add(_FilterChipWidget(
        label: '工作室: ${_filter.studios!.join(", ")}',
        onDeleted: () { setState(() => _filter = _filter.copyWith(clearStudios: true)); _loadMovies(); },
      ));
    }
    if (_filter.minCommunityRating != null) {
      chips.add(_FilterChipWidget(
        label: '${_filter.minCommunityRating}+ 分',
        onDeleted: () { setState(() => _filter = _filter.copyWith(minCommunityRating: null)); _loadMovies(); },
      ));
    }
    return chips;
  }

  Widget _buildMovieList() {
    if (widget.listBuilder != null) {
      return widget.listBuilder!(
        items: _movies,
        onTap: (item) => widget.onNavigateToMovie?.call(context, item),
      );
    }
    // 默认简单列表
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _movies.length,
      itemBuilder: (context, index) {
        final movie = _movies[index];
        return ListTile(
          leading: movie.hasCoverImage
              ? Image.network(movie.getCoverImageUrl()!, width: 50, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.movie))
              : const Icon(Icons.movie),
          title: Text(movie.name),
          subtitle: Text('${movie.productionYear ?? ""} ${movie.communityRating != null ? "⭐ ${movie.ratingText}" : ""}'),
          onTap: () => widget.onNavigateToMovie?.call(context, movie),
        );
      },
    );
  }
}

/// 筛选标签
class _FilterChipWidget extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;
  const _FilterChipWidget({required this.label, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onDeleted,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }
}

/// 电影筛选底部表单
class _MovieFilterSheet extends StatefulWidget {
  final MovieFilter filter;
  final Function(MovieFilter) onApply;
  const _MovieFilterSheet({required this.filter, required this.onApply});

  @override
  State<_MovieFilterSheet> createState() => _MovieFilterSheetState();
}

class _MovieFilterSheetState extends State<_MovieFilterSheet> {
  late MovieFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.filter_list, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text('筛选电影', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          // 内容
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('类型', Icons.category, _buildGenreFilter()),
                const SizedBox(height: 16),
                _buildSection('年份', Icons.calendar_today, _buildYearFilter()),
                const SizedBox(height: 16),
                _buildSection('工作室', Icons.business, _buildStudioFilter()),
                const SizedBox(height: 16),
                _buildSection('评分', Icons.star, _buildRatingFilter()),
                const SizedBox(height: 16),
                _buildSection('其他选项', Icons.tune, _buildOtherFilters()),
              ],
            ),
          ),
          // 底部按钮
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildGenreFilter() {
    final genres = ['动作', '喜剧', '科幻', '爱情', '恐怖', '剧情', '动画', '犯罪'];
    final selected = _filter.genres ?? [];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: genres.map((g) {
        return FilterChip(
          label: Text(g),
          selected: selected.contains(g),
          onSelected: (sel) {
            setState(() {
              final list = List<String>.from(selected);
              sel ? list.add(g) : list.remove(g);
              _filter = _filter.copyWith(genres: list);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildYearFilter() {
    final currentYear = DateTime.now().year;
    final years = List.generate(15, (i) => currentYear - i);
    final selected = _filter.years ?? [];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: years.take(10).map((y) {
        return FilterChip(
          label: Text('$y'),
          selected: selected.contains(y),
          onSelected: (sel) {
            setState(() {
              final list = List<int>.from(selected);
              sel ? list.add(y) : list.remove(y);
              _filter = _filter.copyWith(years: list);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildStudioFilter() {
    final studios = ['漫威', '迪士尼', '华纳兄弟', '环球影业', '派拉蒙'];
    final selected = _filter.studios ?? [];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: studios.map((s) {
        return FilterChip(
          label: Text(s),
          selected: selected.contains(s),
          onSelected: (sel) {
            setState(() {
              final list = List<String>.from(selected);
              sel ? list.add(s) : list.remove(s);
              _filter = _filter.copyWith(studios: list);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildRatingFilter() {
    final ratings = [6.0, 7.0, 8.0, 8.5, 9.0];
    final current = _filter.minCommunityRating;
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: ratings.map((r) {
        return FilterChip(
          label: Text('$r+ 分'),
          selected: current != null && current >= r,
          onSelected: (_) => setState(() => _filter = _filter.copyWith(minCommunityRating: r)),
        );
      }).toList(),
    );
  }

  Widget _buildOtherFilters() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('只显示高清'),
          value: _filter.isHD ?? false,
          onChanged: (v) => setState(() => _filter = _filter.copyWith(isHD: v)),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('只显示4K'),
          value: _filter.is4K ?? false,
          onChanged: (v) => setState(() => _filter = _filter.copyWith(is4K: v)),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('只显示未观看'),
          value: _filter.isUnplayed ?? false,
          onChanged: (v) => setState(() => _filter = _filter.copyWith(isUnplayed: v)),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _filter = MovieFilter.defaultFilter(
                      parentId: widget.filter.parentId,
                      startIndex: 0,
                      limit: widget.filter.limit,
                    );
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重置'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () {
                  widget.onApply(_filter);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check),
                label: const Text('应用筛选'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
