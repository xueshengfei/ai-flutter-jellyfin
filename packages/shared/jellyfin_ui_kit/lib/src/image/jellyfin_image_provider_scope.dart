import 'package:flutter/widgets.dart';
import 'jellyfin_image_provider.dart';

/// InheritedWidget，在 Widget 树中提供 [JellyfinImageProvider]
///
/// 在 App 入口或路由层包裹一次，所有 [JellyfinImage] 自动获取认证图片能力，
/// 不再需要逐层传递 `imageProvider` 参数。
///
/// 用法：
/// ```dart
/// JellyfinImageProviderScope(
///   imageProvider: JellyfinAppImageProvider.fromSession(session),
///   child: MyApp(),
/// )
/// ```
class JellyfinImageProviderScope extends InheritedWidget {
  final JellyfinImageProvider imageProvider;

  const JellyfinImageProviderScope({
    required this.imageProvider,
    required super.child,
    super.key,
  });

  /// 获取树中最近的 [JellyfinImageProvider]
  ///
  /// 不存在时抛异常，用于确定有 provider 的场景。
  static JellyfinImageProvider of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw StateError(
        'No JellyfinImageProviderScope found in widget tree. '
        'Wrap your app with JellyfinImageProviderScope.',
      );
    }
    return scope;
  }

  /// 获取树中最近的 [JellyfinImageProvider]，不存在时返回 null
  static JellyfinImageProvider? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<JellyfinImageProviderScope>()
        ?.imageProvider;
  }

  @override
  bool updateShouldNotify(JellyfinImageProviderScope oldWidget) {
    return imageProvider != oldWidget.imageProvider;
  }
}
