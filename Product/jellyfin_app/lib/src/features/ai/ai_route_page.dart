import 'package:flutter/material.dart';
import 'package:jellyfin_ai_recommendation/jellyfin_ai_recommendation.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../../data/jellyfin_gateway.dart';

/// AI 推荐路由页 — 注入 gateway 回调，包装 AiRecommendPage
class AiRecommendRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String aiServiceUrl;
  final String ttsServiceUrl;
  final JellyfinImageProvider imageProvider;

  const AiRecommendRoutePage({
    super.key,
    required this.gateway,
    required this.aiServiceUrl,
    required this.ttsServiceUrl,
    required this.imageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return AiRecommendPage(
      aiServiceUrl: aiServiceUrl,
      ttsServiceUrl: ttsServiceUrl,
      imageProvider: imageProvider,
      fetchMediaItemDetail: gateway.getMediaItemDetail,
    );
  }
}
