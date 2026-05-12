import 'package:flutter/material.dart';
import '../../data/jellyfin_gateway.dart';

/// 媒体库图标映射
IconData _libraryIcon(String type) {
  switch (type) {
    case 'movies': return Icons.movie;
    case 'music': return Icons.music_note;
    case 'tvshows': return Icons.tv;
    default: return Icons.folder;
  }
}

/// 媒体库列表页面 — 登录后首页
class MediaLibrariesPage extends StatefulWidget {
  final JellyfinGateway gateway;
  final String username;
  final void Function(String libraryId, String libraryName, String libraryType) onLibraryTap;
  final void Function(String itemId) onContinueWatchingTap;
  final VoidCallback onLogout;

  const MediaLibrariesPage({
    super.key,
    required this.gateway,
    required this.username,
    required this.onLibraryTap,
    required this.onContinueWatchingTap,
    required this.onLogout,
  });

  @override
  State<MediaLibrariesPage> createState() => _MediaLibrariesPageState();
}

class _MediaLibrariesPageState extends State<MediaLibrariesPage> {
  List<LibraryInfo> _libraries = [];
  List<ContinueWatchingItem> _continueWatching = [];
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
          _libraries = results[0] as List<LibraryInfo>;
          _continueWatching = results[1] as List<ContinueWatchingItem>;
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(widget.username, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadAll, child: const Text('重试')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 媒体库
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('媒体库', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _libraries.map((lib) => _LibraryCard(
              library: lib,
              onTap: () => widget.onLibraryTap(lib.id, lib.name, lib.type),
            )).toList(),
          ),
          // 继续观看
          if (_continueWatching.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('继续观看', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _continueWatching.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _ContinueWatchingCard(
                  item: _continueWatching[index],
                  onTap: () => widget.onContinueWatchingTap(_continueWatching[index].id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 媒体库卡片
class _LibraryCard extends StatelessWidget {
  final LibraryInfo library;
  final VoidCallback onTap;

  const _LibraryCard({required this.library, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 42) / 2,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Icon(_libraryIcon(library.type), size: 22, color: Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(library.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (library.itemCount != null)
                    Text('${library.itemCount} 项', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 继续观看卡片
class _ContinueWatchingCard extends StatelessWidget {
  final ContinueWatchingItem item;
  final VoidCallback onTap;

  const _ContinueWatchingCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = (item.playedPercentage ?? 0) / 100;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item.coverUrl != null
                        ? Image.network(item.coverUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                            errorBuilder: (_, __, ___) => _placeholder(context))
                        : _placeholder(context),
                  ),
                  if (progress > 0)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(
              '${item.type}${item.productionYear != null ? ' · ${item.productionYear}' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: Icon(Icons.play_circle_outline, size: 32, color: Colors.white54)),
  );
}
