import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:jellyfin_ai_recommendation/src/models/ai_recommendation_models.dart';
import 'package:jellyfin_ai_recommendation/src/models/tts_models.dart';
import 'package:jellyfin_ai_recommendation/src/services/ai_recommendation_service.dart';
import 'package:jellyfin_ai_recommendation/src/services/tts_playback_service.dart';
import 'package:jellyfin_ai_recommendation/src/widgets/tts_control_button.dart';
import 'package:jellyfin_ai_recommendation/src/widgets/tts_settings_dialog.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

/// 获取媒体详情的抽象回调
///
/// 用于解耦 AI 模块对根包 JellyfinClient 的直接依赖。
/// 根包通过注入 `JellyfinClient.mediaLibrary.getMediaItemDetail` 实现。
typedef MediaItemDetailFetcher = Future<MediaItem> Function(String itemId);

/// 获取 AI 服务地址的抽象回调
typedef AiServiceUrlProvider = String Function();

/// AI 挑片页面
///
/// 对话式 AI 推荐页面：
/// 1. 用户输入自然语言
/// 2. 直连后端 SSE 流式通信（GET /ask_stream）
/// 3. 逐事件渲染（thinking/tool/token/card/done）
/// 4. card 事件只含 id+reason，客户端并发调 getMediaItemDetail 获取详情
///
/// **业务解耦设计**：
/// - 通过 [imageProvider] 加载图片，不直接依赖 JellyfinClient
/// - 通过 [fetchMediaItemDetail] 获取详情，不直接依赖 MediaLibraryService
/// - 通过 [onNavigateToMediaItem] / [onNavigateToAlbum] / [onNavigateToArtist]
///   / [onPlaySong] 回调跳转，不直接 import 其它 feature 页面
class AiRecommendPage extends StatefulWidget {
  /// AI 服务地址
  final String aiServiceUrl;

  /// 图片加载适配器
  final JellyfinImageProvider imageProvider;

  /// 获取媒体详情的回调
  final MediaItemDetailFetcher fetchMediaItemDetail;

  /// 卡片点击 → 通用媒体详情页
  final void Function(BuildContext context, MediaItem item)? onNavigateToMediaItem;

  /// 卡片点击 → 专辑详情页
  final void Function(BuildContext context, MediaItem item)? onNavigateToAlbum;

  /// 卡片点击 → 歌手详情页
  final void Function(BuildContext context, MediaItem item)? onNavigateToArtist;

  /// 卡片点击 → 播放歌曲
  final void Function(BuildContext context, MediaItem item)? onPlaySong;

  const AiRecommendPage({
    super.key,
    required this.aiServiceUrl,
    required this.imageProvider,
    required this.fetchMediaItemDetail,
    this.onNavigateToMediaItem,
    this.onNavigateToAlbum,
    this.onNavigateToArtist,
    this.onPlaySong,
  });

  @override
  State<AiRecommendPage> createState() => _AiRecommendPageState();
}

class _AiRecommendPageState extends State<AiRecommendPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late AiStreamService _streamService;

  /// 当前 AI 服务地址（显示用）
  String _aiServiceUrl = '';

  final List<AiChatMessage> _messages = [];

  /// itemId → MediaItem 的缓存（并发获取详情后填充）
  final Map<String, MediaItem> _mediaItemCache = {};

  bool _isLoading = false;
  StreamSubscription<SseEvent>? _currentSubscription;
  int _buildingMessageIndex = -1;

  /// TTS 语音播报
  TtsPlaybackService? _ttsService;
  int? _ttsActiveMsgIdx;
  TtsSettings _ttsSettings = const TtsSettings();

  @override
  void initState() {
    super.initState();
    _streamService = AiStreamService(aiServiceUrl: widget.aiServiceUrl);
    _aiServiceUrl = _streamService.currentBaseUrl;
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _currentSubscription?.cancel();
    _streamService.cancel();
    // 先 dispose 再置 null，避免异步回调在 dispose 后调用 stop/notifyListeners
    final tts = _ttsService;
    _ttsService = null;
    tts?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // 发送提问
  // ─────────────────────────────────────────

  void _sendMessage() {
    final query = _inputController.text.trim();
    if (query.isEmpty || _isLoading) return;

    _inputController.clear();
    _currentSubscription?.cancel();
    _streamService.cancel();

    // 停止当前 TTS，立即创建新服务用于流式播报
    _ttsService?.stop();
    _ttsService?.dispose();
    _ttsService = null;
    _ttsActiveMsgIdx = null;

    setState(() {
      _messages.add(AiChatMessage(
        content: query,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messages.add(AiChatMessage(
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        statusText: '正在连接...',
      ));
      _buildingMessageIndex = _messages.length - 1;
      _isLoading = true;
    });

    // 创建 TTS 服务，流式过程中边生成边播
    _ttsService = TtsPlaybackService(settings: _ttsSettings);
    _ttsActiveMsgIdx = _buildingMessageIndex;

    _scrollToBottom();

    _currentSubscription = _streamService.askStream(query).listen(
      _onSseEvent,
      onError: _onSseError,
      onDone: _onSseDone,
    );
  }

  // ─────────────────────────────────────────
  // SSE 事件处理
  // ─────────────────────────────────────────

  void _onSseEvent(SseEvent event) {
    if (!mounted || _buildingMessageIndex < 0) return;

    if (event.type == SseEventType.token || event.type == SseEventType.thinking || event.type == SseEventType.done) {
      final content = event.type == SseEventType.token ? (event.data['content'] ?? '') : '';
      print('[UI] 收到 ${event.type.name} 事件 @${DateTime.now().toIso8601String()} content="${(content as String).length > 20 ? content.substring(0, 20) + "..." : content}"');
    }

    setState(() {
      final msg = _messages[_buildingMessageIndex];
      switch (event.type) {
        case SseEventType.thinking:
          final thinkEvent = SseThinkingEvent.fromJson(event.data);
          final label = thinkEvent.node == 'reason'
              ? '正在生成推荐理由...'
              : 'AI 正在思考...';
          _messages[_buildingMessageIndex] = msg.copyWith(statusText: label);

        case SseEventType.tool:
          final toolEvent = SseToolEvent.fromJson(event.data);
          final label =
              toolEvent.status == 'calling' ? '正在搜索...' : '搜索完成';
          _messages[_buildingMessageIndex] = msg.copyWith(statusText: label);

        case SseEventType.token:
          final tokenEvent = SseTokenEvent.fromJson(event.data);
          _messages[_buildingMessageIndex] = msg.copyWith(
            content: msg.content + tokenEvent.content,
            statusText: null,
          );
          _ttsService?.feedToken(tokenEvent.content);

        case SseEventType.card:
          final card = AiCard.fromJson(event.data);
          _messages[_buildingMessageIndex] = msg.copyWith(
            cards: [...msg.cards, card],
            statusText: null,
          );
          // 并发获取详情
          _fetchDetailIfNeeded(card.id);

        case SseEventType.session:
          // sessionId 已在 AiStreamService 中自动保存
          break;

        case SseEventType.done:
          final doneEvent = SseDoneEvent.fromJson(event.data);
          // 文本兜底
          var finalContent = msg.content;
          if (finalContent.isEmpty && doneEvent.answer != null) {
            finalContent = doneEvent.answer!;
          }
          // 卡片兜底（如果流式没收到 card，用 done 的）
          var finalCards = msg.cards;
          if (finalCards.isEmpty &&
              doneEvent.cards != null &&
              doneEvent.cards!.isNotEmpty) {
            finalCards = doneEvent.cards!;
            // 补拉详情
            for (final c in finalCards) {
              _fetchDetailIfNeeded(c.id);
            }
          }
          _messages[_buildingMessageIndex] = msg.copyWith(
            content: finalContent,
            cards: finalCards,
            statusText: null,
          );
          _isLoading = false;
          _buildingMessageIndex = -1;
          _ttsService?.flushRemaining();

        case SseEventType.error:
          final errMsg = event.data['message'] as String? ?? '未知错误';
          _messages[_buildingMessageIndex] = msg.copyWith(
            content: msg.content.isEmpty ? '出错了: $errMsg' : msg.content,
            statusText: null,
          );
          _isLoading = false;
          _buildingMessageIndex = -1;
      }
    });

    _scrollToBottom();
  }

  /// 并发获取 MediaItem 详情，获取到后 setState 刷新卡片
  void _fetchDetailIfNeeded(String itemId) {
    if (_mediaItemCache.containsKey(itemId)) return;

    widget.fetchMediaItemDetail(itemId).then((item) {
      if (!mounted) return;
      setState(() {
        _mediaItemCache[itemId] = item;
      });
    }).catchError((_) {
      // 获取失败时忽略，卡片会显示占位信息
    });
  }

  void _onSseError(Object error) {
    if (!mounted) return;
    setState(() {
      if (_buildingMessageIndex >= 0) {
        _messages[_buildingMessageIndex] =
            _messages[_buildingMessageIndex].copyWith(
          content: '连接出错: $error',
          statusText: null,
        );
      }
      _isLoading = false;
      _buildingMessageIndex = -1;
    });
    _scrollToBottom();
  }

  void _onSseDone() {
    if (!mounted) return;
    setState(() {
      if (_buildingMessageIndex >= 0) {
        _messages[_buildingMessageIndex] =
            _messages[_buildingMessageIndex].copyWith(statusText: null);
      }
      _isLoading = false;
      _buildingMessageIndex = -1;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 卡片点击 → 根据 AiCardType 通过回调跳转（业务解耦）
  void _navigateToDetail(MediaItem item, AiCardType type) {
    switch (type) {
      // 视频类 → 通用详情页回调
      case AiCardType.movie:
      case AiCardType.series:
      case AiCardType.episode:
      case AiCardType.video:
      case AiCardType.season:
      case AiCardType.musicvideo:
        widget.onNavigateToMediaItem?.call(context, item);

      // 歌曲 → 播放回调
      case AiCardType.audio:
        widget.onPlaySong?.call(context, item);

      // 专辑 → 专辑详情回调
      case AiCardType.musicalbum:
        widget.onNavigateToAlbum?.call(context, item);

      // 歌手 → 歌手详情回调
      case AiCardType.musicartist:
        widget.onNavigateToArtist?.call(context, item);
    }
  }

  /// 卡片点击（可能还没缓存，先获取再跳转）
  Future<void> _navigateToCard(AiCard card) async {
    final cached = _mediaItemCache[card.id];
    if (cached != null) {
      _navigateToDetail(cached, card.type);
      return;
    }
    try {
      final item = await widget.fetchMediaItemDetail(card.id);
      if (!mounted) return;
      _mediaItemCache[card.id] = item;
      _navigateToDetail(item, card.type);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载详情失败: $e')),
      );
    }
  }

  // ─────────────────────────────────────────
  // UI 构建
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 推荐'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            tooltip: '返回',
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 8),
        actions: [
          IconButton(
            icon: const Icon(Icons.record_voice_over),
            onPressed: _showTtsSettingsDialog,
            tooltip: '语音播报设置',
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: _showServiceUrlDialog,
            tooltip: 'AI 服务地址',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _messages.isEmpty ? null : _clearHistory,
            tooltip: '清空对话',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 消息列表
  // ─────────────────────────────────────────

  Widget _buildMessageList() {
    if (_messages.isEmpty) return _buildEmptyState();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withAlpha(128)),
            const SizedBox(height: 16),
            Text(
              '告诉我你想看什么',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(179),
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '例如："想看关于权谋的历史剧"\n"推荐一些能提升职场认知的电影"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(128),
                  ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickTag('推荐周杰伦的几首歌'),
                _buildQuickTag('推荐最新的科幻电影'),
                _buildQuickTag('高分经典电影'),
                _buildQuickTag('轻松解压喜剧'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTag(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _inputController.text = text;
        _sendMessage();
      },
    );
  }

  // ─────────────────────────────────────────
  // 消息气泡
  // ─────────────────────────────────────────

  Widget _buildMessageBubble(AiChatMessage message) {
    // 流式中时追加打字光标
    final isStreaming = !message.isUser &&
        _isLoading &&
        _buildingMessageIndex >= 0 &&
        _messages.indexOf(message) == _buildingMessageIndex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: Column(
            crossAxisAlignment: message.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // 状态提示（小标签，不遮挡已有文本）
              if (message.statusText != null)
                _buildStatusChip(message.statusText!),
              // 文本（markdown + 打字机光标）
              if (message.content.isNotEmpty)
                _buildTextBubble(
                  isStreaming ? '${message.content}▍' : message.content,
                  message.isUser,
                ),

              // TTS 播放按钮（非用户消息 + 有内容）
              if (!message.isUser && message.content.isNotEmpty)
                _buildTtsButton(message),

              // 推荐卡片（文本下方）
              if (message.cards.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildCardList(message.cards),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 状态提示小标签（不遮挡已有文本）
  Widget _buildStatusChip(String statusText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 去除 markdown 中的代码块（兜底，防止 LLM 输出 ```jellyfin 等）
  static String _stripCodeBlocks(String content) {
    var result = content;
    // 移除完整代码块：```lang\n...\n```
    result = result.replaceAll(RegExp(r'```\w*\n[\s\S]*?\n```'), '');
    // 移除流式传输中未闭合的代码块：```lang\n...（到末尾）
    result = result.replaceAll(RegExp(r'\n*```\w*\n[\s\S]*$'), '');
    // 清理残留的 ``` 标记
    result = result.replaceAll(RegExp(r'\n*```\w*\n*'), '');
    return result.trim();
  }

  /// 文字气泡（AI 回复用 MarkdownBody，用户消息用 Text）
  Widget _buildTextBubble(String content, bool isUser) {
    // AI 回复：去除代码块再渲染
    final displayContent = isUser ? content : _stripCodeBlocks(content);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft:
              isUser ? const Radius.circular(16) : const Radius.circular(4),
          bottomRight:
              isUser ? const Radius.circular(4) : const Radius.circular(16),
        ),
      ),
      child: isUser
          ? Text(
              displayContent,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 15,
              ),
            )
          : MarkdownBody(
              data: displayContent,
              selectable: true,
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.6,
                ),
                a: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.6,
                ),
                listBullet: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────
  // 推荐卡片列表
  // ─────────────────────────────────────────

  Widget _buildCardList(List<AiCard> cards) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _buildCard(cards[index]);
        },
      ),
    );
  }

  Widget _buildCard(AiCard card) {
    final item = _mediaItemCache[card.id];

    return GestureDetector(
      onTap: () => _navigateToCard(card),
      child: SizedBox(
        width: 150,
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 封面 — 使用 JellyfinImageProvider 解耦
              Expanded(
                flex: 3,
                child: item != null
                    ? JellyfinImage(
                        imageProvider: widget.imageProvider,
                        itemId: item.id,
                        imageTag: item.primaryImageTag,
                        fillWidth: 300,
                        fillHeight: 450,
                        fit: BoxFit.cover,
                        placeholder: _buildPlaceholderCover(card.type),
                        errorWidget: _buildPlaceholderCover(card.type),
                      )
                    : _buildLoadingCover(),
              ),
              // 信息
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题
                      Text(
                        item?.name ?? '加载中...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      // 年份 + 评分
                      if (item != null &&
                          (item.productionYear != null ||
                              item.communityRating != null)) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (item.productionYear != null)
                              Text(
                                '${item.productionYear}',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[600]),
                              ),
                            if (item.productionYear != null &&
                                item.communityRating != null)
                              const SizedBox(width: 6),
                            if (item.communityRating != null) ...[
                              Icon(Icons.star,
                                  size: 12, color: Colors.amber[700]),
                              const SizedBox(width: 2),
                              Text(
                                item.communityRating!.toStringAsFixed(1),
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      // 推荐理由
                      Expanded(
                        child: Text(
                          card.reason.isNotEmpty ? card.reason : 'AI 推荐',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 加载中封面（详情还在获取）
  Widget _buildLoadingCover() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  /// 占位封面（按卡片类型显示不同图标）
  Widget _buildPlaceholderCover(AiCardType type) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(type.icon, size: 32, color: Colors.white54),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 输入区域
  // ─────────────────────────────────────────

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: '想看点什么？',
                hintStyle: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withAlpha(102),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isLoading ? null : _sendMessage,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  /// 清空对话
  void _clearHistory() {
    _currentSubscription?.cancel();
    _streamService.cancel();
    _streamService.sessionId = null;
    _ttsService?.stop();
    _ttsService?.dispose();
    _ttsService = null;
    _ttsActiveMsgIdx = null;
    setState(() {
      _messages.clear();
      _mediaItemCache.clear();
      _isLoading = false;
      _buildingMessageIndex = -1;
    });
  }

  // ─────────────────────────────────────────
  // TTS 语音播报
  // ─────────────────────────────────────────

  Widget _buildTtsButton(AiChatMessage message) {
    final msgIdx = _messages.indexOf(message);
    final isActive = _ttsActiveMsgIdx == msgIdx && _ttsService != null;

    if (isActive) {
      return ListenableBuilder(
        listenable: _ttsService!,
        builder: (context, _) {
          return TtsControlButton(
            state: _ttsService!.state,
            onPressed: () {
              switch (_ttsService!.state) {
                case TtsPlaybackState.playing:
                  _ttsService!.pause();
                case TtsPlaybackState.paused:
                  _ttsService!.play();
                case TtsPlaybackState.completed:
                case TtsPlaybackState.idle:
                  _startTtsForMessage(msgIdx);
                case TtsPlaybackState.preparing:
                  break;
                case TtsPlaybackState.error:
                  _startTtsForMessage(msgIdx);
              }
            },
          );
        },
      );
    }

    return TtsControlButton(
      state: TtsPlaybackState.idle,
      onPressed: () => _startTtsForMessage(msgIdx),
    );
  }

  void _startTtsForMessage(int msgIdx) {
    _ttsService?.stop();
    _ttsService?.dispose();
    final msg = _messages[msgIdx];
    if (msg.content.isEmpty) return;
    _ttsService = TtsPlaybackService(settings: _ttsSettings);
    _ttsActiveMsgIdx = msgIdx;
    setState(() {});
    _ttsService!.playFullText(msg.content);
  }

  Future<void> _showTtsSettingsDialog() async {
    final result = await showTtsSettingsDialog(context, _ttsSettings);
    if (result != null) {
      setState(() => _ttsSettings = result);
      _ttsService?.updateSettings(result);
    }
  }

  /// AI 服务地址设置弹窗
  void _showServiceUrlDialog() {
    final controller = TextEditingController(text: _aiServiceUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.language),
        title: const Text('AI 服务地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'IP:端口',
                hintText: 'http://192.168.1.100:5005',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            Text(
              '默认与 Jellyfin 同 IP，端口 5005',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                _streamService.updateBaseUrl(url);
                setState(() => _aiServiceUrl = url);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
