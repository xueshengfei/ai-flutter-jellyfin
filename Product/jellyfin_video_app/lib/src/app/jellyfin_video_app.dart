import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_auth/jellyfin_auth.dart';
import 'app_router.dart';
import '../data/legacy_jellyfin_gateway.dart';
import '../data/personal_repository_adapter.dart';
import '../session/app_session_controller.dart';

/// Jellyfin 视频 App 根 Widget
class JellyfinVideoApp extends StatefulWidget {
  const JellyfinVideoApp({super.key});

  @override
  State<JellyfinVideoApp> createState() => _JellyfinVideoAppState();
}

class _JellyfinVideoAppState extends State<JellyfinVideoApp> {
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
      title: 'Jellyfin 视频',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
