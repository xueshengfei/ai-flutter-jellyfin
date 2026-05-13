import 'package:flutter/material.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'package:jellyfin_service/jellyfin_service.dart';
import 'package:jellyfin_service/src/ui/widgets/media_item_card.dart';
import 'package:jellyfin_service/src/ui/pages/media_item_detail_page.dart';

/// 个人详情页面
///
/// 显示人员（演员、导演、编剧等）的详细信息和参与的作品列表
class PersonDetailPage extends StatefulWidget {
  final JellyfinClient client;
  final String personId;
  final String personName;
  final jellyfin_dart.PersonKind personType;

  const PersonDetailPage({
    super.key,
    required this.client,
    required this.personId,
    required this.personName,
    required this.personType,
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
    _detailFuture = widget.client.mediaLibrary.getPersonDetail(
      widget.personId,
      widget.personType,
    );
    _creditsFuture = widget.client.mediaLibrary.getPersonCredits(
      personId: widget.personId,
      includeItemTypes: const [
        jellyfin_dart.BaseItemKind.movie,
        jellyfin_dart.BaseItemKind.series,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 带背景的 AppBar
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
                      offset: Offset(0, 1),
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
                          Icon(Icons.error_outline, size: 48, color: Colors.red),
                          SizedBox(height: 16),
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

          // 作品列表（网格）
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
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
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
                        client: widget.client,
                        item: item,
                        onTap: () {
                          // 跳转到媒体详情页
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MediaItemDetailPage(
                                client: widget.client,
                                item: item,
                              ),
                            ),
                          );
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

  /// 构建背景图片
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

  /// 构建个人信息
  Widget _buildPersonInfo(Person person) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 头像
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

          // 姓名
          Text(
            person.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 类型标签
          Chip(
            label: Text(person.typeDisplayName),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(height: 16),

          // 简介
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

          // 出生日期（如果有）
          if (person.birthDate != null) ...[
            _buildInfoRow(
              Icons.cake,
              '出生日期',
              _formatDate(person.birthDate!),
            ),
            const SizedBox(height: 8),
          ],

          // 死亡日期（如果有）
          if (person.deathDate != null) ...[
            _buildInfoRow(
              Icons.event,
              '逝世日期',
              _formatDate(person.deathDate!),
            ),
            const SizedBox(height: 8),
          ],

          // 类型标签
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

  /// 构建信息行
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

  /// 格式化日期
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}年${date.month}月${date.day}日';
    } catch (e) {
      return dateString;
    }
  }
}
