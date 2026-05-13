import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';

import '../../session/app_session_controller.dart';
import '../../ui/jellyfin_movie_image_provider.dart';

/// 电影 App 个人中心路由页
///
/// 使用 PersonalModuleConfig.moviesOnly()，只展示电影相关记录。
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
      config: const PersonalModuleConfig.moviesOnly(),
      imageProvider: JellyfinMovieImageProvider.fromSession(session),
      actions: PersonalActions(
        onOpenMedia: (context, item) {
          context.push('/movies/${item.id}');
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
