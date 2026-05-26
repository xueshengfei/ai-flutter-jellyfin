/// 播放路由页面
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_playback/jellyfin_playback_pages.dart';

import '../../data/jellyfin_gateway.dart';
import '../../data/playback_adapter.dart';

/// 视频播放路由页
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
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
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

  static ApiClient? _getApiClient(JellyfinGateway gateway) {
    // ignore: avoid_dynamic_calls
    return (gateway as dynamic).apiClient as ApiClient?;
  }
}
