import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

/// 获取电影详情回调
typedef MovieDetailFetcher = Future<MediaItem> Function(String itemId);

/// 电影详情页面
///
/// 显示电影的完整元数据信息。
/// 通过回调解耦，不依赖 JellyfinClient。
class MovieDetailPage extends StatefulWidget {
  final MediaItem movie;
  final MovieDetailFetcher fetchDetail;
  final void Function(BuildContext context, MediaItem movie)? onStartPlayback;

  /// 图片加载抽象，为 null 时回退到 Image.network
  final JellyfinImageProvider? imageProvider;

  const MovieDetailPage({
    super.key,
    required this.movie,
    required this.fetchDetail,
    this.onStartPlayback,
    this.imageProvider,
  });

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late Future<MediaItem> _detailFuture;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  void _loadDetail() {
    setState(() {
      _detailFuture = widget.fetchDetail(widget.movie.id);
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
                widget.movie.name,
                style: TextStyle(
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 8,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
              background: _buildBackdrop(),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDetail),
            ],
          ),
          FutureBuilder<MediaItem>(
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在加载详情...'),
                    ],
                  )),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('加载失败: ${snapshot.error}'),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _loadDetail, child: const Text('重试')),
                    ],
                  )),
                );
              }
              return SliverToBoxAdapter(child: _buildContent(snapshot.data!));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    if (widget.movie.hasBackdropImage) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.imageProvider != null)
            JellyfinImage(
              imageProvider: widget.imageProvider!,
              itemId: widget.movie.id,
              imageTag: widget.movie.backdropImageTag,
              fillWidth: 800,
              fillHeight: 450,
              fit: BoxFit.cover,
              errorWidget: Container(color: Theme.of(context).colorScheme.surface),
            )
          else
            Image.network(
              widget.movie.getBackdropImageUrl()!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surface),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
              ),
            ),
          ),
        ],
      );
    }
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Icon(Icons.movie_outlined, size: 100, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildContent(MediaItem movie) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderInfo(movie),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => widget.onStartPlayback?.call(context, movie),
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
          const SizedBox(height: 24),
          if (movie.overview != null && movie.overview!.isNotEmpty) ...[
            _sectionTitle('剧情简介'),
            const SizedBox(height: 8),
            Text(movie.overview!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, color: Colors.grey.shade700)),
            const SizedBox(height: 24),
          ],
          if (movie.genres?.isNotEmpty ?? false) ...[
            _sectionTitle('类型'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: movie.genres!.map((g) => Chip(label: Text(g), visualDensity: VisualDensity.compact)).toList()),
            const SizedBox(height: 24),
          ],
          if (movie.communityRating != null) ...[
            _sectionTitle('评分'),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(movie.ratingText, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 24),
          ],
          if (movie.directors?.isNotEmpty ?? false) ...[
            _sectionTitle('导演'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: movie.directors!.map((d) => Chip(avatar: const Icon(Icons.person, size: 16), label: Text(d), visualDensity: VisualDensity.compact)).toList()),
            const SizedBox(height: 24),
          ],
          if (movie.writers?.isNotEmpty ?? false) ...[
            _sectionTitle('作者'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: movie.writers!.map((w) => Chip(avatar: const Icon(Icons.edit, size: 16), label: Text(w), visualDensity: VisualDensity.compact)).toList()),
            const SizedBox(height: 24),
          ],
          if (movie.studios?.isNotEmpty ?? false) ...[
            _sectionTitle('工作室'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: movie.studios!.map((s) => Chip(avatar: const Icon(Icons.business, size: 16), label: Text(s), visualDensity: VisualDensity.compact)).toList()),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(MediaItem movie) {
    return Row(
      children: [
        if (movie.hasCoverImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 100,
              child: widget.imageProvider != null
                  ? JellyfinImage(
                      imageProvider: widget.imageProvider!,
                      itemId: movie.id,
                      imageTag: movie.primaryImageTag,
                      fillWidth: 200,
                      fillHeight: 300,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        width: 100, height: 150,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.movie, color: Colors.grey),
                      ),
                    )
                  : Image.network(
                      movie.getCoverImageUrl()!,
                      width: 100, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 100, height: 150, color: Colors.grey.shade300, child: const Icon(Icons.movie, color: Colors.grey)),
                    ),
            ),
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(movie.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (movie.productionYear != null) Chip(label: Text('${movie.productionYear}'), visualDensity: VisualDensity.compact),
                  if (movie.officialRating != null) Chip(label: Text(movie.officialRating!), visualDensity: VisualDensity.compact, backgroundColor: Colors.orange.shade100),
                  if (movie.runTimeMinutes != null) Chip(label: Text(movie.durationText), visualDensity: VisualDensity.compact),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
  }
}
