import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'package:jellyfin_service/src/ui/pages/video_player_page.dart';
import 'package:jellyfin_service/src/ui/models/view_mode_models.dart';
import 'package:jellyfin_service/src/ui/services/view_mode_manager.dart';
import 'package:jellyfin_service/src/ui/widgets/view_mode_selector.dart';
import 'package:jellyfin_service/src/ui/widgets/media_list_builder.dart';

/// 集列表页面
///
/// 显示指定季的所有集
class EpisodesPage extends StatefulWidget {
  final JellyfinClient client;
  final MediaItem series;
  final Season season;

  const EpisodesPage({
    super.key,
    required this.client,
    required this.series,
    required this.season,
  });

  @override
  State<EpisodesPage> createState() => _EpisodesPageState();
}

class _EpisodesPageState extends State<EpisodesPage> {
  late Future<EpisodeListResult> _episodesFuture;
  int _totalEpisodes = 0;

  // 视图模式配置
  final ViewModeManager _viewModeManager = ViewModeManager();
  ViewModeConfig _viewModeConfig = const ViewModeConfig();

  @override
  void initState() {
    super.initState();
    _loadViewModeConfig();
    _loadEpisodes();
  }

  /// 加载视图模式配置
  Future<void> _loadViewModeConfig() async {
    final config = await _viewModeManager.getViewModeConfig(widget.season.id);
    if (mounted) {
      setState(() {
        _viewModeConfig = config;
      });
    }
  }

  /// 保存视图模式配置
  Future<void> _saveViewModeConfig(ViewModeConfig config) async {
    await _viewModeManager.saveViewModeConfig(widget.season.id, config);
    if (mounted) {
      setState(() {
        _viewModeConfig = config;
      });
    }
  }

  void _loadEpisodes() {
    setState(() {
      _episodesFuture = widget.client.mediaLibrary.getEpisodes(
        seasonId: widget.season.id,
        seriesId: widget.series.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.series.name} - ${widget.season.name}'),
        actions: [
          // 视图模式选择器
          ViewModeSelector(
            libraryId: widget.season.id,
            onViewModeChanged: _saveViewModeConfig,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadEpisodes();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<EpisodeListResult>(
        future: _episodesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadEpisodes,
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
                  Icon(
                    Icons.video_library_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '该季暂无剧集',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // 更新总数
          _totalEpisodes = result.totalCount ?? result.length;

          return Column(
            children: [
              // 数量提示
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                child: Text(
                  '共有 $_totalEpisodes 集',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),

              // 集列表
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _loadEpisodes();
                    await _episodesFuture;
                  },
                  child: _buildEpisodesList(result),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建集列表（根据视图模式）
  Widget _buildEpisodesList(EpisodeListResult result) {
    // 列表视图模式使用原有的卡片
    if (_viewModeConfig.viewMode == ViewMode.list) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: result.episodes.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final episode = result.episodes[index];
          return EpisodeCard(
            episode: episode,
            client: widget.client,
            onTap: () {
              _showEpisodeDetail(episode);
            },
            onPlay: () {
              _playEpisode(context, episode);
            },
          );
        },
      );
    }

    // 其他视图模式转换为 MediaItem 并使用 MediaListBuilder
    final mediaItems = result.episodes.map((episode) {
      return MediaItem(
        id: episode.id,
        name: episode.name,
        type: 'Episode',
        primaryImageTag: episode.primaryImageTag,
        runTimeTicks: episode.runTimeTicks,
        runTimeMinutes: episode.runTimeMinutes,
        overview: episode.overview,
        serverUrl: widget.client.configuration.serverUrl,
      );
    }).toList();

    return MediaListBuilder(
      client: widget.client,
      items: mediaItems,
      config: _viewModeConfig,
      onTap: (item) {
        // 找到对应的 Episode 并播放
        final episode = result.episodes.firstWhere(
          (e) => e.id == item.id,
        );
        _playEpisode(context, episode);
      },
    );
  }

  /// 播放剧集
  void _playEpisode(BuildContext context, Episode episode) {
    print('🎬 播放剧集: ${episode.name}');
    print('   ID: ${episode.id}');

    // 创建临时 MediaItem 用于播放
    final mediaItem = MediaItem(
      id: episode.id,
      name: episode.name,
      type: 'Episode',
      primaryImageTag: episode.primaryImageTag,
      runTimeTicks: episode.runTimeTicks,
      runTimeMinutes: episode.runTimeMinutes,
      overview: episode.overview,
      serverUrl: widget.client.configuration.serverUrl,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          client: widget.client,
          item: mediaItem,
        ),
      ),
    );
  }

  /// 显示剧集详情（简单实现，可以扩展为详情页面）
  void _showEpisodeDetail(Episode episode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => EpisodeDetailSheet(
          episode: episode,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

/// 集卡片组件
class EpisodeCard extends StatelessWidget {
  final Episode episode;
  final JellyfinClient client;
  final VoidCallback onTap;
  final VoidCallback? onPlay;

  const EpisodeCard({
    super.key,
    required this.episode,
    required this.client,
    required this.onTap,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 缩略图
            SizedBox(
              width: 120,
              height: 68,
              child: episode.hasThumbnailImage
                  ? Image.network(
                      episode.getThumbnailImageUrl()!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.error_outline, color: Colors.grey),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 32,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),

            // 信息区域
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 集号和名称
                    Text(
                      episode.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 集号
                    Text(
                      episode.episodeNumberText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),

                    // 时长和评分
                    Row(
                      children: [
                        // 时长
                        if (episode.runTimeMinutes != null) ...[
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            episode.durationText,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                          const SizedBox(width: 12),
                        ],

                        // 评分
                        if (episode.communityRating != null) ...[
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            episode.communityRating!.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ],
                    ),

                    // 剧情简介
                    if (episode.overview != null && episode.overview!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        episode.overview!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 播放按钮
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: IconButton(
                icon: const Icon(Icons.play_circle_filled),
                color: Theme.of(context).colorScheme.primary,
                iconSize: 32,
                onPressed: onPlay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 剧集详情底部弹窗
class EpisodeDetailSheet extends StatelessWidget {
  final Episode episode;
  final ScrollController scrollController;

  const EpisodeDetailSheet({
    super.key,
    required this.episode,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖动指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 内容
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // 标题和集号
                Text(
                  episode.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  episode.episodeNumberText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 16),

                // 缩略图
                if (episode.hasThumbnailImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      episode.getThumbnailImageUrl()!,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.error_outline, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                if (episode.hasThumbnailImage) const SizedBox(height: 16),

                // 信息行
                Wrap(
                  spacing: 16,
                  children: [
                    // 时长
                    if (episode.runTimeMinutes != null)
                      _buildInfoChip(
                        context,
                        icon: Icons.schedule,
                        label: episode.durationText,
                      ),

                    // 评分
                    if (episode.communityRating != null)
                      _buildInfoChip(
                        context,
                        icon: Icons.star,
                        label: '${episode.communityRating!.toStringAsFixed(1)} 分',
                      ),

                    // 播放状态
                    if (episode.played == true)
                      _buildInfoChip(
                        context,
                        icon: Icons.check_circle,
                        label: '已播放',
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // 剧情简介
                if (episode.overview != null && episode.overview!.isNotEmpty) ...[
                  Text(
                    '剧情简介',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    episode.overview!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                  ),
                ],

                const SizedBox(height: 24),

                // 播放按钮
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('播放功能待实现: ${episode.episodeNumberText}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('播放'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
