import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_auth/jellyfin_auth.dart';

import 'app_router.dart';
import '../data/audio_playback_adapter.dart';
import '../data/legacy_jellyfin_gateway.dart';
import '../data/personal_repository_adapter.dart';
import '../session/app_session_controller.dart';

/// Jellyfin 音乐 App 根 Widget
class JellyfinMusicApp extends StatefulWidget {
  const JellyfinMusicApp({super.key});

  @override
  State<JellyfinMusicApp> createState() => _JellyfinMusicAppState();
}

class _JellyfinMusicAppState extends State<JellyfinMusicApp> {
  final _sessionController = AppSessionController();
  final _gateway = LegacyJellyfinGateway();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(
      sessionController: _sessionController,
      gateway: _gateway,
      personalRepository: JellyfinPersonalRepositoryAdapter(
        gateway: _gateway,
        sessionController: _sessionController,
      ),
      audioPlaybackPort: AudioPlaybackAdapter.instance,
      discoveryService: ServerDiscoveryService(),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Jellyfin 音乐',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
