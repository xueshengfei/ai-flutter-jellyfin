/// 导航意图抽象基类
///
/// 模块间通过意图进行页面跳转，不直接 import 其它模块的页面。
/// core 只定义协议，具体 intent 由各 feature 包自行定义。
abstract class NavigationIntent {
  const NavigationIntent();
}

/// 通用导航意图
///
/// 用于尚未拆出独立 feature 包的过渡期，或简单的页面跳转场景。
/// 各 feature 包应定义自己的 Intent 子类，而不是长期使用此类。
class GenericNavigationIntent extends NavigationIntent {
  /// 意图类型标识
  final String action;

  /// 携带参数
  final Map<String, Object?> arguments;

  const GenericNavigationIntent({
    required this.action,
    this.arguments = const {},
  });

  /// 获取参数
  T? arg<T>(String key) => arguments[key] as T?;

  @override
  String toString() => 'GenericNavigationIntent(action: $action, args: $arguments)';
}
