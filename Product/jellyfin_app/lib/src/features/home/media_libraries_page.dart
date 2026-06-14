import 'package:flutter/material.dart';
import 'package:jellyfin_ai_recommendation/jellyfin_ai_recommendation.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../data/jellyfin_gateway.dart';

/// 媒体库列表页面 — 登录后首页
class MediaLibrariesPage extends StatefulWidget {
  final JellyfinGateway gateway;
  final String username;
  final void Function(models.MediaLibrary library) onLibraryTap;
  final void Function(models.MediaItem item) onContinueWatchingTap;
  final VoidCallback onLogout;
  final VoidCallback? onOpenPersonal;
  final VoidCallback? onOpenAiRecommendation;

  const MediaLibrariesPage({
    super.key,
    required this.gateway,
    required this.username,
    required this.onLibraryTap,
    required this.onContinueWatchingTap,
    required this.onLogout,
    this.onOpenPersonal,
    this.onOpenAiRecommendation,
  });

  @override
  State<MediaLibrariesPage> createState() => _MediaLibrariesPageState();
}

class _MediaLibrariesPageState extends State<MediaLibrariesPage> {
  List<models.MediaLibrary> _libraries = [];
  List<models.MediaItem> _continueWatching = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        widget.gateway.getMediaLibraries(),
        widget.gateway.getContinueWatching(),
      ]);
      if (mounted) {
        setState(() {
          _libraries = results[0] as List<models.MediaLibrary>;
          _continueWatching = results[1] as List<models.MediaItem>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '$e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jellyfin'),
        actions: [
          if (widget.onOpenAiRecommendation != null)
            AiRecommendPill(onPressed: widget.onOpenAiRecommendation!),
          if (widget.onOpenPersonal != null)
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: '个人中心',
              onPressed: widget.onOpenPersonal,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            // Liquid Glass 最小集成示例 — standalone 模式
            // 在 Android 上验证 Impeller 渲染是否正常
            child: GlassContainer(
              useOwnLayer: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: const LiquidRoundedSuperellipse(borderRadius: 14),
              settings: const LiquidGlassSettings(
                thickness: 20,
                blur: 6,
              ),
              child: Text(
                widget.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.gateway.logout();
              widget.onLogout();
            },
            tooltip: '登出',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
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
    }

    if (_errorMessage != null) {
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
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
            spacing: 12,
            runSpacing: 12,
            children: _libraries
                .map(
                  (lib) => LibraryCard(
                    library: lib,
                    onTap: () => widget.onLibraryTap(lib),
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
              height: ContinueWatchingCard.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _continueWatching.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) => ContinueWatchingCard(
                  item: _continueWatching[index],
                  onTap: () =>
                      widget.onContinueWatchingTap(_continueWatching[index]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
