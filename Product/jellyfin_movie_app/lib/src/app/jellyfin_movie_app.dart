import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_router.dart';
import '../data/legacy_jellyfin_gateway.dart';
import '../session/app_session_controller.dart';

/// Jellyfin 电影 App 根 Widget
class JellyfinMovieApp extends StatefulWidget {
  const JellyfinMovieApp({super.key});

  @override
  State<JellyfinMovieApp> createState() => _JellyfinMovieAppState();
}

class _JellyfinMovieAppState extends State<JellyfinMovieApp> {
  final _sessionController = AppSessionController();
  final _gateway = LegacyJellyfinGateway();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(
      sessionController: _sessionController,
      gateway: _gateway,
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
      title: 'Jellyfin 电影',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
