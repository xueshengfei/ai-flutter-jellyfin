import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// AI 挑片页面
///
/// 对话式 AI 推荐页面：
/// 1. 用户输入自然语言
/// 2. 直连后端 SSE 流式通信（POST /ask_stream）
/// 3. 逐事件渲染（thinking/tool/card/text/card_update/done）
/// 4. 点击卡片跳转 MediaItemDetailPage
class AiRecommendPage extends StatefulWidget {
  final JellyfinClient client;

  const AiRecommendPage({super.key, required this.client});

  @override
  State<AiRecommendPage> createState() => _AiRecommendPageState();
}

class _AiRecommendPageState extends State<AiRecommendPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// SSE 流式服务
  late final AiStreamService _streamService;

  /// 聊天消息历史
  final List<AiChatMessage> _messages = [];

  /// 当前正在加载
  bool _isLoading = false;

  /// 当前流订阅（用于 dispose 时取消）
  StreamSubscription<SseEvent>? _currentSubscription;

  /// 当前正在构建的 AI 回复消息索引（-1 表示无）
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

  /// 发送提问
  void _sendMessage() {
    final query = _inputController.text.trim();
    if (query.isEmpty || _isLoading) return;

    _inputController.clear();

    // 取消上一次请求
    _currentSubscription?.cancel();
    _streamService.cancel();

    setState(() {
      // 添加用户消息
      _messages.add(AiChatMessage(
        content: query,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      // 添加一条空的 AI 回复占位
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

    // 监听 SSE 事件流
    _currentSubscription = _streamService.askStream(query).listen(
      _onSseEvent,
      onError: _onSseError,
      onDone: _onSseDone,
    );
  }

  /// 处理单个 SSE 事件
  void _onSseEvent(SseEvent event) {
    if (!mounted || _buildingMessageIndex < 0) return;

    setState(() {
      final msg = _messages[_buildingMessageIndex];
      switch (event.type) {
        case SseEventType.thinking:
          _messages[_buildingMessageIndex] = msg.copyWith(
            statusText: 'AI 正在思考...',
          );

        case SseEventType.tool:
          final toolEvent = SseToolEvent.fromJson(event.data);
          final label = toolEvent.status == 'calling' ? '正在搜索...' : '搜索完成';
          _messages[_buildingMessageIndex] = msg.copyWith(
            statusText: label,
          );

        case SseEventType.card:
          final card = AiMediaCard.fromJson(event.data);
          _messages[_buildingMessageIndex] = msg.copyWith(
            cards: [...msg.cards, card],
            statusText: null,
          );

        case SseEventType.text:
          final textEvent = SseTextEvent.fromJson(event.data);
          _messages[_buildingMessageIndex] = msg.copyWith(
            content: msg.content + textEvent.content,
            statusText: null,
          );

        case SseEventType.cardUpdate:
          final update = SseCardUpdateEvent.fromJson(event.data);
          final updatedCards = msg.cards.map((c) {
            if (c.id == update.cardId) {
              return c.copyWith(reason: update.reason);
            }
            return c;
          }).toList();
          _messages[_buildingMessageIndex] = msg.copyWith(
            cards: updatedCards,
          );

        case SseEventType.session:
          // sessionId 已在 AiStreamService 中自动保存
          break;

        case SseEventType.done:
          _messages[_buildingMessageIndex] = msg.copyWith(
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

  /// SSE 流错误
  void _onSseError(Object error) {
    if (!mounted) return;
    setState(() {
      if (_buildingMessageIndex >= 0) {
        _messages[_buildingMessageIndex] = _messages[_buildingMessageIndex].copyWith(
          content: '连接出错: $error',
          statusText: null,
        );
      }
      _isLoading = false;
      _buildingMessageIndex = -1;
    });
    _scrollToBottom();
  }

  /// SSE 流结束
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

  /// 滚动到底部
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

  /// 卡片点击 → 获取完整 MediaItem → 跳转详情页
  Future<void> _navigateToCardDetail(AiMediaCard card) async {
    try {
      // 从 Jellyfin 获取完整 MediaItem
      final mediaItem = await widget.client.mediaLibrary.getMediaItemDetail(card.id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaItemDetailPage(client: widget.client, item: mediaItem),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载详情失败: $e')),
      );
    }
  }

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

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64,
                color: Theme.of(context).colorScheme.primary.withAlpha(128)),
            const SizedBox(height: 16),
            Text(
              '告诉我你想看什么',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '例如："想看关于权谋的历史剧"\n"推荐一些能提升职场认知的电影"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: Column(
            crossAxisAlignment: message.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // 状态提示或文字气泡
              if (message.statusText != null)
                _buildStatusBubble(message.statusText!)
              else if (message.content.isNotEmpty)
                _buildTextBubble(message.content, message.isUser),

              // 推荐卡片
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

  /// 状态提示气泡（正在思考... / 正在搜索...）
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

  /// 文字气泡
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
          bottomLeft: isUser
              ? const Radius.circular(16)
              : const Radius.circular(4),
          bottomRight: isUser
              ? const Radius.circular(4)
              : const Radius.circular(16),
        ),
      ),
      child: Text(
        content,
        style: TextStyle(
          color: isUser
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 推荐卡片列表
  // ─────────────────────────────────────────

  Widget _buildCardList(List<AiMediaCard> cards) {
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

  Widget _buildCard(AiMediaCard card) {
    return GestureDetector(
      onTap: () => _navigateToCardDetail(card),
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
                child: card.posterUrl != null && card.posterUrl!.isNotEmpty
                    ? Image.network(
                        card.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderCover(),
                        loadingBuilder: (_, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildPlaceholderCover();
                        },
                      )
                    : _buildPlaceholderCover(),
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
                        card.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      // 年份 + 评分
                      if (card.year != null || card.rating != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (card.year != null)
                              Text(
                                '${card.year}',
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                            if (card.year != null && card.rating != null)
                              const SizedBox(width: 6),
                            if (card.rating != null) ...[
                              Icon(Icons.star, size: 12, color: Colors.amber[700]),
                              const SizedBox(width: 2),
                              Text(
                                card.rating!.toStringAsFixed(1),
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      // 推荐理由
                      Expanded(
                        child: Text(
                          card.reason ?? 'AI 推荐',
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
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(102),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
      _isLoading = false;
      _buildingMessageIndex = -1;
    });
  }
}
