/// ??????
///
/// ???? MediaItem ? ?? PlaybackDelegate ? ?? VideoPlayerPage?
/// ???????"??????? ? features/playback"????
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_playback/jellyfin_playback_pages.dart';

import '../../data/jellyfin_gateway.dart';
import '../../data/playback_adapter.dart';
import '../../data/watch_assist_client.dart';

/// ???????
///
/// ? path parameter ? itemId ? Gateway ?? MediaItem ?
/// PlaybackAdapter ?? PlaybackDelegate ? VideoPlayerPage ???
class VideoPlaybackRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String itemId;
  final String? aiServiceUrl;
  final void Function(BuildContext context, models.MediaItem item)?
      onStartDownload;

  const VideoPlaybackRoutePage({
    super.key,
    required this.gateway,
    required this.itemId,
    this.aiServiceUrl,
    this.onStartDownload,
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
              title: const Text('????', style: TextStyle(color: Colors.white)),
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
                    child: const Text('??'),
                  ),
                ],
              ),
            ),
          );
        }

        final item = snapshot.data!;

        // ?? ApiClient ??? PlaybackAdapter
        // ?? Gateway ??? apiClient ??
        final apiClient = _getApiClient(gateway);
        if (apiClient == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('??????', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('??'),
                  ),
                ],
              ),
            ),
          );
        }

        final adapter = PlaybackAdapter(apiClient);
        final delegate = adapter.createDelegate();
        final watchAssistClient =
            aiServiceUrl != null && aiServiceUrl!.isNotEmpty
            ? WatchAssistClient(aiServiceUrl: aiServiceUrl!)
            : null;

        return VideoPlayerPage(
          item: item,
          playback: delegate,
          fetchWatchAssist: watchAssistClient?.fetchWatchAssist,
          onStartDownload: onStartDownload,
        );
      },
    );
  }

  /// ? Gateway ????? ApiClient
  ///
  /// ?????? ApiClient ??? PostedPlaybackInfo ? API?
  /// ???? dynamic ?? LegacyJellyfinGateway.apiClient?
  /// ?????????"data ? adapter"???
  static ApiClient? _getApiClient(JellyfinGateway gateway) {
    // ignore: avoid_dynamic_calls
    return (gateway as dynamic).apiClient as ApiClient?;
  }
}
