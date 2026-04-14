import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════
// SSE 事件类型
// ═══════════════════════════════════════════

/// SSE 事件类型枚举
enum SseEventType {
  thinking,
  tool,
  token,
  card,
  session,
  done,
  error;

  /// 从后端 event 字段名解析
  static SseEventType fromName(String name) {
    return switch (name) {
      'thinking' => SseEventType.thinking,
      'tool' => SseEventType.tool,
      'token' => SseEventType.token,
      'card' => SseEventType.card,
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
///
/// `{"node": "llm"}` 或 `{"node": "reason"}`
class SseThinkingEvent extends Equatable {
  final String node;

  const SseThinkingEvent({required this.node});

  factory SseThinkingEvent.fromJson(Map<String, dynamic> json) =>
      SseThinkingEvent(node: json['node'] as String? ?? 'llm');

  @override
  List<Object?> get props => [node];
}

/// tool 事件
///
/// `{"tool": "search_media_json", "status": "calling", "args": {...}}`
class SseToolEvent extends Equatable {
  final String tool;
  final String status;
  final Map<String, dynamic>? args;
  final String? preview;

  const SseToolEvent({
    required this.tool,
    required this.status,
    this.args,
    this.preview,
  });

  factory SseToolEvent.fromJson(Map<String, dynamic> json) => SseToolEvent(
        tool: json['tool'] as String? ?? '',
        status: json['status'] as String? ?? '',
        args: json['args'] as Map<String, dynamic>?,
        preview: json['preview'] as String?,
      );

  @override
  List<Object?> get props => [tool, status, args, preview];
}

/// token 事件 — 逐字文本推送
///
/// `{"content": "根"}`，客户端按序拼接为完整 markdown
class SseTokenEvent extends Equatable {
  final String content;

  const SseTokenEvent({required this.content});

  factory SseTokenEvent.fromJson(Map<String, dynamic> json) =>
      SseTokenEvent(content: json['content'] as String? ?? '');

  @override
  List<Object?> get props => [content];
}

/// session 事件
///
/// `{"session_id": "a1b2c3d4", "history_count": 4}`
class SseSessionEvent extends Equatable {
  final String sessionId;

  const SseSessionEvent({required this.sessionId});

  factory SseSessionEvent.fromJson(Map<String, dynamic> json) =>
      SseSessionEvent(sessionId: json['session_id'] as String? ?? '');

  @override
  List<Object?> get props => [sessionId];
}

/// done 事件
///
/// `{"answer": "...", "cards": [{id, reason}, ...], "session_id": "..."}`
class SseDoneEvent extends Equatable {
  final String? answer;
  final List<AiCard>? cards;
  final String? sessionId;

  const SseDoneEvent({this.answer, this.cards, this.sessionId});

  factory SseDoneEvent.fromJson(Map<String, dynamic> json) => SseDoneEvent(
        answer: json['answer'] as String?,
        cards: (json['cards'] as List<dynamic>?)
            ?.map((e) => AiCard.fromJson(e as Map<String, dynamic>))
            .toList(),
        sessionId: json['session_id'] as String?,
      );

  @override
  List<Object?> get props => [answer, cards, sessionId];
}

// ═══════════════════════════════════════════
// 卡片模型
// ═══════════════════════════════════════════

/// AI 推荐卡片（精简版：只有 id + reason）
///
/// 协议: `{"id": "5269cdea...", "reason": "影史经典..."}`
/// 客户端拿到 id 后调 getMediaItemDetail(id) 从 Jellyfin 获取完整数据
class AiCard extends Equatable {
  /// Jellyfin Item ID
  final String id;

  /// AI 推荐理由
  final String reason;

  const AiCard({required this.id, required this.reason});

  factory AiCard.fromJson(Map<String, dynamic> json) => AiCard(
        id: json['id'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, reason];
}

// ═══════════════════════════════════════════
// UI 模型
// ═══════════════════════════════════════════

/// 哨兵值，用于区分"未传参"和"显式传 null"
const _absent = Object();

/// 对话消息（UI 展示用）
class AiChatMessage extends Equatable {
  /// 消息文字内容（markdown）
  final String content;

  /// 是否是用户发送的
  final bool isUser;

  /// 时间戳
  final DateTime timestamp;

  /// AI 推荐卡片列表（id + reason）
  final List<AiCard> cards;

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
  AiChatMessage copyWith({
    String? content,
    bool? isUser,
    DateTime? timestamp,
    List<AiCard>? cards,
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
