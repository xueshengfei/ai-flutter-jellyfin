import 'package:go_router/go_router.dart';
import 'package:jellyfin_auth/jellyfin_auth_pages.dart';
import 'package:jellyfin_movies/jellyfin_movies.dart' as movies;
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import '../data/jellyfin_gateway.dart';
import '../features/home/media_libraries_page.dart';
import '../features/media/media_route_pages.dart';
import '../session/app_session.dart';
import '../session/app_session_controller.dart';

/// 认证重定向纯函数
String? resolveAuthRedirect({
  required bool isLoggedIn,
  required String matchedLocation,
  String loginPath = '/login',
  String homePath = '/libraries',
}) {
  final isLogin = matchedLocation == loginPath;
  if (!isLoggedIn && !isLogin) return loginPath;
  if (isLoggedIn && isLogin) return homePath;
  return null;
}

/// 创建 App 路由表
GoRouter createAppRouter({
  required AppSessionController sessionController,
  JellyfinGateway? gateway,
  String initialLocation = '/login',
}) {
  final effectiveGateway = gateway ?? _StubGateway();

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: sessionController,
    redirect: (context, state) => resolveAuthRedirect(
      isLoggedIn: sessionController.isLoggedIn,
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          onLogin: ({required serverUrl, required username, required password}) async {
            try {
              final session = await effectiveGateway.login(
                serverUrl: serverUrl,
                username: username,
                password: password,
              );
              sessionController.setSession(session);
              return null;
            } catch (e) {
              return '登录失败: $e';
            }
          },
        ),
      ),
      GoRoute(
        path: '/libraries',
        builder: (context, state) {
          final session = sessionController.currentSession;
          return MediaLibrariesPage(
            gateway: effectiveGateway,
            username: session?.username ?? '',
            onLibraryTap: (library) {
              // 根据媒体库类型路由到不同页面
              switch (library.type) {
                case models.MediaLibraryType.movies:
                  context.push('/libraries/${library.id}/movies?name=${Uri.encodeComponent(library.name)}');
                case models.MediaLibraryType.tvshows:
                  // 剧集库暂时也跳到媒体详情
                  context.push('/libraries/${library.id}/movies?name=${Uri.encodeComponent(library.name)}');
                default:
                  // 其他类型暂用通用列表
                  context.push('/libraries/${library.id}/movies?name=${Uri.encodeComponent(library.name)}');
              }
            },
            onContinueWatchingTap: (item) {
              context.push('/media/items/${item.id}');
            },
            onLogout: () => sessionController.clearSession(),
          );
        },
      ),
      // 电影筛选页
      GoRoute(
        path: '/libraries/:libraryId/movies',
        builder: (context, state) {
          final libraryId = state.pathParameters['libraryId']!;
          final libraryName = state.uri.queryParameters['name'] ?? '媒体库';
          return MoviesRoutePage(
            gateway: effectiveGateway,
            libraryId: libraryId,
            libraryName: libraryName,
          );
        },
      ),
      // 电影详情页
      GoRoute(
        path: '/movies/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return MovieDetailRoutePage(
            gateway: effectiveGateway,
            itemId: itemId,
          );
        },
      ),
      // 通用媒体详情页
      GoRoute(
        path: '/media/items/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return MediaDetailRoutePage(
            gateway: effectiveGateway,
            itemId: itemId,
          );
        },
      ),
      // 剧集季列表
      GoRoute(
        path: '/series/:seriesId/seasons',
        builder: (context, state) {
          final seriesId = state.pathParameters['seriesId']!;
          return SeriesSeasonsRoutePage(
            gateway: effectiveGateway,
            seriesId: seriesId,
          );
        },
      ),
      // 剧集集列表
      GoRoute(
        path: '/series/:seriesId/seasons/:seasonId/episodes',
        builder: (context, state) {
          final seriesId = state.pathParameters['seriesId']!;
          final seasonId = state.pathParameters['seasonId']!;
          return SeriesEpisodesRoutePage(
            gateway: effectiveGateway,
            seriesId: seriesId,
            seasonId: seasonId,
          );
        },
      ),
    ],
  );
}

/// 测试用空 gateway（无 gateway 时不抛错）
class _StubGateway implements JellyfinGateway {
  @override
  Future<AppSession> login({required String serverUrl, required String username, required String password}) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<void> register({required String serverUrl, required String adminUsername, required String adminPassword, required String username, required String password}) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<void> logout() async {}

  @override
  Future<List<models.MediaLibrary>> getMediaLibraries() async => [];

  @override
  Future<List<models.MediaItem>> getContinueWatching({int limit = 10}) async => [];

  @override
  Future<models.MediaItem> getMediaItemDetail(String itemId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<models.SeasonListResult> getSeasons(String seriesId) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<models.EpisodeListResult> getEpisodes({required String seasonId, required String seriesId}) {
    throw UnimplementedError('No gateway configured');
  }

  @override
  Future<movies.MovieFilterResult> fetchMovies(movies.MovieFilter filter) {
    throw UnimplementedError('No gateway configured');
  }
}
