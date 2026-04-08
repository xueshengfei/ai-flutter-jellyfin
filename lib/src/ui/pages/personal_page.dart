import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'package:jellyfin_service/src/ui/pages/media_item_detail_page.dart';
import 'package:jellyfin_service/src/ui/pages/video_player_page.dart';
import 'package:jellyfin_service/src/ui/widgets/media_list_builder.dart';
import 'package:jellyfin_service/src/ui/widgets/media_list_layouts/poster_grid_view.dart';
import 'package:jellyfin_service/src/ui/models/view_mode_models.dart';
import 'package:jellyfin_service/src/ui/services/view_mode_manager.dart';
import 'package:jellyfin_service/src/ui/widgets/view_mode_selector.dart';
import 'package:jellyfin_service/src/ui/widgets/media_item_card_with_actions.dart';

/// 个人中心页面
///
/// 显示用户的：
/// - 继续观看
/// - 个人收藏
/// - 观看历史
class PersonalPage extends StatefulWidget {
  final JellyfinClient client;

  const PersonalPage({
    super.key,
    required this.client,
  });

  @override
  State<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 视图模式管理
  final ViewModeManager _viewModeManager = ViewModeManager();
  ViewModeConfig _viewModeConfig = const ViewModeConfig();

  // 数据
  late Future<MediaItemListResult> _continueWatchingFuture;
  late Future<MediaItemListResult> _favoritesFuture;
  late Future<MediaItemListResult> _watchHistoryFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadViewModeConfig();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载视图模式配置
  Future<void> _loadViewModeConfig() async {
    final config = await _viewModeManager.getViewModeConfig('personal');
    if (mounted) {
      setState(() {
        _viewModeConfig = config;
      });
    }
  }

  /// 保存视图模式配置
  Future<void> _saveViewModeConfig(ViewModeConfig config) async {
    await _viewModeManager.saveViewModeConfig('personal', config);
    if (mounted) {
      setState(() {
        _viewModeConfig = config;
      });
    }
  }

  /// 加载数据
  void _loadData() {
    setState(() {
      _continueWatchingFuture = widget.client.user.getContinueWatching();
      _favoritesFuture = widget.client.user.getFavorites();
      _watchHistoryFuture = widget.client.user.getWatchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text('个人中心'),
                background: _buildHeaderBackground(),
              ),
              actions: [
                ViewModeSelector(
                  libraryId: 'personal',
                  onViewModeChanged: _saveViewModeConfig,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                  tooltip: '刷新',
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '继续观看', icon: Icon(Icons.play_circle_outline)),
                  Tab(text: '我的收藏', icon: Icon(Icons.favorite_border)),
                  Tab(text: '观看历史', icon: Icon(Icons.history)),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildContinueWatchingTab(),
            _buildFavoritesTab(),
            _buildWatchHistoryTab(),
          ],
        ),
      ),
    );
  }

  /// 构建头部背景
  Widget _buildHeaderBackground() {
    final user = widget.client.configuration.userId;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: Colors.white.withOpacity(0.9),
            ),
            const SizedBox(height: 8),
            Text(
              '用户: ${user ?? "未登录"}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 继续观看标签页
  Widget _buildContinueWatchingTab() {
    return FutureBuilder<MediaItemListResult>(
      future: _continueWatchingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('加载失败: ${snapshot.error}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadData,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final result = snapshot.data;
        if (result == null || result.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('暂无继续观看的内容', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _loadData();
            await _continueWatchingFuture;
          },
          child: _buildMediaGrid(result.items, showFavorite: false),
        );
      },
    );
  }

  /// 收藏标签页
  Widget _buildFavoritesTab() {
    return FutureBuilder<MediaItemListResult>(
      future: _favoritesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('加载失败: ${snapshot.error}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadData,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final result = snapshot.data;
        if (result == null || result.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('暂无收藏内容', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _loadData();
            await _favoritesFuture;
          },
          child: _buildMediaGrid(result.items, showFavorite: true),
        );
      },
    );
  }

  /// 观看历史标签页
  Widget _buildWatchHistoryTab() {
    return FutureBuilder<MediaItemListResult>(
      future: _watchHistoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('加载失败: ${snapshot.error}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadData,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final result = snapshot.data;
        if (result == null || result.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('暂无观看历史', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _loadData();
            await _watchHistoryFuture;
          },
          child: _buildMediaGrid(result.items, showFavorite: true),
        );
      },
    );
  }

  /// 播放媒体项（用于继续观看）
  void _playItem(MediaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          client: widget.client,
          item: item,
        ),
      ),
    );
  }

  /// 跳转到详情页
  void _navigateToDetail(MediaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaItemDetailPage(
          client: widget.client,
          item: item,
        ),
      ),
    );
  }

  /// 构建媒体网格
  Widget _buildMediaGrid(List<MediaItem> items, {required bool showFavorite}) {
    return PosterGridView(
      client: widget.client,
      items: items,
      crossAxisCount: _viewModeConfig.crossAxisCount,
      onTap: (item) => _navigateToDetail(item),
      cardBuilder: showFavorite
          ? (item, onTap) => MediaItemCardWithActions(
                client: widget.client,
                item: item,
                onTap: onTap,
                onFavoriteToggle: (newState) {
                  // 重新加载数据以更新UI
                  _loadData();
                },
              )
          : null,
    );
  }
}
