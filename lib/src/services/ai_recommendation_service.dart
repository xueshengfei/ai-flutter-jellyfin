import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:jellyfin_service/src/models/ai_recommendation_models.dart';

// ═══════════════════════════════════════════
// SSE 事件统一封装
// ═══════════════════════════════════════════

/// SSE 事件（type + 原始 data JSON）
class SseEvent {
  final SseEventType type;
  final Map<String, dynamic> data;

  const SseEvent({required this.type, required this.data});

  @override
  String toString() => 'SseEvent(type: $type, data: $data)';
}

// ═══════════════════════════════════════════
// AI 流式通信服务
// ═══════════════════════════════════════════

/// AI 流式推荐服务
///
/// 直连后端 `http://localhost:5000`，通过 POST `/ask_stream` 建立 SSE 连接。
/// 后端负责全部 AI + Jellyfin 逻辑，客户端只负责消费 SSE 事件流并渲染。
///
/// 仅用 dart:async + dart:convert，兼容鸿蒙平台。
class AiStreamService {
  /// 后端地址
  static const String _baseUrl = 'http://localhost:5000';

  final Dio _dio;

  /// 当前会话 ID（多轮对话自动传递）
  String? sessionId;

  /// 取消令牌（用于取消上一次请求）
  CancelToken? _cancelToken;

  AiStreamService() : _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  /// 发送提问并返回 SSE 事件流
  ///
  /// [question] 用户自然语言提问
  /// 返回 `Stream<SseEvent>`，调用方逐事件监听即可
  Stream<SseEvent> askStream(String question) {
    // 取消上一次未完成的请求
    _cancelToken?.cancel('新请求已发起');
    _cancelToken = CancelToken();

    final controller = StreamController<SseEvent>();

    _startSseConnection(question, controller);

    return controller.stream;
  }

  /// 取消当前请求
  void cancel() {
    _cancelToken?.cancel('用户取消');
    _cancelToken = null;
  }

  /// 建立 SSE 连接并解析事件流
  Future<void> _startSseConnection(
    String question,
    StreamController<SseEvent> controller,
  ) async {
    try {
      final body = <String, dynamic>{'question': question};
      if (sessionId != null) {
        body['session_id'] = sessionId;
      }

      final response = await _dio.post<ResponseBody>(
        '/ask_stream',
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
          receiveTimeout: const Duration(minutes: 5),
        ),
        cancelToken: _cancelToken,
      );

      final stream = response.data!.stream;

      // 逐行状态机解析 SSE
      // 后端每个事件是两行：event: xxx \n data: {...} \n
      // 事件之间可能有空行也可能没有，所以用 event: 行作为事件开始标记
      final buffer = StringBuffer();
      String? currentEventName;
      final currentDataLines = <String>[];

      await for (final chunk in stream) {
        final text = utf8.decode(chunk, allowMalformed: true);
        buffer.write(text);

        // 逐行处理
        String content = buffer.toString();
        int newlineIdx;
        while ((newlineIdx = content.indexOf('\n')) >= 0) {
          // 取一行，去掉 \r
          var line = content.substring(0, newlineIdx);
          if (line.endsWith('\r')) {
            line = line.substring(0, line.length - 1);
          }
          content = content.substring(newlineIdx + 1);

          if (line.startsWith('event:')) {
            // 如果上一个事件还没派发，先派发
            if (currentEventName != null && currentDataLines.isNotEmpty) {
              _emitEvent(currentEventName, currentDataLines, controller);
            }
            // 开始新事件
            currentEventName = line.substring(6).trim();
            currentDataLines.clear();
          } else if (line.startsWith('data:')) {
            currentDataLines.add(line.substring(5).trim());
          }
          // 空行或其他行：忽略
        }
        buffer.clear();
        buffer.write(content);
      }

      // 派发最后一个事件（流结束时）
      if (currentEventName != null && currentDataLines.isNotEmpty) {
        _emitEvent(currentEventName, currentDataLines, controller);
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        // 用户主动取消，不报错
      } else {
        print('[SSE] 连接异常: $e');
        controller.add(SseEvent(
          type: SseEventType.error,
          data: {'message': '连接失败: $e'},
        ));
      }
    } finally {
      await controller.close();
    }
  }

  /// 解析并派发一个完整事件
  void _emitEvent(
    String eventName,
    List<String> dataLines,
    StreamController<SseEvent> controller,
  ) {
    final dataStr = dataLines.join('\n');
    try {
      final data = jsonDecode(dataStr) as Map<String, dynamic>;
      final event = SseEvent(
        type: SseEventType.fromName(eventName),
        data: data,
      );
      // 自动保存 sessionId
      if (event.type == SseEventType.session) {
        final sessionEvent = SseSessionEvent.fromJson(event.data);
        sessionId = sessionEvent.sessionId;
      }
      controller.add(event);
    } catch (e) {
      print('[SSE] JSON解析失败: $e\nevent: $eventName\nraw: $dataStr');
      controller.add(SseEvent(
        type: SseEventType.error,
        data: {'message': '解析失败', 'raw': dataStr},
      ));
    }
  }
}
