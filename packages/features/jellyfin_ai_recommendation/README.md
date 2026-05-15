# jellyfin_ai_recommendation

AI 对话推荐业务模块。通过 SSE 流式通信直连后端 AI 服务，实现对话式媒体推荐、实时 Markdown 渲染、推荐卡片展示和 TTS 语音播报。

## 功能清单

- 对话式 AI 推荐：用户输入自然语言，后端执行搜索+推理，流式返回结果
- SSE 流式通信：条件导入适配 Web / Native 平台
- 多轮对话：自动传递 `session_id`，支持上下文连续对话
- 实时渲染：逐 token 推送并拼接 Markdown，带打字机光标效果
- 推荐卡片：card 事件携带 id + reason + type，客户端并发拉取详情展示封面
- TTS 语音播报：流式过程中边生成边合成边播放，支持暂停/继续/整段重播
- 快捷标签：首页提供预设提问入口（"推荐最新的科幻电影"等）
- 服务地址可配置：运行时修改 AI 服务地址和 TTS 服务地址

## 核心类说明

### 页面

| 类名 | 文件 | 说明 |
|------|------|------|
| `AiRecommendPage` | `lib/src/pages/ai_recommend_page.dart` | AI 对话推荐主页面。接收 `imageProvider`、`fetchMediaItemDetail`、导航回调等注入参数，通过 SSE 流驱动 UI 更新 |

### 模型

| 类名 | 文件 | 说明 |
|------|------|------|
| `SseEventType` | `lib/src/models/ai_recommendation_models.dart` | SSE 事件类型枚举：`thinking` / `tool` / `token` / `card` / `session` / `done` / `error` |
| `SseThinkingEvent` | 同上 | thinking 事件数据，包含 `node` 字段（`llm` 或 `reason`） |
| `SseToolEvent` | 同上 | tool 事件数据，包含 `tool`、`status`、`args`、`preview` 字段 |
| `SseTokenEvent` | 同上 | token 事件数据，逐字文本推送 `content` |
| `SseSessionEvent` | 同上 | session 事件数据，携带 `sessionId` 用于多轮对话 |
| `SseDoneEvent` | 同上 | done 事件数据，包含完整 `answer`、`cards` 列表和 `sessionId` |
| `AiCardType` | 同上 | 推荐卡片类型枚举，透传 Jellyfin 原始类型（movie/series/audio/musicalbum/musicartist 等） |
| `AiCard` | 同上 | 推荐卡片模型：`id`（Jellyfin Item ID）、`reason`（推荐理由）、`type`（卡片类型） |
| `AiChatMessage` | 同上 | 对话消息 UI 模型：`content`（Markdown 文本）、`isUser`、`cards`、`statusText` |
| `SseEvent` | `lib/src/services/ai_recommendation_service.dart` | SSE 事件统一封装：`type` + `data`（原始 JSON） |
| `TtsSettings` | `lib/src/models/tts_models.dart` | TTS 设置：`voiceName`、`speed`、`ttsBaseUrl` |
| `TtsSegment` | 同上 | TTS 分段模型：`index`、`text`、`state`、`audioUrl`、`errorMessage` |
| `TtsSegmentState` | 同上 | 分段状态枚举：`pending` / `synthesizing` / `ready` / `playing` / `played` / `error` |
| `TtsPlaybackState` | 同上 | 全局播放状态枚举：`idle` / `preparing` / `playing` / `paused` / `completed` / `error` |

### 服务

| 类名 | 文件 | 说明 |
|------|------|------|
| `AiStreamService` | `lib/src/services/ai_recommendation_service.dart` | AI 流式通信服务。GET `/ask_stream` 建立 SSE 连接，解析事件流并派发 `SseEvent`。支持取消、多轮 session、地址更新 |
| `TtsPlaybackService` | `lib/src/services/tts_playback_service.dart` | TTS 语音播报服务（ChangeNotifier）。流程：SSE tokens -> SentenceBuffer -> 分句 -> 并发 TTS 合成 -> 顺序播放队列 |
| `createSseStream()` | `lib/src/services/sse_fetch.dart` | SSE 流式连接 stub（不支持的平台抛出异常） |
| `createSseStream()` | `lib/src/services/sse_fetch_native.dart` | 原生平台实现：Dio GET + `ResponseType.stream` |
| `createSseStream()` | `lib/src/services/sse_fetch_web.dart` | Web 平台实现：XMLHttpRequest 渐进式读取 |

### 组件

| 类名 | 文件 | 说明 |
|------|------|------|
| `AiRecommendPill` | `lib/src/widgets/ai_recommend_pill.dart` | AppBar 入口胶囊动画按钮。9 秒周期：圆形 -> 展开胶囊显示"AI 推荐" -> 收回 -> 静止 |
| `TtsControlButton` | `lib/src/widgets/tts_control_button.dart` | TTS 播放/暂停按钮，根据 `TtsPlaybackState` 切换图标和提示文本 |
| `showTtsSettingsDialog()` | `lib/src/widgets/tts_settings_dialog.dart` | TTS 设置弹窗：服务地址、音色选择（从 TTS 服务拉取列表）、语速调节、连接测试 |

## SSE 流式通信架构

模块使用 Dart 条件导入（conditional import）实现跨平台 SSE 流式传输：

```
ai_recommendation_service.dart
  └── import 'sse_fetch.dart'
        if (dart.library.html) 'sse_fetch_web.dart'     // Web
        if (dart.library.io)  'sse_fetch_native.dart'    // Native/HarmonyOS
```

三个文件导出同名函数 `Stream<Uint8List> createSseStream(url, headers, {cancelToken})`：

- **sse_fetch.dart**（stub）-- 不支持的平台直接抛出 `UnsupportedError`
- **sse_fetch_native.dart** -- 使用 Dio 发起 GET 请求，`ResponseType.stream` 读取 `ResponseBody` 逐 chunk 推送
- **sse_fetch_web.dart** -- 使用 `XMLHttpRequest`，在 `readyState >= 3`（LOADING）时通过 `responseText` 增量读取已接收数据

`AiStreamService` 统一消费 `createSseStream()` 返回的字节流，按行解析 `event:` / `data:` 字段，JSON 反序列化后派发为 `SseEvent`。

### 事件处理流程

```
用户提问
  -> AiStreamService.askStream(question)
  -> GET /ask_stream?question=...&session_id=...
  -> 逐 chunk 解析 SSE 协议
  -> 派发 SseEvent:
       thinking -> 显示"AI 正在思考..."
       tool     -> 显示"正在搜索..."
       token    -> 追加文本 + feedToken 到 TTS
       card     -> 追加卡片 + 并发 fetchMediaItemDetail
       session  -> 自动保存 sessionId
       done     -> 兜底文本/卡片 + flushRemaining(TTS)
       error    -> 显示错误信息
```

## TTS 语音播报流程

`TtsPlaybackService` 实现流式边生成边播报：

```
SSE token 事件
  -> feedToken(token) 写入 StringBuffer
  -> 遇到句号/问号/感叹号等句子边界
  -> _flushBuffer() 分句 + 清理 Markdown 语法
  -> _synthesizeSegment() 并发调 RainfallTTS 生成音频
  -> _tryStartPlayback() 按顺序播放已合成的分段
  -> AudioPlayer 播完一段 -> _playNextReady() 播下一段
```

支持两种模式：
- **流式播报**：SSE 过程中通过 `feedToken()` 实时喂入 token，边生成边播放
- **整段播报**：对话完成后点击 TTS 按钮，通过 `playFullText(text)` 播放完整回答

TTS 合成使用 `rainfall_tts_sdk`（雨落 AI 语音 Gradio 服务），支持音色选择和语速调节。

## 依赖关系

```
jellyfin_ai_recommendation
  ├── jellyfin_core          # 配置、异常基类
  ├── jellyfin_models        # MediaItem 等共享模型
  ├── jellyfin_ui_kit        # JellyfinImage、JellyfinImageProvider
  ├── rainfall_tts_sdk       # 雨落 AI 语音合成 SDK（vendor）
  ├── dio                    # HTTP 客户端（SSE Native）
  ├── just_audio             # 音频播放（TTS）
  ├── flutter_markdown       # Markdown 渲染
  └── equatable              # 值对象相等性
```

注意：本模块不直接依赖 `jellyfin_api` 或 `jellyfin_dart`，图片加载和媒体详情获取通过注入回调实现解耦。

## 使用示例

### 1. 路由注册（Product App 中）

```dart
// app_router.dart
GoRoute(
  path: '/ai-recommend',
  builder: (context, state) => AiRecommendPage(
    aiServiceUrl: session.aiServiceUrl,
    imageProvider: imageProvider,
    fetchMediaItemDetail: gateway.getMediaItemDetail,
    onNavigateToMediaItem: (ctx, item) => ctx.push('/media/detail/${item.id}'),
    onNavigateToAlbum: (ctx, item) => ctx.push('/libraries/${item.libraryId}/music/album/${item.id}'),
    onNavigateToArtist: (ctx, item) => ctx.push('/libraries/${item.libraryId}/music/artist/${item.id}'),
    onPlaySong: (ctx, item) { /* 播放歌曲 */ },
  ),
),
```

### 2. AppBar 入口按钮

```dart
AppBar(
  actions: [
    AiRecommendPill(
      onPressed: () => context.push('/ai-recommend'),
    ),
  ],
)
```

### 3. 单独使用 AiStreamService

```dart
final service = AiStreamService(aiServiceUrl: 'http://192.168.1.100:5005');
await for (final event in service.askStream('推荐好看的科幻电影')) {
  switch (event.type) {
    case SseEventType.token:
      final token = SseTokenEvent.fromJson(event.data);
      print(token.content);
    case SseEventType.card:
      final card = AiCard.fromJson(event.data);
      print('推荐: ${card.id} - ${card.reason}');
    case SseEventType.done:
      print('完成');
    default:
      break;
  }
}
```

### 4. 单独使用 TtsPlaybackService

```dart
final tts = TtsPlaybackService(settings: TtsSettings(
  ttsBaseUrl: 'http://192.168.1.100:7861',
  voiceName: 'demo_boy.wav',
  speed: 1.0,
));

// 整段播报
tts.playFullText('这是一段测试文本。AI 推荐了以下电影。');

// 流式播报
tts.feedToken('这是');
tts.feedToken('一句。');
tts.flushRemaining();
```

## 测试说明

```bash
# 运行本模块测试
cd packages/features/jellyfin_ai_recommendation && flutter test
```

测试覆盖内容（`test/jellyfin_ai_recommendation_test.dart`）：
- `SseEventType.fromName` 解析所有事件类型及兜底
- `AiCardType.fromName` 解析所有卡片类型及兜底
- `AiCard.fromJson` 正常解析与缺失字段默认值
- `AiChatMessage.copyWith` 状态文本保留/清空/更新、卡片追加
- SSE 事件数据类反序列化（thinking/tool/token/session/done）
- `AiRecommendPill` 组件渲染与点击响应

外部依赖通过 `FakeImageProvider` 替代，无需真实 Jellyfin 服务。
