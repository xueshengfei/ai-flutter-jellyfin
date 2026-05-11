import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_series/src/widgets/season_card.dart';

/// 季列表页面（解耦版）
///
/// 通过回调注入数据和导航，不依赖 JellyfinClient。
class SeasonsPage extends StatefulWidget {
  /// 剧集信息
  final MediaItem series;

  /// 获取季列表回调
  final SeasonsFetcher fetchSeasons;

  /// 点击季 → 导航到集列表页
  final void Function(BuildContext context, MediaItem series, Season season)?
      onNavigateToEpisodes;

  const SeasonsPage({
    super.key,
    required this.series,
    required this.fetchSeasons,
    this.onNavigateToEpisodes,
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
    setState(() {
      _seasonsFuture = widget.fetchSeasons(widget.series.id);
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
            onPressed: _loadSeasons,
          ),
        ],
      ),
      body: FutureBuilder<SeasonListResult>(
        future: _seasonsFuture,
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
                  FilledButton(onPressed: _loadSeasons, child: const Text('重试')),
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
                  Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('该剧集暂无季信息', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          _totalSeasons = result.totalCount ?? result.length;

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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                          widget.onNavigateToEpisodes?.call(
                              context, widget.series, season);
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
