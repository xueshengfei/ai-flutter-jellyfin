import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'media_item_detail_page.dart';
import 'models/view_mode_models.dart';
import 'services/view_mode_manager.dart';
import 'widgets/view_mode_selector.dart';
import 'widgets/media_list_builder.dart';

/// 电影过滤页面
///
/// 提供电影筛选和展示功能
class MovieFilterPage extends StatefulWidget {
  final JellyfinClient client;
  final String libraryId;
  final String libraryName;

  const MovieFilterPage({
    super.key,
    required this.client,
    required this.libraryId,
    required this.libraryName,
  });

  @override
  State<MovieFilterPage> createState() => _MovieFilterPageState();
}

class _MovieFilterPageState extends State<MovieFilterPage> {
  // 当前过滤器
  late MovieFilter _filter;

  // 电影列表
  List<MediaItem> _movies = [];

  // 加载状态
  bool _isLoading = false;
  bool _isLoadingMore = false;

  // 总数
  int? _totalCount;

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  // 视图模式配置
  final ViewModeManager _viewModeManager = ViewModeManager();
  ViewModeConfig _viewModeConfig = const ViewModeConfig();

  @override
  void initState() {
    super.initState();

    print('🎬 MovieFilterPage initState');
    print('   Library ID: ${widget.libraryId}');
    print('   Library Name: ${widget.libraryName}');
    print('   Client: ${widget.client}');

    _filter = MovieFilter.defaultFilter(parentId: widget.libraryId);
    print('   Filter created: $_filter');

    _loadViewModeConfig();
    _loadMovies();
    _scrollController.addListener(_onScroll);
  }

  /// 加载视图模式配置
  Future<void> _loadViewModeConfig() async {
    final config = await _viewModeManager.getViewModeConfig(widget.libraryId);
    if (mounted) {
      setState(() {
        _viewModeConfig = config;
      });
    }
  }

  /// 保存视图模式配置
  Future<void> _saveViewModeConfig(ViewModeConfig config) async {
    await _viewModeManager.saveViewModeConfig(widget.libraryId, config);
    if (mounted) {
      setState(() {
        _viewModeConfig = config;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 监听滚动事件，实现上拉加载
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

  /// 加载电影列表
  Future<void> _loadMovies() async {
    print('🔄 开始加载电影...');
    print('   Library ID: ${widget.libraryId}');
    print('   Filter: $_filter');

    setState(() {
      _isLoading = true;
      _movies = [];
      _filter = _filter.copyWith(startIndex: 0);
    });

    try {
      print('📡 调用 client.mediaLibrary.getMovies()...');
      final result = await widget.client.mediaLibrary.getMovies(_filter);

      print('✅ API调用成功!');
      print('   返回电影数量: ${result.items.length}');
      print('   总记录数: ${result.totalCount}');

      if (result.items.isNotEmpty) {
        print('   第一部电影: ${result.items.first.name}');
      }

      setState(() {
        _movies = result.items;
        _totalCount = result.totalCount;
        _isLoading = false;
      });

      print('✅ UI更新完成，显示 ${_movies.length} 部电影');
    } catch (e, stackTrace) {
      print('❌ 加载失败: $e');
      print('   堆栈跟踪: $stackTrace');

      setState(() {
        _isLoading = false;
      });
      if (mounted) {
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

  /// 加载更多电影
  Future<void> _loadMoreMovies() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextFilter = _filter.copyWith(
        startIndex: _movies.length,
      );
      final result = await widget.client.mediaLibrary.getMovies(nextFilter);

      setState(() {
        _movies.addAll(result.items);
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// 显示筛选对话框
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MovieFilterSheet(
        filter: _filter,
        onApply: (newFilter) {
          setState(() {
            _filter = newFilter;
          });
          _loadMovies();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 调试：打印当前状态
    print('🎨 build() 被调用');
    print('   _isLoading: $_isLoading');
    print('   _movies.length: ${_movies.length}');
    print('   _totalCount: $_totalCount');
    print('   isEmpty: ${_movies.isEmpty}');

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 自定义AppBar
          _buildSliverAppBar(),

          // 内容区域
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

  /// 构建SliverAppBar
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.libraryName,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.secondary.withOpacity(0.05),
              ],
            ),
          ),
        ),
      ),
      actions: [
        // 视图模式选择器
        ViewModeSelector(
          libraryId: widget.libraryId,
          onViewModeChanged: _saveViewModeConfig,
        ),
        // 搜索按钮
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _showSearchDialog,
          tooltip: '搜索',
        ),
        // 筛选按钮
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterDialog,
          tooltip: '筛选',
        ),
      ],
    );
  }

  /// 加载中
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

  /// 空状态
  Widget _buildEmptyWidget() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.movie_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '暂无电影',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试调整筛选条件',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 内容区域
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 结果统计
        _buildResultHeader(),

        // 电影网格
        _buildMovieGrid(),

        // 加载更多指示器
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  /// 结果统计头部
  Widget _buildResultHeader() {
    final hasFilters = _hasActiveFilters();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计信息
          Row(
            children: [
              Icon(
                Icons.movie_filter_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
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
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),

          // 筛选标签
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

  /// 是否有活动筛选
  bool _hasActiveFilters() {
    return (_filter.genres?.isNotEmpty ?? false) ||
        (_filter.years?.isNotEmpty ?? false) ||
        (_filter.nameStartsWith != null) ||
        (_filter.studios?.isNotEmpty ?? false) ||
        (_filter.filters?.isNotEmpty ?? false) ||
        (_filter.minCommunityRating != null);
  }

  /// 清除所有筛选
  void _clearAllFilters() {
    setState(() {
      _filter = MovieFilter.defaultFilter(
        parentId: widget.libraryId,
        startIndex: 0,
        limit: _filter.limit,
      ).copyWith(filters: []);
    });
    _loadMovies();
  }

  /// 构建筛选标签
  List<Widget> _buildFilterChips() {
    final chips = <Widget>[];

    if (_filter.genres != null && _filter.genres!.isNotEmpty) {
      chips.add(_FilterChip(
        label: '类型: ${_filter.genres!.join(", ")}',
        onDeleted: () {
          setState(() => _filter = _filter.copyWith(clearGenres: true));
          _loadMovies();
        },
      ));
    }

    if (_filter.years != null && _filter.years!.isNotEmpty) {
      chips.add(_FilterChip(
        label: '年份: ${_filter.years!.join(", ")}',
        onDeleted: () {
          setState(() => _filter = _filter.copyWith(clearYears: true));
          _loadMovies();
        },
      ));
    }

    if (_filter.nameStartsWith != null) {
      chips.add(_FilterChip(
        label: '首字母: ${_filter.nameStartsWith}',
        onDeleted: () {
          setState(() => _filter = _filter.copyWith(nameStartsWith: null));
          _loadMovies();
        },
      ));
    }

    if (_filter.studios != null && _filter.studios!.isNotEmpty) {
      chips.add(_FilterChip(
        label: '工作室: ${_filter.studios!.join(", ")}',
        onDeleted: () {
          setState(() => _filter = _filter.copyWith(clearStudios: true));
          _loadMovies();
        },
      ));
    }

    if (_filter.minCommunityRating != null) {
      chips.add(_FilterChip(
        label: '${_filter.minCommunityRating}+ 分',
        onDeleted: () {
          setState(() => _filter = _filter.copyWith(minCommunityRating: null));
          _loadMovies();
        },
      ));
    }

    return chips;
  }

  /// 电影列表
  Widget _buildMovieGrid() {
    return SizedBox(
      height: _calculateListHeight(),
      child: MediaListBuilder(
        client: widget.client,
        items: _movies,
        config: _viewModeConfig,
        onTap: (item) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaItemDetailPage(
                client: widget.client,
                item: item,
              ),
            ),
          );
        },
      ),
    );
  }

  /// 计算列表高度
  double _calculateListHeight() {
    // 根据视图模式和项目数量动态计算高度
    if (_movies.isEmpty) return 400;

    switch (_viewModeConfig.viewMode) {
      case ViewMode.banner:
        // 横幅视图：每个项目约 300px
        return _movies.length * 300.0 + 32;
      case ViewMode.list:
        // 列表视图：每个项目 120px
        return _movies.length * 120.0 + 32;
      case ViewMode.poster:
      case ViewMode.card:
        // 网格视图：根据列数计算
        final rowCount = (_movies.length / _viewModeConfig.crossAxisCount).ceil();
        final itemHeight = _viewModeConfig.viewMode == ViewMode.poster ? 280.0 : 320.0;
        return rowCount * itemHeight + 32;
    }
  }

  /// 显示搜索对话框
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
}

/// 筛选标签
class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _FilterChip({
    required this.label,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onDeleted,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }
}

/// 电影卡片
class _MovieCard extends StatelessWidget {
  final MediaItem movie;
  final JellyfinClient client;

  const _MovieCard({
    required this.movie,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = movie.getCoverImageUrl();

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            Expanded(
              child: _buildCoverImage(context, coverUrl),
            ),

            // 电影信息
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 电影名称
                  Text(
                    movie.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // 年份和评分
                  Row(
                    children: [
                      if (movie.productionYear != null)
                        _buildInfoChip(
                          context,
                          Icons.calendar_today,
                          '${movie.productionYear}',
                        ),
                      if (movie.productionYear != null)
                        const SizedBox(width: 6),
                      if (movie.communityRating != null)
                        _buildInfoChip(
                          context,
                          Icons.star,
                          movie.communityRating!.toStringAsFixed(1),
                          color: Colors.amber,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context, String? coverUrl) {
    if (coverUrl != null) {
      return Image.network(
        coverUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(context);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String text, {Color? color}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaItemDetailPage(
          client: client,
          item: movie,
        ),
      ),
    );
  }
}

/// 电影筛选底部表单
class MovieFilterSheet extends StatefulWidget {
  final MovieFilter filter;
  final Function(MovieFilter) onApply;

  const MovieFilterSheet({
    super.key,
    required this.filter,
    required this.onApply,
  });

  @override
  State<MovieFilterSheet> createState() => _MovieFilterSheetState();
}

class _MovieFilterSheetState extends State<MovieFilterSheet> {
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
          // 顶部拖拽指示器
          _buildDragHandle(),

          // 标题栏
          _buildHeader(context),

          // 筛选内容
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 类型筛选
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.category, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '类型',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildGenreFilter(),
                  ],
                ),
                const SizedBox(height: 16),

                // 年份筛选
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '年份',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildYearFilter(),
                  ],
                ),
                const SizedBox(height: 16),

                // 工作室筛选
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '工作室',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStudioFilter(),
                  ],
                ),
                const SizedBox(height: 16),

                // 评分筛选
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '评分',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRatingFilter(),
                  ],
                ),
                const SizedBox(height: 16),

                // 其他选项
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '其他选项',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildOtherFilters(),
                  ],
                ),
              ],
            ),
          ),

          // 底部按钮
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            '筛选电影',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreFilter() {
    final genres = ['动作', '喜剧', '科幻', '爱情', '恐怖', '剧情', '动画', '犯罪'];
    final selectedGenres = _filter.genres ?? [];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: genres.map((genre) {
        final isSelected = selectedGenres.contains(genre);
        return FilterChip(
          label: Text(genre),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              final newGenres = List<String>.from(selectedGenres);
              if (selected) {
                newGenres.add(genre);
              } else {
                newGenres.remove(genre);
              }
              _filter = _filter.copyWith(genres: newGenres);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildYearFilter() {
    final currentYear = DateTime.now().year;
    final years = List.generate(15, (index) => currentYear - index);
    final selectedYears = _filter.years ?? [];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: years.take(10).map((year) {
        final isSelected = selectedYears.contains(year);
        return FilterChip(
          label: Text('$year'),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              final newYears = List<int>.from(selectedYears);
              if (selected) {
                newYears.add(year);
              } else {
                newYears.remove(year);
              }
              _filter = _filter.copyWith(years: newYears);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildStudioFilter() {
    final studios = ['漫威', '迪士尼', '华纳兄弟', '环球影业', '派拉蒙'];
    final selectedStudios = _filter.studios ?? [];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: studios.map((studio) {
        final isSelected = selectedStudios.contains(studio);
        return FilterChip(
          label: Text(studio),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              final newStudios = List<String>.from(selectedStudios);
              if (selected) {
                newStudios.add(studio);
              } else {
                newStudios.remove(studio);
              }
              _filter = _filter.copyWith(studios: newStudios);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildRatingFilter() {
    final ratings = [6.0, 7.0, 8.0, 8.5, 9.0];
    final currentRating = _filter.minCommunityRating;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ratings.map((rating) {
        final isSelected = currentRating != null && currentRating >= rating;
        return FilterChip(
          label: Text('$rating+ 分'),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _filter = _filter.copyWith(minCommunityRating: rating);
            });
          },
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
          onChanged: (value) {
            setState(() {
              _filter = _filter.copyWith(isHD: value);
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('只显示4K'),
          value: _filter.is4K ?? false,
          onChanged: (value) {
            setState(() {
              _filter = _filter.copyWith(is4K: value);
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('只显示未观看'),
          value: _filter.filters?.contains(jellyfin_dart.ItemFilter.isUnplayed) ?? false,
          onChanged: (value) {
            setState(() {
              final currentFilters = _filter.filters ?? [];
              if (value == true) {
                _filter = _filter.copyWith(
                  filters: [...currentFilters, jellyfin_dart.ItemFilter.isUnplayed],
                );
              } else {
                _filter = _filter.copyWith(
                  filters: currentFilters.where((f) => f != jellyfin_dart.ItemFilter.isUnplayed).toList(),
                );
              }
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
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
                    ).copyWith(filters: []);
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
