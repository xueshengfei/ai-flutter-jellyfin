import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// AI 挑片页面
///
/// 对话式 AI 推荐页面：
/// 1. 用户输入自然语言
/// 2. 直连后端 SSE 流式通信（POST /ask_stream）
/// 3. 逐事件渲染（thinking/tool/token/card/done）
/// 4. card 事件只含 id+reason，客户端并发调 getMediaItemDetail 获取详情
class AiRecommendPage extends StatefulWidget {
  final JellyfinClient client;

  const AiRecommendPage({super.key, required this.client});

  @override
  State<AiRecommendPage> createState() => _AiRecommendPageState();
}

class _AiRecommendPageState extends State<AiRecommendPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final AiStreamService _streamService;

  final List<AiChatMessage> _messages = [];

  /// itemId → MediaItem 的缓存（并发获取详情后填充）
  final Map<String, MediaItem> _mediaItemCache = {};

  bool _isLoading = false;
  StreamSubscription<SseEvent>? _currentSubscription;
  int _buildingMessageIndex = -1;

  @override
  void initState() {
    super.initState();
    _streamService = AiStreamService();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _currentSubscription?.cancel();
    _streamService.cancel();
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

    widget.client.mediaLibrary.getMediaItemDetail(itemId).then((item) {
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

  /// 卡片点击 → 直接跳转（详情已缓存或重新获取）
  void _navigateToDetail(MediaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MediaItemDetailPage(client: widget.client, item: item),
      ),
    );
  }

  /// 卡片点击（可能还没缓存，先获取再跳转）
  Future<void> _navigateToCard(AiCard card) async {
    final cached = _mediaItemCache[card.id];
    if (cached != null) {
      _navigateToDetail(cached);
      return;
    }
    try {
      final item =
          await widget.client.mediaLibrary.getMediaItemDetail(card.id);
      if (!mounted) return;
      _mediaItemCache[card.id] = item;
      _navigateToDetail(item);
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
        title: const Text('AI 挑片'),
        actions: [
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
                _buildQuickTag('历史权谋剧'),
                _buildQuickTag('职场认知提升'),
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
              // 状态提示
              if (message.statusText != null)
                _buildStatusBubble(message.statusText!)
              // 文本（markdown + 打字机光标）
              else if (message.content.isNotEmpty)
                _buildTextBubble(
                  isStreaming ? '${message.content}▍' : message.content,
                  message.isUser,
                ),

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

  /// 状态提示气泡
  Widget _buildStatusBubble(String statusText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 文字气泡（AI 回复用 MarkdownBody，用户消息用 Text）
  Widget _buildTextBubble(String content, bool isUser) {
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
              content,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 15,
              ),
            )
          : MarkdownBody(
              data: content,
              selectable: true,
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.6,
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
              // 封面
              Expanded(
                flex: 3,
                child: item != null
                    ? JellyfinImageWithClient(
                        client: widget.client,
                        itemId: item.id,
                        imageTag: item.primaryImageTag,
                        fillWidth: 300,
                        fillHeight: 450,
                        fit: BoxFit.cover,
                        placeholder: _buildPlaceholderCover(),
                        errorWidget: _buildPlaceholderCover(),
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

  /// 占位封面
  Widget _buildPlaceholderCover() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.movie_outlined, size: 32, color: Colors.white54),
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
    setState(() {
      _messages.clear();
      _mediaItemCache.clear();
      _isLoading = false;
      _buildingMessageIndex = -1;
    });
  }
}
