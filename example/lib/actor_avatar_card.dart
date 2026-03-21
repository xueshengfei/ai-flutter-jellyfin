import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 演员头像卡片组件
///
/// 用于在详情页中显示演员信息
class ActorAvatarCard extends StatelessWidget {
  final ActorInfo actor;

  const ActorAvatarCard({
    super.key,
    required this.actor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头像图片
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: ClipOval(
                  child: actor.imageUrl != null
                      ? Image.network(
                          actor.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.person,
                                size: 32,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Icon(
                          Icons.person,
                          size: 32,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 演员名称
          Text(
            actor.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // 角色名称
          if (actor.role != null && actor.role!.isNotEmpty)
            Text(
              actor.role!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// 演员列表横向滚动组件（带滚动提示）
///
/// 显示演员头像的横向滚动列表
class ActorListRow extends StatefulWidget {
  final List<ActorInfo> actors;
  final String? title;

  const ActorListRow({
    super.key,
    required this.actors,
    this.title,
  });

  @override
  State<ActorListRow> createState() => _ActorListRowState();
}

class _ActorListRowState extends State<ActorListRow> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftHint = false;
  bool _showRightHint = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() => _updateScrollHints());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollHints() {
    if (!mounted) return;

    setState(() {
      _showLeftHint = _scrollController.position.pixels > 16;
      _showRightHint = _scrollController.position.pixels <
          _scrollController.position.maxScrollExtent - 16;
    });
  }

  // 点击向左滚动
  void _scrollLeft() {
    final target = _scrollController.position.pixels - 300.0; // 每次滚动300像素（约3-4个演员）
    _scrollController.animateTo(
      target < 0 ? 0 : target,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // 点击向右滚动
  void _scrollRight() {
    final target = _scrollController.position.pixels + 300.0;
    final maxExtent = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target > maxExtent ? maxExtent : target,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actors.isEmpty) {
      return const SizedBox.shrink();
    }

    print('🎭 ActorListRow: 构建演员列表，数量: ${widget.actors.length}');

    // 只有当演员数量大于7个时才显示左右按钮
    final needsScrollButtons = widget.actors.length > 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title != null && widget.title!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  widget.title!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${widget.actors.length})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
                const Spacer(),
                // 滚动提示文本
                if (needsScrollButtons)
                  Text(
                    '点击箭头滚动',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue,
                          fontSize: 10,
                        ),
                  ),
              ],
            ),
          ),
        ] else
          const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: Stack(
            children: [
              // 列表 - 禁用直接拖动
              ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(), // 禁用鼠标拖动
                padding: EdgeInsets.symmetric(
                  horizontal: needsScrollButtons ? 48 : 16,
                ),
                itemCount: widget.actors.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  print('   构建演员卡片: ${widget.actors[index].name}');
                  return ActorAvatarCard(actor: widget.actors[index]);
                },
              ),

              // 左侧滚动按钮
              if (needsScrollButtons && _showLeftHint)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 48,
                  child: InkWell(
                    onTap: _scrollLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Theme.of(context).colorScheme.surface.withOpacity(0.95),
                            Theme.of(context).colorScheme.surface.withOpacity(0.6),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.chevron_left,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),

              // 右侧滚动按钮
              if (needsScrollButtons && _showRightHint)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 48,
                  child: InkWell(
                    onTap: _scrollRight,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Theme.of(context).colorScheme.surface.withOpacity(0.6),
                            Theme.of(context).colorScheme.surface.withOpacity(0.95),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
