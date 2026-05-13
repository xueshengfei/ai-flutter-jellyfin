import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';

import '../../session/app_session_controller.dart';
import '../../ui/jellyfin_app_image_provider.dart';

/// jellyfin_app 个人中心路由页
///
/// 注入 PersonalModuleConfig.full()，展示所有媒体类型。
final class PersonalRoutePage extends StatelessWidget {
  final PersonalRepository repository;
  final AppSessionController sessionController;

  const PersonalRoutePage({
    super.key,
    required this.repository,
    required this.sessionController,
  });

  @override
  Widget build(BuildContext context) {
    final session = sessionController.currentSession;
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('登录态不存在')),
      );
    }

    return PersonalPage(
      repository: repository,
      config: const PersonalModuleConfig.full(),
      imageProvider: JellyfinAppImageProvider.fromSession(session),
      actions: PersonalActions(
        onOpenMedia: (context, item) {
          context.push('/media/items/${item.id}');
        },
        onPlayMedia: (context, item) {
          context.push('/playback/video/${item.id}');
        },
        onLogout: () {
          sessionController.clearSession();
        },
      ),
    );
  }
}
