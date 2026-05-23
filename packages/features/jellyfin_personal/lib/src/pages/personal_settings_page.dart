import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../contracts/personal_repository.dart';

/// 个人设置页
final class PersonalSettingsPage extends StatelessWidget {
  final PersonalRepository repository;
  final JellyfinImageProvider imageProvider;
  final VoidCallback? onLogout;
  final VoidCallback? onOpenStats;

  const PersonalSettingsPage({
    super.key,
    required this.repository,
    required this.imageProvider,
    this.onLogout,
    this.onOpenStats,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: FutureBuilder<models.UserProfile>(
        future: repository.getProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('加载用户信息失败'));
          }
          return ListView(
            children: [
              _ProfileCard(profile: profile, imageProvider: imageProvider),
              const Divider(height: 1),
              if (onOpenStats != null)
                ListTile(
                  leading: const Icon(Icons.bar_chart_outlined),
                  title: const Text('查看统计'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenStats,
                ),
              if (onLogout != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    '退出登录',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: onLogout,
                ),
              ],
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('关于'),
                subtitle: Text('版本 0.3.0'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 头像 + 用户名 + 服务器信息卡片
class _ProfileCard extends StatelessWidget {
  final models.UserProfile profile;
  final JellyfinImageProvider imageProvider;

  const _ProfileCard({
    required this.profile,
    required this.imageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: colorScheme.primaryContainer,
            foregroundImage: profile.primaryImageTag != null
                ? NetworkImage(
                    imageProvider.buildImageUrl(
                      itemId: profile.id,
                      imageTag: profile.primaryImageTag,
                    ),
                  )
                : null,
            child: profile.primaryImageTag == null
                ? Text(
                    profile.name.isEmpty
                        ? '?'
                        : profile.name[0].toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile.isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '管理员',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  profile.serverUrl,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
