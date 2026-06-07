import 'package:flutter/widgets.dart';

import 'app_navigator.dart';
import 'service_registry.dart';

/// 业务模块注册协议
///
/// 每个业务 feature 实现此接口，由 App 壳统一注册。
/// 模块提供路由元数据 + 页面构建能力。
abstract class JellyfinFeatureModule {
  /// 模块名称（唯一标识）
  String get name;

  /// 模块版本
  String get version;

  /// 构建模块路由描述
  ///
  /// [context] 提供模块间通信所需的共享服务。
  /// 返回路由元数据列表，App 壳负责关联实际 Widget builder。
  List<RouteDescriptor> buildRoutes(ModuleContext context);

  /// 构建导航入口
  ///
  /// 返回模块希望在首页展示的导航项
  List<NavigationEntry> buildNavigationEntries(ModuleContext context);

  /// 根据路由名构建页面 Widget
  ///
  /// [context] 已包含 [ServiceRegistry]，可通过
  /// `ServiceRegistry.get<T>(context)` 获取共享服务。
  /// [pathParameters] 是 GoRouter 路径参数（如 itemId、libraryId）。
  /// [extra] 是 GoRouter extra 参数。
  Widget buildPage(
    BuildContext context,
    String routeName, {
    Map<String, String> pathParameters = const {},
    Object? extra,
  });
}

/// 模块上下文
///
/// 提供模块间通信所需的共享服务。
/// config 字段使用 JellyfinConfiguration 类型（通过 import jellyfin_core.dart 获取）。
abstract class ModuleContext {
  /// 导航服务
  AppNavigator get navigator;

  /// 服务器配置
  ///
  /// 返回 JellyfinConfiguration 实例。
  /// 使用 Object? 类型避免 core 循环依赖自身 configuration；
  /// 调用方应 as 转型为 JellyfinConfiguration。
  Object? get config;
}

/// 路由描述（纯元数据，不含 Widget）
///
/// Flutter 层的 Widget builder 由 App 壳根据 path/name 关联。
class RouteDescriptor {
  /// 路由路径
  final String path;

  /// 路由名称（唯一标识）
  final String name;

  /// 路由元数据（可选，供 App 壳路由配置使用）
  final Map<String, Object?> metadata;

  const RouteDescriptor({
    required this.path,
    required this.name,
    this.metadata = const {},
  });
}

/// 导航入口
class NavigationEntry {
  /// 入口标题
  final String title;

  /// 路由路径
  final String routePath;

  /// 图标名称（语义化，由 App 壳映射到实际图标）
  final String? iconName;

  /// 排序权重（越小越靠前）
  final int order;

  const NavigationEntry({
    required this.title,
    required this.routePath,
    this.iconName,
    this.order = 0,
  });
}
