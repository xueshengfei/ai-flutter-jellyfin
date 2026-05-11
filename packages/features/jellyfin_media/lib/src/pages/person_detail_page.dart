import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_media/src/models/person_models.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

/// 获取人物详情回调
typedef PersonDetailFetcher = Future<Person> Function(String personId, String personType);

/// 获取人物作品列表回调
typedef PersonCreditsFetcher = Future<PersonCreditsResult> Function(String personId, {List<String>? includeItemTypes});

/// 个人详情页面
///
/// 显示人员（演员、导演、编剧等）的详细信息和参与的作品列表
/// 通过回调解耦，不直接依赖 JellyfinClient
class PersonDetailPage extends StatefulWidget {
  /// 人员ID
  final String personId;

  /// 人员姓名
  final String personName;

  /// 人员类型
  final String personType;

  /// 获取详情回调
  final PersonDetailFetcher fetchPersonDetail;

  /// 获取作品列表回调
  final PersonCreditsFetcher fetchPersonCredits;

  /// 图片加载器
  final JellyfinImageProvider imageProvider;

  /// 跳转到媒体详情页
  final void Function(BuildContext context, MediaItem item)? onNavigateToMediaItem;

  const PersonDetailPage({
    super.key,
    required this.personId,
    required this.personName,
    required this.personType,
    required this.fetchPersonDetail,
    required this.fetchPersonCredits,
    required this.imageProvider,
    this.onNavigateToMediaItem,
  });

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  late Future<Person> _detailFuture;
  late Future<PersonCreditsResult> _creditsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _detailFuture = widget.fetchPersonDetail(
      widget.personId,
      widget.personType,
    );
    _creditsFuture = widget.fetchPersonCredits(
      widget.personId,
      includeItemTypes: const ['movie', 'series'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.personName,
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
              background: _buildBackground(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _loadData();
                  });
                },
              ),
            ],
          ),

          // 个人信息
          SliverToBoxAdapter(
            child: FutureBuilder<Person>(
              future: _detailFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('加载失败: ${snapshot.error}'),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final person = snapshot.data!;
                return _buildPersonInfo(person);
              },
            ),
          ),

          // 作品列表标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                '参与作品',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),

          // 作品列表
          FutureBuilder<PersonCreditsResult>(
            future: _creditsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('加载失败: ${snapshot.error}'),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.items.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('暂无作品')),
                );
              }

              final items = snapshot.data!.items;

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.67,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      return MediaItemCard(
                        item: item,
                        imageProvider: widget.imageProvider,
                        onTap: () {
                          widget.onNavigateToMediaItem?.call(context, item);
                        },
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: Icon(
            Icons.person,
            size: 100,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
  }

  Widget _buildPersonInfo(Person person) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (person.imageUrl != null) ...[
            ClipOval(
              child: Image.network(
                person.imageUrl!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text(
            person.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Chip(
            label: Text(person.typeDisplayName),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(height: 16),

          if (person.bio != null && person.bio!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                person.bio!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (person.birthDate != null) ...[
            _buildInfoRow(
              Icons.cake,
              '出生日期',
              _formatDate(person.birthDate!),
            ),
            const SizedBox(height: 8),
          ],

          if (person.deathDate != null) ...[
            _buildInfoRow(
              Icons.event,
              '逝世日期',
              _formatDate(person.deathDate!),
            ),
            const SizedBox(height: 8),
          ],

          if (person.genres != null && person.genres!.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: person.genres!
                  .map((genre) => Chip(
                        label: Text(genre),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}年${date.month}月${date.day}日';
    } catch (e) {
      return dateString;
    }
  }
}
