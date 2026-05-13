import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;

/// 个人页头部 — 用户信息 + 退出登录
final class PersonalHeader extends StatelessWidget {
  final models.UserProfile profile;
  final VoidCallback? onLogout;

  const PersonalHeader({
    super.key,
    required this.profile,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        child: Text(profile.name.isEmpty ? '?' : profile.name[0].toUpperCase()),
      ),
      title: Text(profile.name),
      subtitle: Text(profile.serverUrl),
      trailing: onLogout == null
          ? null
          : IconButton(
              tooltip: '退出登录',
              icon: const Icon(Icons.logout),
              onPressed: onLogout,
            ),
    );
  }
}
