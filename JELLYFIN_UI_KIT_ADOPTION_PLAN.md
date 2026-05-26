# Jellyfin UI Kit 引用与迁移方案

> 目标：把旧 `lib/` 中已经验证过的通用视觉能力沉淀到 `packages/shared/jellyfin_ui_kit`，再由 `Product/jellyfin_app` 统一装配给上层业务模块，使新 App 逐步达到旧 `lib` 的媒体库、列表、详情、人物、继续观看等业务体验。

## 1. 当前判断

这次不是简单把旧 `lib/src/ui/widgets` 复制到 `jellyfin_ui_kit`。正确目标是把“跨业务可复用的 UI 表达”做成共享组件，把“路由、数据请求、播放、筛选、音乐播放状态”等业务能力继续留在 App 或 feature 模块里。

当前 `jellyfin_ui_kit` 已经具备一批从旧 `lib/` 迁出的组件：

- `JellyfinImageProvider` / `JellyfinImage`
- `LibraryCard`
- `ContinueWatchingCard`
- `MediaItemCard`
- `MediaItemCardWithActions`
- `MediaListBuilder`
- `ViewModeSelector`
- `MediaGroupedScrollView`
- `AlphabetIndexBar`
- `PersonAvatarCard` / `PersonListRow`
- 4 种媒体列表布局：`BannerListView`、`VerticalListView`、`PosterGridView`、`CardGridView`

这说明组件抽取方向已经开始对了，但新 `Product/jellyfin_app` 还没有把这些 UI 能力系统性接进去。现在的问题不是“组件不够”，而是“上层装配层没有统一使用”。

## 2. 分层引用规则

推荐依赖方向如下：

```text
Product/jellyfin_app
  ├── 依赖 feature 模块：auth / media / movies / series / music / playback / ai / rvc
  ├── 依赖 jellyfin_ui_kit：统一装配图片、列表、视图模式、首页卡片
  └── 依赖 data/gateway：提供 Jellyfin 数据和认证 token

feature 模块
  ├── 可依赖 jellyfin_models
  ├── 可依赖 jellyfin_ui_kit，但只能使用通用视觉组件
  └── 不依赖 go_router、不依赖 Product/jellyfin_app、不依赖具体 ApiClient

jellyfin_ui_kit
  ├── 可依赖 flutter、jellyfin_models、shimmer、shared_preferences
  └── 不依赖 go_router、jellyfin_api、jellyfin_dart、Product app、播放模块、音乐模块
```

也就是说，上层业务不是直接到处 `new` 旧 widget，而是按两种方式引用：

1. **Feature 内部直接使用 UI Kit**
   适合人物头像、认证图片、媒体卡片这类“业务页面天然需要展示”的通用视觉组件。例如 `jellyfin_media` 的人物详情页可以直接依赖 `jellyfin_ui_kit`。

2. **Product app 装配后注入 Feature**
   适合列表布局、视图模式、AppBar 操作、路由跳转、图片 provider 这类需要和 App 状态协同的能力。例如 `MovieFilterPage` 不应该自己知道 `ViewModeManager`，应由 `Product/jellyfin_app` 通过 `listBuilder` 和 `appBarActions` 注入。

## 3. 10 个通用 UI 组件的定位

| 序号 | UI Kit 组件 | 来源能力 | 上层使用方式 | 不应包含 |
|---|---|---|---|---|
| 1 | `JellyfinImageProvider` | 旧认证图片加载适配层 | Product app 实现具体 provider | 具体 `ApiClient`、token 保存 |
| 2 | `JellyfinImage` | 旧 `JellyfinImage` 认证图片组件 | Feature / Product 直接使用 | 路由、业务请求 |
| 3 | `LibraryCard` | 首页媒体库卡片 | Product 首页直接使用 | 点击后的路由判断 |
| 4 | `ContinueWatchingCard` | 继续观看横向卡片 | Product 首页直接使用 | 播放页跳转逻辑 |
| 5 | `MediaItemCard` | 海报媒体卡片 | 列表布局内部或 Feature 使用 | 数据加载 |
| 6 | `MediaItemCardWithActions` | 带操作按钮的媒体卡片 | 需要收藏/播放/更多操作的页面使用 | 具体收藏 API |
| 7 | `MediaListBuilder` | 旧多视图列表入口 | Product route 层注入给电影/剧集/媒体页 | 自己读取业务数据 |
| 8 | `ViewModeSelector` | 旧视图切换入口 | Product route 层放进 AppBar | 强绑定某个页面 |
| 9 | `AlphabetIndexBar` | 字母快速索引 | 演员、音乐艺术家、分组列表使用 | 数据分组算法之外的业务请求 |
| 10 | `PersonAvatarCard` / `PersonListRow` | 详情页人物横滑列表 | `jellyfin_media`、电影详情页使用 | 人物详情路由 |

注意：`MiniPlayerBar`、`LyricsPanel`、`EpisodeCard`、`MovieFilterSheet`、`RvcPage` 不建议放入 `jellyfin_ui_kit`。这些是明确的业务组件，应该留在对应 feature 模块。

## 4. Product app 需要提供的装配能力

`Product/jellyfin_app` 应新增一个轻量的 UI 装配层，建议路径：

```text
Product/jellyfin_app/lib/src/ui/
  jellyfin_app_image_provider.dart
  view_mode_media_list_host.dart
  app_ui_composition.dart
```

### 4.1 `jellyfin_app_image_provider.dart`

职责：实现 `JellyfinImageProvider`，把 UI Kit 的图片请求转成当前登录用户的 Jellyfin 认证图片请求。

建议输入：

- 当前 `LegacyJellyfinGateway.apiClient`
- 或者一个更干净的 `ImageGateway` 接口

短期可以复用现有 `LegacyJellyfinGateway.apiClient`，但不要让 `jellyfin_ui_kit` 直接依赖 `ApiClient`。

### 4.2 `view_mode_media_list_host.dart`

职责：把 `ViewModeSelector` 和 `MediaListBuilder` 绑定起来。

原因：`ViewModeSelector` 负责改配置，`MediaListBuilder` 负责按配置渲染列表。新 app 的 route 层现在是 `StatelessWidget` 为主，如果直接散落写，会很快重复。建议封装一个 Product app 层的小 host：

```dart
class ViewModeMediaListHost extends StatefulWidget {
  final String? libraryId;
  final List<MediaItem> items;
  final JellyfinImageProvider imageProvider;
  final ValueChanged<MediaItem> onTap;
}
```

它内部负责：

- 读取 `ViewModeManager().getViewModeConfig(libraryId)`
- 渲染 `MediaListBuilder`
- 当 `ViewModeSelector` 回调时刷新当前 config

如果 AppBar 里要显示 `ViewModeSelector`，可以让 route page 保持一个 `ViewModeConfig` 状态，或者提供一个 `ViewModeScope`。第一阶段建议先用 route page `StatefulWidget`，成本最低。

### 4.3 `app_ui_composition.dart`

职责：集中暴露常用构造方法，避免每个 route page 重复写 UI Kit 接线。

建议包含：

- `JellyfinImageProvider createImageProvider(JellyfinGateway gateway)`
- `Widget buildMediaList({required libraryId, required items, required onTap})`
- `Widget buildViewModeAction({required libraryId, required onChanged})`

这不是后端式“大 Factory”，而是 App 装配层。它不创建业务对象，只负责把 Product app 的数据能力和 UI Kit 的视觉能力接起来。

## 5. 新 App 逐页追平旧 lib 业务效果

### 5.1 登录后的首页 `/libraries`

当前 `Product/jellyfin_app/lib/src/features/home/media_libraries_page.dart` 里还有私有 `_LibraryCard` 和 `_ContinueWatchingCard`。

建议改造：

- 引入 `package:jellyfin_ui_kit/jellyfin_ui_kit.dart`
- 由 Product app 注入 `JellyfinImageProvider`
- 使用 `LibraryCard`
- 使用 `ContinueWatchingCard`

这样首页能追平旧 lib 的两个核心体验：

- 媒体库卡片统一样式
- 继续观看卡片带封面和进度条

### 5.2 电影列表 `/libraries/:libraryId/movies`

当前 `MovieFilterPage` 已经预留：

- `listBuilder`
- `appBarActions`

建议由 `Product/jellyfin_app/lib/src/features/media/media_route_pages.dart` 注入：

- `ViewModeSelector`
- `MediaListBuilder`
- `JellyfinImageProvider`

这样电影列表能追平旧 lib 的多视图切换能力：横幅、列表、海报、卡片网格。

### 5.3 剧集列表 `/libraries/:libraryId/series`

当前 `SeriesListRoutePage` 使用 `MediaItemsPage`，但没有注入 UI Kit 列表。

建议改造：

- `MediaItemsPage.listBuilder` 使用 `MediaListBuilder`
- AppBar 可加入 `ViewModeSelector`
- 点击 item 仍由 Product route 层跳转 `/media/items/:itemId`

这样 TV Shows 列表可以和电影列表共享同一套多视图能力。

### 5.4 通用详情页 `/media/items/:itemId`

当前 `MediaItemDetailPage` 仍有一些 `Image.network` 和局部人物组件来源不一致的问题。

建议：

- 详情页头图、封面统一改成 `JellyfinImage`
- 人物列表统一使用 UI Kit 的 `PersonAvatarCard` / `PersonListRow`
- 详情页不处理路由，人物点击继续通过 `onNavigateToPerson`

这样详情页可以接近旧 lib 的封面、背景图、演员/导演/编剧列表效果，同时保持 feature 不依赖路由。

### 5.5 人物详情页

`jellyfin_media` 的 `PersonDetailPage` 已经要求 `JellyfinImageProvider`，这是正确方向。

Product route 层需要补齐：

- 人物详情路由
- `imageProvider` 注入
- 人物相关媒体列表使用 `MediaItemCard` 或 `MediaListBuilder`

### 5.6 AI 推荐页

`jellyfin_ai_recommendation` 已经依赖 `JellyfinImageProvider`，方向正确。

Product app 只需要保证：

- AI 页面由 App 层传入同一个 `JellyfinImageProvider`
- AI 推荐 item 的播放/详情跳转通过回调或统一路由协议处理
- AI 模块不要自己依赖 `go_router`

### 5.7 音乐模块

音乐模块不要为了“统一”强行套 `MediaItemCard`。

音乐页有专辑、艺术家、歌曲、歌词、迷你播放器，这些是音乐业务 UI。建议只复用：

- `JellyfinImage`
- 必要时复用 `AlphabetIndexBar`
- 必要时复用通用 loading/error/empty 组件（如果后续加入 UI Kit）

`MiniPlayerBar` 保持在 `jellyfin_music`，不要移动到 UI Kit。

## 6. 推荐执行顺序

### Phase A：先让 Product app 有统一图片能力

1. 在 `Product/jellyfin_app` 新增 `JellyfinAppImageProvider`
2. 从 `LegacyJellyfinGateway.apiClient` 获取认证能力
3. 替换首页、详情页、AI 页中直接 `Image.network` 的路径
4. 验证登录后的封面图在需要 token 的服务器上能加载

### Phase B：首页替换私有卡片

1. `MediaLibrariesPage` 增加 `imageProvider` 入参
2. 删除私有 `_LibraryCard`
3. 删除私有 `_ContinueWatchingCard`
4. 使用 UI Kit 的 `LibraryCard` 和 `ContinueWatchingCard`

### Phase C：电影/剧集列表接入多视图

1. 把 `MoviesRoutePage` 改成 `StatefulWidget`
2. 注入 `ViewModeSelector` 到 `MovieFilterPage.appBarActions`
3. 注入 `MediaListBuilder` 到 `MovieFilterPage.listBuilder`
4. 对 `SeriesListRoutePage` 做同样处理

### Phase D：详情页视觉追平

1. `MediaItemDetailPage` 使用 `JellyfinImage`
2. `MovieDetailPage` 使用 `JellyfinImage`
3. 人物列表统一使用 UI Kit 的 `PersonAvatarCard`
4. 补 Product app 的人物详情 route

### Phase E：清理重复组件

1. 删除 Product app 内重复的首页卡片
2. 删除 feature 内重复的人物头像组件
3. 保留业务专属组件：`EpisodeCard`、`MiniPlayerBar`、`LyricsPanel`、`MovieFilterSheet`
4. 每删一个重复组件都跑对应 package 的 `flutter analyze`

## 7. 员工需要遵守的边界

必须遵守：

- `jellyfin_ui_kit` 只放视觉组件、布局组件、轻量 UI 状态，不放业务请求。
- `jellyfin_ui_kit` 不引入 `go_router`。
- `jellyfin_ui_kit` 不引入 `jellyfin_api`、`jellyfin_dart`、旧根包 `jellyfin_service`。
- `Product/jellyfin_app` 负责路由、Gateway、认证 token、图片 provider、播放跳转。
- feature 页面通过回调暴露动作，不自己跳转。

可以接受：

- feature 直接依赖 `jellyfin_ui_kit` 使用通用组件。
- Product app 通过 `listBuilder`、`appBarActions` 把 UI Kit 注入 feature。
- UI Kit 依赖 `jellyfin_models`，因为媒体卡片需要稳定共享模型。

不建议：

- 把 `MovieFilterSheet` 放到 UI Kit。
- 把音乐迷你播放器放到 UI Kit。
- 把 RVC 页面放到 UI Kit。
- 为了复用而让所有业务页长得完全一样。

## 8. 验收标准

完成后新 app 至少达到以下效果：

- 登录后首页使用 UI Kit 的媒体库卡片和继续观看卡片。
- 首页、电影列表、剧集列表、详情页不再直接散落 `Image.network` 加载 Jellyfin 认证图片。
- 电影和剧集列表支持旧 lib 的视图切换：横幅、列表、海报、卡片网格。
- 详情页的人物列表样式统一。
- AI 推荐页、人物详情页、媒体详情页共用同一个 `JellyfinImageProvider`。
- `jellyfin_ui_kit` 仍然不依赖 Product app、路由、ApiClient。
- `Product/jellyfin_app`、`packages/shared/jellyfin_ui_kit`、受影响 feature package 均能通过 `flutter analyze`。

## 9. 给员工的最终建议

先不要继续盲目“提取更多组件”。这一步应该先把已经提取到 `jellyfin_ui_kit` 的组件接进新 App，让首页、电影列表、剧集列表、详情页真正用起来。

如果新 App 还在复制旧 `lib/` 的私有卡片和 `Image.network`，说明模块化只是搬了文件，还没有形成共享 UI 能力。优先把 Product app 的 UI 装配层补起来，之后再决定是否需要继续抽第 11、第 12 个组件。
