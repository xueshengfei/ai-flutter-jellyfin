# Phase 5B 进度评估与下一阶段策略报告

评估对象：`PHASE5B_PROGRESS_REPORT.md` 及当前代码  
评估时间：2026-05-12  
结论：Phase 5B 主方向正确，核心路由迁移有实质推进；但存在一个需要优先修复的运行时风险：部分代码已经开始跳转音乐路由，但音乐路由尚未注册。

---

## 1. 验收结论

本阶段可以评价为：

```text
通过，带 P1 修复项。
```

通过的原因：

- 统一路由协议继续保持在 `jellyfin_core`，feature 模块没有直接依赖 `go_router`。
- 根包 `app_shell` 已注册 4 个核心业务路由：电影详情、通用媒体详情、剧集季列表、剧集集列表。
- `FeaturePageFactory` 已经开始从“页面构造工厂”过渡为“旧页面兼容桥 + 新路由分发桥”。
- `ContinueWatchingCard` 已接入 `AppNavigator`，播放链路开始向统一路由协议收敛。
- `JellyfinRouteIntents` 的加入能减少业务侧手写 route name 和参数 key 的错误。
- 新增 `initialLocation` 参数，让路由测试更容易写。
- 边界脚本从纯提示变成基线守卫，方向正确。

但不能无条件通过的原因：

- `musicAlbum`、`musicArtist` 已经被 `FeaturePageFactory` 的 navigator 分支调用，但 `jellyfin_go_router.dart` 尚未注册这两个路由。
- 当前 go_router 测试没有覆盖“所有被调用 route name 必须已注册”的一致性。
- 边界脚本目前只是数量基线，不能发现“迁掉 1 个旧跳转，又新增 1 个旧跳转”的位置漂移问题。

---

## 2. 我实际验证的命令

已执行：

```powershell
dart scripts/check_module_boundaries.dart
flutter test test/go_router_app_navigator_test.dart
Push-Location packages\foundation\jellyfin_core; dart test; Pop-Location
flutter test
dart analyze lib test
```

验证结果：

- `dart scripts/check_module_boundaries.dart`：通过，仍有 `41/41` 处 `MaterialPageRoute`。
- `flutter test test/go_router_app_navigator_test.dart`：11 个测试通过。
- `packages/foundation/jellyfin_core` 下 `dart test`：27 个测试通过。
- `flutter test`：55 个测试通过。
- `dart analyze lib test`：0 errors，但仍有 232 个 warnings/info，命令返回非零。

`dart analyze` 的状态不能写成完全通过，只能写成：

```text
0 errors；仍有 warnings/info，需要后续清理。
```

---

## 3. 主要问题

### P1：已调用未注册的音乐路由，存在运行时跳转失败

当前 `jellyfin_go_router.dart` 已注册 10 条路由：

- `auth.login`
- `libraries.index`
- `libraries.detail`
- `ai.recommend`
- `profile`
- `playback.video`
- `movies.detail`
- `media.detail`
- `series.seasons`
- `series.episodes`

但 `FeaturePageFactory` 中已经有代码在新 navigator 分支调用：

```dart
JellyfinRouteNames.musicAlbum
JellyfinRouteNames.musicArtist
```

具体位置：

- `lib/src/app_shell/feature_page_factory.dart`：艺术家详情页跳专辑。
- `lib/src/app_shell/feature_page_factory.dart`：AI 推荐页跳专辑。
- `lib/src/app_shell/feature_page_factory.dart`：AI 推荐页跳艺术家。

这会导致一个实际问题：

```text
在新的 AppShell 主链路中，AI 推荐页持有 AppNavigator。
用户点击音乐专辑或艺术家时，会走 navigator.push(musicAlbum/musicArtist)。
但 go_router 里没有这两个 name。
结果是运行时跳转失败。
```

员工下一步必须二选一：

1. 立刻注册 `music.album` 和 `music.artist` 路由。
2. 在音乐路由注册前，不要对这两个跳转启用 navigator 分支，继续走旧 fallback。

我建议选第 1 个，因为 Phase 5C 本来就要注册音乐模块路由。

### P1：go_router 测试覆盖不够，容易漏掉 route name 一致性

新增的 11 个测试是有价值的，但还不够。

当前测试主要覆盖：

- redirect 逻辑。
- 部分 path 参数映射。
- 缺少参数时抛错。
- `pushIntent` 不同步抛错。

但没有覆盖：

- 所有 `JellyfinRouteNames` 是否都有对应 `GoRoute`。
- 所有 `FeaturePageFactory` navigator 分支使用的 route name 是否已注册。
- `musicAlbum`、`musicArtist` 这类“已映射 path 参数但未注册 GoRoute”的状态。

建议新增一个一致性测试：

```dart
test('FeaturePageFactory 使用的命名路由必须已注册', () {
  final registeredNames = collectRegisteredRouteNames(router);
  expect(registeredNames, contains(JellyfinRouteNames.musicAlbum));
  expect(registeredNames, contains(JellyfinRouteNames.musicArtist));
});
```

如果 go_router 不方便直接取 route table，就维护一份根包内部 route registry，由 `createJellyfinGoRouter` 和测试共用。

### P1：边界守卫只能防数量增加，不能防位置漂移

`scripts/check_module_boundaries.dart` 当前使用：

```dart
const materialPageRouteBaseline = 41;
```

这个能防止总数超过 41，但不能防止以下情况：

```text
员工迁移掉 1 处旧 MaterialPageRoute；
又在另一个新页面新增 1 处 MaterialPageRoute；
总数仍然是 41；
脚本仍然通过。
```

建议 Phase 5C 改成 allowlist 或 snapshot：

```text
只允许已有文件 + 已有行附近的旧 MaterialPageRoute 留存；
任何新增文件中的 MaterialPageRoute 直接 fail；
任何非 allowlist 的新增位置直接 fail。
```

数量基线可以保留，但不应该是唯一守卫。

### P2：`JellyfinRouteIntents` 已新增，但业务代码还没有使用

`JellyfinRouteIntents` 是好方向，但目前 `FeaturePageFactory` 和 `ContinueWatchingCard` 仍在手写：

```dart
nav.push(JellyfinRouteNames.playbackVideo, arguments: {'itemId': item.id});
```

建议逐步改为：

```dart
nav.pushIntent(JellyfinRouteIntents.playbackVideo(itemId: item.id));
```

这样参数 key 不会散落在业务代码里。这个不是阻断项，但应该作为 Phase 5C 的清理任务。

### P2：redirect 测试复制了生产逻辑，存在漂移风险

`test/go_router_app_navigator_test.dart` 中 redirect 测试使用了一个精简 `GoRouter`，并复制了一份 redirect 逻辑。

这能避免真实 `JellyfinClient` 请求，测试意图可以理解。但它没有真正验证 `createJellyfinGoRouter` 的 redirect 实现。

建议把 redirect 判断抽成纯函数：

```dart
String? resolveAuthRedirect({
  required bool isLoggedIn,
  required String matchedLocation,
})
```

生产路由和测试都调用这个函数。这样既避免网络依赖，又不会复制逻辑。

### P2：Route 页面内部 Widget 已经膨胀，后续要拆出小组件或 route builders

`jellyfin_go_router.dart` 已经增长到约 500 行，并包含多个内部 Widget：

- `_LibraryRoutePage`
- `_PlaybackRoutePage`
- `_MovieDetailRoutePage`
- `_MediaDetailRoutePage`
- `_SeriesSeasonsRoutePage`
- `_EpisodesRoutePage`

当前可以接受，因为路由主干还在搭建。但如果 Phase 5C 再加入音乐模块 4 条路由，这个文件会继续膨胀。

建议下一步拆成：

```text
lib/src/app_shell/routes/jellyfin_go_router.dart
lib/src/app_shell/routes/media_route_pages.dart
lib/src/app_shell/routes/series_route_pages.dart
lib/src/app_shell/routes/music_route_pages.dart
```

注意：这不是给 feature 模块引入 go_router，而只是根包 app_shell 内部整理代码。

---

## 4. 本阶段做得好的地方

### 4.1 10/14 路由注册是实质进展

从 Phase 5 的 6/14 到 Phase 5B 的 10/14，说明员工已经开始执行迁移，而不是停留在设计层。

新增的 4 条路由是核心业务链路：

- 电影详情
- 通用媒体详情
- 剧集季列表
- 剧集集列表

这比先迁音乐模块更合理，因为播放、电影、剧集、AI 推荐都会依赖这些详情链路。

### 4.2 `FeaturePageFactory` 双模式兼容是正确过渡

当前做法是：

```text
有 AppNavigator：走统一路由协议。
没有 AppNavigator：保留旧 Navigator.push。
```

这个策略适合当前阶段。它避免一次性打断旧页面，又让新 AppShell 主链路开始走统一协议。

### 4.3 `ContinueWatchingCard` 接入播放路由方向正确

继续观看卡片是播放链路的高频入口。它开始优先走：

```dart
JellyfinRouteNames.playbackVideo
```

这是正确的，因为播放页应该成为全局路由能力，而不是被每个业务页面直接 import。

### 4.4 `initialLocation` 是测试友好的小改动

给 `createJellyfinGoRouter` 增加 `initialLocation`，让测试可以直接从 `/libraries`、`/login` 等位置启动。这个改动小，但价值很实在。

---

## 5. 对 `PHASE5B_PROGRESS_REPORT.md` 的修正建议

建议员工补充以下内容：

### 5.1 把音乐路由风险写进“遇到的问题”

报告现在写剩余 4 个均为音乐模块路由，但没有说明已有代码已经开始调用其中的 `musicAlbum` 和 `musicArtist`。

建议补充：

```text
注意：FeaturePageFactory 中已有 musicAlbum/musicArtist 的 navigator 分支，
但对应 GoRoute 尚未注册。Phase 5C 必须优先注册这两个路由，
否则 AI 推荐页的音乐专辑/艺术家跳转会在新 AppShell 主链路下失败。
```

### 5.2 测试结果不要只写“全部通过”

可以写全部测试通过，但需要加一句：

```text
当前测试尚未覆盖 route name 注册一致性，后续需要补充。
```

### 5.3 `dart analyze` 结果要保持准确

建议写：

```text
dart analyze lib test：0 errors，但仍有 232 warnings/info，命令返回非零。
```

不要写成完全通过。

### 5.4 文档归档需要处理 git 状态

当前根目录旧文档显示为删除状态，`PHASE5B_PROGRESS_REPORT.md` 还是未跟踪文件。下次提交前要确认：

- 旧文档是否确实归档到了 `docs/archive/modularization/`。
- 根目录删除状态是否是预期。
- 新的 Phase 5B 文档是否加入版本控制。

---

## 6. Phase 5C 建议执行顺序

### 第 1 步：先补音乐路由注册

优先级：

1. `music.album`
2. `music.artist`
3. `music.library`
4. `music.search`

其中 `music.album` 和 `music.artist` 是 P1，因为已经被新 navigator 分支调用。

### 第 2 步：补 route name 注册一致性测试

至少覆盖：

- `musicAlbum` 已注册。
- `musicArtist` 已注册。
- `FeaturePageFactory` 中使用的所有 route name 都存在。
- `GoRouterAppNavigator._pathParametersFor` 支持的 route name 不应长期多于实际注册 route。

### 第 3 步：把业务代码改用 `JellyfinRouteIntents`

先改高频链路：

```text
播放
电影详情
媒体详情
剧集集列表
音乐专辑
音乐艺术家
```

目标写法：

```dart
nav.pushIntent(JellyfinRouteIntents.mediaDetail(itemId: item.id));
```

### 第 4 步：升级边界脚本为 allowlist

建议生成一个清单文件：

```text
scripts/module_boundary_allowlist.txt
```

里面记录允许暂留的旧 `MaterialPageRoute` 位置。脚本逻辑变成：

```text
扫描到 MaterialPageRoute；
如果在 allowlist 中，提示待迁移；
如果不在 allowlist 中，直接 fail。
```

### 第 5 步：再迁移活跃页面

优先迁移：

- `music_library_page.dart`
- `media_item_detail_page.dart`
- `ai_recommend_page.dart`
- `personal_page.dart`
- `mini_player_card.dart`

不要先清理 deprecated 页面。先保证活跃主链路不再新增耦合。

---

## 7. 给员工的下一步任务单

建议直接给员工如下任务：

```text
1. 先注册 music.album 和 music.artist 两个路由，修复已调用未注册的问题。
2. 给 go_router 增加 route name 注册一致性测试。
3. 将 FeaturePageFactory 和 ContinueWatchingCard 中的新导航调用改为 JellyfinRouteIntents + pushIntent。
4. 将 MaterialPageRoute 基线守卫升级为 allowlist 守卫。
5. 再注册 music.library 和 music.search。
6. 迁移 music_library_page.dart 的活跃跳转。
```

验收标准：

```text
flutter test 通过。
packages/foundation/jellyfin_core 下 dart test 通过。
dart scripts/check_module_boundaries.dart 通过。
dart analyze lib test 仍允许 warnings/info，但不得出现 error。
AI 推荐页点击音乐专辑/艺术家不会触发 unknown route name。
```

---

## 8. 最终评价

Phase 5B 是有价值的一步，不是空转。员工已经把电影、媒体、剧集核心链路接入到了统一路由协议，并且保留了旧链路兼容，这个节奏是对的。

但这轮最需要纠正的是“路由协议声明、路径参数映射、GoRoute 注册、业务调用”四者必须一致。现在音乐路由已经出现了“四者不一致”：

```text
JellyfinRouteNames 有声明；
GoRouterAppNavigator 有参数映射；
FeaturePageFactory 已经调用；
但 GoRoute 没有注册。
```

这类问题不会被普通单元测试发现，却会在用户点击时爆出来。Phase 5C 应该先补这个洞，再继续迁移剩余页面。

