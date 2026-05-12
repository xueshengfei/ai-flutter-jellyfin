import 'package:go_router/go_router.dart';
import 'package:jellyfin_core/jellyfin_core.dart';

/// go_router-backed implementation of [AppNavigator].
///
/// Feature modules should depend on [AppNavigator], not on go_router. The app
/// shell owns this adapter and the concrete route table.
class GoRouterAppNavigator implements AppNavigator {
  GoRouter? _router;

  GoRouterAppNavigator([GoRouter? router]) : _router = router;

  void attach(GoRouter router) {
    _router = router;
  }

  GoRouter get _attachedRouter {
    final router = _router;
    if (router == null) {
      throw StateError(
        'GoRouterAppNavigator has not been attached to a GoRouter',
      );
    }
    return router;
  }

  @override
  Future<T?> push<T>(String routeName, {Map<String, Object?>? arguments}) {
    final args = arguments ?? const <String, Object?>{};
    return _attachedRouter.pushNamed<T>(
      routeName,
      pathParameters: _pathParametersFor(routeName, args),
      extra: args,
    );
  }

  @override
  Future<T?> pushIntent<T>(NavigationIntent intent) {
    if (intent is RouteNavigationIntent) {
      return push<T>(intent.routeName, arguments: intent.arguments);
    }
    if (intent is GenericNavigationIntent) {
      return push<T>(intent.action, arguments: intent.arguments);
    }
    throw UnsupportedError('Unsupported navigation intent: $intent');
  }

  @override
  Future<T?> replace<T>(String routeName, {Map<String, Object?>? arguments}) {
    final args = arguments ?? const <String, Object?>{};
    return _attachedRouter.replaceNamed<T>(
      routeName,
      pathParameters: _pathParametersFor(routeName, args),
      extra: args,
    );
  }

  @override
  void pop<T extends Object?>([T? result]) {
    _attachedRouter.pop<T>(result);
  }

  Map<String, String> _pathParametersFor(
    String routeName,
    Map<String, Object?> arguments,
  ) {
    switch (routeName) {
      case JellyfinRouteNames.library:
      case JellyfinRouteNames.musicLibrary:
        return {'libraryId': _requiredString(arguments, 'libraryId')};
      case JellyfinRouteNames.mediaDetail:
      case JellyfinRouteNames.movieDetail:
      case JellyfinRouteNames.playbackVideo:
        return {'itemId': _requiredString(arguments, 'itemId')};
      case JellyfinRouteNames.seriesSeasons:
        return {'seriesId': _requiredString(arguments, 'seriesId')};
      case JellyfinRouteNames.seriesEpisodes:
        return {
          'seriesId': _requiredString(arguments, 'seriesId'),
          'seasonId': _requiredString(arguments, 'seasonId'),
        };
      case JellyfinRouteNames.musicAlbum:
        return {'albumId': _requiredString(arguments, 'albumId')};
      case JellyfinRouteNames.musicArtist:
        return {'artistId': _requiredString(arguments, 'artistId')};
      default:
        return const {};
    }
  }

  String _requiredString(Map<String, Object?> arguments, String key) {
    final value = arguments[key];
    if (value is String && value.isNotEmpty) return value;
    throw ArgumentError.value(value, key, 'Expected a non-empty String');
  }
}
