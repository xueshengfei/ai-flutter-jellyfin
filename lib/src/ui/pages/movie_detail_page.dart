import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 电影详情页面
///
/// 显示电影的完整元数据信息
class MovieDetailPage extends StatefulWidget {
  final JellyfinClient client;
  final MediaItem movie;

  const MovieDetailPage({
    super.key,
    required this.client,
    required this.movie,
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
      _detailFuture = widget.client.mediaLibrary.getMediaItemDetail(widget.movie.id);
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
                widget.movie.name,
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
                onPressed: _loadDetail,
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
                          onPressed: _loadDetail,
                          child: Text('重试'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final movie = snapshot.data!;
              return SliverToBoxAdapter(
                child: _buildContent(movie),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建背景图片
  Widget _buildBackdrop() {
    if (widget.movie.hasBackdropImage) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.movie.getBackdropImageUrl()!,
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
  Widget _buildContent(MediaItem movie) {
    // 调试：打印所有字段
    print('📄 MovieDetailPage: 显示电影详情');
    print('   名称: ${movie.name}');
    print('   年份: ${movie.productionYear}');
    print('   评分: ${movie.communityRating}');
    print('   评级: ${movie.officialRating}');
    print('   时长: ${movie.runTimeMinutes}');
    print('   剧情简介: ${movie.overview?.substring(0, movie.overview!.length > 50 ? 50 : movie.overview!.length)}...');
    print('   类型数量: ${movie.genres?.length ?? 0}');
    print('   导演数量: ${movie.directors?.length ?? 0}');
    print('   作者数量: ${movie.writers?.length ?? 0}');
    print('   工作室数量: ${movie.studios?.length ?? 0}');

    if (movie.genres != null && movie.genres!.isNotEmpty) {
      print('   类型列表: ${movie.genres}');
    }
    if (movie.directors != null && movie.directors!.isNotEmpty) {
      print('   导演列表: ${movie.directors}');
    }
    if (movie.studios != null && movie.studios!.isNotEmpty) {
      print('   工作室列表: ${movie.studios}');
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部信息行
          _buildHeaderInfo(movie),
          const SizedBox(height: 24),

          // 播放按钮
          SizedBox(
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
          const SizedBox(height: 24),

          // 剧情简介
          if (movie.overview != null && movie.overview!.isNotEmpty) ...[
            _buildSectionTitle('剧情简介'),
            const SizedBox(height: 8),
            Text(
              movie.overview!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 24),
          ],

          // 类型标签
          if (movie.genres != null && movie.genres!.isNotEmpty) ...[
            _buildSectionTitle('类型'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: movie.genres!
                  .map((genre) => Chip(
                        label: Text(genre),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // 评分信息
          _buildSectionTitle('评分'),
          const SizedBox(height: 8),
            _buildRatingRow(movie),
          const SizedBox(height: 24),

          // 导演
          if (movie.directors != null && movie.directors!.isNotEmpty) ...[
            _buildSectionTitle('导演'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: movie.directors!
                  .map((director) => Chip(
                        avatar: Icon(Icons.person, size: 16),
                        label: Text(director),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // 作者
          if (movie.writers != null && movie.writers!.isNotEmpty) ...[
            _buildSectionTitle('作者'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: movie.writers!
                  .map((writer) => Chip(
                        avatar: Icon(Icons.edit, size: 16),
                        label: Text(writer),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // 工作室
          if (movie.studios != null && movie.studios!.isNotEmpty) ...[
            _buildSectionTitle('工作室'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: movie.studios!
                  .map((studio) => Chip(
                        avatar: Icon(Icons.business, size: 16),
                        label: Text(studio),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // 底部间距
          SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 构建顶部信息行
  Widget _buildHeaderInfo(MediaItem movie) {
    return Row(
      children: [
        // 海报图片
        if (movie.hasCoverImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              movie.getCoverImageUrl()!,
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
                movie.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),

              // 年份和评级
              Wrap(
                spacing: 8,
                children: [
                  if (movie.productionYear != null)
                    Chip(
                      label: Text('${movie.productionYear}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (movie.officialRating != null)
                    Chip(
                      label: Text(movie.officialRating!),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.orange.shade100,
                    ),
                  if (movie.runTimeMinutes != null)
                    Chip(
                      label: Text(movie.durationText),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建评分行
  Widget _buildRatingRow(MediaItem movie) {
    return Row(
      children: [
        // 社区评分
        if (movie.communityRating != null) ...[
          Icon(Icons.star, color: Colors.amber, size: 20),
          const SizedBox(width: 4),
          Text(
            movie.ratingText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          if (movie.voteCount != null)
            Text(
              '(${movie.voteCount} 票)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
        ],
      ],
    );
  }

  /// 构建章节标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
