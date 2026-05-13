# WORK_PROGRESS.md 进度评估报告

评估日期：2026-05-13

评估对象：

- `WORK_PROGRESS.md`
- `Product/jellyfin_app/lib/src/app/app_router.dart`
- `Product/jellyfin_app/lib/src/app/app_shell.dart`
- `Product/jellyfin_app/lib/src/features/music/music_route_pages.dart`
- `packages/features/jellyfin_music/lib/src/pages/music_library_page.dart`
- `packages/features/jellyfin_music/lib/src/pages/music_player_page.dart`
- `packages/features/jellyfin_music/lib/src/widgets/mini_player_bar.dart`

## 1. 总体结论

当前员工完成的工作整体质量不差，`P0 音乐模块边界修正` 方向基本正确，但 `P1 迷你播放器` 的产品边界出现偏差。

最主要的问题是：

```text
员工按“全局迷你播放器 / App Shell”实现了。
但当前产品决策是：迷你播放器只放在音乐模块范围内，不做全 App 全局悬浮。
```

因此现在不是“代码跑不起来”的问题，而是“实现方向和最新产品架构决策不一致”的问题。

已验证：

- `Product/jellyfin_app` 测试通过：15 个测试全部通过。
- `packages/features/jellyfin_music` 测试通过：26 个测试全部通过。

## 2. 做得正确的部分

### 2.1 P0 音乐模块边界修正方向正确

`WORK_PROGRESS.md` 中 P0 的目标是把音乐 UI 从 App 编排层迁移到 `jellyfin_music` 包，这个方向是正确的。

当前已经看到这些调整：

```text
packages/features/jellyfin_music/lib/src/pages/music_library_page.dart
packages/features/jellyfin_music/lib/src/pages/music_player_page.dart
packages/features/jellyfin_music/lib/src/widgets/mini_player_bar.dart
```

这说明员工已经开始把音乐库页面、音乐播放页、迷你播放器 UI 放回音乐模块。

这个方向符合当前架构原则：

```text
Product/jellyfin_app
  负责路由、session、gateway、播放适配器实例。

packages/features/jellyfin_music
  负责音乐 UI、音乐页面、音乐播放 UI、迷你播放器 UI。
```

### 2.2 `AudioPlaybackPort` 的抽象方向正确

当前 `jellyfin_music` 定义 `AudioPlaybackPort`，`Product/jellyfin_app` 通过 `AudioPlaybackAdapter` 实现它。

这个设计是正确的：

```text
jellyfin_music
  -> 只知道 AudioPlaybackPort
  -> 不直接依赖 just_audio

jellyfin_app
  -> 创建 AudioPlaybackAdapter
  -> 内部使用 just_audio
  -> 控制播放器生命周期
```

这可以保证：

- 音乐 feature 不绑定具体播放器插件。
- 后续适配鸿蒙、替换播放器、增加后台播放能力时，不需要大面积改音乐 UI。
- 播放器状态可以比页面活得更久，退出音乐播放详情页后音乐仍可继续播放。

### 2.3 `music_route_pages.dart` 精简为注入层是对的

当前 `Product/jellyfin_app/lib/src/features/music/music_route_pages.dart` 的职责已经更接近 App 业务编排层：

```text
拿 route 参数
注入 JellyfinGateway
注入 AudioPlaybackPort
处理 context.push(...)
组装 jellyfin_music 页面
```

这比之前把大量音乐 UI 写在 App 层更合理。

## 3. 明确偏差：P1 做成了全局迷你播放器

### 3.1 文档记录的偏差

`WORK_PROGRESS.md` 中 P1 写的是：

```text
P1：全局迷你播放器（App Shell）
目标：任意主业务页面底部统一显示迷你播放器，播放详情页隐藏。
```

并且它设计了：

```text
ShellRoute
  /libraries
  /libraries/:libraryId/movies
  /libraries/:libraryId/series
  /libraries/:libraryId/music
  /music/albums/:albumId
  /music/artists/:artistId
  /movies/:itemId
  /media/items/:itemId
  /series/:seriesId/seasons
  /series/:seriesId/seasons/:seasonId/episodes
  /playback/video/:itemId
  /playback/music
```

这表示迷你播放器会出现在电影、剧集、媒体详情、视频播放等非音乐业务页面。

这与当前决策冲突。

### 3.2 代码实现的偏差

`Product/jellyfin_app/lib/src/app/app_router.dart` 当前使用了 `ShellRoute` 包住主业务路由。

这会导致：

```text
/libraries
/libraries/:libraryId/movies
/libraries/:libraryId/series
/movies/:itemId
/media/items/:itemId
/playback/video/:itemId
```

这些页面也被 `AppShell` 包裹，从而拥有底部迷你播放器。

`Product/jellyfin_app/lib/src/app/app_shell.dart` 当前职责是：

```text
Stack
  -> child
  -> bottom MiniPlayerBar
```

这个实现本身没有技术问题，但它把迷你播放器提升到了 App 全局层。

### 3.3 最新产品边界应该是

当前产品决策应该改为：

```text
AI 推荐入口：
  不放音乐页面。
  不属于音乐模块。
  由首页、媒体库首页或独立 AI 推荐入口承载。

迷你播放器：
  放在音乐模块下面。
  只在音乐相关页面显示。
  不做全 App 全局悬浮。

播放状态：
  仍然可以由 App 级 AudioPlaybackAdapter 持有。
  用户离开音乐模块后，音乐可以继续播放。
  但非音乐页面不显示迷你播放器。
```

也就是说：

```text
要收窄的是 MiniPlayerBar 的显示范围。
不要把 AudioPlaybackAdapter 的生命周期也收窄到页面级。
```

## 4. 应该如何修正 P1

### 4.1 不建议继续保留全局 AppShell 方案

如果保持当前全局 AppShell，后续会有几个问题：

1. 电影详情页底部出现音乐迷你播放器，产品表达会混乱。
2. 视频播放页和音乐迷你播放器同时存在，容易冲突。
3. AI 推荐、媒体详情、剧集页被迫感知音乐播放状态。
4. App Shell 会越来越重，后续如果再加下载浮层、RVC 任务浮层、投屏状态，容易变成全局 UI 杂货层。

所以建议员工停止沿着“全局迷你播放器”继续扩展。

### 4.2 推荐改成音乐路由范围内挂载

迷你播放器应该只覆盖音乐业务范围：

```text
/libraries/:libraryId/music
/music/albums/:albumId
/music/artists/:artistId
/music/search       后续增加
```

播放详情页不显示迷你播放器：

```text
/playback/music
  -> 不显示 MiniPlayerBar
```

非音乐页面不显示迷你播放器：

```text
/libraries
/libraries/:libraryId/movies
/libraries/:libraryId/series
/movies/:itemId
/media/items/:itemId
/series/:seriesId/seasons
/series/:seriesId/seasons/:seasonId/episodes
/playback/video/:itemId
```

### 4.3 推荐实现方式 A：只在音乐 RoutePage 里包一层

这是最小改动方案。

新增一个音乐范围壳：

```dart
class MusicAreaShell extends StatelessWidget {
  final Widget child;
  final music.AudioPlaybackPort audioPlaybackPort;
  final VoidCallback onOpenMusicPlayer;
  final bool showMiniPlayer;

  const MusicAreaShell({
    super.key,
    required this.child,
    required this.audioPlaybackPort,
    required this.onOpenMusicPlayer,
    this.showMiniPlayer = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        if (showMiniPlayer)
          MiniPlayerBar(
            playbackPort: audioPlaybackPort,
            onOpenPlayer: onOpenMusicPlayer,
          ),
      ],
    );
  }
}
```

然后只在音乐 route page 中使用：

```dart
return MusicAreaShell(
  audioPlaybackPort: audioPlaybackPort!,
  onOpenMusicPlayer: () => context.push('/playback/music'),
  child: MusicLibraryPage(...),
);
```

专辑详情：

```dart
return MusicAreaShell(
  audioPlaybackPort: audioPlaybackPort!,
  onOpenMusicPlayer: () => context.push('/playback/music'),
  child: AlbumDetailPage(...),
);
```

艺术家详情：

```dart
return MusicAreaShell(
  audioPlaybackPort: audioPlaybackPort!,
  onOpenMusicPlayer: () => context.push('/playback/music'),
  child: ArtistDetailPage(...),
);
```

优点：

- 改动小。
- 不需要大改全局路由结构。
- 非音乐页面天然不会显示迷你播放器。
- 符合当前产品边界。

缺点：

- 每个音乐 route page 都要包一层。
- 如果音乐路由变多，可能重复。

### 4.4 推荐实现方式 B：音乐专属 ShellRoute

如果想结构更清晰，可以在 `go_router` 中只给音乐路由组包 `ShellRoute`：

```dart
ShellRoute(
  builder: (context, state, child) {
    final port = effectiveAudioPort;
    if (port == null) return child;

    final hideMiniPlayer = state.matchedLocation == '/playback/music';

    return MusicAreaShell(
      audioPlaybackPort: port,
      onOpenMusicPlayer: () => context.push('/playback/music'),
      showMiniPlayer: !hideMiniPlayer,
      child: child,
    );
  },
  routes: [
    GoRoute(path: '/libraries/:libraryId/music', ...),
    GoRoute(path: '/music/albums/:albumId', ...),
    GoRoute(path: '/music/artists/:artistId', ...),
  ],
)
```

注意：`/playback/music` 是否放进这个音乐 ShellRoute 要看产品表现。

推荐：

```text
/playback/music 不放进 MusicAreaShell
```

因为它本身就是完整播放器页面，不需要底部迷你播放器。

优点：

- 音乐路由组边界清楚。
- 不污染电影、剧集、视频播放页面。
- 后续加 `/music/search` 很自然。

缺点：

- 路由结构需要重新整理。
- 现有 `app_router_test.dart` 中关于 ShellRoute 的测试需要调整。

### 4.5 选择建议

建议先走方式 A，最小修正。

理由：

- 当前最重要的是纠偏，不是重构路由系统。
- 现有代码已经能跑，应该减少不必要改动。
- 员工可以快速完成，降低返工成本。

后续音乐路由多起来后，再考虑方式 B。

## 5. 对 `WORK_PROGRESS.md` 的评价

### 5.1 记录完整，但需要单独修正方向

`WORK_PROGRESS.md` 记录得比较完整，能看出员工做了哪些阶段：

- A：App 骨架
- B：登录注册
- C：媒体库首页
- D：电影与媒体详情
- E：视频播放
- G：音乐业务模块
- P0：音乐模块边界修正
- P1：全局迷你播放器

但是从当前最新产品决策看，P1 需要改名和改目标。

建议员工后续新建一个进度修正文档，而不是直接覆盖原记录：

```text
P1_FIX_MUSIC_SCOPED_MINI_PLAYER.md
```

或者在下一版进度文档中明确：

```text
P1 原设计：全局 App Shell 迷你播放器
P1 修正后：音乐模块范围内迷你播放器
```

### 5.2 P0 可以保留为已完成

P0 的方向基本正确，不需要推倒。

保留：

- `MusicLibraryPage` 进入 `jellyfin_music`
- `MusicPlayerPage` 进入 `jellyfin_music`
- `MiniPlayerBar` 进入 `jellyfin_music`
- `AudioPlaybackPort` 保留在 `jellyfin_music`
- `AudioPlaybackAdapter` 保留在 `Product/jellyfin_app`

### 5.3 P1 不能标记为最终完成

P1 当前虽然测试通过，但不符合最新产品边界。

建议状态改为：

```text
P1：需调整
原因：当前实现为全局迷你播放器，需改成音乐模块范围内显示。
```

## 6. 下一步给员工的执行建议

### Step 1：停止扩展全局 AppShell

不要继续基于 `Product/jellyfin_app/lib/src/app/app_shell.dart` 增加更多全局 UI。

当前全局 AppShell 可以先保留代码，但不要继续依赖它扩展业务。

### Step 2：把迷你播放器显示范围收窄到音乐模块

员工需要调整：

```text
Product/jellyfin_app/lib/src/app/app_router.dart
Product/jellyfin_app/lib/src/app/app_shell.dart
Product/jellyfin_app/lib/src/features/music/music_route_pages.dart
Product/jellyfin_app/test/app_router_test.dart
```

目标：

```text
非音乐页面不出现 MiniPlayerBar。
音乐库、专辑详情、艺术家详情下面出现 MiniPlayerBar。
音乐播放详情页不出现 MiniPlayerBar。
```

### Step 3：保留 App 级播放状态

不要把 `AudioPlaybackAdapter` 改成页面级。

正确做法仍然是：

```text
JellyfinApp
  -> 创建 AudioPlaybackAdapter.instance
  -> 传给 createAppRouter
  -> 音乐 route page 注入给 jellyfin_music 页面
```

这样可以保证用户离开音乐模块后音乐仍可继续播放，只是不显示迷你播放器。

### Step 4：之后再做 RVC 任务中心

P1 修正后，再进入 P2。

P2 的重点不是 UI，而是任务生命周期：

```text
RvcPage 退出后，一键翻唱任务不能丢。
```

推荐方向：

```text
Product/jellyfin_app
  -> 持有 RvcTaskController / RvcTaskCenter

rvc_flutter
  -> RvcPage 只展示 controller 状态
  -> 不把 _isConverting / _convertResult 只放在页面 State 里
```

## 7. 是否存在 AI 推荐入口偏差

从当前 `WORK_PROGRESS.md` 看，没有看到员工把 AI 推荐入口继续塞到音乐页面。

但需要明确告诉员工：

```text
AI 推荐入口不属于音乐模块。
不要在 MusicLibraryPage 的 AppBar 里加 AI 推荐入口。
不要让 jellyfin_music import jellyfin_ai_recommendation。
```

AI 推荐与音乐的关系只保留为：

```text
AI 推荐卡片点击 audio / album / artist
  -> 回调给 jellyfin_app
  -> jellyfin_app 决定跳转音乐播放、专辑详情、艺术家详情
```

## 8. 验收标准

员工修正后，按下面标准验收：

1. `/libraries` 不显示迷你播放器。
2. `/libraries/:libraryId/movies` 不显示迷你播放器。
3. `/libraries/:libraryId/series` 不显示迷你播放器。
4. `/movies/:itemId` 不显示迷你播放器。
5. `/media/items/:itemId` 不显示迷你播放器。
6. `/playback/video/:itemId` 不显示迷你播放器。
7. `/libraries/:libraryId/music` 显示迷你播放器。
8. `/music/albums/:albumId` 显示迷你播放器。
9. `/music/artists/:artistId` 显示迷你播放器。
10. `/playback/music` 不显示迷你播放器。
11. 离开音乐模块后音乐仍可以继续播放。
12. `jellyfin_music` 不 import `go_router`。
13. `jellyfin_music` 不 import `jellyfin_ai_recommendation`。
14. `jellyfin_music` 不直接依赖 `just_audio`。
15. `Product/jellyfin_app` 测试通过。
16. `packages/features/jellyfin_music` 测试通过。

## 9. 最终判断

当前进度可以这样评价：

```text
P0：通过，方向正确。
P1：代码可运行，测试通过，但产品边界错误，需要调整。
P2：还未开始，下一步应在 P1 修正后再做 RVC 任务中心。
```

建议给员工的结论：

```text
你现在的代码不是质量问题，是方向边界需要修正。
音乐 UI 拆到 jellyfin_music 是对的。
AudioPlaybackPort 抽象也是对的。
但 MiniPlayerBar 不应该挂到全 App Shell。
请把它收敛到音乐模块范围内显示，然后再进入 RVC 任务中心。
```
