/// 剧集业务模块 — 回调类型定义

import 'package:jellyfin_models/jellyfin_models.dart';

/// 获取集列表回调
typedef EpisodesFetcher = Future<EpisodeListResult> Function({
  required String seasonId,
  required String seriesId,
});
