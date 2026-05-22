enum WatchAssistType {
  currentStage('current_stage', '当前阶段', false),
  plotSummary('plot_summary', '全文概括', false),
  characterAnalysis('character_analysis', '人物解析', false),
  themeAnalysis('theme_analysis', '主题寓意', false),
  endingExplanation('ending_explanation', '结局解析', true);

  const WatchAssistType(this.apiValue, this.label, this.requiresSpoiler);

  final String apiValue;
  final String label;
  final bool requiresSpoiler;

  static WatchAssistType fromApiValue(String? value) {
    for (final type in WatchAssistType.values) {
      if (type.apiValue == value) return type;
    }
    return WatchAssistType.currentStage;
  }
}

enum WatchAssistSpoilerMode {
  safe('safe', '无剧透'),
  spoiler('spoiler', '含剧透');

  const WatchAssistSpoilerMode(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static WatchAssistSpoilerMode fromApiValue(String? value) {
    for (final mode in WatchAssistSpoilerMode.values) {
      if (mode.apiValue == value) return mode;
    }
    return WatchAssistSpoilerMode.safe;
  }
}

class WatchAssistRequest {
  final String itemId;
  final int positionSeconds;
  final WatchAssistSpoilerMode spoilerMode;
  final WatchAssistType assistType;
  final String? subtitleWindow;

  const WatchAssistRequest({
    required this.itemId,
    required this.positionSeconds,
    this.spoilerMode = WatchAssistSpoilerMode.safe,
    this.assistType = WatchAssistType.currentStage,
    this.subtitleWindow,
  });

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'position_seconds': positionSeconds,
      'spoiler_mode': spoilerMode.apiValue,
      'assist_type': assistType.apiValue,
      'subtitle_window': subtitleWindow,
    };
  }

  WatchAssistRequest copyWith({
    int? positionSeconds,
    WatchAssistSpoilerMode? spoilerMode,
    WatchAssistType? assistType,
    String? subtitleWindow,
  }) {
    return WatchAssistRequest(
      itemId: itemId,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      spoilerMode: spoilerMode ?? this.spoilerMode,
      assistType: assistType ?? this.assistType,
      subtitleWindow: subtitleWindow ?? this.subtitleWindow,
    );
  }
}

typedef WatchAssistFetcher = Future<WatchAssistResponse> Function(
  WatchAssistRequest request,
);

class WatchAssistTypeOption {
  final WatchAssistType type;
  final String label;
  final bool requiresSpoiler;

  const WatchAssistTypeOption({
    required this.type,
    required this.label,
    required this.requiresSpoiler,
  });

  factory WatchAssistTypeOption.fromJson(Map<String, dynamic> json) {
    final type = WatchAssistType.fromApiValue(json['type'] as String?);
    return WatchAssistTypeOption(
      type: type,
      label: _asString(json['label'], type.label),
      requiresSpoiler: json['requiresSpoiler'] is bool
          ? json['requiresSpoiler'] as bool
          : type.requiresSpoiler,
    );
  }
}

class WatchAssistContent {
  final String title;
  final String text;
  final List<String> items;

  const WatchAssistContent({
    required this.title,
    required this.text,
    required this.items,
  });

  factory WatchAssistContent.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const WatchAssistContent(title: '', text: '', items: []);
    }
    return WatchAssistContent(
      title: _asString(json['title'], ''),
      text: _asString(json['text'], ''),
      items: _asStringList(json['items']),
    );
  }
}

class WatchAssistResponse {
  final String schemaVersion;
  final String itemId;
  final String title;
  final WatchAssistSpoilerMode mode;
  final WatchAssistType requestedAssistType;
  final WatchAssistType assistType;
  final String assistTypeLabel;
  final List<WatchAssistTypeOption> availableAssistTypes;
  final String capabilityLabel;
  final String notice;
  final String progressStage;
  final WatchAssistContent activeContent;

  const WatchAssistResponse({
    required this.schemaVersion,
    required this.itemId,
    required this.title,
    required this.mode,
    required this.requestedAssistType,
    required this.assistType,
    required this.assistTypeLabel,
    required this.availableAssistTypes,
    required this.capabilityLabel,
    required this.notice,
    required this.progressStage,
    required this.activeContent,
  });

  factory WatchAssistResponse.fromJson(Map<String, dynamic> json) {
    final availableRaw = json['availableAssistTypes'];
    final progressRaw = json['progress'];
    return WatchAssistResponse(
      schemaVersion: _asString(json['schemaVersion'], ''),
      itemId: _asString(json['itemId'], ''),
      title: _asString(json['title'], 'AI 解读'),
      mode: WatchAssistSpoilerMode.fromApiValue(json['mode'] as String?),
      requestedAssistType: WatchAssistType.fromApiValue(
        json['requestedAssistType'] as String?,
      ),
      assistType: WatchAssistType.fromApiValue(json['assistType'] as String?),
      assistTypeLabel: _asString(json['assistTypeLabel'], ''),
      availableAssistTypes: availableRaw is List
          ? availableRaw
              .whereType<Map>()
              .map((item) => WatchAssistTypeOption.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
      capabilityLabel: _asString(json['capabilityLabel'], ''),
      notice: _asString(json['notice'], ''),
      progressStage:
          progressRaw is Map ? _asString(progressRaw['stage'], '') : '',
      activeContent: WatchAssistContent.fromJson(
        json['activeContent'] is Map
            ? Map<String, dynamic>.from(json['activeContent'] as Map)
            : null,
      ),
    );
  }
}

String _asString(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

List<String> _asStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
