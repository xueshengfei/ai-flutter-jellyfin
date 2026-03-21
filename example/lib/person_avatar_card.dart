import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 人员头像卡片（通用）
///
/// 用于显示演员、导演、编剧等人员信息
class PersonAvatarCard extends StatelessWidget {
  /// 人员信息
  final ActorInfo person;

  /// 点击回调
  final VoidCallback? onTap;

  const PersonAvatarCard({
    super.key,
    required this.person,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = SizedBox(
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
                  child: person.imageUrl != null
                      ? Image.network(
                          person.imageUrl!,
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

          // 人员名称
          Text(
            person.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // 角色/职位
          if (person.role != null && person.role!.isNotEmpty)
            Text(
              person.role!,
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

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// 人员列表横向滚动组件
///
/// 通用的横向滚动人员列表，支持演员、导演、编剧等
class PersonListRow extends StatefulWidget {
  /// 人员列表
  final List<ActorInfo> persons;

  /// 标题
  final String? title;

  /// 自定义构建器（可选）
  final Widget Function(ActorInfo person)? itemBuilder;

  const PersonListRow({
    super.key,
    required this.persons,
    this.title,
    this.itemBuilder,
  });

  @override
  State<PersonListRow> createState() => _PersonListRowState();
}

class _PersonListRowState extends State<PersonListRow> {
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
    final target = _scrollController.position.pixels - 300.0;
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
    if (widget.persons.isEmpty) {
      return const SizedBox.shrink();
    }

    // 只有当人员数量大于7个时才显示左右按钮
    final needsScrollButtons = widget.persons.length > 7;

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
                  '(${widget.persons.length})',
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
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: needsScrollButtons ? 48 : 16,
                ),
                itemCount: widget.persons.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (widget.itemBuilder != null) {
                    return widget.itemBuilder!(widget.persons[index]);
                  }
                  return PersonAvatarCard(person: widget.persons[index]);
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
