import 'package:flutter/material.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_service/src/jellyfin_client.dart';
import 'package:jellyfin_service/src/models/user_models.dart';
import 'package:jellyfin_service/src/models/media_library_models.dart';
import 'package:jellyfin_service/src/models/media_item_models.dart' as local;
import 'package:jellyfin_service/src/ui/services/audio_playback_manager.dart';
import 'package:jellyfin_service/src/ui/pages/login_page.dart';
import 'package:jellyfin_service/src/ui/pages/personal_page.dart';
import 'package:jellyfin_service/src/ui/widgets/library_card.dart';
import 'package:jellyfin_service/src/ui/widgets/continue_watching_card.dart';
import 'package:jellyfin_service/src/ui/widgets/mini_player_card.dart';
import 'package:jellyfin_service/src/app_shell/app_session.dart';
import 'package:jellyfin_service/src/app_shell/feature_page_factory.dart';
import 'package:jellyfin_ai_recommendation/jellyfin_ai_recommendation.dart';

/// 媒体库列表页面 - 登录后展示所有媒体库，点击进入对应类型的页面
class MediaLibrariesPage extends StatefulWidget {
  final JellyfinClient client;
  final UserProfile user;
  final AppNavigator? navigator;
  final Future<void> Function()? onLogout;

  const MediaLibrariesPage({
    super.key,
    required this.client,
    required this.user,
    this.navigator,
    this.onLogout,
  });

  @override
  State<MediaLibrariesPage> createState() => _MediaLibrariesPageState();
}

class _MediaLibrariesPageState extends State<MediaLibrariesPage> {
  List<MediaLibrary> _mediaLibraries = [];
  List<local.MediaItem> _continueWatching = [];
  bool _isLoading = true;
  String? _errorMessage;

  late final FeaturePageFactory _pages;

  @override
  void initState() {
    super.initState();
    _pages = FeaturePageFactory(
      AppSession(client: widget.client, user: widget.user),
    );
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        widget.client.mediaLibrary.getMediaLibraries(),
        widget.client.user.getContinueWatching(limit: 10),
      ]);
      if (mounted) {
        setState(() {
          _mediaLibraries = (results[0] as MediaLibraryListResult).libraries;
          _continueWatching = (results[1] as local.MediaItemListResult).items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = '$e';
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          // AI 推荐入口（胶囊动画按钮 — 来自独立业务模块）
          AiRecommendPill(
            onPressed: () {
              final navigator = widget.navigator;
              if (navigator != null) {
                navigator.push(JellyfinRouteNames.aiRecommend);
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _pages.aiRecommendPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              final navigator = widget.navigator;
              if (navigator != null) {
                navigator.push(JellyfinRouteNames.profile);
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonalPage(client: widget.client),
                ),
              );
            },
            tooltip: '个人中心',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                widget.user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final onLogout = widget.onLogout;
              if (onLogout != null) {
                await onLogout();
                return;
              }
              await widget.client.auth.logout();
              if (mounted)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
            },
            tooltip: '登出',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          ListenableBuilder(
            listenable: AudioPlaybackManager.instance,
            builder: (context, _) {
              if (!AudioPlaybackManager.instance.hasPlaylist)
                return const SizedBox.shrink();
              return MiniPlayerCard(client: widget.client);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading)
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载...'),
          ],
        ),
      );
    if (_errorMessage != null)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadAll, child: const Text('重试')),
          ],
        ),
      );

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 媒体库
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '媒体库',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _mediaLibraries
                .map(
                  (lib) => LibraryCard(
                    client: widget.client,
                    library: lib,
                    onTap: () => _navigateToLibrary(lib),
                  ),
                )
                .toList(),
          ),
          // 继续观看
          if (_continueWatching.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '继续观看',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _continueWatching.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => ContinueWatchingCard(
                  item: _continueWatching[index],
                  client: widget.client,
                  navigator: widget.navigator,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToLibrary(MediaLibrary library) {
    final navigator = widget.navigator;
    if (navigator != null) {
      navigator.push(
        JellyfinRouteNames.library,
        arguments: {'libraryId': library.id, 'library': library},
      );
      return;
    }
    final page = _pages.pageForLibrary(library);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
