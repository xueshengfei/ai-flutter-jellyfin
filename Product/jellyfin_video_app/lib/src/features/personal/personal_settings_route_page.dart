import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';

import '../../session/app_session_controller.dart';
import '../../ui/jellyfin_video_image_provider.dart';

/// 视频 App 设置页路由页
final class PersonalSettingsRoutePage extends StatelessWidget {
  final PersonalRepository repository;
  final AppSessionController sessionController;

  const PersonalSettingsRoutePage({
    super.key,
    required this.repository,
    required this.sessionController,
  });

  @override
  Widget build(BuildContext context) {
    final session = sessionController.currentSession;
    if (session == null) {
      return const Scaffold(body: Center(child: Text('登录态不存在')));
    }

    return PersonalSettingsPage(
      repository: repository,
      imageProvider: JellyfinVideoImageProvider.fromSession(session),
      onLogout: () => sessionController.clearSession(),
      onOpenStats: () => context.push('/personal/stats'),
    );
  }
}
