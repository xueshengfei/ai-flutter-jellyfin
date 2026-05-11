import 'package:jellyfin_core/jellyfin_core.dart';

/// Fake App 导航器
///
/// 记录所有导航操作，用于验证模块发出的跳转意图
class FakeAppNavigator implements AppNavigator {
  /// 记录的 push 调用
  final List<_PushRecord> pushCalls = [];

  /// 记录的 pushIntent 调用
  final List<NavigationIntent> pushIntentCalls = [];

  /// 记录的 pop 调用
  final List<dynamic> popCalls = [];

  /// 记录的 replace 调用
  final List<_PushRecord> replaceCalls = [];

  @override
  Future<T?> push<T>(String routeName, {Map<String, Object?>? arguments}) {
    pushCalls.add(_PushRecord(routeName: routeName, arguments: arguments));
    return Future<T?>.value();
  }

  @override
  Future<T?> pushIntent<T>(NavigationIntent intent) {
    pushIntentCalls.add(intent);
    return Future<T?>.value();
  }

  @override
  void pop<T extends Object?>([T? result]) {
    popCalls.add(result);
  }

  @override
  Future<T?> replace<T>(String routeName, {Map<String, Object?>? arguments}) {
    replaceCalls.add(_PushRecord(routeName: routeName, arguments: arguments));
    return Future<T?>.value();
  }

  /// 清除所有记录
  void clear() {
    pushCalls.clear();
    pushIntentCalls.clear();
    popCalls.clear();
    replaceCalls.clear();
  }

  /// 检查是否发出过特定 action 的 intent
  bool hasIntentAction(String action) {
    return pushIntentCalls.any((intent) {
      if (intent is GenericNavigationIntent) {
        return intent.action == action;
      }
      return false;
    });
  }
}

/// Push 调用记录
class _PushRecord {
  final String routeName;
  final Map<String, Object?>? arguments;

  _PushRecord({required this.routeName, this.arguments});
}
