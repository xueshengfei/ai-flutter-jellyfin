# go_router 统一路由协议设计

## 背景

当前模块化改造已经把电影、剧集、播放、音乐、AI 推荐等业务逐步拆成 feature 包，但页面跳转仍大量散落在 root UI 页面和 `FeaturePageFactory` 中。模块之间不能直接 import 彼此页面，否则业务包会重新耦合；但如果继续靠 root 里手写 `Navigator.push(MaterialPageRoute(...))`，跳转关系又会分散、难维护。

本阶段采用 `go_router` 作为 Flutter 导航执行引擎，项目自己维护统一路由协议和手工路由表。目标是形成类似鸿蒙 ZRouter 的“路由黑板”：业务模块只发出导航意图，App Shell 统一解析、构造页面、注入依赖并执行跳转。

## 设计目标

1. feature 模块不依赖其他 feature 模块页面。
2. feature 模块不直接依赖 `go_router`。
3. root App Shell 使用 `go_router` 维护唯一页面路由表。
4. 路由协议放在 `jellyfin_core`，可被所有模块依赖。
5. 页面参数优先传 `id/type/libraryId`，避免把大对象塞进 URL。
6. `state.extra` 只作为过渡期性能优化，页面必须能靠 id 重新加载。
7. 旧 `Navigator.push` 不一次性全部删除，先建立新主干，再逐步迁移。

## 架构

```text
feature modules
  -> depend on jellyfin_core routing protocol
  -> emit RouteNavigationIntent / AppNavigator.push(...)
  -> do not import other feature pages
  -> do not import go_router

jellyfin_core
  -> defines route names
  -> defines typed route intent
  -> keeps AppNavigator protocol
  -> has no Flutter Widget dependency beyond existing module contracts

root app shell
  -> owns GoRouter
  -> implements AppNavigator with go_router
  -> registers all GoRoute entries manually
  -> injects JellyfinClient, playback delegate, audio port, callbacks

go_router
  -> executes push/go/pop
  -> handles login redirect
  -> keeps browser/deep-link friendly locations
```

## 核心协议

新增 `JellyfinRouteNames`，作为全项目唯一的路由名集合：

```dart
abstract final class JellyfinRouteNames {
  static const login = 'auth.login';
  static const libraries = 'libraries.index';
  static const library = 'libraries.detail';
  static const mediaDetail = 'media.detail';
  static const movieDetail = 'movies.detail';
  static const seriesSeasons = 'series.seasons';
  static const seriesEpisodes = 'series.episodes';
  static const playbackVideo = 'playback.video';
  static const musicLibrary = 'music.library';
  static const musicAlbum = 'music.album';
  static const musicArtist = 'music.artist';
  static const musicSearch = 'music.search';
  static const aiRecommend = 'ai.recommend';
  static const profile = 'profile';
}
```

新增 `RouteNavigationIntent`：

```dart
class RouteNavigationIntent extends NavigationIntent {
  final String routeName;
  final Map<String, Object?> arguments;

  const RouteNavigationIntent({
    required this.routeName,
    this.arguments = const {},
  });
}
```

业务模块后续只需要依赖 `AppNavigator`：

```dart
navigator.pushIntent(RouteNavigationIntent(
  routeName: JellyfinRouteNames.playbackVideo,
  arguments: {'itemId': item.id},
));
```

## Root 路由表

第一阶段手工维护这些路由：

```text
auth.login              /login
libraries.index         /libraries
libraries.detail        /libraries/:libraryId
media.detail            /media/items/:itemId
movies.detail           /movies/:itemId
series.seasons          /series/:seriesId/seasons
series.episodes         /series/:seriesId/seasons/:seasonId/episodes
playback.video          /playback/video/:itemId
music.library           /music/libraries/:libraryId
music.album             /music/albums/:albumId
music.artist            /music/artists/:artistId
music.search            /music/search
ai.recommend            /ai/recommend
profile                 /profile
```

第一批实际接入：

- `/login`
- `/libraries`
- `/libraries/:libraryId`
- `/ai/recommend`
- `/profile`
- `/playback/video/:itemId`

其余路由先声明协议和名称，后续员工逐步注册。

## 登录重定向

`AppSessionController` 作为 `GoRouter.refreshListenable`。

规则：

- 未登录访问非 `/login`，重定向到 `/login`。
- 已登录访问 `/login`，重定向到 `/libraries`。
- 登录成功只设置 session，不再由 `LoginPage` 自己 push 主页面。
- 登出只清 session，不再由 `MediaLibrariesPage` 自己 push 登录页。

## 与旧代码兼容

`FeaturePageFactory` 暂时保留，只作为旧页面构造适配器。新入口优先走 `go_router`：

- `MediaLibrariesPage` 新增可选 `AppNavigator`。
- 传入 `AppNavigator` 时，媒体库、AI、个人中心、登出使用新路由。
- 未传入时，保留旧的 `Navigator.push` 行为，避免一次性破坏现有测试和示例。

## 下一步迁移规则

1. 新增跨模块跳转时，只能新增 route name 和 route handler。
2. feature 页面需要跳转时，只能调用注入的 `AppNavigator` 或回调。
3. 页面内部不得直接 import 目标模块页面。
4. root shell 可以 import 所有 feature 页面，因为它是应用编排层。
5. 每迁移一个旧 `Navigator.push`，补一个路由测试或 widget smoke test。

## 验收

最低验收命令：

```powershell
flutter test test/app_shell_test.dart
flutter test
dart scripts/check_module_boundaries.dart
dart analyze lib test
```

注意：全仓 `dart analyze` 当前会扫描 `packages/ohos` 三方目录，噪声太多，不作为本阶段主验收命令。

