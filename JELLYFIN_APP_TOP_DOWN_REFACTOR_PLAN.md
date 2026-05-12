# Jellyfin App 自顶向下重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新建 `apps/jellyfin_app`，从 App 壳层开始重构，逐步接入登录注册、媒体库、音乐、电影/详情、剧集、AI 推荐、播放等 feature 模块，不再继续在旧根包 `lib/` 内做业务拆分。

**Architecture:** 旧 `lib/` 进入冻结维护状态，只作为参考实现和短期 SDK 桥，不再承载新的业务模块化改造。新 `jellyfin_app` 作为真正的产品 App，拥有自己的 AppShell、Session、Route Table、Dependency Composition 和页面编排层；feature 包继续保持 UI/业务能力包的角色，由 App 层注入数据获取、播放、导航等能力。

**Tech Stack:** Flutter、go_router、jellyfin_core、jellyfin_api、jellyfin_models、jellyfin_ui_kit、现有 `packages/features/*`。

---

## 0. 战略调整

之前 Phase 5 / Phase 5B 的路线是在旧根包 `jellyfin_service/lib` 内继续改造路由、页面和兼容工厂。现在停止这条路线。

新的路线是：

```text
不再继续拆旧 lib
  -> 新建 apps/jellyfin_app
  -> 先搭 App 壳层
  -> 再按用户主链路逐步接 feature
  -> 最后替换旧 example/root UI
```

关键原则：

- 旧 `lib/` 不再新增业务页面、不再新增路由、不再继续扩大 `FeaturePageFactory`。
- 新 App 不直接 import 旧 `lib/src/ui/pages/*` 页面。
- 新 App 可以短期引用旧根包里的 `JellyfinClient` 作为 SDK 桥，但必须包在 app 自己的 gateway/adapter 后面。
- 新 App 的页面入口优先来自 `packages/features/*`。
- `go_router` 只存在于 `apps/jellyfin_app` 的 AppShell 层。
- feature 模块只能依赖 `jellyfin_core`、`jellyfin_models`、`jellyfin_ui_kit` 等基础包，不能依赖新 App，也不能互相 import 对方的 `src/`。

---

## 1. 新目录目标

最终主目录结构：

```text
apps/
  jellyfin_app/
    pubspec.yaml
    lib/
      main.dart
      src/
        app/
          jellyfin_app.dart
          app_router.dart
          app_route_names.dart
          app_theme.dart
        session/
          app_session.dart
          app_session_controller.dart
          session_storage.dart
        navigation/
          go_router_app_navigator.dart
        data/
          jellyfin_gateway.dart
          legacy_jellyfin_gateway.dart
          mappers/
        features/
          auth/
            login_page.dart
            register_page.dart
          home/
            home_shell_page.dart
            media_libraries_page.dart
          media/
            media_route_pages.dart
          music/
            music_route_pages.dart
          playback/
            playback_route_pages.dart
    test/
      app_router_test.dart
      session_controller_test.dart
      gateway_contract_test.dart
```

说明：

- `apps/jellyfin_app/lib/src/app`：只放 App 壳、路由表、主题。
- `apps/jellyfin_app/lib/src/session`：只处理登录态、session 生命周期、持久化。
- `apps/jellyfin_app/lib/src/data`：只处理 App 对 Jellyfin 数据服务的访问，短期可以包旧 `JellyfinClient`。
- `apps/jellyfin_app/lib/src/features/*`：不是新的业务 package，而是 App 层对 feature 包的页面编排入口。
- 现有 `packages/features/*` 继续作为业务 UI/能力包，不把 App 依赖倒灌进去。

---

## 2. 依赖策略

### 2.1 推荐依赖方向

```text
apps/jellyfin_app
  -> jellyfin_core
  -> jellyfin_api
  -> jellyfin_models
  -> jellyfin_ui_kit
  -> jellyfin_ai_recommendation
  -> jellyfin_media
  -> jellyfin_movies
  -> jellyfin_series
  -> jellyfin_music
  -> jellyfin_playback
  -> go_router
  -> shared_preferences
```

短期可选桥接：

```text
apps/jellyfin_app
  -> jellyfin_service
```

但只能用于 `legacy_jellyfin_gateway.dart`，不能让页面直接 import 旧根包 UI。

### 2.2 旧根包使用边界

允许：

- 参考旧代码实现。
- 短期通过 `LegacyJellyfinGateway` 调用旧 `JellyfinClient` 的 auth/media/music 服务。

禁止：

- 新 App 页面 import `package:jellyfin_service/src/ui/pages/...`。
- 新 App 路由直接返回旧根包页面。
- 继续在旧 `lib/src/app_shell` 中新增路由。
- 继续在旧 `FeaturePageFactory` 中扩展新业务。

---

## 3. 里程碑

### Milestone A：冻结旧路线，建立新 App 骨架

目标：`apps/jellyfin_app` 可以独立启动，但只显示登录页或空壳。

验收：

- `flutter test` 不受影响。
- `cd apps/jellyfin_app && flutter test` 通过。
- 根目录旧 Phase 5 文档归档到 `docs/archive/modularization/phase5-routing/`。
- 根目录只保留当前新计划。

### Milestone B：接入登录注册模块

目标：新 App 能完成 Jellyfin 登录、注册入口展示、保存 session、退出登录。

说明：

当前项目没有独立 `jellyfin_auth` feature 包。第一阶段不要为了“完美模块化”先拆 auth 包，可以先在 `apps/jellyfin_app/lib/src/features/auth/` 建 App 级登录注册页。

后续如果 auth 页面稳定，再决定是否下沉为：

```text
packages/features/jellyfin_auth
```

验收：

- 未登录访问任何业务路由都跳 `/login`。
- 登录成功后跳 `/libraries`。
- 登出后回到 `/login`。
- 登录页不依赖旧根包 UI。
- Auth 数据访问通过 `JellyfinGateway`，不是页面直接 new `JellyfinClient`。

### Milestone C：接入媒体库首页

目标：登录后展示媒体库列表，点击不同 library 进入对应 feature 页面。

优先接入：

1. 媒体库列表页。
2. 继续观看入口。
3. AI 推荐入口按钮。
4. Profile/设置入口。

验收：

- `/libraries` 可加载用户媒体库。
- library 点击只发路由意图，不直接构造跨业务页面。
- 电影库跳 `/libraries/:libraryId/movies`。
- 音乐库跳 `/libraries/:libraryId/music`。
- 其他媒体库跳 `/libraries/:libraryId/media`。

### Milestone D：接入电影与媒体详情链路

目标：电影列表、电影详情、通用媒体详情接入 feature 包。

优先路由：

```text
/libraries/:libraryId/movies
/movies/:itemId
/media/items/:itemId
/series/:seriesId/seasons
/series/:seriesId/seasons/:seasonId/episodes
```

验收：

- 电影库使用 `jellyfin_movies` 的 `MovieFilterPage`。
- 电影详情使用 `jellyfin_movies` 的 `MovieDetailPage`。
- 通用详情使用 `jellyfin_media` 的 `MediaItemDetailPage`。
- 剧集季/集使用 `jellyfin_series`。
- 点击播放只跳 `/playback/video/:itemId`，不直接 import 播放页。

### Milestone E：接入音乐链路

目标：音乐库、专辑详情、艺术家详情、音乐搜索接入新 App。

优先路由：

```text
/libraries/:libraryId/music
/music/albums/:albumId
/music/artists/:artistId
/music/search
```

验收：

- 音乐库使用 `jellyfin_music` 页面或 App 级编排页。
- AI 推荐页点击音乐专辑/艺术家不会出现 unknown route。
- 音乐播放仍走音频播放服务，不混入视频播放链路。

### Milestone F：接入播放模块

目标：播放页作为全局能力，由电影、剧集、继续观看、AI 推荐等入口统一跳转。

优先路由：

```text
/playback/video/:itemId
```

验收：

- 所有视频播放入口只依赖 `JellyfinRouteNames.playbackVideo` 或新 App route helper。
- 播放页使用 `jellyfin_playback`。
- App 层负责把 `itemId` 加载成播放页需要的 item + playback delegate。
- feature 页面不直接 import 其他 feature 的播放页。

### Milestone G：接入 AI 推荐

目标：AI 推荐作为 App 的一个业务入口，而不是旧根包页面。

优先路由：

```text
/ai/recommend
```

验收：

- AI 推荐页使用 `jellyfin_ai_recommendation`。
- AI 推荐跳媒体详情、音乐专辑、音乐艺术家、播放，都走新 App route table。
- AI service url、TTS、图片 provider 都由 App 层注入。

### Milestone H：替换旧入口

目标：确认 `apps/jellyfin_app` 已覆盖主流程后，再考虑 root/example 的退场。

验收：

- 主开发入口切到 `apps/jellyfin_app`。
- 旧 `example/` 降级为 SDK 示例或删除。
- 旧根包 `lib/src/ui` 不再是产品 UI 主路径。
- 边界脚本开始检查新 App 不 import 旧 UI 页面。

---

## 4. 详细任务拆分

### Task 1：归档旧 Phase 5 路线文档

**Files:**

- Move: `PHASE5_ROUTING_DESIGN.md`
- Move: `PHASE5_ROUTING_EXECUTION_PLAN.md`
- Move: `PHASE5_PROGRESS_REPORT.md`
- Move: `PHASE5_STRATEGY_REPORT.md`
- Move: `PHASE5B_PROGRESS_REPORT.md`
- Move: `PHASE5B_STRATEGY_REPORT.md`
- Destination: `docs/archive/modularization/phase5-routing/`

- [ ] **Step 1: 确认旧文档均已归档**

Run:

```powershell
Get-ChildItem docs\archive\modularization\phase5-routing
```

Expected:

```text
PHASE5_ROUTING_DESIGN.md
PHASE5_ROUTING_EXECUTION_PLAN.md
PHASE5_PROGRESS_REPORT.md
PHASE5_STRATEGY_REPORT.md
PHASE5B_PROGRESS_REPORT.md
PHASE5B_STRATEGY_REPORT.md
```

- [ ] **Step 2: 确认根目录不再保留旧 Phase 5 文档**

Run:

```powershell
Get-ChildItem PHASE5*.md
```

Expected:

```text
No files found
```

如果 PowerShell 报找不到文件，这是预期结果。

### Task 2：创建 `apps/jellyfin_app` 骨架

**Files:**

- Create: `apps/jellyfin_app/pubspec.yaml`
- Create: `apps/jellyfin_app/lib/main.dart`
- Create: `apps/jellyfin_app/lib/src/app/jellyfin_app.dart`
- Create: `apps/jellyfin_app/lib/src/app/app_router.dart`
- Create: `apps/jellyfin_app/test/app_smoke_test.dart`

- [ ] **Step 1: 创建 Flutter App 目录**

Run:

```powershell
flutter create --platforms=android,ios,web,windows,macos,linux apps/jellyfin_app
```

Expected:

```text
All done!
```

- [ ] **Step 2: 修改 `apps/jellyfin_app/pubspec.yaml`**

必须添加本地依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  go_router: ^17.2.3
  shared_preferences: ^2.2.2
  jellyfin_core:
    path: ../../packages/foundation/jellyfin_core
  jellyfin_api:
    path: ../../packages/foundation/jellyfin_api
  jellyfin_models:
    path: ../../packages/shared/jellyfin_models
  jellyfin_ui_kit:
    path: ../../packages/shared/jellyfin_ui_kit
  jellyfin_media:
    path: ../../packages/features/jellyfin_media
  jellyfin_movies:
    path: ../../packages/features/jellyfin_movies
  jellyfin_series:
    path: ../../packages/features/jellyfin_series
  jellyfin_music:
    path: ../../packages/features/jellyfin_music
  jellyfin_playback:
    path: ../../packages/features/jellyfin_playback
  jellyfin_ai_recommendation:
    path: ../../packages/features/jellyfin_ai_recommendation
```

短期如果需要旧 SDK 桥，再加：

```yaml
  jellyfin_service:
    path: ../..
```

但只能用于 `legacy_jellyfin_gateway.dart`。

- [ ] **Step 3: 建立最小 AppShell**

`apps/jellyfin_app/lib/main.dart`：

```dart
import 'package:flutter/material.dart';
import 'src/app/jellyfin_app.dart';

void main() {
  runApp(const JellyfinApp());
}
```

`apps/jellyfin_app/lib/src/app/jellyfin_app.dart`：

```dart
import 'package:flutter/material.dart';
import 'app_router.dart';

class JellyfinApp extends StatefulWidget {
  const JellyfinApp({super.key});

  @override
  State<JellyfinApp> createState() => _JellyfinAppState();
}

class _JellyfinAppState extends State<JellyfinApp> {
  late final router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Jellyfin App',
      routerConfig: router,
    );
  }
}
```

`apps/jellyfin_app/lib/src/app/app_router.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return const Scaffold(body: Center(child: Text('Login')));
        },
      ),
    ],
  );
}
```

- [ ] **Step 4: 验证新 App 可测试**

Run:

```powershell
Push-Location apps\jellyfin_app
flutter test
Pop-Location
```

Expected:

```text
All tests passed!
```

### Task 3：建立新 App Session 层

**Files:**

- Create: `apps/jellyfin_app/lib/src/session/app_session.dart`
- Create: `apps/jellyfin_app/lib/src/session/app_session_controller.dart`
- Create: `apps/jellyfin_app/lib/src/session/session_storage.dart`
- Test: `apps/jellyfin_app/test/session_controller_test.dart`

- [ ] **Step 1: 定义 AppSession**

`app_session.dart`：

```dart
class AppSession {
  final String serverUrl;
  final String accessToken;
  final String userId;
  final String username;

  const AppSession({
    required this.serverUrl,
    required this.accessToken,
    required this.userId,
    required this.username,
  });

  bool get isValid =>
      serverUrl.isNotEmpty &&
      accessToken.isNotEmpty &&
      userId.isNotEmpty;
}
```

- [ ] **Step 2: 定义 SessionController**

`app_session_controller.dart`：

```dart
import 'package:flutter/foundation.dart';
import 'app_session.dart';

class AppSessionController extends ChangeNotifier {
  AppSession? _session;

  AppSession? get currentSession => _session;
  bool get isLoggedIn => _session?.isValid == true;

  void setSession(AppSession session) {
    _session = session;
    notifyListeners();
  }

  void clearSession() {
    _session = null;
    notifyListeners();
  }
}
```

- [ ] **Step 3: 写 Session 测试**

`session_controller_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_app/src/session/app_session.dart';
import 'package:jellyfin_app/src/session/app_session_controller.dart';

void main() {
  test('setSession marks controller as logged in', () {
    final controller = AppSessionController();
    controller.setSession(const AppSession(
      serverUrl: 'http://server',
      accessToken: 'token',
      userId: 'user-1',
      username: 'tester',
    ));

    expect(controller.isLoggedIn, isTrue);
    expect(controller.currentSession?.userId, 'user-1');
  });

  test('clearSession marks controller as logged out', () {
    final controller = AppSessionController();
    controller.setSession(const AppSession(
      serverUrl: 'http://server',
      accessToken: 'token',
      userId: 'user-1',
      username: 'tester',
    ));

    controller.clearSession();

    expect(controller.isLoggedIn, isFalse);
    expect(controller.currentSession, isNull);
  });
}
```

- [ ] **Step 4: 跑测试**

Run:

```powershell
Push-Location apps\jellyfin_app
flutter test test/session_controller_test.dart
Pop-Location
```

Expected:

```text
All tests passed!
```

### Task 4：建立统一路由主壳

**Files:**

- Modify: `apps/jellyfin_app/lib/src/app/app_router.dart`
- Create: `apps/jellyfin_app/lib/src/navigation/go_router_app_navigator.dart`
- Test: `apps/jellyfin_app/test/app_router_test.dart`

- [ ] **Step 1: 新 App 只在 App 层依赖 go_router**

`go_router_app_navigator.dart` 实现 `jellyfin_core` 的 `AppNavigator`，逻辑可以参考旧根包 `lib/src/app_shell/go_router_app_navigator.dart`，但文件必须放在 `apps/jellyfin_app`。

- [ ] **Step 2: 路由表先只注册登录和媒体库**

`app_router.dart` 第一版只保留：

```text
/login
/libraries
```

未登录访问 `/libraries` 必须 redirect 到 `/login`。

- [ ] **Step 3: 写 redirect 测试**

覆盖：

- 未登录访问 `/libraries` -> `/login`
- 已登录访问 `/login` -> `/libraries`

- [ ] **Step 4: 跑测试**

Run:

```powershell
Push-Location apps\jellyfin_app
flutter test test/app_router_test.dart
Pop-Location
```

Expected:

```text
All tests passed!
```

### Task 5：接入登录注册模块

**Files:**

- Create: `apps/jellyfin_app/lib/src/features/auth/login_page.dart`
- Create: `apps/jellyfin_app/lib/src/features/auth/register_page.dart`
- Create: `apps/jellyfin_app/lib/src/data/jellyfin_gateway.dart`
- Create: `apps/jellyfin_app/lib/src/data/legacy_jellyfin_gateway.dart`
- Modify: `apps/jellyfin_app/lib/src/app/app_router.dart`
- Test: `apps/jellyfin_app/test/auth_flow_test.dart`

- [ ] **Step 1: 定义 Gateway 协议**

`jellyfin_gateway.dart`：

```dart
import '../session/app_session.dart';

abstract class JellyfinGateway {
  Future<AppSession> login({
    required String serverUrl,
    required String username,
    required String password,
  });

  Future<void> register({
    required String serverUrl,
    required String adminUsername,
    required String adminPassword,
    required String username,
    required String password,
  });

  Future<void> logout();
}
```

- [ ] **Step 2: 实现 Legacy Gateway**

第一版可以包旧根包 `JellyfinClient`，但页面不能直接碰旧 client。

`legacy_jellyfin_gateway.dart` 负责：

- 创建 `JellyfinClient`。
- 调 `auth.authenticate`。
- 把结果转换成新 App 的 `AppSession`。
- 持有当前 client，供后续媒体库阶段使用。

- [ ] **Step 3: 登录页只依赖 Gateway**

`login_page.dart` 不直接创建 client，只调用：

```dart
final session = await gateway.login(
  serverUrl: serverUrl,
  username: username,
  password: password,
);
sessionController.setSession(session);
```

- [ ] **Step 4: 注册页作为入口存在**

注册可以先接真实 gateway，也可以先只完成表单和回调；但路由必须存在：

```text
/register
```

- [ ] **Step 5: 跑 auth flow 测试**

使用 fake gateway 测：

- 登录成功 setSession。
- 登录失败显示错误。
- 注册入口可跳转。

### Task 6：接入媒体库首页

**Files:**

- Create: `apps/jellyfin_app/lib/src/features/home/media_libraries_page.dart`
- Modify: `apps/jellyfin_app/lib/src/data/jellyfin_gateway.dart`
- Modify: `apps/jellyfin_app/lib/src/data/legacy_jellyfin_gateway.dart`
- Modify: `apps/jellyfin_app/lib/src/app/app_router.dart`
- Test: `apps/jellyfin_app/test/media_libraries_flow_test.dart`

- [ ] **Step 1: Gateway 增加媒体库能力**

```dart
Future<List<MediaLibrary>> getMediaLibraries();
Future<List<MediaItem>> getContinueWatching({int limit = 10});
```

模型优先使用 `jellyfin_models`，不要继续暴露旧根包模型。

- [ ] **Step 2: 媒体库页只负责展示和发起路由**

点击 library 时：

```text
movies -> /libraries/:libraryId/movies
music  -> /libraries/:libraryId/music
else   -> /libraries/:libraryId/media
```

- [ ] **Step 3: 继续观看跳播放路由**

点击继续观看：

```text
/playback/video/:itemId
```

- [ ] **Step 4: 验证路由**

测试：

- 有电影库时点击进入 movie route。
- 有音乐库时点击进入 music route。
- 继续观看点击进入 playback route。

### Task 7：接入电影、媒体、剧集详情

**Files:**

- Create: `apps/jellyfin_app/lib/src/features/media/media_route_pages.dart`
- Modify: `apps/jellyfin_app/lib/src/app/app_router.dart`
- Modify: `apps/jellyfin_app/lib/src/data/jellyfin_gateway.dart`
- Test: `apps/jellyfin_app/test/media_routes_test.dart`

- [ ] **Step 1: 注册核心媒体路由**

```text
/libraries/:libraryId/movies
/libraries/:libraryId/media
/movies/:itemId
/media/items/:itemId
/series/:seriesId/seasons
/series/:seriesId/seasons/:seasonId/episodes
```

- [ ] **Step 2: App route page 负责加载数据**

route page 做：

```text
path itemId/libraryId
  -> gateway fetch
  -> mapper
  -> feature page
```

- [ ] **Step 3: feature page 只通过回调跳转**

例如电影详情播放：

```dart
onStartPlayback: (context, movie) {
  navigator.push(JellyfinRouteNames.playbackVideo, arguments: {
    'itemId': movie.id,
  });
}
```

- [ ] **Step 4: 跑媒体路由测试**

覆盖：

- movie list -> movie detail
- media detail -> series episodes
- episodes -> playback

### Task 8：接入音乐模块

**Files:**

- Create: `apps/jellyfin_app/lib/src/features/music/music_route_pages.dart`
- Modify: `apps/jellyfin_app/lib/src/app/app_router.dart`
- Modify: `apps/jellyfin_app/lib/src/data/jellyfin_gateway.dart`
- Test: `apps/jellyfin_app/test/music_routes_test.dart`

- [ ] **Step 1: 注册音乐路由**

```text
/libraries/:libraryId/music
/music/albums/:albumId
/music/artists/:artistId
/music/search
```

- [ ] **Step 2: 音乐 route page 注入音频播放端口**

音乐播放不要走视频播放模块。App 层提供音频播放 manager 或 adapter，传给 `jellyfin_music`。

- [ ] **Step 3: AI/音乐之间只走路由**

AI 推荐点击 album/artist 时，只跳：

```text
/music/albums/:albumId
/music/artists/:artistId
```

- [ ] **Step 4: 跑音乐路由测试**

覆盖：

- music library -> album detail
- artist detail -> album detail
- music search -> artist/album

### Task 9：接入播放模块

**Files:**

- Create: `apps/jellyfin_app/lib/src/features/playback/playback_route_pages.dart`
- Modify: `apps/jellyfin_app/lib/src/app/app_router.dart`
- Modify: `apps/jellyfin_app/lib/src/data/jellyfin_gateway.dart`
- Test: `apps/jellyfin_app/test/playback_routes_test.dart`

- [ ] **Step 1: 注册播放路由**

```text
/playback/video/:itemId
```

- [ ] **Step 2: route page 加载 item 和 playback delegate**

App 层负责把 `itemId` 变成：

```text
jellyfin_models.MediaItem
PlaybackDelegate
```

然后传给 `jellyfin_playback` 的 `VideoPlayerPage`。

- [ ] **Step 3: 所有播放入口统一到这条路由**

包括：

- 继续观看。
- 电影详情。
- 媒体详情。
- 剧集集列表。
- AI 推荐。

- [ ] **Step 4: 跑播放路由测试**

覆盖：

- 缺少 itemId 报错。
- item 加载失败显示错误页。
- item 加载成功显示播放页。

### Task 10：接入 AI 推荐

**Files:**

- Create: `apps/jellyfin_app/lib/src/features/ai/ai_route_pages.dart`
- Modify: `apps/jellyfin_app/lib/src/app/app_router.dart`
- Modify: `apps/jellyfin_app/lib/src/data/jellyfin_gateway.dart`
- Test: `apps/jellyfin_app/test/ai_routes_test.dart`

- [ ] **Step 1: 注册 AI 路由**

```text
/ai/recommend
```

- [ ] **Step 2: App 层注入 AI 页面依赖**

需要注入：

- AI service url。
- image provider。
- media item detail fetcher。
- album/artist/media/playback navigation callbacks。

- [ ] **Step 3: 跑 AI 路由测试**

覆盖：

- 点击推荐媒体 -> media detail。
- 点击推荐专辑 -> music album。
- 点击推荐艺术家 -> music artist。
- 点击播放 -> playback。

### Task 11：建立新边界检查

**Files:**

- Modify: `scripts/check_module_boundaries.dart`
- Create: `scripts/check_jellyfin_app_boundaries.dart`

- [ ] **Step 1: 增加新 App 边界规则**

规则：

```text
apps/jellyfin_app 可以 import feature public barrel。
apps/jellyfin_app 不得 import packages/features/*/lib/src。
apps/jellyfin_app 不得 import package:jellyfin_service/src/ui。
packages/features 不得 import apps/jellyfin_app。
packages/features 不得 import 其他 feature 的 src。
```

- [ ] **Step 2: 跑边界检查**

Run:

```powershell
dart scripts/check_module_boundaries.dart
dart scripts/check_jellyfin_app_boundaries.dart
```

Expected:

```text
All checks passed
```

### Task 12：切换主开发入口

**Files:**

- Modify: `README.md`
- Create: `apps/jellyfin_app/README.md`
- Optional Modify: `.vscode/launch.json` 或项目启动脚本

- [ ] **Step 1: README 标明新方向**

根 README 增加：

```text
新的产品 App 位于 apps/jellyfin_app。
旧 lib 保留为历史 SDK/参考实现，不再作为 UI 主开发入口。
```

- [ ] **Step 2: 新启动命令**

```powershell
Push-Location apps\jellyfin_app
flutter run
Pop-Location
```

- [ ] **Step 3: 验收主链路**

手动验收：

```text
启动 App
登录
进入媒体库
进入电影列表
进入电影详情
进入播放页
返回媒体库
进入音乐库
进入专辑/艺术家
进入 AI 推荐
登出
```

---

## 5. 员工执行顺序

按下面顺序执行，不要跳：

```text
1. 归档旧 Phase 5 路由文档。
2. 创建 apps/jellyfin_app 骨架。
3. 建 session 和 router。
4. 做登录注册。
5. 做媒体库首页。
6. 做电影/媒体/剧集详情。
7. 做音乐。
8. 做播放。
9. 做 AI 推荐。
10. 做边界检查。
11. 切换主开发入口。
```

每个阶段都必须有：

```text
测试
边界检查
进度报告
```

建议每个 milestone 完成后新建：

```text
JELLYFIN_APP_MILESTONE_A_PROGRESS_REPORT.md
JELLYFIN_APP_MILESTONE_B_PROGRESS_REPORT.md
...
```

---

## 6. 不再做的事情

以下事情暂停：

- 不再继续给旧 `lib/src/app_shell/jellyfin_go_router.dart` 加新路由。
- 不再继续扩展旧 `FeaturePageFactory`。
- 不再为了旧根包 UI 去清理 41 处 `MaterialPageRoute`。
- 不再把 Phase 5B 的音乐路由补到旧根包 AppShell。
- 不再把旧 `example/` 当作主产品入口。

旧代码只保留三种价值：

```text
参考实现
短期 SDK 桥
回归对照
```

---

## 7. 成功标准

新路线成功的判断不是“旧 lib 被拆干净”，而是：

```text
apps/jellyfin_app 可以作为新主 App 独立运行；
主链路功能逐步恢复；
feature 包被新 App 自顶向下接入；
旧 lib 不再承载新 UI 演进；
最后旧 UI 可以自然退场。
```

第一阶段只要做到：

```text
新 App 可启动
可登录
可进入媒体库
旧 lib 没有继续被修改
```

就算方向正确。

