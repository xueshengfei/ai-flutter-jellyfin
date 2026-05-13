import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rvc_flutter/rvc_flutter.dart';
import 'app_router.dart';
import '../data/audio_playback_adapter.dart';
import '../data/legacy_jellyfin_gateway.dart';
import '../data/personal_repository_adapter.dart';
import '../session/app_session_controller.dart';

/// Jellyfin 产品 App 根 Widget
class JellyfinApp extends StatefulWidget {
  const JellyfinApp({super.key});

  @override
  State<JellyfinApp> createState() => _JellyfinAppState();
}

class _JellyfinAppState extends State<JellyfinApp> {
  final _sessionController = AppSessionController();
  final _gateway = LegacyJellyfinGateway();
  late final GoRouter _router;

  /// App 级 RVC 任务控制器 — 延迟初始化，生命周期与 App 一致
  /// 用户退出 RVC 页面后任务继续执行，下次进入可恢复
  RvcTaskController? _rvcTaskController;

  /// 获取或创建 RVC 任务控制器
  RvcTaskController _getOrCreateRvcController() {
    return _rvcTaskController ??= RvcTaskController(
      serverUrl: 'http://localhost:9880',
    );
  }

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
      rvcTaskController: _getOrCreateRvcController(),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _rvcTaskController?.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Jellyfin',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
