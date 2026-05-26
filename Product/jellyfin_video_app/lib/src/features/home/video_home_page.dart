import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_movies/jellyfin_movies_pages.dart';
import 'package:jellyfin_media/jellyfin_media_pages.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../../data/jellyfin_gateway.dart';
import '../../ui/jellyfin_video_image_provider.dart';
import 'recommend_tab.dart';

/// 腾讯视频风格首页
///
/// 布局：顶部 TabBar（推荐 | 电影 | 电视剧 | ...） + 底部导航（首页 | 我的）
class VideoHomePage extends StatefulWidget {
  final JellyfinGateway gateway;
  final JellyfinVideoImageProvider imageProvider;
  final VoidCallback onLogout;

  const VideoHomePage({
    super.key,
    required this.gateway,
    required this.imageProvider,
    required this.onLogout,
  });

  @override
  State<VideoHomePage> createState() => _VideoHomePageState();
}

class _VideoHomePageState extends State<VideoHomePage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<_VideoTab> _tabs = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLibraries();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadLibraries() async {
    try {
      final libraries = await widget.gateway.getMediaLibraries();

      // 只保留视频类型库（电影、电视剧），过滤掉书籍/音乐等
      final videoLibs = libraries.where((lib) {
        return lib.type == models.MediaLibraryType.movies ||
            lib.type == models.MediaLibraryType.tvshows;
      }).toList();

      final tabs = <_VideoTab>[_VideoTab.recommend()];

      // 分类规则
      for (final lib in videoLibs) {
        if (lib.type == models.MediaLibraryType.movies) {
          tabs.add(_VideoTab(
            label: '电影',
            library: lib,
            tabType: _VideoTabType.movies,
          ));
        } else if (lib.type == models.MediaLibraryType.tvshows) {
          // 检查是否是动漫库
          if (lib.name.contains('动漫') ||
              lib.name.toLowerCase().contains('anime')) {
            tabs.add(_VideoTab(
              label: lib.name,
              library: lib,
              tabType: _VideoTabType.series,
            ));
          } else {
            tabs.add(_VideoTab(
              label: '电视剧',
              library: lib,
              tabType: _VideoTabType.series,
            ));
          }
        } else {
          // 其他类型也展示
          tabs.add(_VideoTab(
            label: lib.name,
            library: lib,
            tabType: _VideoTabType.series,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _tabs = tabs;
          _tabController = TabController(length: tabs.length, vsync: this);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '加载失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Jellyfin 视频')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadLibraries();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jellyfin 视频'),
        bottom: _tabController != null
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _tabs.map((tab) => Tab(text: tab.label)).toList(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: '个人中心',
            onPressed: () => context.push('/personal'),
          ),
        ],
      ),
      body: _tabController != null
          ? TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) => _buildTabContent(tab)).toList(),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildTabContent(_VideoTab tab) {
    switch (tab.tabType) {
      case _VideoTabType.recommend:
        return RecommendTab(
          gateway: widget.gateway,
          imageProvider: widget.imageProvider,
          libraries: _tabs
              .where((t) => t.library != null)
              .map((t) => t.library!)
              .toList(),
        );
      case _VideoTabType.movies:
        return _EmbeddedMovieFilter(
          gateway: widget.gateway,
          library: tab.library!,
          imageProvider: widget.imageProvider,
        );
      case _VideoTabType.series:
        return _EmbeddedSeriesList(
          gateway: widget.gateway,
          library: tab.library!,
          imageProvider: widget.imageProvider,
        );
    }
  }
}

// ─── Tab 定义 ───

enum _VideoTabType { recommend, movies, series }

class _VideoTab {
  final String label;
  final models.MediaLibrary? library;
  final _VideoTabType tabType;

  const _VideoTab({
    required this.label,
    this.library,
    required this.tabType,
  });

  const _VideoTab.recommend()
      : label = '推荐',
        library = null,
        tabType = _VideoTabType.recommend;
}

// ─── 嵌入式电影筛选页 ───

class _EmbeddedMovieFilter extends StatefulWidget {
  final JellyfinGateway gateway;
  final models.MediaLibrary library;
  final JellyfinVideoImageProvider imageProvider;

  const _EmbeddedMovieFilter({
    required this.gateway,
    required this.library,
    required this.imageProvider,
  });

  @override
  State<_EmbeddedMovieFilter> createState() => _EmbeddedMovieFilterState();
}

class _EmbeddedMovieFilterState extends State<_EmbeddedMovieFilter> {
  ViewModeConfig _viewModeConfig = const ViewModeConfig();

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final config = await ViewModeManager().getViewModeConfig(widget.library.id);
    if (mounted) {
      setState(() => _viewModeConfig = config);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MovieFilterPage(
      libraryId: widget.library.id,
      libraryName: widget.library.name,
      fetchMovies: widget.gateway.fetchMovies,
      onNavigateToMovie: (context, item) {
        context.push('/movies/${item.id}');
      },
      appBarActions: [
        ViewModeSelector(
          libraryId: widget.library.id,
          onViewModeChanged: (config) {
            setState(() => _viewModeConfig = config);
          },
        ),
      ],
      listBuilder: ({required items, required onTap}) {
        return MediaListBuilder(
          imageProvider: widget.imageProvider,
          items: items,
          config: _viewModeConfig,
          onTap: onTap,
        );
      },
    );
  }
}

// ─── 嵌入式剧集列表页 ───

class _EmbeddedSeriesList extends StatefulWidget {
  final JellyfinGateway gateway;
  final models.MediaLibrary library;
  final JellyfinVideoImageProvider imageProvider;

  const _EmbeddedSeriesList({
    required this.gateway,
    required this.library,
    required this.imageProvider,
  });

  @override
  State<_EmbeddedSeriesList> createState() => _EmbeddedSeriesListState();
}

class _EmbeddedSeriesListState extends State<_EmbeddedSeriesList> {
  ViewModeConfig _viewModeConfig = const ViewModeConfig();

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final config = await ViewModeManager().getViewModeConfig(widget.library.id);
    if (mounted) {
      setState(() => _viewModeConfig = config);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaItemsPage(
      library: widget.library,
      fetchMediaItems: widget.gateway.fetchMediaItems,
      onNavigateToMediaItem: (context, item) {
        context.push('/media/items/${item.id}');
      },
      appBarActions: [
        ViewModeSelector(
          libraryId: widget.library.id,
          onViewModeChanged: (config) {
            setState(() => _viewModeConfig = config);
          },
        ),
      ],
      listBuilder: (items, onTap) {
        return MediaListBuilder(
          imageProvider: widget.imageProvider,
          items: items,
          config: _viewModeConfig,
          onTap: onTap,
        );
      },
    );
  }
}
