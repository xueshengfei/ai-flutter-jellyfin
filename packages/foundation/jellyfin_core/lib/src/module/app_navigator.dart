import 'navigation_intent.dart';

/// App 导航服务协议
///
/// 由 App 壳实现，各业务模块通过此接口进行页面跳转
abstract class AppNavigator {
  /// 通过路由名跳转页面
  Future<T?> push<T>(String routeName, {Map<String, Object?>? arguments});

  /// 通过 NavigationIntent 跳转
  Future<T?> pushIntent<T>(NavigationIntent intent);

  /// 返回上一页
  void pop<T extends Object?>([T? result]);

  /// 替换当前页面
  Future<T?> replace<T>(String routeName, {Map<String, Object?>? arguments});
}
