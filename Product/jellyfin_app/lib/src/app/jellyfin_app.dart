import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_auth/jellyfin_auth.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';
import 'package:rvc_flutter/rvc_flutter.dart';
import 'app_router.dart';
import '../data/audio_playback_adapter.dart';
import '../data/legacy_jellyfin_gateway.dart';
import '../data/personal_repository_adapter.dart';
import '../session/app_session_controller.dart';
import '../ui/jellyfin_app_image_provider.dart';

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
      discoveryService: ServerDiscoveryService(),
    );

    // 登录后用 session 的 serverUrl 更新 RVC 服务地址
    _sessionController.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    final serverUrl = _sessionController.currentSession?.serverUrl;
    if (serverUrl != null && serverUrl.isNotEmpty) {
      final rvcUrl = deriveServiceUrl(serverUrl, 9880);
      _rvcTaskController?.updateServerUrl(rvcUrl);
    }
  }

  @override
  void dispose() {
    _sessionController.removeListener(_onSessionChanged);
    _router.dispose();
    _rvcTaskController?.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听 session 变化，session 变化时重建 JellyfinImageProviderScope
    // （登录/登出/切换服务器时 provider 需要跟着换）
    return ListenableBuilder(
      listenable: _sessionController,
      builder: (context, _) {
        final session = _sessionController.currentSession;
        final imageProvider = (session != null && session.isValid)
            ? JellyfinAppImageProvider.fromSession(session)
            : null;

        final materialApp = MaterialApp.router(
          title: 'Jellyfin',
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
        );

        // 未登录时不需要图片 provider
        if (imageProvider == null) return materialApp;

        return JellyfinImageProviderScope(
          imageProvider: imageProvider,
          child: materialApp,
        );
      },
    );
  }
}
