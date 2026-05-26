import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../../data/jellyfin_gateway.dart';
import '../../ui/jellyfin_video_image_provider.dart';

/// 推荐页 Tab 内容
///
/// 布局分区：
/// 1. Banner 轮播（最新项的 backdrop 图）
/// 2. 继续观看（水平列表）
/// 3. 最新电影（水平列表）
/// 4. 最新剧集（水平列表）
class RecommendTab extends StatefulWidget {
  final JellyfinGateway gateway;
  final JellyfinVideoImageProvider imageProvider;
  final List<models.MediaLibrary> libraries;

  const RecommendTab({
    super.key,
    required this.gateway,
    required this.imageProvider,
    required this.libraries,
  });

  @override
  State<RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<RecommendTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // Banner 轮播
        _BannerSection(
          gateway: widget.gateway,
          imageProvider: widget.imageProvider,
          libraries: widget.libraries,
        ),
        // 继续观看
        _Section(
          title: '继续观看',
          future: widget.gateway.getContinueWatching(limit: 10),
          imageProvider: widget.imageProvider,
          onTapItem: (item) => context.push('/media/items/${item.id}'),
        ),
        // 各个库的最新内容
        for (final library in widget.libraries)
          _Section(
            title: '最新${library.name}',
            future: widget.gateway.getLatestMediaItems(library.id, limit: 12),
            imageProvider: widget.imageProvider,
            onTapItem: (item) => context.push('/media/items/${item.id}'),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Banner 轮播区 ───

class _BannerSection extends StatefulWidget {
  final JellyfinGateway gateway;
  final JellyfinVideoImageProvider imageProvider;
  final List<models.MediaLibrary> libraries;

  const _BannerSection({
    required this.gateway,
    required this.imageProvider,
    required this.libraries,
  });

  @override
  State<_BannerSection> createState() => _BannerSectionState();
}

class _BannerSectionState extends State<_BannerSection> {
  PageController? _pageController;
  Timer? _autoPlayTimer;
  int _currentPage = 0;
  List<models.MediaItem> _items = const [];

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  void _startAutoPlay(int itemCount) {
    _autoPlayTimer?.cancel();
    if (itemCount <= 1) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % itemCount;
      _pageController?.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<models.MediaItem>>(
      future: widget.gateway.getSuggestions(limit: 8),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final items = snapshot.data!;

        // 首次拿到数据时初始化 controller 和定时器
        if (_items != items) {
          _items = items;
          _pageController?.dispose();
          _currentPage = 0;
          _pageController = PageController();
          _startAutoPlay(items.length);
        }

        return SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: items.length,
            onPageChanged: (index) => _currentPage = index,
            itemBuilder: (context, index) {
              final item = items[index];
              return _BannerCard(
                item: item,
                imageProvider: widget.imageProvider,
                onTap: () => context.push('/media/items/${item.id}'),
              );
            },
          ),
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final models.MediaItem item;
  final JellyfinVideoImageProvider imageProvider;
  final VoidCallback onTap;

  const _BannerCard({
    required this.item,
    required this.imageProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop 图片
            JellyfinImage(
              itemId: item.id,
              imageType: JellyfinImageType.backdrop,
              imageTag: item.backdropImageTag,
              imageProvider: imageProvider,
              fit: BoxFit.cover,
            ),
            // 底部渐变 + 标题
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 通用分区组件 ───

class _Section extends StatelessWidget {
  final String title;
  final Future<List<models.MediaItem>> future;
  final JellyfinVideoImageProvider imageProvider;
  final void Function(models.MediaItem) onTapItem;

  const _Section({
    required this.title,
    required this.future,
    required this.imageProvider,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<models.MediaItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final items = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            // 水平列表
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _MediaCard(
                    item: item,
                    imageProvider: imageProvider,
                    onTap: () => onTapItem(item),
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

class _MediaCard extends StatelessWidget {
  final models.MediaItem item;
  final JellyfinVideoImageProvider imageProvider;
  final VoidCallback onTap;

  const _MediaCard({
    required this.item,
    required this.imageProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasProgress = item.playedPercentage != null &&
        item.playedPercentage! > 0 &&
        item.playedPercentage! < 100;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    JellyfinImage(
                      itemId: item.id,
                      imageType: JellyfinImageType.primary,
                      imageTag: item.primaryImageTag,
                      imageProvider: imageProvider,
                      fit: BoxFit.cover,
                    ),
                    // 继续观看进度条
                    if (hasProgress)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: item.playedPercentage! / 100,
                          backgroundColor: Colors.black26,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 标题
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
