import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_auth/jellyfin_auth_pages.dart';
import '../data/jellyfin_gateway.dart';
import '../features/home/media_libraries_page.dart';
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
///
/// 当前只注册 /login 和 /libraries 两个路由，
/// 后续 milestone 逐步接入电影、音乐、剧集、播放、AI 推荐。
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
              return null; // 成功
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
            onLibraryTap: (libraryId, libraryName, libraryType) {
              // 后续 milestone 接入具体 library 路由
            },
            onContinueWatchingTap: (itemId) {
              // 后续 milestone 接入播放路由
            },
            onLogout: () => sessionController.clearSession(),
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
  Future<List<LibraryInfo>> getMediaLibraries() async => [];

  @override
  Future<List<ContinueWatchingItem>> getContinueWatching({int limit = 10}) async => [];
}
