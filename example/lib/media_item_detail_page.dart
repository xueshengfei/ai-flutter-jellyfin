import 'package:flutter/material.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'package:jellyfin_service/jellyfin_service.dart';
import 'person_avatar_card.dart';
import 'person_detail_page.dart';
import 'episodes_page.dart';

/// 通用媒体项详情页面
///
/// 支持所有媒体类型：Movie, Series, Episode 等
class MediaItemDetailPage extends StatefulWidget {
  final JellyfinClient client;
  final MediaItem item;

  const MediaItemDetailPage({
    super.key,
    required this.client,
    required this.item,
  });

  @override
  State<MediaItemDetailPage> createState() => _MediaItemDetailPageState();
}

class _MediaItemDetailPageState extends State<MediaItemDetailPage> {
  late Future<MediaItem> _detailFuture;
  late Future<SeasonListResult> _seasonsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _detailFuture = widget.client.mediaLibrary.getMediaItemDetail(widget.item.id);

      // 如果是剧集类型，同时加载季列表
      if (widget.item.type.toLowerCase() == 'series') {
        _seasonsFuture = widget.client.mediaLibrary.getSeasons(widget.item.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 自定义 AppBar
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
                      offset: Offset(0, 1),
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
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
              ),
            ],
          ),

          // 内容
          FutureBuilder<MediaItem>(
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在加载详情...'),
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
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text('加载失败: ${snapshot.error}'),
                        SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadData,
                          child: Text('重试'),
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

  /// 构建背景图片
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

  /// 构建内容
  Widget _buildContent(MediaItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部信息行
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('播放功能待实现'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(Icons.play_arrow),
              label: Text('播放'),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 季列表（仅剧集显示）
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
                // 跳转到演员详情页
                if (person.id != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PersonDetailPage(
                        client: widget.client,
                        personId: person.id!,
                        personName: person.name,
                        personType: jellyfin_dart.PersonKind.actor,
                      ),
                    ),
                  );
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
                // 跳转到导演详情页
                if (person.id != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PersonDetailPage(
                        client: widget.client,
                        personId: person.id!,
                        personName: person.name,
                        personType: jellyfin_dart.PersonKind.director,
                      ),
                    ),
                  );
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
                // 跳转到编剧详情页
                if (person.id != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PersonDetailPage(
                        client: widget.client,
                        personId: person.id!,
                        personName: person.name,
                        personType: jellyfin_dart.PersonKind.writer,
                      ),
                    ),
                  );
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

  /// 构建顶部信息行
  Widget _buildHeaderInfo(MediaItem item) {
    return Row(
      children: [
        // 海报图片
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

        // 信息
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                item.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),

              // 年份和评级
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

              // 评分
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

  /// 构建季列表（横向滚动）
  Widget _buildSeasonsList() {
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
                physics: const AlwaysScrollableScrollPhysics(), // 确保可以滚动
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: seasons.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final season = seasons[index];
                  return _buildSeasonCard(season);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建季卡片
  Widget _buildSeasonCard(Season season) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EpisodesPage(
              client: widget.client,
              series: widget.item,
              season: season,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 季封面
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

            // 季名称
            Text(
              season.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // 剧集数量
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

  /// 构建其他信息（剧情简介、类型、导演等）
  Widget _buildAdditionalInfo(MediaItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 剧情简介
        if (item.overview != null && item.overview!.isNotEmpty) ...[
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

        // 类型标签
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

        // 工作室
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
                        avatar: Icon(Icons.business, size: 16),
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

  /// 构建章节标题
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
}
