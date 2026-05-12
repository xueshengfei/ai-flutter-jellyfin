import 'package:jellyfin_service/src/jellyfin_client.dart';
import 'package:jellyfin_service/src/models/media_item_models.dart' as local;
import 'package:jellyfin_service/src/ui/services/playback_service.dart';
import 'package:jellyfin_service/src/models/video_quality_models.dart';
import 'package:jellyfin_playback/jellyfin_playback.dart' as playback;

/// 创建 [playback.PlaybackDelegate]（将 PlaybackService 包装为回调集合）
class PlaybackDelegateFactory {
  final JellyfinClient _client;

  const PlaybackDelegateFactory(this._client);

  /// 为给定 [localItem] 创建播放委托
  playback.PlaybackDelegate create(local.MediaItem localItem) {
    final service = PlaybackService(client: _client);
    service.setCurrentItem(localItem);
    return playback.PlaybackDelegate(
      getPlaybackUrl: ({required itemId, startTimeTicks, maxStreamingBitrate}) async {
        final info = await service.getPlaybackUrl(
          itemId: itemId,
          startTimeTicks: startTimeTicks,
          maxStreamingBitrate: maxStreamingBitrate,
        );
        return playback.PlaybackInfo(
          url: info.url,
          playSessionId: info.playSessionId,
          isTranscoded: info.isTranscoded,
          actualBitrate: info.actualBitrate,
        );
      },
      startSession: ({required itemId, required sessionIds}) =>
          service.startPlaybackSession(itemId: itemId, sessionIds: sessionIds),
      switchQuality: ({required itemId, required quality, required currentPosition}) async {
        final rootQuality = VideoQuality.values.firstWhere((q) => q.name == quality.name);
        final info = await service.switchQuality(
          itemId: itemId,
          quality: rootQuality,
          currentPosition: currentPosition,
        );
        return playback.PlaybackInfo(
          url: info.url,
          playSessionId: info.playSessionId,
          isTranscoded: info.isTranscoded,
          actualBitrate: info.actualBitrate,
        );
      },
      stopEncoding: (playSessionId) =>
          service.stopActiveEncodings(playSessionId),
      stopSession: () => service.stopPlaybackSession(),
      dispose: () => service.dispose(),
    );
  }
}
