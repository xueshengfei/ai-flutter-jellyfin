import 'package:flutter/widgets.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../pages/ai_recommend_page.dart';

/// AI 服务地址回调包装
///
/// 避免使用 Function 作为 ServiceRegistry key（类型冲突）。
/// Product App 注册:
/// ```dart
/// services[AiServiceUrlProvider] = AiServiceUrlProvider(() => session.aiUrl)
/// ```
final class AiServiceUrlProvider {
  final String Function() call;
  const AiServiceUrlProvider(this.call);
}

/// AI 对话推荐 Feature 模块
///
/// 自注册路由：AI 推荐页面。
/// 导航通过 AppNavigator（ServiceRegistry 注入），不再需要导航回调。
final class AiFeatureModule extends JellyfinFeatureModule {
  AiFeatureModule();

  @override
  String get name => 'ai_recommendation';

  @override
  String get version => '0.1.0';

  @override
  List<RouteDescriptor> buildRoutes(ModuleContext context) => [
    const RouteDescriptor(
      path: '/ai',
      name: JellyfinRouteNames.aiRecommend,
    ),
  ];

  @override
  List<NavigationEntry> buildNavigationEntries(ModuleContext context) => [
    const NavigationEntry(
      title: 'AI 推荐',
      routePath: '/ai',
      iconName: 'auto_awesome',
      order: 50,
    ),
  ];

  @override
  Widget buildPage(
    BuildContext context,
    String routeName, {
    Map<String, String> pathParameters = const {},
    Object? extra,
  }) {
    final imageProvider = ServiceRegistry.get<JellyfinImageProvider>(context);
    final fetchMediaItemDetail =
        ServiceRegistry.get<MediaItemDetailFetcher>(context);
    final aiUrlProvider = ServiceRegistry.tryGet<AiServiceUrlProvider>(context);
    final aiServiceUrl = aiUrlProvider?.call() ?? '';

    return switch (routeName) {
      JellyfinRouteNames.aiRecommend => AiRecommendPage(
          aiServiceUrl: aiServiceUrl,
          imageProvider: imageProvider,
          fetchMediaItemDetail: fetchMediaItemDetail,
        ),
      _ => throw ArgumentError(
          'AiFeatureModule: unknown route $routeName',
        ),
    };
  }
}
