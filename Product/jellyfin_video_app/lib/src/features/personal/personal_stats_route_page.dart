import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';

import '../../session/app_session_controller.dart';
import '../../ui/jellyfin_video_image_provider.dart';

/// 视频 App 统计页路由页
final class PersonalStatsRoutePage extends StatelessWidget {
  final PersonalRepository repository;
  final AppSessionController sessionController;

  const PersonalStatsRoutePage({
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

    return PersonalStatsPage(
      repository: repository,
      config: const PersonalModuleConfig(
        title: '我的视频',
        sections: [
          PersonalSection.continueWatching,
          PersonalSection.favorites,
          PersonalSection.history,
        ],
        mediaKinds: PersonalMediaKindSets.video,
      ),
      imageProvider: JellyfinVideoImageProvider.fromSession(session),
      actions: PersonalActions(
        onOpenMedia: (context, item) {
          context.push('/media/items/${item.id}');
        },
        onPlayMedia: (context, item) {
          context.push('/playback/video/${item.id}');
        },
      ),
    );
  }
}
