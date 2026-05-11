import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:jellyfin_ai_recommendation/jellyfin_ai_recommendation.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

void main() {
  runApp(const AiRecommendExampleApp());
}

class AiRecommendExampleApp extends StatelessWidget {
  const AiRecommendExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 推荐模块测试',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _HomePage(),
    );
  }
}

/// 首页：输入服务地址后跳转 AI 推荐页
class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final _aiUrlController = TextEditingController(
    text: 'http://localhost:5005',
  );
  final _jellyfinUrlController = TextEditingController(
    text: 'http://localhost:8096',
  );

  @override
  void dispose() {
    _aiUrlController.dispose();
    _jellyfinUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 推荐模块测试')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '独立测试 jellyfin_ai_recommendation 模块',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),

            // AI 服务地址
            TextField(
              controller: _aiUrlController,
              decoration: const InputDecoration(
                labelText: 'AI 服务地址',
                hintText: 'http://192.168.1.100:5005',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.smart_toy),
              ),
            ),
            const SizedBox(height: 12),

            // Jellyfin 地址
            TextField(
              controller: _jellyfinUrlController,
              decoration: const InputDecoration(
                labelText: 'Jellyfin 地址（图片 / 详情用）',
                hintText: 'http://192.168.1.100:8096',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.cloud),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: () {
                final aiUrl = _aiUrlController.text.trim();
                final jfUrl = _jellyfinUrlController.text.trim();
                if (aiUrl.isEmpty) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiRecommendPage(
                      aiServiceUrl: aiUrl,
                      imageProvider: _StubImageProvider(),
                      fetchMediaItemDetail: (id) => _stubDetail(id, jfUrl),
                      onNavigateToMediaItem: (ctx, item) =>
                          _showSnack(ctx, '媒体详情: ${item.name}'),
                      onNavigateToAlbum: (ctx, item) =>
                          _showSnack(ctx, '专辑: ${item.name}'),
                      onNavigateToArtist: (ctx, item) =>
                          _showSnack(ctx, '歌手: ${item.name}'),
                      onPlaySong: (ctx, item) =>
                          _showSnack(ctx, '播放: ${item.name}'),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('进入 AI 推荐页'),
            ),

            const SizedBox(height: 32),
            Text('说明', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '- 图片加载为占位实现（不依赖真实 Jellyfin）\n'
              '- 卡片详情通过 fetchMediaItemDetail 回调获取\n'
              '- 卡片点击通过 SnackBar 回显',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showSnack(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
}

// ─────────────────────────────────────────
// 占位实现
// ─────────────────────────────────────────

/// 占位图片加载器 — 返回 1x1 透明 PNG
class _StubImageProvider implements JellyfinImageProvider {
  @override
  Future<Uint8List> getPrimaryImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  }) async {
    return Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02,
      0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
      0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
  }
}

/// 占位详情获取
Future<MediaItem> _stubDetail(String itemId, String serverUrl) async {
  return MediaItem(
    id: itemId,
    name: '测试媒体 $itemId',
    type: 'Movie',
    serverUrl: serverUrl,
    productionYear: 2024,
    communityRating: 8.5,
  );
}
