import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'episodes_page.dart';
import 'video_player_page.dart';

/// 季列表页面
///
/// 显示指定剧集的所有季
class SeasonsPage extends StatefulWidget {
  final JellyfinClient client;
  final MediaItem series;

  const SeasonsPage({
    super.key,
    required this.client,
    required this.series,
  });

  @override
  State<SeasonsPage> createState() => _SeasonsPageState();
}

class _SeasonsPageState extends State<SeasonsPage> {
  late Future<SeasonListResult> _seasonsFuture;
  int _totalSeasons = 0;

  @override
  void initState() {
    super.initState();
    _loadSeasons();
  }

  void _loadSeasons() {
    print('🔄 SeasonsPage: 加载季列表');
    print('   剧集ID: ${widget.series.id}');
    print('   剧集名称: ${widget.series.name}');
    print('   剧集类型: ${widget.series.type}');

    setState(() {
      _seasonsFuture = widget.client.mediaLibrary.getSeasons(widget.series.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.series.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadSeasons();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<SeasonListResult>(
        future: _seasonsFuture,
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
                    onPressed: _loadSeasons,
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
                    '该剧集暂无季信息',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // 更新总数
          _totalSeasons = result.totalCount ?? result.length;

          return Column(
            children: [
              // 数量提示
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                child: Text(
                  '共有 $_totalSeasons 季',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),

              // 季列表
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _loadSeasons();
                    await _seasonsFuture;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: result.seasons.length,
                    itemBuilder: (context, index) {
                      final season = result.seasons[index];
                      return SeasonCard(
                        season: season,
                        seriesName: widget.series.name,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EpisodesPage(
                                client: widget.client,
                                series: widget.series,
                                season: season,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 季卡片组件
class SeasonCard extends StatelessWidget {
  final Season season;
  final String seriesName;
  final VoidCallback onTap;

  const SeasonCard({
    super.key,
    required this.season,
    required this.seriesName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图片
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: season.hasCoverImage
                    ? Image.network(
                        season.getCoverImageUrl()!,
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
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              season.seasonNumberText,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // 信息区域
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 季名称
                    Text(
                      season.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // 剧集数量
                    if (season.episodeCount != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.play_circle_outline,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${season.episodeCount} 集',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
