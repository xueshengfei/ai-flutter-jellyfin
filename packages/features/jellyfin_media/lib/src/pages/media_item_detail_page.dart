import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_media/src/widgets/person_avatar_card.dart';

// MediaItemDetailFetcher 和 SeasonsFetcher 已收敛到 jellyfin_models/media_contracts.dart
// 此处 re-export 以保持子入口 jellyfin_media_pages.dart 的兼容性

/// 通用媒体项详情页面
///
/// 支持所有媒体类型：Movie, Series, Episode 等
/// 通过回调解耦，不直接依赖具体页面
class MediaItemDetailPage extends StatefulWidget {
  /// 初始媒体项数据
  final MediaItem item;

  /// 获取详情回调
  final MediaItemDetailFetcher fetchDetail;

  /// 获取季列表回调
  final SeasonsFetcher? fetchSeasons;

  /// 跳转到人员详情页
  final void Function(BuildContext context, String personId, String personName, String personType)? onNavigateToPerson;

  /// 跳转到剧集列表页
  final void Function(BuildContext context, MediaItem series, Season season)? onNavigateToEpisodes;

  /// 开始播放
  final void Function(BuildContext context, MediaItem item)? onStartPlayback;

  const MediaItemDetailPage({
    super.key,
    required this.item,
    required this.fetchDetail,
    this.fetchSeasons,
    this.onNavigateToPerson,
    this.onNavigateToEpisodes,
    this.onStartPlayback,
  });

  @override
  State<MediaItemDetailPage> createState() => _MediaItemDetailPageState();
}

class _MediaItemDetailPageState extends State<MediaItemDetailPage> {
  late Future<MediaItem> _detailFuture;
  Future<SeasonListResult>? _seasonsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _detailFuture = widget.fetchDetail(widget.item.id);

      if (widget.item.type.toLowerCase() == 'series' && widget.fetchSeasons != null) {
        _seasonsFuture = widget.fetchSeasons!(widget.item.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.item.name,
                style: TextStyle(
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 8,
                      color: Colors.black.withOpacity(0.8),
                    ),
                  ],
                ),
              ),
              background: _buildBackdrop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: _startPlayback,
                tooltip: '播放',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
              ),
            ],
          ),

          FutureBuilder<MediaItem>(
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('正在加载详情...'),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
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
                  ),
                );
              }

              final item = snapshot.data!;
              return SliverToBoxAdapter(
                child: _buildContent(item),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    if (widget.item.hasBackdropImage) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.item.getBackdropImageUrl()!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Theme.of(context).colorScheme.surface,
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      return Container(
        color: Theme.of(context).colorScheme.surface,
        child: Icon(
          Icons.movie_outlined,
          size: 100,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
  }

  Widget _buildContent(MediaItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildHeaderInfo(item),
        ),
        const SizedBox(height: 16),

        // 播放按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _startPlayback,
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 剧情简介
        if (item.overview != null && item.overview!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('剧情简介'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    item.overview!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: Colors.grey.shade700,
                        ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

        // 季列表
        if (item.type.toLowerCase() == 'series')
          _buildSeasonsList(),
        const SizedBox(height: 24),

        // 演员列表
        if (item.actorInfos != null && item.actorInfos!.isNotEmpty)
          PersonListRow(
            persons: item.actorInfos!,
            title: '演员',
            itemBuilder: (person) => PersonAvatarCard(
              person: person,
              onTap: () {
                if (person.id != null) {
                  widget.onNavigateToPerson?.call(context, person.id!, person.name, 'actor');
                }
              },
            ),
          ),
        const SizedBox(height: 24),

        // 导演列表
        if (item.directorInfos != null && item.directorInfos!.isNotEmpty)
          PersonListRow(
            persons: item.directorInfos!,
            title: '导演',
            itemBuilder: (person) => PersonAvatarCard(
              person: person,
              onTap: () {
                if (person.id != null) {
                  widget.onNavigateToPerson?.call(context, person.id!, person.name, 'director');
                }
              },
            ),
          ),
        const SizedBox(height: 24),

        // 编剧列表
        if (item.writerInfos != null && item.writerInfos!.isNotEmpty)
          PersonListRow(
            persons: item.writerInfos!,
            title: '编剧',
            itemBuilder: (person) => PersonAvatarCard(
              person: person,
              onTap: () {
                if (person.id != null) {
                  widget.onNavigateToPerson?.call(context, person.id!, person.name, 'writer');
                }
              },
            ),
          ),
        const SizedBox(height: 24),

        // 其他信息
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildAdditionalInfo(item),
        ),
      ],
    );
  }

  Widget _buildHeaderInfo(MediaItem item) {
    return Row(
      children: [
        if (item.hasCoverImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.getCoverImageUrl()!,
              width: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 100,
                  height: 150,
                  color: Colors.grey.shade300,
                  child: Icon(Icons.movie, color: Colors.grey),
                );
              },
            ),
          ),
        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                children: [
                  if (item.productionYear != null)
                    Chip(
                      label: Text('${item.productionYear}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (item.officialRating != null)
                    Chip(
                      label: Text(item.officialRating!),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.orange.shade100,
                    ),
                  if (item.runTimeMinutes != null)
                    Chip(
                      label: Text(item.durationText),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (item.communityRating != null)
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      item.ratingText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonsList() {
    if (_seasonsFuture == null) return const SizedBox.shrink();

    return FutureBuilder<SeasonListResult>(
      future: _seasonsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.seasons.isEmpty) {
          return const SizedBox.shrink();
        }

        final seasons = snapshot.data!.seasons;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '季',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: seasons.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildSeasonCard(seasons[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSeasonCard(Season season) {
    return InkWell(
      onTap: () {
        widget.onNavigateToEpisodes?.call(context, widget.item, season);
      },
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: season.hasCoverImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          season.getCoverImageUrl()!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Text(
                                  season.seasonNumberText,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text(
                          season.seasonNumberText,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),

            Text(
              season.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            if (season.episodeCount != null)
              Text(
                '${season.episodeCount} 集',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfo(MediaItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.genres != null && item.genres!.isNotEmpty) ...[
          _buildSectionTitle('类型'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.genres!
                  .map((genre) => Chip(
                        label: Text(genre),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (item.studios != null && item.studios!.isNotEmpty) ...[
          _buildSectionTitle('工作室'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.studios!
                  .map((studio) => Chip(
                        avatar: const Icon(Icons.business, size: 16),
                        label: Text(studio),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _startPlayback() {
    widget.onStartPlayback?.call(context, widget.item);
  }
}
