import 'package:flutter/widgets.dart';
import 'package:jellyfin_core/jellyfin_core.dart';

import '../controllers/rvc_task_controller.dart';
import '../rvc_page.dart';

/// RVC 语音转换 Feature 模块
///
/// 自注册路由：RVC 页面。
/// 通过 ServiceRegistry 获取 RvcTaskController 服务。
final class RvcFeatureModule extends JellyfinFeatureModule {
  RvcFeatureModule();

  @override
  String get name => 'rvc';

  @override
  String get version => '0.1.0';

  @override
  List<RouteDescriptor> buildRoutes(ModuleContext context) => [
    const RouteDescriptor(
      path: '/rvc',
      name: JellyfinRouteNames.rvc,
    ),
  ];

  @override
  List<NavigationEntry> buildNavigationEntries(ModuleContext context) => [
    const NavigationEntry(
      title: 'RVC 语音转换',
      routePath: '/rvc',
      iconName: 'record_voice_over',
      order: 80,
    ),
  ];

  @override
  Widget buildPage(
    BuildContext context,
    String routeName, {
    Map<String, String> pathParameters = const {},
    Object? extra,
  }) {
    final args = (extra as Map<String, Object?>?) ?? const {};
    final controller = ServiceRegistry.get<RvcTaskController>(context);
    final audioPath = args['audioPath'] as String?;

    return switch (routeName) {
      JellyfinRouteNames.rvc => RvcPage(
          controller: controller,
          audioPath: audioPath,
        ),
      _ => throw ArgumentError(
          'RvcFeatureModule: unknown route $routeName',
        ),
    };
  }
}
