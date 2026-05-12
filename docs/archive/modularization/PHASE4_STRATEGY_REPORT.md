# Phase 4 模块化改造评估与下一阶段策略

## 结论

Phase 4 的方向是正确的：`media_libraries_page.dart` 已经从“巨型编排页”收缩为入口页，`FeaturePageFactory`、`AppSession`、`PlaybackDelegateFactory`、`MusicPlaybackAdapter` 等 app shell 对象也把跨模块组装逻辑集中到了根包编排层。这一步对业务模块解耦是有价值的，尤其是电影、剧集、播放页的跳转已经基本改成“feature 页面 + 根包注入回调”的形态。

但当前不能按报告里的“全部完成”来验收。代码里仍有三类关键问题：

1. `dart analyze lib test` 仍有根包错误，和 facade 清理直接相关。
2. `AudioPlaybackPort` 现在更像“参数形状注入”，内部很多地方仍然强依赖 `AudioPlaybackManager.instance`。
3. `AppSessionController` 已创建，但主流程还没有真正接管登录/登出和根页面切换，Shell 还处于半落地状态。

建议把 Phase 4 定义为“App Shell 雏形完成”，不要定义为“App Shell 收敛完成”。下一阶段重点应放在：补齐会话闭环、消除假注入、修复 facade 回归，并把 `FeaturePageFactory` 拆成更细的路由编排单元。

## 我实际验证了什么

已执行：

```powershell
dart scripts/check_module_boundaries.dart
flutter test
flutter test test/app_shell_test.dart test/audio_playback_port_injection_test.dart
dart analyze lib test
```

结果：

- `scripts/check_module_boundaries.dart` 通过，hide 数量为 18，低于阈值 20。
- `flutter test` 全量 44 个测试通过。
- 新增测试 `app_shell_test.dart` 和 `audio_playback_port_injection_test.dart` 通过。
- `dart analyze lib test` 未通过：`lib/src/ui/pages/seasons_page.dart:155` 找不到 `EpisodesPage`。

注意：直接运行 `dart analyze` 会把 `packages/ohos` 里的大量三方/示例问题也扫进来，输出非常多，不适合作为当前阶段主验收命令。当前阶段建议固定使用 `dart analyze lib test packages/features packages/shared packages/foundation` 或先为 ohos 三方目录配置排除策略。

## 已完成得比较好的部分

### 1. `media_libraries_page.dart` 的职责明显变轻

`MediaLibrariesPage` 现在主要做三件事：

- 加载媒体库和继续观看数据。
- 构建入口 UI。
- 调用 `FeaturePageFactory.pageForLibrary()` 进入具体业务模块。

这比之前把电影筛选、播放委托、音乐转换、AI 推荐跳转都堆在同一个 State 里要清晰很多。这个方向应该保留。

### 2. app shell 编排层开始成形

`lib/src/app_shell/` 下的对象已经把“根包模型/服务”和“feature 页面”之间的适配放到统一位置：

- `AppSession` 封装 `JellyfinClient + UserProfile`。
- `MovieFilterAdapter` 处理电影筛选模型转换。
- `PlaybackDelegateFactory` 处理播放模块需要的委托。
- `MusicPlaybackAdapter` 处理根包音乐模型和 feature 音乐模型转换。
- `FeaturePageFactory` 统一创建各业务页面。

这个分层是对的。根包作为 App Shell，feature 包负责业务页面和业务模型，二者之间通过回调、delegate、adapter 衔接。

### 3. 边界检查比 Phase 3 更完整

边界脚本已经增加了：

- feature 包不得 import 根包 `jellyfin_service`。
- feature 包不得 import 其他 feature 的 `src/`。
- 根包不得 import feature 的 `src/`。
- `hide` 数量阈值检查。
- shared/foundation 不得反向依赖 feature。

这能阻止一部分“拆包后又偷偷耦回去”的问题，应该继续保留在阶段验收里。

## 关键问题

### 问题 1：facade 清理导致根包仍有 analyze 错误

位置：

- `lib/src/ui/pages/seasons_page.dart:155`
- `lib/jellyfin_service.dart`

现象：

`lib/src/ui/pages/seasons_page.dart` 仍然通过 `package:jellyfin_service/jellyfin_service.dart` 间接引用 `EpisodesPage`，但 `lib/jellyfin_service.dart` 已移除了相关页面 export，导致：

```text
The method 'EpisodesPage' isn't defined for the type '_SeasonsPageState'
```

这是 Phase 4 facade cleanup 的直接回归。虽然全量测试通过，但 analyze 已经提示根包代码不可通过静态检查。

建议有两个选择，优先选 A：

**A. 删除旧根包页面**

如果 `SeasonsPage` 已经不再被 public barrel 暴露，且实际导航已经全部走 `FeaturePageFactory` + `jellyfin_series`，那就把旧的：

- `lib/src/ui/pages/seasons_page.dart`
- `lib/src/ui/pages/episodes_page.dart`

纳入 legacy 删除清单。不要保留一个既 deprecated 又无法 analyze 的旧页面。

**B. 保留兼容页，但显式接入 feature 页面**

如果短期还需要兼容旧入口，就不要依赖 root barrel，改为显式引入页面子入口，并补齐模型转换：

```dart
import 'package:jellyfin_series/jellyfin_series_pages.dart' as series_pages;
import 'package:jellyfin_service/src/adapters/media_item_mapper.dart';

// ...
builder: (context) => series_pages.EpisodesPage(
  series: MediaItemMapper.toShared(
    widget.series,
    serverUrl: widget.client.configuration.serverUrl,
    accessToken: widget.client.configuration.accessToken,
  ),
  season: MediaItemMapper.toSharedSeason(season),
  fetchEpisodes: ({required seasonId, required seriesId}) async {
    final result = await widget.client.mediaLibrary.getEpisodes(
      seasonId: seasonId,
      seriesId: seriesId,
    );
    return MediaItemMapper.toSharedEpisodeListResult(result);
  },
  onStartPlayback: (ctx, episode) {
    // 这里继续走 PlaybackDelegateFactory，不要回到旧 VideoPlayerPage。
  },
);
```

### 问题 2：`AudioPlaybackPort` 注入还没有真正落地

位置：

- `lib/src/ui/pages/music_library_page.dart:107`
- `lib/src/ui/pages/music_library_page.dart:648`
- `lib/src/ui/pages/lyrics_page.dart:32`
- `lib/src/ui/widgets/mini_player_card.dart:22`
- `lib/src/ui/widgets/mini_player_card.dart:24`
- `lib/src/app_shell/feature_page_factory.dart:308`
- `lib/src/app_shell/feature_page_factory.dart:389`
- `lib/src/app_shell/music_playback_adapter.dart:72`

现象：

测试证明页面“接受了 `audioPlayback` 参数”，但代码内部仍大量直接使用 `AudioPlaybackManager.instance`，甚至把抽象端口强转回具体实现：

```dart
final manager = audioPlayback as AudioPlaybackManager? ?? AudioPlaybackManager.instance;
```

这不是完整解耦。它带来的问题是：

- 传入 mock port 时，UI 仍可能读取 singleton。
- feature 页面看起来依赖抽象，实际仍被根包全局播放管理器支配。
- 后续要替换播放器、支持多播放实例、做测试隔离会继续困难。

下一阶段应该把 `AudioPlaybackPort` 作为真实运行时依赖，而不是只作为构造参数存在。

建议改法：

```dart
music.AudioPlaybackPort get _playback =>
    widget.audioPlayback ?? AudioPlaybackManager.instance;
```

然后 UI 读取 `AudioPlaybackPort` 的抽象字段：

```dart
final track = playback.currentTrack;
if (track == null) return const SizedBox.shrink();

Text(track.name);
Text(track.artistText ?? '未知艺术家');
```

`MusicPlaybackAdapter.playMusicSongs()` 不应继续接收 `AudioPlaybackManager`，应接收 `music.AudioPlaybackPort`：

```dart
static Future<void> playMusicSongs(
  List<music.MusicSong> songs,
  int index,
  music.AudioPlaybackPort playback,
) async {
  final tracks = songs.map(toAudioTrack).toList();
  if (tracks.isEmpty) return;
  await playback.playSong(tracks[index], tracks, index);
}

static music.AudioTrack toAudioTrack(music.MusicSong song) {
  return music.AudioTrack(
    id: song.id,
    name: song.name,
    streamUrl: song.getStreamUrl(),
    coverUrl: song.getAlbumCoverUrl(fillWidth: 300, fillHeight: 300),
    artistText: song.artistText,
    albumName: song.albumName,
    trackNumber: song.trackNumber,
    duration: song.runTimeSeconds == null
        ? null
        : Duration(seconds: song.runTimeSeconds!),
    isFavorite: song.isFavorite,
  );
}
```

同时，`AudioPlaybackManager` 可以继续保留 `play(List<MusicSong>...)` 作为旧接口，但 `AudioPlaybackPort` 路径必须走 `playSong(AudioTrack...)`。

### 问题 3：`MiniPlayerCard` 的抽象不成立

位置：

- `lib/src/ui/widgets/mini_player_card.dart:22`
- `lib/src/ui/widgets/mini_player_card.dart:24`
- `lib/src/ui/widgets/mini_player_card.dart:37`

`MiniPlayerCard` 当前虽然支持传入 `audioPlayback`，但内部马上把它转回 `AudioPlaybackManager`，并读取 `currentSong`、`musicPlaylist` 这些具体实现字段。这样 mock port 和未来其他播放实现都无法真正工作。

建议下一步把 `MiniPlayerCard` 改成只认识 `AudioTrack`：

```dart
class MiniPlayerCard extends StatelessWidget {
  final JellyfinClient client;
  final music.AudioPlaybackPort audioPlayback;

  const MiniPlayerCard({
    super.key,
    required this.client,
    required this.audioPlayback,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: audioPlayback,
      builder: (context, _) {
        final track = audioPlayback.currentTrack;
        if (track == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            // 下一步：跳转到基于 AudioPlaybackPort 的播放页，
            // 不再依赖 MusicSong / AudioPlaybackManager。
          },
          child: /* 使用 track.name / track.coverUrl / audioPlayback.position */,
        );
      },
    );
  }
}
```

如果当前 `AudioPlayerPage` 还必须吃 `MusicSong`，说明音乐播放页本身仍是根包旧页面。那下一阶段要么把 `AudioPlayerPage` 下沉/迁移到 `jellyfin_music`，要么在 app shell 新增一个 `AudioPlayerShellPage` 做 root 模型与 port 的桥接。

### 问题 4：`AppSessionController` 没有真正接管主流程

位置：

- `lib/src/app_shell/app_session_controller.dart`
- `lib/src/ui/pages/login_page.dart`
- `lib/src/ui/pages/media_libraries_page.dart:74`

`AppSessionController` 有 `login/logout`，但主页面仍然直接：

```dart
await widget.client.auth.logout();
Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
```

这说明 Auth Shell 只完成了对象创建，没有完成流程收敛。真正的 Shell 应该是：

- 登录成功后设置 `currentSession`。
- 登出时清空 `currentSession`。
- 根页面根据 session 自动切换 `LoginPage` / `MediaLibrariesPage`。
- 页面内部不再手写回登录页跳转。

建议引入一个真正的根 Shell Widget：

```dart
class JellyfinAppShell extends StatefulWidget {
  const JellyfinAppShell({super.key});

  @override
  State<JellyfinAppShell> createState() => _JellyfinAppShellState();
}

class _JellyfinAppShellState extends State<JellyfinAppShell> {
  final AppSessionController _sessionController = AppSessionController();

  @override
  void dispose() {
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sessionController,
      builder: (context, _) {
        final session = _sessionController.currentSession;
        if (session == null) {
          return LoginPage(
            onLoginSuccess: _sessionController.setSession,
          );
        }
        return MediaLibrariesPage(
          client: session.client,
          user: session.user,
          onLogout: _sessionController.logout,
        );
      },
    );
  }
}
```

对应地，`AppSessionController` 需要补一个 `setSession`：

```dart
void setSession(AppSession session) {
  _currentSession = session;
  notifyListeners();
}
```

`MediaLibrariesPage` 应改为接收 `onLogout`：

```dart
final Future<void> Function()? onLogout;

// ...
IconButton(
  icon: const Icon(Icons.logout),
  onPressed: () async {
    await widget.onLogout?.call();
  },
)
```

这样主页面不再知道“登出后去 LoginPage”，只发出“我要登出”的意图。

### 问题 5：`FeaturePageFactory` 已成为新的上帝编排类

位置：

- `lib/src/app_shell/feature_page_factory.dart`

当前 `FeaturePageFactory` 约 300 多行，集中处理：

- 媒体库分派。
- 电影筛选页。
- 电影详情页。
- 通用媒体列表。
- 剧集、季、集。
- 播放委托。
- 音乐专辑、艺术家、播放。
- AI 推荐页。
- 多处 `Navigator.push`。

它比原来塞在 `MediaLibrariesPage` 里好，但只是把复杂度转移到了另一个类。这个类可以作为 Phase 4 过渡层，但不应继续膨胀。

下一阶段建议拆成模块级 route factory：

```dart
class AppRouteFactories {
  final MovieRouteFactory movies;
  final MediaRouteFactory media;
  final SeriesRouteFactory series;
  final MusicRouteFactory music;
  final AiRouteFactory ai;

  AppRouteFactories(AppSession session, AppDependencies deps)
      : movies = MovieRouteFactory(session, deps),
        media = MediaRouteFactory(session, deps),
        series = SeriesRouteFactory(session, deps),
        music = MusicRouteFactory(session, deps),
        ai = AiRouteFactory(session, deps);
}
```

`FeaturePageFactory.pageForLibrary()` 可以暂时保留为很薄的分派：

```dart
Widget pageForLibrary(MediaLibrary library) {
  return switch (library.type) {
    MediaLibraryType.movies => movies.filterPage(library),
    MediaLibraryType.music => music.libraryPage(library),
    _ => media.itemsPage(library),
  };
}
```

目标是让每个 route factory 只负责一个业务模块的页面组装，避免下一阶段又形成新的大泥球。

## 下一阶段建议任务

### P0：修复 analyze 回归

验收标准：

```powershell
dart analyze lib test
flutter test
dart scripts/check_module_boundaries.dart
```

必须全部通过。

工作项：

- 删除或修复 `lib/src/ui/pages/seasons_page.dart` 的 `EpisodesPage` 引用。
- 如果旧页面已不再对外 export，优先删除旧页面，避免 deprecated 文件继续拖累分析结果。
- 将 `test_api_page.dart` 中因 barrel 清理产生的直连页面 import 纳入 debug-only 或 test-only 处理，不要让示例/调试页成为 public API 清理的阻力。

### P0：把 `AudioPlaybackPort` 从“形状注入”改成“真实依赖”

验收标准：

- `rg "as AudioPlaybackManager\\?|AudioPlaybackManager\\.instance" lib/src/ui/pages lib/src/ui/widgets lib/src/app_shell` 中，除 app shell 默认注入点外，不应在音乐页面和音乐 widget 内看到 singleton 直接读取。
- `MiniPlayerCard`、`LyricsPage`、`AudioPlayerPage` 的核心状态读取来自 `AudioPlaybackPort`。
- 测试不只验证构造参数，还要 pump widget，用 fake port 的 `currentTrack/isPlaying/position` 验证 UI 真读了 fake port。

建议新增测试：

```dart
testWidgets('MiniPlayerCard 使用注入的 AudioPlaybackPort 渲染当前歌曲', (tester) async {
  final port = FakeAudioPlaybackPort(
    currentTrack: const music.AudioTrack(
      id: 's1',
      name: 'Injected Song',
      streamUrl: 'http://test/audio',
      artistText: 'Injected Artist',
    ),
  );

  await tester.pumpWidget(MaterialApp(
    home: MiniPlayerCard(client: client, audioPlayback: port),
  ));

  expect(find.text('Injected Song'), findsOneWidget);
  expect(find.text('Injected Artist'), findsOneWidget);
});
```

### P1：完成 Auth Shell 闭环

验收标准：

- 应用根入口只由 `AppSessionController.currentSession` 决定展示登录页还是主页面。
- `MediaLibrariesPage` 不再 import `LoginPage`。
- 登出逻辑由 Shell 执行，业务页面只调用 `onLogout`。
- `LoginPage` 不再自己默认 push 到 `MediaLibrariesPage`，或者默认跳转逻辑被标记为 legacy/example-only。

### P1：拆分 `FeaturePageFactory`

验收标准：

- `feature_page_factory.dart` 保持在 80 行以内，只做媒体库分派。
- 每个业务模块拥有独立 route factory。
- `Navigator.push` 调用集中在 route factory 或一个 `AppNavigator` 中，不散落在页面和 widget 内。

### P2：收紧 facade 出口策略

当前 `lib/jellyfin_service.dart` 仍然 export 很多 UI 页面和 widget。短期可以兼容，但下一阶段要明确两类入口：

- SDK 入口：模型、服务、client、adapter。
- App/Example 入口：页面、shell、调试工具。

建议新增两个 barrel：

```text
lib/jellyfin_service.dart          // SDK/API 主入口，尽量少 UI
lib/jellyfin_service_app.dart      // App Shell + 页面入口
lib/jellyfin_service_debug.dart    // test_api/debug panel 等调试入口
```

这样可以减少根包 public API 与 feature 页面之间的命名冲突，也能降低 `hide` 数量继续增长的风险。

## 对员工的直接建议

1. Phase 4 的主方向认可，但不要急着进入新功能，先把 `dart analyze lib test` 的错误清掉。
2. `AudioPlaybackPort` 这块需要返工一小轮：构造参数传入不等于解耦完成，内部不能再强转回 `AudioPlaybackManager`。
3. `AppSessionController` 要接管页面切换，否则它只是一个未接线的类。
4. `FeaturePageFactory` 暂时可用，但下一阶段必须拆，不然它会变成新的 `media_libraries_page.dart`。
5. Phase 5 的验收不要只看测试通过，要增加结构性 grep 检查，例如 singleton 使用、root 页面 import、feature `src/` import、barrel hide 数量。

## 建议的 Phase 5 标题

**Phase 5：App Shell 闭环与真实依赖注入**

目标不是继续“多拆几个文件”，而是让已经抽出来的边界真的生效：

- 会话由 Shell 管。
- 路由由 Shell 管。
- 播放由 Port 管。
- feature 页面只接收数据、回调和抽象依赖。
- 根包旧 UI 逐步迁移到 app/example 层或删除。

