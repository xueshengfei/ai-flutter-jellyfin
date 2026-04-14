import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════
// SSE 事件类型
// ═══════════════════════════════════════════

/// SSE 事件类型枚举
enum SseEventType {
  thinking,
  tool,
  card,
  text,
  cardUpdate,
  session,
  done,
  error;

  /// 从后端 event 字段名解析
  static SseEventType fromName(String name) {
    return switch (name) {
      'thinking' => SseEventType.thinking,
      'tool' => SseEventType.tool,
      'card' => SseEventType.card,
      'text' => SseEventType.text,
      'card_update' => SseEventType.cardUpdate,
      'session' => SseEventType.session,
      'done' => SseEventType.done,
      'error' => SseEventType.error,
      _ => SseEventType.error,
    };
  }
}

// ═══════════════════════════════════════════
// SSE 事件数据类
// ═══════════════════════════════════════════

/// thinking 事件
class SseThinkingEvent extends Equatable {
  final String content;

  const SseThinkingEvent({required this.content});

  factory SseThinkingEvent.fromJson(Map<String, dynamic> json) =>
      SseThinkingEvent(content: json['content'] as String? ?? '');

  @override
  List<Object?> get props => [content];
}

/// tool 事件
class SseToolEvent extends Equatable {
  /// 工具名称（如 "search"）
  final String name;

  /// 工具状态（如 "calling"、"result"）
  final String status;

  /// 附加数据
  final Map<String, dynamic>? extra;

  const SseToolEvent({required this.name, required this.status, this.extra});

  factory SseToolEvent.fromJson(Map<String, dynamic> json) => SseToolEvent(
        name: json['name'] as String? ?? '',
        status: json['status'] as String? ?? '',
        extra: json['extra'] as Map<String, dynamic>?,
      );

  @override
  List<Object?> get props => [name, status, extra];
}

/// text 事件
class SseTextEvent extends Equatable {
  final String content;

  const SseTextEvent({required this.content});

  factory SseTextEvent.fromJson(Map<String, dynamic> json) =>
      SseTextEvent(content: json['content'] as String? ?? '');

  @override
  List<Object?> get props => [content];
}

/// card_update 事件（更新卡片推荐理由）
class SseCardUpdateEvent extends Equatable {
  /// 要更新的卡片 ID
  final String cardId;

  /// 更新内容（如推荐理由 reason）
  final String reason;

  const SseCardUpdateEvent({required this.cardId, required this.reason});

  factory SseCardUpdateEvent.fromJson(Map<String, dynamic> json) =>
      SseCardUpdateEvent(
        cardId: json['card_id'] as String? ?? json['cardId'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
      );

  @override
  List<Object?> get props => [cardId, reason];
}

/// session 事件
class SseSessionEvent extends Equatable {
  final String sessionId;

  const SseSessionEvent({required this.sessionId});

  factory SseSessionEvent.fromJson(Map<String, dynamic> json) =>
      SseSessionEvent(sessionId: json['session_id'] as String? ?? '');

  @override
  List<Object?> get props => [sessionId];
}

/// done 事件
class SseDoneEvent extends Equatable {
  final String? summary;

  const SseDoneEvent({this.summary});

  factory SseDoneEvent.fromJson(Map<String, dynamic> json) =>
      SseDoneEvent(summary: json['summary'] as String?);

  @override
  List<Object?> get props => [summary];
}

// ═══════════════════════════════════════════
// 卡片模型
// ═══════════════════════════════════════════

/// card.people 子模型
class AiCardPerson extends Equatable {
  final String id;
  final String name;
  final String? role;
  final String? type;
  final String? primaryImageTag;

  const AiCardPerson({
    required this.id,
    required this.name,
    this.role,
    this.type,
    this.primaryImageTag,
  });

  factory AiCardPerson.fromJson(Map<String, dynamic> json) => AiCardPerson(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: json['role'] as String?,
        type: json['type'] as String?,
        primaryImageTag: json['primaryImageTag'] as String?,
      );

  @override
  List<Object?> get props => [id, name, role, type, primaryImageTag];
}

/// AI 推荐卡片（映射 card 事件完整 JSON）
class AiMediaCard extends Equatable {
  /// Jellyfin ItemId
  final String id;

  /// 标题
  final String name;

  /// 媒体类型（Movie/Series 等）
  final String? type;

  /// 上映年份
  final int? year;

  /// 评分
  final double? rating;

  /// 类型标签
  final List<String> genres;

  /// 简介
  final String? overview;

  /// 海报 URL（后端已拼接完整地址）
  final String? posterUrl;

  /// AI 推荐理由
  final String? reason;

  /// 演员/导演列表
  final List<AiCardPerson> people;

  const AiMediaCard({
    required this.id,
    required this.name,
    this.type,
    this.year,
    this.rating,
    this.genres = const [],
    this.overview,
    this.posterUrl,
    this.reason,
    this.people = const [],
  });

  factory AiMediaCard.fromJson(Map<String, dynamic> json) => AiMediaCard(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String?,
        year: (json['year'] as num?)?.toInt(),
        rating: (json['rating'] as num?)?.toDouble(),
        genres: (json['genres'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        overview: json['overview'] as String?,
        posterUrl: json['posterUrl'] as String?,
        reason: json['reason'] as String?,
        people: (json['people'] as List<dynamic>?)
                ?.map((e) => AiCardPerson.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  /// 创建副本并更新推荐理由
  AiMediaCard copyWith({String? reason}) => AiMediaCard(
        id: id,
        name: name,
        type: type,
        year: year,
        rating: rating,
        genres: genres,
        overview: overview,
        posterUrl: posterUrl,
        reason: reason ?? this.reason,
        people: people,
      );

  @override
  List<Object?> get props => [id, name, type, year, rating, genres, overview, posterUrl, reason, people];
}

// ═══════════════════════════════════════════
// UI 模型
// ═══════════════════════════════════════════

/// 哨兵值，用于区分"未传参"和"显式传 null"
const _absent = Object();

/// 对话消息（UI 展示用）
class AiChatMessage extends Equatable {
  /// 消息文字内容
  final String content;

  /// 是否是用户发送的
  final bool isUser;

  /// 时间戳
  final DateTime timestamp;

  /// AI 推荐卡片列表
  final List<AiMediaCard> cards;

  /// 状态提示（如 "正在思考..."、"正在搜索..."）
  final String? statusText;

  const AiChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.cards = const [],
    this.statusText,
  });

  /// 创建副本
  ///
  /// [statusText] 不传则保留原值，传 null 则清空，传字符串则设置。
  /// 其他字段行为不变：传 null 保留原值。
  AiChatMessage copyWith({
    String? content,
    bool? isUser,
    DateTime? timestamp,
    List<AiMediaCard>? cards,
    Object? statusText = _absent,
  }) =>
      AiChatMessage(
        content: content ?? this.content,
        isUser: isUser ?? this.isUser,
        timestamp: timestamp ?? this.timestamp,
        cards: cards ?? this.cards,
        statusText: identical(statusText, _absent)
            ? this.statusText
            : statusText as String?,
      );

  @override
  List<Object?> get props => [content, isUser, timestamp, cards, statusText];
}
