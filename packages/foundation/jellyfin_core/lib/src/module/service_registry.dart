import 'package:flutter/widgets.dart';

/// InheritedWidget 服务定位器
///
/// Feature 页面通过 `ServiceRegistry.get<T>(context)` 获取共享服务，
/// 不需要构造函数注入。
///
/// 由 Product App 在路由 builder 中注入到 Widget 树。
class ServiceRegistry extends InheritedWidget {
  final Map<Type, Object> _services;

  ServiceRegistry({
    required Map<Type, Object> services,
    required super.child,
    super.key,
  }) : _services = services;

  /// 获取指定类型的服务，不存在时抛异常
  static T get<T>(BuildContext context) {
    final registry = maybeOf(context);
    if (registry == null) {
      throw StateError('No ServiceRegistry found in widget tree');
    }
    final service = registry._services[T];
    if (service == null) {
      throw StateError('No service registered for type $T');
    }
    return service as T;
  }

  /// 获取指定类型的服务，不存在时返回 null
  static T? tryGet<T>(BuildContext context) {
    final registry = maybeOf(context);
    if (registry == null) return null;
    final service = registry._services[T];
    return service as T?;
  }

  /// InheritedWidget 查找方法
  static ServiceRegistry? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ServiceRegistry>();
  }

  @override
  bool updateShouldNotify(ServiceRegistry oldWidget) {
    // 服务 map 引用不变时不通知
    return !identical(_services, oldWidget._services);
  }
}
