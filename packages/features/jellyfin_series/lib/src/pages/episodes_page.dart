import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_series/src/models/series_models.dart';
import 'package:jellyfin_series/src/widgets/episode_card.dart';
import 'package:jellyfin_series/src/widgets/episode_detail_sheet.dart';

/// 集列表页面（解耦版）
///
/// 通过回调注入数据和导航，不依赖 JellyfinClient / ViewModeManager。
class EpisodesPage extends StatefulWidget {
  /// 剧集信息
  final MediaItem series;

  /// 季信息
  final Season season;

  /// 获取集列表回调
  final EpisodesFetcher fetchEpisodes;

  /// 点击播放回调
  final void Function(BuildContext context, Episode episode)?
      onStartPlayback;

  /// 自定义列表构建器（可选，用于注入外部布局组件如 MediaListBuilder）
  final Widget Function(
    BuildContext context,
    List<Episode> episodes,
    void Function(Episode) onTap,
    void Function(Episode)? onPlay,
  )? listBuilder;

  /// 额外的 AppBar actions（可选，用于注入 ViewModeSelector 等）
  final List<Widget>? appBarActions;

  const EpisodesPage({
    super.key,
    required this.series,
    required this.season,
    required this.fetchEpisodes,
    this.onStartPlayback,
    this.listBuilder,
    this.appBarActions,
  });

  @override
  State<EpisodesPage> createState() => _EpisodesPageState();
}

class _EpisodesPageState extends State<EpisodesPage> {
  late Future<EpisodeListResult> _episodesFuture;
  int _totalEpisodes = 0;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  void _loadEpisodes() {
    setState(() {
      _episodesFuture = widget.fetchEpisodes(
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
          ...?widget.appBarActions,
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEpisodes,
          ),
        ],
      ),
      body: FutureBuilder<EpisodeListResult>(
        future: _episodesFuture,
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
                  Text('加载失败: ${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _loadEpisodes, child: const Text('重试')),
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
                  Icon(Icons.video_library_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('该季暂无剧集',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          _totalEpisodes = result.totalCount ?? result.length;

          return Column(
            children: [
              // 数量提示
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.3),
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
                  child: _buildEpisodesList(context, result),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEpisodesList(BuildContext context, EpisodeListResult result) {
    // 如果调用方提供了自定义列表构建器，优先使用
    if (widget.listBuilder != null) {
      return widget.listBuilder!(
        context,
        result.episodes,
        (episode) => _showEpisodeDetail(episode),
        (episode) => _playEpisode(context, episode),
      );
    }

    // 默认：ListView + EpisodeCard
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: result.episodes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final episode = result.episodes[index];
        return EpisodeCard(
          episode: episode,
          onTap: () => _showEpisodeDetail(episode),
          onPlay: () => _playEpisode(context, episode),
        );
      },
    );
  }

  /// 播放剧集
  void _playEpisode(BuildContext context, Episode episode) {
    widget.onStartPlayback?.call(context, episode);
  }

  /// 显示剧集详情弹窗
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
