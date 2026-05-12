import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_service/src/app_shell/app_session_controller.dart';
import 'package:jellyfin_service/src/app_shell/go_router_app_navigator.dart';
import 'package:jellyfin_service/src/app_shell/jellyfin_go_router.dart';

/// Root Flutter app shell backed by go_router.
///
/// This widget owns app session state, the go_router instance, and the concrete
/// [AppNavigator] adapter used by feature modules.
class JellyfinAppShell extends StatefulWidget {
  final String title;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode? themeMode;

  const JellyfinAppShell({
    super.key,
    this.title = 'Jellyfin',
    this.theme,
    this.darkTheme,
    this.themeMode,
  });

  @override
  State<JellyfinAppShell> createState() => _JellyfinAppShellState();
}

class _JellyfinAppShellState extends State<JellyfinAppShell> {
  late final AppSessionController _sessionController;
  late final GoRouterAppNavigator _appNavigator;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _sessionController = AppSessionController();
    _appNavigator = GoRouterAppNavigator();
    _router = createJellyfinGoRouter(
      sessionController: _sessionController,
      appNavigator: _appNavigator,
    );
    _appNavigator.attach(_router);
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
      title: widget.title,
      theme: widget.theme,
      darkTheme: widget.darkTheme,
      themeMode: widget.themeMode,
      routerConfig: _router,
    );
  }
}
