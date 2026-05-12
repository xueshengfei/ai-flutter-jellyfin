/// 播放路由页面
///
/// 负责加载 MediaItem → 创建 PlaybackDelegate → 组装 VideoPlayerPage。
/// 对应架构文档中"产品业务编排层 → features/playback"的角色。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_playback/jellyfin_playback_pages.dart';

import '../../data/jellyfin_gateway.dart';
import '../../data/playback_adapter.dart';

/// 视频播放路由页
///
/// 从 path parameter 取 itemId → Gateway 加载 MediaItem →
/// PlaybackAdapter 创建 PlaybackDelegate → VideoPlayerPage 播放。
class VideoPlaybackRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String itemId;

  const VideoPlaybackRoutePage({
    super.key,
    required this.gateway,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.MediaItem>(
      future: gateway.getMediaItemDetail(itemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: const Text('播放错误', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          );
        }

        final item = snapshot.data!;

        // 需要 ApiClient 来创建 PlaybackAdapter
        // 通过 Gateway 暴露的 apiClient 获取
        final apiClient = _getApiClient(gateway);
        if (apiClient == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('播放器未就绪', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          );
        }

        final adapter = PlaybackAdapter(apiClient);
        final delegate = adapter.createDelegate();

        return VideoPlayerPage(
          item: item,
          playback: delegate,
        );
      },
    );
  }

  /// 从 Gateway 实现中获取 ApiClient
  ///
  /// 播放模块需要 ApiClient 来调用 PostedPlaybackInfo 等 API，
  /// 这里通过 dynamic 访问 LegacyJellyfinGateway.apiClient。
  /// 这是架构文档允许的"data 层 adapter"模式。
  static ApiClient? _getApiClient(JellyfinGateway gateway) {
    // ignore: avoid_dynamic_calls
    return (gateway as dynamic).apiClient as ApiClient?;
  }
}
