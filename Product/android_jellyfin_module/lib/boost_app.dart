import 'package:flutter/material.dart';
import 'package:flutter_boost/flutter_boost.dart';
import 'package:jellyfin_auth/jellyfin_auth.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;

/// FlutterBoost 路由工厂
/// 页面名 → Android 侧 FlutterBoost.instance().open("xxx")
Route<dynamic>? routeFactory(RouteSettings settings, String? uniqueId) {
  final name = settings.name ?? '';

  switch (name) {
    // 登录页 - 使用 jellyfin_auth 的 LoginPage
    case 'login':
      return PageRouteBuilder<dynamic>(
        settings: settings,
        pageBuilder: (_, __, ___) => _LoginPage(),
      );

    // 媒体库首页
    case 'media_home':
      return PageRouteBuilder<dynamic>(
        settings: settings,
        pageBuilder: (_, __, ___) => const _MediaHomePage(),
      );

    default:
      return PageRouteBuilder<dynamic>(
        settings: settings,
        pageBuilder: (_, __, ___) => Scaffold(
          body: Center(child: Text('未知页面: $name')),
        ),
      );
  }
}

/// 登录页
class _LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LoginPage(
      discoveryService: ServerDiscoveryService(),
      onLogin: ({required serverUrl, required username, required password}) async {
        // TODO: 通过 MethodChannel 把登录信息传给 Android 侧
        // Android 侧负责实际的 API 登录
        if (context.mounted) {
          BoostNavigator.instance.push('media_home',
            arguments: {'serverUrl': serverUrl},
          );
        }
        return null;
      },
    );
  }
}

/// 媒体库首页
class _MediaHomePage extends StatelessWidget {
  const _MediaHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jellyfin 媒体库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => BoostNavigator.instance.pop(),
          ),
        ],
      ),
      body: ListView(
        children: [
          _MediaLibraryTile(icon: Icons.movie, name: '电影', id: 'movies'),
          _MediaLibraryTile(icon: Icons.tv, name: '剧集', id: 'series'),
          _MediaLibraryTile(icon: Icons.library_music, name: '音乐', id: 'music'),
        ],
      ),
    );
  }
}

class _MediaLibraryTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String id;

  const _MediaLibraryTile({
    required this.icon,
    required this.name,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 32),
      title: Text(name, style: const TextStyle(fontSize: 18)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: 进入具体媒体库
      },
    );
  }
}

/// FlutterBoost App 入口 Widget
class BoostModuleApp extends StatelessWidget {
  const BoostModuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterBoostApp(
      routeFactory,
      appBuilder: (child) => MaterialApp(
        home: child,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
