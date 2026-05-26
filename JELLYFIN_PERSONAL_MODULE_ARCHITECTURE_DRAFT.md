# Jellyfin 个人模块产品矩阵架构讨论稿

> 讨论目标：设计一个可被 `jellyfin_app`、`jellyfin_movie_app`、未来 `jellyfin_music_app` 复用的个人模块，覆盖继续观看、收藏、观看历史、个人资料等能力。本文先讨论模块边界和四层级架构，不进入代码实现。

## 1. 结论先行

个人模块应该做成独立 feature 包：

```text
packages/features/jellyfin_personal/
```

它不是 `jellyfin_ui_kit` 的一部分，也不应该写死在某一个 Product App 里。原因是：

- `jellyfin_ui_kit` 只放通用视觉组件，不能放“收藏、历史、继续观看”这种用户业务。
- `jellyfin_app`、`jellyfin_movie_app`、`jellyfin_music_app` 都需要个人中心，但展示范围不同。
- 个人模块依赖登录态、用户 token、媒体筛选、播放跳转，必须通过 App 注入能力，不能自己创建 `ApiClient` 或依赖 `go_router`。

推荐形态：

```text
jellyfin_personal = 个人业务 feature
  - 定义页面、状态、个人业务模型、仓储协议
  - 使用 jellyfin_models 作为媒体模型
  - 使用 jellyfin_ui_kit 作为卡片、图片、列表能力
  - 不直接依赖 Product app
  - 不直接依赖 go_router
  - 不直接依赖 jellyfin_api / jellyfin_dart
```

Product App 负责：

- 登录态和 token
- Jellyfin API 适配
- 路由跳转
- 当前产品只展示哪些 tab
- 点击媒体后进入详情页还是播放页

## 2. 四层级架构

```text
┌──────────────────────────────────────────────────────────────┐
│ L1 产品表现层 Product Apps                                    │
│ jellyfin_app / jellyfin_movie_app / jellyfin_music_app        │
│ 负责路由、主题、登录态、模块组合、产品差异化入口                  │
├──────────────────────────────────────────────────────────────┤
│ L2 业务模块层 Feature Modules                                 │
│ jellyfin_personal / jellyfin_movies / jellyfin_music / media  │
│ 负责个人中心、电影、音乐、媒体详情等业务页面和业务状态             │
├──────────────────────────────────────────────────────────────┤
│ L3 通用能力层 Shared Capabilities                             │
│ jellyfin_models / jellyfin_ui_kit / jellyfin_core             │
│ 负责共享模型、通用 UI、路由意图协议、基础配置                     │
├──────────────────────────────────────────────────────────────┤
│ L4 基础设施层 Infrastructure                                  │
│ jellyfin_api / jellyfin_dart / http / cache / shared prefs    │
│ 负责真实网络请求、认证头、Jellyfin REST API、缓存和本地存储        │
└──────────────────────────────────────────────────────────────┘

依赖方向：L1 -> L2 -> L3 -> L4 的能力由上层装配，下层不知道上层。
```

更精确地说，`jellyfin_personal` 本身只应该依赖 L3，不直接依赖 L4。L4 通过 Product App 的 adapter 注入进来。

```text
Product App
  ├── PersonalRepositoryAdapter 依赖 jellyfin_api
  ├── PersonalPage 依赖 jellyfin_personal
  └── go_router 负责实际跳转

jellyfin_personal
  ├── 依赖 PersonalRepository 抽象协议
  ├── 依赖 jellyfin_models.MediaItem / UserProfile
  ├── 依赖 jellyfin_ui_kit.MediaListBuilder / JellyfinImage
  └── 通过 callbacks 发出播放、详情、登出等动作
```

## 3. 模块定位

个人模块负责“用户维度的媒体聚合”，不是媒体详情模块，也不是播放模块。

应该包含：

- 个人中心首页
- 继续观看
- 我的收藏
- 观看历史
- 用户资料摘要
- 登出入口
- 可选的产品筛选：全部、电影、剧集、音乐
- 收藏切换
- 标记已看 / 未看
- 点击媒体后的动作回调，历史记录点击必须能进入对应媒体详情页

不应该包含：

- 具体登录实现
- 具体注册实现
- 具体播放页
- 具体媒体详情页
- `go_router`
- `ApiClient`
- RVC、AI 推荐、音乐播放器状态
- Product App 的底部导航

## 4. 产品矩阵复用方式

| 产品 | 个人模块展示范围 | 推荐 tab | 点击行为 | 备注 |
|---|---|---|---|---|
| `jellyfin_app` 综合 App | 全部媒体 | 继续观看、收藏、历史、资料 | 根据媒体类型跳详情或播放 | 功能最完整 |
| `jellyfin_movie_app` 电影 App | Movie | 继续观看、收藏电影、观看历史 | 电影详情 / 视频播放 | 不显示音乐和剧集入口 |
| `jellyfin_music_app` 音乐 App | Audio / MusicAlbum / MusicArtist | 最近播放、收藏、资料 | 播放歌曲 / 打开专辑或艺术家 | “观看历史”文案应改为“播放历史” |
| 未来 TV App | Series / Episode | 继续观看、收藏剧集、观看历史 | 剧集详情 / 剧集播放 | 可复用同一模块配置 |

关键是个人模块不能假设自己运行在哪个产品里，而是通过配置决定展示内容。

```text
PersonalModuleConfig.full()
PersonalModuleConfig.moviesOnly()
PersonalModuleConfig.musicOnly()
PersonalModuleConfig.custom(...)
```

## 5. 推荐包结构

```text
packages/features/jellyfin_personal/
  pubspec.yaml
  lib/
    jellyfin_personal.dart
    jellyfin_personal_pages.dart
    src/
      models/
        personal_models.dart
        personal_config.dart
        personal_query.dart
      contracts/
        personal_repository.dart
        personal_actions.dart
      pages/
        personal_page.dart
        personal_collection_page.dart
      widgets/
        personal_header.dart
        personal_tab_shell.dart
        personal_media_section.dart
        personal_empty_state.dart
        personal_error_state.dart
      controllers/
        personal_controller.dart
```

### 5.1 公开入口

建议提供两个入口：

```text
jellyfin_personal.dart
  - 导出模型、配置、协议
  - 适合 Product app 编排层引用

jellyfin_personal_pages.dart
  - 导出页面和可复用 widget
  - 适合 Product app route page 引用
```

这样以后如果某个产品只想复用协议，不想引入页面，也有空间。

## 6. 核心协议设计

个人模块应该定义自己的仓储协议，由 Product App 提供实现。

```dart
abstract class PersonalRepository {
  Future<PersonalProfile> getProfile();

  Future<PersonalMediaResult> getContinueWatching(
    PersonalMediaQuery query,
  );

  Future<PersonalMediaResult> getFavorites(
    PersonalMediaQuery query,
  );

  Future<PersonalMediaResult> getHistory(
    PersonalMediaQuery query,
  );

  Future<void> setFavorite({
    required String itemId,
    required bool isFavorite,
  });

  Future<void> setPlayed({
    required String itemId,
    required bool isPlayed,
  });
}
```

`PersonalMediaQuery` 负责表达产品差异：

```dart
class PersonalMediaQuery {
  final Set<PersonalMediaKind> mediaKinds;
  final int limit;
  final int startIndex;
  final PersonalSort sort;
}
```

媒体结果统一返回共享模型：

```dart
class PersonalMediaResult {
  final List<MediaItem> items;
  final int? totalCount;
  final int? startIndex;
}
```

这样 `jellyfin_personal` 不关心数据来自综合 App、电影 App 还是音乐 App。

## 7. Action 回调设计

个人模块里所有跨模块行为都要通过回调发出去。

```dart
class PersonalActions {
  /// 点击卡片主区域，默认语义是打开媒体详情。
  final void Function(BuildContext context, MediaItem item)? onOpenMedia;

  /// 点击播放按钮，默认语义是直接播放。
  final void Function(BuildContext context, MediaItem item)? onPlayMedia;

  final VoidCallback? onLogout;
  final VoidCallback? onOpenSettings;
}
```

原因：

- 个人模块不依赖 `go_router`
- 个人模块不 import 电影详情页、播放页、音乐播放页
- 各 Product App 可以决定点击后的具体路径

示例：

```text
jellyfin_movie_app:
  onOpenMedia -> /movies/:itemId
  onPlayMedia -> /playback/video/:itemId

jellyfin_music_app:
  onOpenMedia -> /music/albums/:albumId 或 /playback/music
  onPlayMedia -> audioPlaybackPort.playSong(...)

jellyfin_app:
  onOpenMedia -> 根据 item.type 分发到 movie/media/series/music
```

### 7.1 历史记录点击跳转规则

历史记录页的卡片点击行为必须进入对应媒体详情页。例如用户在历史记录里点击《疯狂动物城》，个人模块调用：

```dart
actions.onOpenMedia?.call(context, item);
```

然后由当前 Product App 决定跳转路径：

```text
jellyfin_app 综合 App:
  Movie   -> /movies/:itemId
  Series  -> /media/items/:itemId 或 /series/:seriesId/seasons
  Episode -> /media/items/:itemId
  Audio   -> /playback/music 或 /music/albums/:albumId，按音乐产品设计决定

jellyfin_movie_app:
  Movie -> /movies/:itemId

jellyfin_music_app:
  Audio      -> /playback/music
  MusicAlbum -> /music/albums/:albumId
  MusicArtist -> /music/artists/:artistId
```

个人模块内部不写这些路由路径，也不 import 电影详情页、剧集详情页、音乐详情页。它只负责在历史列表中把被点击的 `MediaItem` 发出去。这样同一套历史记录 UI 可以在综合 App、电影 App、音乐 App 里复用。

卡片内部如果有单独的播放按钮，播放按钮才调用 `onPlayMedia`；卡片主体点击始终调用 `onOpenMedia`。这样可以避免“用户想看详情却直接播放”的误触。

## 8. UI 设计建议

### 8.1 页面结构

第一版推荐使用一个 `PersonalPage`，内部使用 tab：

```text
PersonalPage
  SliverAppBar / Header
    用户头像
    用户名
    当前服务器
    登出按钮
  Tabs
    继续观看 / 最近播放
    我的收藏
    历史记录
  Content
    MediaListBuilder
    EmptyState
    ErrorState
```

综合 App 可以显示 3 个 tab。电影 App 可以把 tab 名称改成：

- 继续观看
- 收藏电影
- 观看历史

音乐 App 可以改成：

- 最近播放
- 收藏音乐
- 播放历史

### 8.2 UI Kit 复用

个人模块应直接复用 `jellyfin_ui_kit`：

- `JellyfinImageProvider`：头像、封面
- `MediaListBuilder`：列表视图切换
- `MediaItemCardWithActions`：收藏按钮、进度条
- `ViewModeSelector`：可由 Product App 注入或 PersonalPage 内部使用
- `ContinueWatchingCard`：个人首页摘要区可选使用

不要把这些 UI 再复制一份到 `jellyfin_personal`。

## 9. 数据适配方案

### 9.1 综合 App adapter

`Product/jellyfin_app` 可以在自己的 data 层新增：

```text
Product/jellyfin_app/lib/src/data/personal_repository_adapter.dart
```

它依赖当前 `LegacyJellyfinGateway.apiClient`，实现 `PersonalRepository`。

API 对应关系：

| PersonalRepository 方法 | Jellyfin API |
|---|---|
| `getProfile()` | 登录结果 `AppSession` + User API |
| `getContinueWatching()` | `getResumeItems(userId, limit)` |
| `getFavorites()` | `getItems(userId, isFavorite: true, includeItemTypes: ...)` |
| `getHistory()` | `getItems(userId, isPlayed: true, sortBy: DatePlayed desc, includeItemTypes: ...)` |
| `setFavorite()` | `POST/DELETE /Users/{userId}/FavoriteItems/{itemId}` |
| `setPlayed()` | `PlaystateApi.markPlayedItem / markUnplayedItem` |

### 9.2 电影 App adapter

`jellyfin_movie_app` 不要复制整套综合 App gateway。只实现电影范围：

```text
PersonalModuleConfig.moviesOnly()
query.mediaKinds = {movie}
```

这样收藏和历史只返回电影。

### 9.3 音乐 App adapter

音乐 App 要注意文案和媒体类型：

```text
PersonalModuleConfig.musicOnly()
query.mediaKinds = {audio, musicAlbum, musicArtist}
```

音乐播放历史不应该叫“观看历史”，应由 config 提供 tab label。

## 10. 路由接入方式

Product App 手动维护路由表，个人模块只提供页面。

综合 App：

```text
/profile
  -> PersonalRoutePage(
       repository: PersonalRepositoryAdapter(gateway),
       imageProvider: JellyfinAppImageProvider(gateway),
       config: PersonalModuleConfig.full(),
       actions: PersonalActions(
         onOpenMedia: 根据 item.type 跳转详情页,
         onPlayMedia: 根据 item.type 播放,
       )
     )
```

电影 App：

```text
/profile
  -> PersonalRoutePage(
       repository: MoviePersonalRepositoryAdapter(gateway),
       config: PersonalModuleConfig.moviesOnly(),
       actions: PersonalActions(
         onOpenMedia: /movies/:itemId,
         onPlayMedia: /playback/video/:itemId,
       )
     )
```

音乐 App：

```text
/profile
  -> PersonalRoutePage(
       repository: MusicPersonalRepositoryAdapter(gateway),
       config: PersonalModuleConfig.musicOnly(),
       actions: PersonalActions(
         onOpenMedia: album / artist / song 分发,
         onPlayMedia: AudioPlaybackPort.playSong,
       )
     )
```

如果后续继续完善统一路由协议，可以让 `PersonalActions` 改成 `AppNavigator + RouteNavigationIntent`，但第一版回调更简单，也和当前 feature 模块风格一致。

## 11. 个人模块与现有旧 lib 的关系

旧 `lib/src/ui/pages/personal_page.dart` 已经包含了三个核心能力：

- 继续观看
- 我的收藏
- 观看历史

但它的问题也很明显：

- 直接依赖旧根包 `JellyfinClient`
- 直接 `Navigator.push` 到详情页和播放页
- 直接依赖旧 UI services 和 widgets
- 只适合旧 monolith，不适合产品矩阵

新模块可以复用它的业务概念，但不能照搬依赖方式。

正确迁移方式：

```text
旧 PersonalPage 的页面结构和 tab 概念 -> 可参考
旧 UserService 的 API 调用方式 -> 可参考
旧 JellyfinClient / Navigator / 旧 widget 依赖 -> 不迁移
```

## 12. 第一版范围建议

第一版不要做太大。建议只做：

1. `PersonalRepository` 协议
2. `PersonalModuleConfig`
3. `PersonalPage`
4. 继续观看 tab
5. 收藏 tab
6. 历史 tab
7. 收藏切换
8. Product app 接入 `/profile`
9. Movie app 接入 `/profile`

暂不做：

- 用户设置页
- 多用户切换
- 本地离线历史
- 云同步以外的本地收藏
- AI 推荐历史
- RVC 任务历史
- 复杂统计图表

这些可以后续作为个人模块二期。

## 13. 验收标准

模块设计成立的标准：

- `jellyfin_personal` 不依赖 `go_router`
- `jellyfin_personal` 不依赖 `jellyfin_api`
- `jellyfin_personal` 不依赖任何 `Product/*`
- `jellyfin_app` 和 `jellyfin_movie_app` 都能接入同一个 `PersonalPage`
- 综合 App 能看到全部媒体的继续观看、收藏、历史
- 电影 App 只看到电影范围的数据
- 收藏切换后当前列表能刷新
- 历史记录点击媒体卡片时，能跳转到对应媒体详情页，例如点击《疯狂动物城》进入《疯狂动物城》详情页
- 点击媒体由 Product App 决定跳转，个人模块不直接写路由路径
- UI 使用 `jellyfin_ui_kit`，不复制旧 UI 组件

## 14. 需要你确认的关键点

我建议第一版个人模块采用“页面 + 协议 + Product adapter”的设计：

```text
jellyfin_personal 提供页面和 PersonalRepository 协议
Product app 提供具体 repository adapter 和路由动作
```

这个方案最适合当前产品矩阵，因为它既能复用页面，又不会把综合 App、电影 App、音乐 App 的产品差异硬塞进一个模块里。

需要确认的是：第一版是否只做“继续观看 / 收藏 / 历史 / 用户资料头部”，设置、多用户、统计、AI/RVC 历史先不进入范围。
