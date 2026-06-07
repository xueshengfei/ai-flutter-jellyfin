import 'package:flutter/widgets.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../contracts/personal_repository.dart';
import '../models/personal_module_config.dart';
import '../pages/personal_page.dart';
import '../pages/personal_settings_page.dart';
import '../pages/personal_stats_page.dart';

/// 退出登录回调包装
///
/// 避免使用 VoidCallback 作为 ServiceRegistry key（类型冲突）。
/// Product App 注册:
/// ```dart
/// services[LogoutAction] = LogoutAction(() => ctrl.clearSession())
/// ```
final class LogoutAction {
  final void Function() call;
  const LogoutAction(this.call);
}

/// 个人中心 Feature 模块
///
/// 自注册路由：个人中心、设置、统计。
/// 导航通过 ServiceRegistry 获取 AppNavigator，不需要 Product App 注入回调。
final class PersonalFeatureModule extends JellyfinFeatureModule {
  PersonalFeatureModule();

  @override
  String get name => 'personal';

  @override
  String get version => '0.1.0';

  @override
  List<RouteDescriptor> buildRoutes(ModuleContext context) => [
    const RouteDescriptor(
      path: '/personal',
      name: JellyfinRouteNames.profile,
    ),
    const RouteDescriptor(
      path: '/personal/settings',
      name: JellyfinRouteNames.profileSettings,
    ),
    const RouteDescriptor(
      path: '/personal/stats',
      name: JellyfinRouteNames.profileStats,
    ),
  ];

  @override
  List<NavigationEntry> buildNavigationEntries(ModuleContext context) => [
    const NavigationEntry(
      title: '个人中心',
      routePath: '/personal',
      iconName: 'person',
      order: 99,
    ),
  ];

  @override
  Widget buildPage(
    BuildContext context,
    String routeName, {
    Map<String, String> pathParameters = const {},
    Object? extra,
  }) {
    final repository = ServiceRegistry.get<PersonalRepository>(context);
    final imageProvider = ServiceRegistry.get<JellyfinImageProvider>(context);
    final config = ServiceRegistry.tryGet<PersonalModuleConfig>(context) ??
        const PersonalModuleConfig.full();
    final logoutAction = ServiceRegistry.tryGet<LogoutAction>(context);

    return switch (routeName) {
      JellyfinRouteNames.profile => PersonalPage(
          repository: repository,
          config: config,
          imageProvider: imageProvider,
          onLogout: logoutAction?.call,
        ),
      JellyfinRouteNames.profileSettings => PersonalSettingsPage(
          repository: repository,
          imageProvider: imageProvider,
          onLogout: logoutAction?.call,
        ),
      JellyfinRouteNames.profileStats => PersonalStatsPage(
          repository: repository,
          config: config,
          imageProvider: imageProvider,
        ),
      _ => throw ArgumentError(
          'PersonalFeatureModule: unknown route $routeName',
        ),
    };
  }
}
