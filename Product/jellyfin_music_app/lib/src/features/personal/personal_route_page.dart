import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';

import '../../session/app_session_controller.dart';
import '../../ui/jellyfin_music_image_provider.dart';

/// 音乐 App 个人中心路由页
///
/// 使用 PersonalModuleConfig.musicOnly()，只展示音乐相关记录。
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
      config: const PersonalModuleConfig.musicOnly(),
      imageProvider: JellyfinMusicImageProvider.fromSession(session),
      actions: PersonalActions(
        onOpenMedia: (context, item) {
          // 音乐 App 暂无播放详情跳转
        },
        onPlayMedia: (context, item) {
          // 音乐 App 暂无直接播放跳转
        },
        onLogout: () {
          sessionController.clearSession();
        },
        onOpenSettings: () => context.push('/personal/settings'),
        onOpenStats: () => context.push('/personal/stats'),
      ),
    );
  }
}
