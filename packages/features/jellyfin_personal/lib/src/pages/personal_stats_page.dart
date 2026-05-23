import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../contracts/personal_actions.dart';
import '../contracts/personal_repository.dart';
import '../models/personal_media_query.dart';
import '../models/personal_module_config.dart';
import '../models/personal_stats.dart';
import '../widgets/personal_media_card.dart';
import '../widgets/stats_summary_card.dart';

/// 个人统计页
final class PersonalStatsPage extends StatefulWidget {
  final PersonalRepository repository;
  final PersonalModuleConfig config;
  final JellyfinImageProvider imageProvider;
  final PersonalActions actions;

  const PersonalStatsPage({
    super.key,
    required this.repository,
    required this.config,
    required this.imageProvider,
    required this.actions,
  });

  @override
  State<PersonalStatsPage> createState() => _PersonalStatsPageState();
}

class _PersonalStatsPageState extends State<PersonalStatsPage> {
  late final Future<PersonalStats> _statsFuture;
  late final Future<models.MediaItemListResult> _recentFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.repository
        .getStats(PersonalMediaQuery(mediaKinds: widget.config.mediaKinds));
    _recentFuture = widget.repository.getHistory(
      const PersonalMediaQuery(limit: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('观看统计')),
      body: FutureBuilder<PersonalStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          final stats = snapshot.data ?? const PersonalStats();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _statsFuture = widget.repository.getStats(
                  PersonalMediaQuery(mediaKinds: widget.config.mediaKinds),
                );
              });
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                // 概览行
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                  child: Row(
                    children: [
                      StatsSummaryCard(
                        icon: Icons.visibility_outlined,
                        count: stats.totalWatched,
                        label: '已观看',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      StatsSummaryCard(
                        icon: Icons.favorite_outline,
                        count: stats.totalFavorites,
                        label: '收藏数',
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 12),
                      StatsSummaryCard(
                        icon: Icons.play_circle_outline,
                        count: stats.continueWatchingCount,
                        label: '继续观看',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
                // 按类型细分
                if (stats.breakdown.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      '按类型细分',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final item in stats.breakdown)
                    _BreakdownRow(count: item),
                ],
                // 最近观看
                _RecentWatchSection(
                  future: _recentFuture,
                  imageProvider: widget.imageProvider,
                  actions: widget.actions,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 按类型细分行
class _BreakdownRow extends StatelessWidget {
  final MediaTypeCount count;

  const _BreakdownRow({required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              count.kind.jellyfinTypeName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(Icons.visibility_outlined,
                    size: 16, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text('${count.watchedCount}'),
                const SizedBox(width: 16),
                const Icon(Icons.favorite_outline, size: 16, color: Colors.redAccent),
                const SizedBox(width: 4),
                Text('${count.favoriteCount}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 最近观看区域
class _RecentWatchSection extends StatelessWidget {
  final Future<models.MediaItemListResult> future;
  final JellyfinImageProvider imageProvider;
  final PersonalActions actions;

  const _RecentWatchSection({
    required this.future,
    required this.imageProvider,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.MediaItemListResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final result = snapshot.data;
        if (result == null) return const SizedBox.shrink();

        final items = result.items;
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                '最近观看',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 224,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 176,
                    height: 224,
                    child: PersonalMediaCard(
                      imageProvider: imageProvider,
                      item: items[index],
                      actions: actions,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
