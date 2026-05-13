# 音乐模块拆分评估与重构建议

本文档面向后续执行模块化改造的开发人员，基于当前旧根包 `lib`、新 `Product/jellyfin_app`、已拆出的 `packages/features/jellyfin_music`、`packages/features/rvc_flutter`、`packages/features/jellyfin_ai_recommendation` 的代码现状，评估音乐模块应该如何继续拆分。

结论先行：

1. 音乐不是一个简单页面，它包含“音乐库浏览、搜索、专辑/艺术家详情、歌曲播放、歌词、全局迷你播放器、AI 推荐入口、RVC 一键翻唱入口”等多个子业务。
2. 当前 `jellyfin_music` 的拆分是一个好的开始，但只拆出了“专辑详情、艺术家详情、音乐模型、音频播放端口”，还没有覆盖完整音乐业务。
3. 不建议把所有音乐相关代码都塞回 `Product/jellyfin_app`，否则音乐会成为新 App 里的第一个大耦合模块。
4. 不建议把 RVC 的耗时任务状态放在 `RvcPage State` 里。页面退出后任务状态会丢，这是当前用户体验问题的根因。
5. 全局底部悬浮迷你播放器不应该属于某一个音乐页面，它应该属于 App Shell，由根 App 统一挂载，监听全局 `AudioPlaybackPort`。

## 1. 当前旧包音乐业务结构

旧根包音乐业务主要分散在这些文件：

| 文件 | 当前职责 | 问题 |
| --- | --- | --- |
| `lib/src/ui/pages/music_library_page.dart` | 音乐库入口、艺术家 Tab、专辑 Tab、歌曲 Tab、音频播放页、歌词、RVC 入口 | 文件过大，页面、播放、歌词、RVC 入口混在一起 |
| `lib/src/ui/pages/music_search_page.dart` | 音乐搜索，搜索艺术家/专辑/歌曲 | 直接依赖 `JellyfinClient`，直接 `Navigator.push` 到其它页面 |
| `lib/src/ui/pages/artist_detail_page.dart` | 艺术家详情、专辑列表 | 直接依赖 `JellyfinClient` 和旧页面 |
| `lib/src/ui/pages/album_detail_page.dart` | 专辑详情、歌曲列表、播放全部 | 直接依赖 `JellyfinClient` 和旧播放器页 |
| `lib/src/ui/pages/lyrics_page.dart` | 独立歌词页、歌词同步、远程歌词搜索/下载 | 还没有进入新音乐 feature |
| `lib/src/ui/widgets/mini_player_card.dart` | 全局迷你播放器 UI | 实际只挂在音乐页底部，不是真正 App 全局 |
| `lib/src/ui/services/audio_playback_manager.dart` | `just_audio` 单例播放器、播放列表、播放模式、进度流 | 是全局播放状态，但还绑定旧根包模型和旧 `JellyfinClient` |
| `lib/src/services/music_service.dart` | Jellyfin 音乐 API、歌词 API、搜索 API、音频流地址 | 数据能力完整，但属于旧根包 |
| `packages/features/rvc_flutter/lib/src/rvc_page.dart` | RVC 服务连接、模型选择、音色转换、一键翻唱、结果播放 | 转换状态在页面 State 中，退出页面后状态丢失 |

旧包里音乐模块的真实业务边界不是“音乐库页面”，而是：

```text
音乐浏览：音乐库、艺术家、专辑、歌曲、搜索
音乐播放：播放列表、当前歌曲、进度、播放模式、全局迷你播放器、播放详情页
歌词能力：获取歌词、同步滚动、远程歌词搜索/下载
AI 入口：AI 推荐里的音乐卡片、音乐页里的 AI 入口
RVC 能力：音色转换、一键翻唱、结果播放、结果保存、耗时任务状态
```

## 2. 当前新模块拆分评估

### 2.1 已经做得对的地方

`packages/features/jellyfin_music` 已经开始走正确方向：

- `AlbumDetailPage` 和 `ArtistDetailPage` 不再直接依赖旧 `JellyfinClient`。
- 页面通过 `fetchAlbumDetail`、`fetchAlbumSongs`、`fetchArtistDetail`、`fetchArtistAlbums` 注入数据。
- 播放动作通过 `OnPlaySong` 回调抛给 App。
- `AudioPlaybackPort` 抽象了 `just_audio`，feature 包不用直接依赖 `just_audio`。

`Product/jellyfin_app` 也已经做了一部分正确接线：

- `MusicLibraryRoutePage` 作为 App 业务编排页，负责拿 `JellyfinGateway` 和 `AudioPlaybackPort`。
- 点击歌曲后通过 `AudioPlaybackPort.playSong(...)` 设置播放状态，再跳转 `/playback/music`。
- `AudioPlaybackAdapter` 在 App 内实现 `AudioPlaybackPort`，把 `just_audio` 限制在 App 数据/能力适配层。

`jellyfin_ai_recommendation` 的方向也比旧代码更好：

- AI 页面通过 `onNavigateToMediaItem`、`onNavigateToAlbum`、`onNavigateToArtist`、`onPlaySong` 回调交给 App 跳转。
- AI 推荐模块不应该直接 import 音乐详情页或播放页，这一点已经走对。

### 2.2 当前拆解存在的问题

#### 问题 1：`jellyfin_music` 仍然只是“半个音乐模块”

当前 `jellyfin_music` 只有：

```text
models/music_models.dart
services/audio_playback_port.dart
pages/album_detail_page.dart
pages/artist_detail_page.dart
```

缺失：

```text
MusicLibraryPage
MusicSearchPage
LyricsPage / LyricsPanel
MusicPlayerPage
MiniPlayerBar
RVC 入口协议
音乐列表公共组件
```

所以现在不能说音乐模块已经拆完，只能说“详情页和播放端口已拆出”。

#### 问题 2：新 App 的 `MusicLibraryRoutePage` 承担了太多 UI

`Product/jellyfin_app/lib/src/features/music/music_route_pages.dart` 现在包含：

- 音乐库 Tab 页面
- 专辑列表 UI
- 艺术家列表 UI
- 歌曲列表 UI
- 专辑详情 route 包装
- 艺术家详情 route 包装
- 歌曲到 `AudioTrack` 的转换

作为 App 业务编排层，它可以负责路由和注入 gateway，但不应该长期承载大量音乐 UI。否则音乐业务会继续长在 `jellyfin_app` 里。

推荐调整为：

```text
Product/jellyfin_app/lib/src/features/music/music_route_pages.dart
  只负责：
  - 从 route 参数拿 libraryId / albumId / artistId
  - 注入 JellyfinGateway
  - 注入 AudioPlaybackPort
  - 处理 context.push(...)

packages/features/jellyfin_music/lib/src/pages/*
  负责：
  - 音乐库 UI
  - 搜索 UI
  - 专辑详情 UI
  - 艺术家详情 UI
  - 歌词 UI
  - 迷你播放器 UI
  - 播放详情 UI
```

#### 问题 3：音乐模型携带 `serverUrl/accessToken`，边界不够干净

当前 `packages/features/jellyfin_music/lib/src/models/music_models.dart` 中的 `MusicSong`、`MusicAlbum`、`MusicArtist` 都携带 `serverUrl`，部分携带 `accessToken`，并且模型内部拼接图片 URL 和音频流 URL。

这在过渡阶段可以接受，但长期会带来几个问题：

- feature 模型知道 Jellyfin URL 规则。
- token 被塞进 UI 模型，测试和安全边界都不清晰。
- 如果后续图片加载、鉴权头、缓存策略变化，要改模型和 UI。
- 如果改成代理流、离线缓存、本地播放，模型里的 `getStreamUrl()` 会成为障碍。

更好的方向是：

```text
MusicSong / MusicAlbum / MusicArtist
  只描述业务数据。

JellyfinGateway / ImageProvider / AudioTrackFactory
  负责把业务数据转成：
  - 图片 URL 或 ImageProvider
  - AudioTrack.streamUrl
  - 带 token 的请求
```

短期可以保留现状，但后续应该逐步把 URL 拼接从模型里移走。

#### 问题 4：全局迷你播放器还不是全局

旧版 `MiniPlayerCard` 只挂在 `MusicLibraryPage` 的底部。用户离开音乐库去电影详情、AI 推荐、媒体库页时，迷你播放器并不天然存在。

正确位置应该是 App Shell：

```text
MaterialApp.router
  -> AppShell / ShellRoute
     -> 当前 route child
     -> 底部 MiniPlayerBar
```

它监听同一个 `AudioPlaybackPort`。只要有播放列表，所有页面底部都能看到迷你播放器。点击迷你播放器统一跳转 `/playback/music`。

#### 问题 5：RVC 一键翻唱状态绑定页面生命周期

当前 `RvcPage` 中这些状态都在页面 State 里：

```dart
bool _isConverting = false;
dynamic _convertResult;
String? _convertError;
String _convertMode = 'convert';
```

转换方法也在页面里：

```dart
Future<void> _doConvert() async {
  setState(() {
    _isConverting = true;
    _convertResult = null;
    _convertError = null;
  });

  final result = await _client.cover(...);

  if (!mounted) return;
  setState(() {
    _convertResult = result;
    _isConverting = false;
  });
}
```

这意味着：

- 用户退出 RVC 页面后，`mounted == false`，结果不会再写回 UI。
- `dispose()` 会关闭 `_client` 和 `_audioPlayer`。
- 下次进入 RVC 页面会重新创建 `_RvcPageState`，之前任务状态丢失。
- 如果一键翻唱耗时几十秒到几分钟，用户只能停留在页面等待。

这正是用户反馈的核心问题。

## 3. 推荐拆分方案

如果项目坚持 4 层架构，音乐模块建议这样归类：

```text
┌─────────────────────────────────────────────┐
│ 产品表现层 Product/App                       │
│ Product/jellyfin_app                         │
│ AppShell、go_router、全局 MiniPlayer 挂载、任务中心实例 │
├─────────────────────────────────────────────┤
│ 业务编排层 Business                           │
│ Product/jellyfin_app/lib/src/features/music  │
│ route page、gateway 注入、跨业务跳转、AI/RVC 入口组装 │
├─────────────────────────────────────────────┤
│ 通用能力层 Capability                         │
│ jellyfin_music、rvc_flutter、jellyfin_ai_recommendation │
│ 音乐 UI、播放端口、RVC UI/任务控制器、AI 推荐 UI │
├─────────────────────────────────────────────┤
│ 基础设施层 Infrastructure                     │
│ jellyfin_api、rvc_sdk、rainfall_tts_sdk、just_audio、缓存 │
│ API、SDK、播放器插件、文件系统、网络请求          │
└─────────────────────────────────────────────┘
```

### 3.1 `Product/jellyfin_app` 应该保留什么

保留：

```text
Product/jellyfin_app/lib/src/app/app_router.dart
Product/jellyfin_app/lib/src/app/app_shell.dart
Product/jellyfin_app/lib/src/features/music/music_route_pages.dart
Product/jellyfin_app/lib/src/data/audio_playback_adapter.dart
Product/jellyfin_app/lib/src/data/rvc_task_center.dart
Product/jellyfin_app/lib/src/data/legacy_jellyfin_gateway.dart
```

职责：

- 管理路由表。
- 管理登录态、serverUrl、token。
- 创建全局 `AudioPlaybackPort`。
- 创建全局 `RvcTaskCenter`。
- 决定 AI 推荐卡片点击后跳到哪里。
- 决定 RVC 入口显示在哪里。
- 决定迷你播放器显示在全局哪些页面。

不应该做：

- 不要在 App 层长期维护大段音乐列表 UI。
- 不要在 App 层直接写专辑卡片、艺术家卡片、歌词滚动细节。
- 不要让 RVC 任务状态只存在 route page 或 widget state 里。

### 3.2 `jellyfin_music` 应该包含什么

建议把 `jellyfin_music` 扩展成完整音乐能力包：

```text
packages/features/jellyfin_music/lib/
  jellyfin_music.dart
  jellyfin_music_pages.dart

  src/models/
    music_models.dart
    lyrics_models.dart

  src/ports/
    music_repository_port.dart
    audio_playback_port.dart
    lyrics_port.dart

  src/pages/
    music_library_page.dart
    music_search_page.dart
    album_detail_page.dart
    artist_detail_page.dart
    music_player_page.dart
    lyrics_page.dart

  src/widgets/
    music_album_card.dart
    music_artist_card.dart
    music_song_tile.dart
    mini_player_bar.dart
    lyrics_panel.dart
```

其中：

| 模块 | 是否放入 `jellyfin_music` | 原因 |
| --- | --- | --- |
| 音乐库三 Tab UI | 是 | 属于音乐领域 UI，不能长期留在 App route page |
| 音乐搜索页 | 是 | 搜索艺术家/专辑/歌曲，是音乐业务的一部分 |
| 专辑详情页 | 已经是 | 当前方向正确 |
| 艺术家详情页 | 已经是 | 当前方向正确 |
| 歌词页/歌词面板 | 是 | 依赖播放进度，但仍是音乐能力 |
| 音乐播放详情页 | 建议是 | 只要依赖 `AudioPlaybackPort`，就可以从 App 移入 feature |
| 迷你播放器 UI | 是 | UI 可复用，但挂载位置由 App Shell 决定 |
| `just_audio` 具体实现 | 否 | 仍然留在 App 或基础能力适配层 |
| go_router | 否 | feature 不直接依赖 go_router |
| JellyfinClient | 否 | 通过 fetcher/repository port 注入 |

### 3.3 `rvc_flutter` 应该怎么改

`rvc_flutter` 不应该只是一个 `RvcPage`。它需要拆成：

```text
packages/features/rvc_flutter/lib/
  rvc_flutter.dart

  src/models/
    rvc_task.dart
    rvc_params.dart

  src/controllers/
    rvc_task_controller.dart

  src/pages/
    rvc_page.dart

  src/widgets/
    rvc_task_status_card.dart
    rvc_result_card.dart
```

核心原则：

```text
RvcPage 不持有任务生命周期。
RvcPage 只展示和操作 RvcTaskController。
RvcTaskController 由 Product/jellyfin_app 创建并长期持有。
```

这样用户退出页面后，任务还在 App 级 controller 里继续跑。下次进入 RVC 页面，页面重新绑定 controller，就能看到上次任务状态。

## 4. RVC 耗时任务的正确设计

### 4.1 最小可落地方案：App 内存级任务中心

这是最快能解决“退出页面后状态丢失”的方案。

适用范围：

- 用户只是退出 RVC 页面，但 App 没有被杀。
- HTTP 请求仍在 App 进程里继续执行。
- 下次进入页面可以看到正在转换、成功、失败状态。

设计：

```dart
enum RvcTaskStatus {
  idle,
  running,
  succeeded,
  failed,
  cancelled,
}

class RvcTaskSnapshot {
  final String id;
  final RvcTaskStatus status;
  final String mode; // convert / cover
  final String? sourceName;
  final String? modelName;
  final double? progress;
  final Object? result;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const RvcTaskSnapshot({
    required this.id,
    required this.status,
    required this.mode,
    this.sourceName,
    this.modelName,
    this.progress,
    this.result,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });
}
```

Controller：

```dart
class RvcTaskController extends ChangeNotifier {
  RvcTaskController({required RVCClient client}) : _client = client;

  final RVCClient _client;
  RvcTaskSnapshot? _currentTask;

  RvcTaskSnapshot? get currentTask => _currentTask;
  bool get hasRunningTask => _currentTask?.status == RvcTaskStatus.running;

  Future<void> startCover(RvcCoverRequest request) async {
    final taskId = DateTime.now().microsecondsSinceEpoch.toString();
    _currentTask = RvcTaskSnapshot(
      id: taskId,
      status: RvcTaskStatus.running,
      mode: 'cover',
      sourceName: request.audioFilename,
      modelName: request.modelName,
      createdAt: DateTime.now(),
    );
    notifyListeners();

    try {
      final result = await _client.cover(
        modelName: request.modelName,
        inputPath: request.inputPath,
        audioBytes: request.audioBytes,
        audioFilename: request.audioFilename,
        f0UpKey: request.f0UpKey,
        f0Method: request.f0Method,
        indexRate: request.indexRate,
        filterRadius: request.filterRadius,
        resampleSr: request.resampleSr,
        protect: request.protect,
        vocalVol: request.vocalVol,
        instVol: request.instVol,
      );

      if (_currentTask?.id != taskId) return;
      _currentTask = _currentTask!.copyWith(
        status: RvcTaskStatus.succeeded,
        result: result,
        completedAt: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      if (_currentTask?.id != taskId) return;
      _currentTask = _currentTask!.copyWith(
        status: RvcTaskStatus.failed,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }
}
```

页面使用方式：

```dart
class RvcPage extends StatelessWidget {
  final RvcTaskController controller;

  const RvcPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final task = controller.currentTask;
        return RvcTaskView(
          task: task,
          onStartCover: controller.startCover,
        );
      },
    );
  }
}
```

App 持有：

```dart
class _JellyfinAppState extends State<JellyfinApp> {
  late final RvcTaskController _rvcTaskController;

  @override
  void initState() {
    super.initState();
    _rvcTaskController = RvcTaskController(
      client: RVCClient(baseUrl: resolvedRvcServerUrl),
    );
  }

  @override
  void dispose() {
    _rvcTaskController.dispose();
    super.dispose();
  }
}
```

这样改完后：

```text
用户进入 RVC 页面
  -> 点击一键翻唱
  -> controller.startCover()
  -> 用户退出页面
  -> controller 仍在 App 内存中
  -> HTTP Future 完成后写入 controller
  -> 用户再次进入 RVC 页面
  -> 页面读取 controller.currentTask
  -> 展示上次任务结果
```

### 4.2 中期方案：任务快照持久化

内存级任务中心只能解决“页面退出”，不能解决“App 被系统杀掉”。

中期可以把任务快照存到本地：

```text
SharedPreferences / 本地 JSON
  rvc_last_task:
    id
    mode
    sourceName
    modelName
    status
    playUrl
    downloadUrl
    filename
    createdAt
    completedAt
```

恢复逻辑：

```text
App 启动
  -> RvcTaskController.restore()
  -> 如果 last_task 是 succeeded
       展示上次结果
  -> 如果 last_task 是 running
       标记为 unknown/interrupted
       提示用户“上次任务可能仍在服务端执行，请检查历史结果”
```

注意：如果当前 RVC 服务只有同步 `/cover` 接口，没有服务端 jobId，那么 App 被杀后无法继续追踪正在执行的同步 HTTP 请求。

### 4.3 长期方案：RVC 服务端任务队列

如果一键翻唱经常需要几十秒到几分钟，最好让 RVC 服务端提供异步任务 API：

```text
POST /cover/jobs
  -> 返回 jobId

GET /cover/jobs/{jobId}
  -> 返回 queued/running/succeeded/failed/progress

GET /cover/jobs/{jobId}/result
  -> 返回 playUrl/downloadUrl

GET /cover/jobs/{jobId}/events
  -> SSE 推送进度
```

客户端只保存 `jobId`。页面退出、App 重启都可以恢复。

这是最终最稳的方案，但需要改 RVC 服务端。

推荐执行顺序：

```text
第一步：先做 App 内存级 RvcTaskController。
第二步：保存成功结果和最近任务快照。
第三步：如果体验仍不够，再推动 RVC 服务端 job API。
```

## 5. 全局底部悬浮迷你播放器设计

迷你播放器应该由 `jellyfin_app` 的 App Shell 挂载，而不是音乐库页自己挂。

推荐结构：

```text
Product/jellyfin_app/lib/src/app/jellyfin_app_shell.dart
  -> Stack
     -> Positioned.fill(child: routeChild)
     -> Positioned(bottom: 0, child: MiniPlayerBar)
```

或者使用 `go_router` 的 `ShellRoute`：

```dart
ShellRoute(
  builder: (context, state, child) {
    return AppScaffold(
      audioPlaybackPort: audioPlaybackPort,
      child: child,
    );
  },
  routes: [
    // libraries
    // music
    // media detail
    // ai recommend
    // playback
  ],
)
```

AppScaffold：

```dart
class AppScaffold extends StatelessWidget {
  final Widget child;
  final AudioPlaybackPort audioPlaybackPort;

  const AppScaffold({
    super.key,
    required this.child,
    required this.audioPlaybackPort,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            bottom: audioPlaybackPort.hasPlaylist ? 72 : 0,
          ),
          child: child,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: MiniPlayerBar(
            playbackPort: audioPlaybackPort,
            onOpenPlayer: () => context.push('/playback/music'),
          ),
        ),
      ],
    );
  }
}
```

`MiniPlayerBar` 放在 `jellyfin_music`：

```dart
class MiniPlayerBar extends StatelessWidget {
  final AudioPlaybackPort playbackPort;
  final VoidCallback onOpenPlayer;

  const MiniPlayerBar({
    super.key,
    required this.playbackPort,
    required this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playbackPort,
      builder: (context, _) {
        final track = playbackPort.currentTrack;
        if (track == null) return const SizedBox.shrink();

        return InkWell(
          onTap: onOpenPlayer,
          child: Row(
            children: [
              // cover
              // title
              // play/pause
              // next
            ],
          ),
        );
      },
    );
  }
}
```

这样它就是真正的全局播放器卡片。

## 6. AI 推荐与音乐模块的关系

AI 推荐不应该放进音乐模块，也不应该让音乐模块依赖 AI。

正确关系：

```text
jellyfin_ai_recommendation
  -> 展示 AI 对话和推荐卡片
  -> 通过回调告诉 App：用户点了 audio/album/artist/movie/series

jellyfin_app
  -> 决定跳转到音乐播放、专辑详情、艺术家详情、电影详情

jellyfin_music
  -> 提供音乐页面和音乐播放 UI
```

AI 推荐点击音乐卡片的理想流程：

```text
AiRecommendPage
  -> onPlaySong(context, item)

jellyfin_app
  -> gateway.getMediaItemDetail(item.id)
  -> 转成 AudioTrack
  -> audioPlaybackPort.playSong(...)
  -> context.push('/playback/music')
```

AI 推荐点击专辑：

```text
AiRecommendPage
  -> onNavigateToAlbum(context, item)

jellyfin_app
  -> context.push('/music/albums/${item.id}')
```

AI 推荐点击艺术家：

```text
AiRecommendPage
  -> onNavigateToArtist(context, item)

jellyfin_app
  -> context.push('/music/artists/${item.id}')
```

注意：AI 推荐里有 TTS 播报，音乐播放也有 `just_audio`。后续要考虑音频焦点：

- AI TTS 开始播放时，是否暂停当前音乐。
- 音乐恢复播放时，是否停止 TTS。
- RVC 结果试听时，是否暂停当前音乐。

这可以放到后续的 `AudioFocusCoordinator` 里做。

## 7. 推荐的最终包结构

在坚持 4 层架构的前提下，推荐目标结构：

```text
Product/jellyfin_app/
  lib/src/app/
    jellyfin_app.dart
    app_router.dart
    app_shell.dart

  lib/src/features/music/
    music_route_pages.dart
    music_navigation.dart

  lib/src/data/
    legacy_jellyfin_gateway.dart
    audio_playback_adapter.dart
    rvc_task_center.dart

packages/features/jellyfin_music/
  lib/src/models/
    music_models.dart
    lyrics_models.dart

  lib/src/ports/
    music_repository_port.dart
    audio_playback_port.dart
    lyrics_port.dart

  lib/src/pages/
    music_library_page.dart
    music_search_page.dart
    album_detail_page.dart
    artist_detail_page.dart
    music_player_page.dart
    lyrics_page.dart

  lib/src/widgets/
    mini_player_bar.dart
    music_album_card.dart
    music_artist_card.dart
    music_song_tile.dart
    lyrics_panel.dart

packages/features/rvc_flutter/
  lib/src/models/
    rvc_task.dart
    rvc_params.dart

  lib/src/controllers/
    rvc_task_controller.dart

  lib/src/pages/
    rvc_page.dart

  lib/src/widgets/
    rvc_task_status_card.dart
    rvc_result_card.dart

packages/features/jellyfin_ai_recommendation/
  继续保持回调式导航，不直接依赖音乐页面

packages/foundation/
  jellyfin_api/
  jellyfin_core/

packages/vendor/
  rvc_sdk/
  rainfall_tts_sdk/
```

## 8. 给开发人员的下一阶段任务建议

### P0：先修正音乐模块边界

1. 不要继续往 `Product/jellyfin_app/lib/src/features/music/music_route_pages.dart` 堆 UI。
2. 把音乐库三 Tab UI 提取到 `packages/features/jellyfin_music/lib/src/pages/music_library_page.dart`。
3. App route page 只负责注入：

```dart
MusicLibraryPage(
  library: library,
  fetchAlbums: gateway.fetchAlbums,
  fetchArtists: gateway.fetchArtists,
  fetchSongs: gateway.fetchSongs,
  onOpenAlbum: (context, album) => context.push('/music/albums/${album.id}'),
  onOpenArtist: (context, artist) => context.push('/music/artists/${artist.id}'),
  onPlaySong: (...args) { ... },
)
```

### P1：把迷你播放器变成 App 全局能力

1. 在 `jellyfin_music` 新增 `MiniPlayerBar`。
2. 在 `jellyfin_app` 新增 App Shell 或 `ShellRoute`。
3. 所有主业务页面底部统一显示迷你播放器。
4. 播放详情页 `/playback/music` 可以选择隐藏迷你播放器，避免重复。

### P2：RVC 先做内存级任务中心

1. 在 `rvc_flutter` 新增 `RvcTaskController` 和 `RvcTaskSnapshot`。
2. `RvcPage` 改成接收 controller。
3. `Product/jellyfin_app` 创建并持有 controller。
4. 用户退出 RVC 页面后，controller 不销毁。
5. 下次进入 RVC 页面，从 controller 恢复上次任务状态。

### P3：补齐音乐搜索和歌词

1. 把旧 `MusicSearchPage` 提取到 `jellyfin_music`。
2. 把旧 `LyricsPage` 拆成：

```text
LyricsPanel：播放器页内部右侧/底部歌词面板
LyricsPage：完整歌词页
LyricsPort：获取歌词、搜索远程歌词、下载远程歌词
```

3. `LyricsPanel` 只依赖 `AudioPlaybackPort.onPositionChanged`，不要直接依赖旧 `AudioPlaybackManager`。

### P4：清理模型里的 URL 拼接

短期保留 `serverUrl/accessToken` 可以降低改造成本，但后续建议逐步改成：

```text
MusicSong
  只保留 id/name/albumId/artists/duration/path 等业务字段

AudioTrack
  由 App/Gateway 组装 streamUrl

ImageProvider
  由 App/Gateway 注入
```

这样音乐 feature 就不会知道 token 和 Jellyfin URL 规则。

## 9. 判断标准

后续验收音乐模块拆分时，可以用这几个标准：

1. `jellyfin_music` 不 import `go_router`。
2. `jellyfin_music` 不 import 旧根包 `jellyfin_service`。
3. `jellyfin_music` 不直接 new `JellyfinClient`。
4. `jellyfin_music` 不直接依赖 `just_audio`。
5. `Product/jellyfin_app` 负责路由、session、gateway、全局播放器实例、RVC 任务中心。
6. `RvcPage` 退出后，一键翻唱任务状态不会丢。
7. 任意主业务页面都能看到全局迷你播放器，而不只是音乐库页面。
8. AI 推荐模块只通过回调跳转音乐相关页面，不直接 import 音乐页面。

## 10. 最终建议

当前音乐模块不要继续按“页面文件搬家”的方式拆。音乐模块应该按状态生命周期来拆：

```text
短生命周期：页面 UI、筛选条件、Tab 状态
  -> 放在 jellyfin_music 页面里

中生命周期：播放列表、当前歌曲、播放进度
  -> 放在 App 级 AudioPlaybackPort 实例里

长生命周期：RVC 一键翻唱任务、转换结果
  -> 放在 App 级 RvcTaskController / 任务中心里

跨业务跳转：AI 推荐、专辑详情、艺术家详情、播放页
  -> 放在 jellyfin_app 路由编排里
```

这套拆法能同时解决三个问题：

- 音乐 UI 不会继续污染 `jellyfin_app`。
- 播放器和迷你播放器可以真正全局复用。
- RVC 一键翻唱不会因为用户退出页面而丢失任务状态。
