import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_ai_recommendation/jellyfin_ai_recommendation.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_music/jellyfin_music.dart' as music;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../../data/jellyfin_gateway.dart';

/// AI 推荐路由页 — 注入 gateway 回调 + 导航回调，包装 AiRecommendPage
class AiRecommendRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String aiServiceUrl;
  final JellyfinImageProvider imageProvider;
  final music.AudioPlaybackPort? audioPlaybackPort;

  const AiRecommendRoutePage({
    super.key,
    required this.gateway,
    required this.aiServiceUrl,
    required this.imageProvider,
    this.audioPlaybackPort,
  });

  @override
  Widget build(BuildContext context) {
    return AiRecommendPage(
      aiServiceUrl: aiServiceUrl,
      imageProvider: imageProvider,
      fetchMediaItemDetail: gateway.getMediaItemDetail,
      onNavigateToMediaItem: (ctx, item) {
        ctx.push('/media/items/${item.id}');
      },
      onNavigateToAlbum: (ctx, item) {
        ctx.push('/music/albums/${item.id}');
      },
      onNavigateToArtist: (ctx, item) {
        ctx.push('/music/artists/${item.id}');
      },
      onPlaySong: (ctx, item) {
        final port = audioPlaybackPort;
        if (port == null) return;
        final track = _mediaItemToTrack(item);
        port.playSong(track, [track], 0);
        ctx.push('/playback/music');
      },
    );
  }
}

/// 将 [MediaItem]（音频类型）转为 [AudioTrack]
music.AudioTrack _mediaItemToTrack(MediaItem item) {
  final streamUrl =
      '${item.serverUrl}/Audio/${item.id}/universal'
      '?container=mp3,aac&audioCodec=mp3&transcodingContainer=ts'
      '&transcodingProtocol=hls&api_key=${item.accessToken ?? ''}';
  return music.AudioTrack(
    id: item.id,
    name: item.name,
    streamUrl: streamUrl,
    coverUrl: item.getCoverImageUrl(),
    duration: item.runTimeTicks != null
        ? Duration(microseconds: item.runTimeTicks! ~/ 10)
        : null,
    isFavorite: item.isFavorite,
  );
}
