# Phase 5B 进展报告：核心业务路由迁移

> 阶段目标：将 4 个核心详情/列表路由注册到 go_router，FeaturePageFactory 注入 AppNavigator，逐步替代旧 Navigator.push。

## 一、完成状态

| Task | 描述 | 状态 |
|------|------|------|
| 5B-1 | 注册 movieDetail / mediaDetail / seriesSeasons / seriesEpisodes 4 个路由 | ✅ 完成 |
| 5B-2 | FeaturePageFactory 注入 `AppNavigator?`，12 个回调加 navigator 分支 | ✅ 完成 |
| 5B-3 | ContinueWatchingCard 注入 `AppNavigator?`，优先走路由协议 | ✅ 完成 |
| 5B-4 | JellyfinRouteIntents 辅助类（8 个类型安全工厂方法） | ✅ 完成 |
| 5B-5 | createJellyfinGoRouter 新增 `initialLocation` 参数 | ✅ 完成 |
| 5B-6 | 边界检查规则 7 改为基线守卫（baseline=41） | ✅ 完成 |
| 5B-7 | go_router 行为测试（11 个用例） | ✅ 完成 |
| 5B-8 | 旧文档归档到 `docs/archive/modularization/` | ✅ 完成 |

## 二、路由注册进度（10/14）

| 路由名 | URL 路径 | 注册状态 | Phase |
|--------|----------|----------|-------|
| `auth.login` | `/login` | ✅ 已注册 | 5 |
| `libraries.index` | `/libraries` | ✅ 已注册 | 5 |
| `libraries.detail` | `/libraries/:libraryId` | ✅ 已注册 | 5 |
| `movies.detail` | `/movies/:itemId` | ✅ 已注册 | **5B** |
| `media.detail` | `/media/items/:itemId` | ✅ 已注册 | **5B** |
| `series.seasons` | `/series/:seriesId/seasons` | ✅ 已注册 | **5B** |
| `series.episodes` | `/series/:seriesId/seasons/:seasonId/episodes` | ✅ 已注册 | **5B** |
| `playback.video` | `/playback/video/:itemId` | ✅ 已注册 | 5 |
| `ai.recommend` | `/ai/recommend` | ✅ 已注册 | 5 |
| `profile` | `/profile` | ✅ 已注册 | 5 |
| `music.library` | `/music/libraries/:libraryId` | ❌ 待注册 | — |
| `music.album` | `/music/albums/:albumId` | ❌ 待注册 | — |
| `music.artist` | `/music/artists/:artistId` | ❌ 待注册 | — |
| `music.search` | `/music/search` | ❌ 待注册 | — |

**10/14 路由已注册**，剩余 4 个均为音乐模块路由。

## 三、新增/修改文件清单

### 3.1 路由注册层（jellyfin_go_router.dart）

`jellyfin_go_router.dart` 从 226 行增长到 493 行，新增 4 个内部 Widget：

| 内部 Widget | 路由 | 说明 |
|-------------|------|------|
| `_MovieDetailRoutePage` | `/movies/:itemId` | FutureBuilder 加载 MediaItem → MovieDetailPage |
| `_MediaDetailRoutePage` | `/media/items/:itemId` | FutureBuilder 加载 MediaItem → MediaItemDetailPage |
| `_SeriesSeasonsRoutePage` | `/series/:seriesId/seasons` | FutureBuilder 加载 Series → SeasonsPage |
| `_EpisodesRoutePage` | `/series/:seriesId/seasons/:seasonId/episodes` | FutureBuilder 加载 Series+Season → EpisodesPage |

### 3.2 jellyfin_core 协议扩展

| 文件 | 类型 | 说明 |
|------|------|------|
| `jellyfin_route_intents.dart` | 新建（67 行） | 8 个类型安全工厂方法 |
| `jellyfin_route_names.dart` | 新建（20 行） | 14 个路由名常量 |
| `navigation_intent.dart` | 修改 | RouteNavigationIntent 支持路径参数 |
| `jellyfin_core.dart` | 修改 | 导出 route_intents + route_names |

### 3.3 App Shell 层修改

| 文件 | 变更 |
|------|------|
| `feature_page_factory.dart` | +72 行：注入 `AppNavigator?`，12 个 Navigator.push 回调加 navigator 分支 |
| `app_session_controller.dart` | +9 行：新增 `setSession()` |
| `go_router_app_navigator.dart` | 新建 96 行：GoRouterAppNavigator 适配器 |
| `jellyfin_app_shell.dart` | 新建 63 行：根 MaterialApp.router 封装 |
| `app_shell.dart` | +3 行：barrel 导出新文件 |

### 3.4 UI 层修改

| 文件 | 变更 |
|------|------|
| `media_libraries_page.dart` | +165 行：接入 navigator/onLogout，优先走路由协议 |
| `seasons_page.dart` | +73 行：注入 navigator 走路由协议 |
| `continue_watching_card.dart` | +9 行：注入 AppNavigator? |

### 3.5 基础设施

| 文件 | 变更 |
|------|------|
| `check_module_boundaries.dart` | +59 行：规则 7 改为基线守卫（baseline=41） |
| `example/lib/main.dart` | 使用 JellyfinAppShell 替代手动 MaterialApp |
| `pubspec.yaml` | 添加 go_router 依赖 |

### 3.6 文档归档

Phase 1-4 的进度报告、设计文档从根目录迁移到 `docs/archive/modularization/`：
- `MODULARIZATION_DESIGN.md`
- `MODULARIZATION_EXECUTION_PLAN.md`
- `PHASE1_PROGRESS_REPORT.md` ~ `PHASE4_PROGRESS_REPORT.md`
- `PHASE2_STRATEGY_REPORT.md`, `PHASE3_STRATEGY_REPORT.md`, `PHASE4_STRATEGY_REPORT.md`
- `README.md`（归档索引）

## 四、FeaturePageFactory navigator 注入详情

`FeaturePageFactory` 构造函数新增可选参数 `AppNavigator? navigator`，12 个回调方法均添加了 navigator 分支：

```dart
FeaturePageFactory(this._session, {AppNavigator? navigator})
    : _navigator = navigator { ... }
```

| 回调位置 | navigator 路由名 | 旧路径 |
|----------|-----------------|--------|
| `movieFilterPage.onNavigateToMovie` | `movieDetail` | Navigator.push → movieDetailPage |
| `movieDetailPage.onStartPlayback` | `playbackVideo` | Navigator.push → VideoPlayerPage |
| `mediaItemsPage.onNavigateToMediaItem` | `mediaDetail` | Navigator.push → mediaItemDetailPage |
| `mediaItemDetailPage.onNavigateToEpisodes` | `seriesEpisodes` | Navigator.push → episodesPage |
| `mediaItemDetailPage.onStartPlayback` | `playbackVideo` | Navigator.push → VideoPlayerPage |
| `personDetailPage.onNavigateToMediaItem` | `mediaDetail` | Navigator.push → mediaItemDetailPage |
| `episodesPage.onStartPlayback` | `playbackVideo` | Navigator.push → VideoPlayerPage |
| `artistDetailPage.onNavigateToAlbum` | `musicAlbum` | Navigator.push → albumDetailPage |
| `aiRecommendPage.onNavigateToMediaItem` | `mediaDetail` | Navigator.push → mediaItemDetailPage |
| `aiRecommendPage.onNavigateToAlbum` | `musicAlbum` | Navigator.push → albumDetailPage |
| `aiRecommendPage.onNavigateToArtist` | `musicArtist` | Navigator.push → artistDetailPage |
| `_SeriesSeasonsRoutePage.onNavigateToEpisodes` | `seriesEpisodes` | Navigator.push → episodesPage |

**策略**：navigator 不为 null 时走新路由协议，为 null 时保留旧 `Navigator.push` 作为回退。这确保了新旧代码可以并存，逐步迁移。

## 五、测试与验证

### 5.1 新增测试

| 测试文件 | 用例数 | 覆盖范围 |
|----------|--------|----------|
| `test/go_router_app_navigator_test.dart` | 11 | 登录重定向、路径参数映射、参数校验、pushIntent、initialLocation |

### 5.2 验证结果

```
# jellyfin_core 测试
→ 27 passed（含 RouteNames + RouteIntents + NavigationIntent 测试）

# root 包测试
→ 55 passed（含 app_shell + go_router + integration_smoke + playback_port）

# 合计
→ 82 个全部通过
```

### 5.3 边界检查

```
dart scripts/check_module_boundaries.dart
→ ✓ 所有模块边界检查通过
→ ℹ 41/41 处仍使用 MaterialPageRoute（基线守卫通过）
```

## 六、遇到的问题

### 6.1 GoRouter + JellyfinClient 测试隔离

**问题**：go_router 路由 builder 内部会调用 `JellyfinClient` 发起真实网络请求（如 `getMediaItemDetail`），在 `testWidgets` 中无法直接验证路由是否正确渲染目标页面。

**解决方案**：
- 登录重定向测试使用独立的精简 `GoRouter`（只注册 `/login` 和 `/libraries` 两个 Scaffold 页面），只验证重定向逻辑
- 路由参数映射测试用 `router.pushNamed()` 验证路径参数解析正确，不实际渲染页面
- 缺参校验测试用 `expect(throwsArgumentError)` 确保参数完整性

### 6.2 FeaturePageFactory 双模式兼容

**问题**：`FeaturePageFactory` 需要同时支持旧调用方式（无 navigator）和新调用方式（有 navigator），不能破坏已有代码。

**解决方案**：每个回调方法内部先检查 `_navigator != null`，有则走 `nav.push(routeName, arguments: {...})`，无则保留原有 `Navigator.push(ctx, MaterialPageRoute(...))` 模式。`jellyfin_go_router.dart` 创建 factory 时传入 navigator，旧代码不传即可。

### 6.3 路由页面数据获取

**问题**：go_router 路由 builder 只能拿到 `pathParameters`（string），但 FeaturePageFactory 需要完整的 `MediaItem` 对象。

**解决方案**：为每个详情路由创建内部 Widget（如 `_MovieDetailRoutePage`），内部用 `FutureBuilder` 通过 `getMediaItemDetail(itemId)` 获取完整对象，再传递给 FeaturePageFactory。同时提供加载/错误态 UI。

### 6.4 旧文档文件残留

**问题**：Phase 5B 提交中将旧进度报告移到 `docs/archive/modularization/`，但 git status 显示根目录的 `MODULARIZATION_DESIGN.md`、`PHASE1_PROGRESS_REPORT.md` 等文件仍显示为 ` D`（已删除未暂存），说明归档操作是 `git mv` 后又删除了源文件，但未正确提交删除操作。

**当前状态**：这些文件在工作区已被删除（` D` 状态），但变更尚未暂存和提交。下次提交时应一并处理。

## 七、迁移进度

### 7.1 MaterialPageRoute 使用分布

| 分类 | 数量 | 说明 |
|------|------|------|
| A 类：FeaturePageFactory 兼容桥 | 12 | 有 navigator 分支，旧路径作为回退保留 |
| B 类：活跃页面待迁移 | ~15 | music_library_page / media_item_detail_page / ai_recommend_page / personal_page |
| C 类：Deprecated 页面 | ~12 | 随 deprecated 页面自然退出 |
| **合计** | **~41** | 基线守卫值 |

### 7.2 路由注册进度

```
Phase 5:  6/14 路由注册（login/libraries/library/aiRecommend/profile/playbackVideo）
Phase 5B: +4/14 路由注册（movieDetail/mediaDetail/seriesSeasons/seriesEpisodes）
剩余:     4/14 路由待注册（music.library/music.album/music.artist/music.search）
```

## 八、下一步建议（Phase 5C）

1. **注册音乐模块 4 个路由**：musicAlbum / musicArtist / musicLibrary / musicSearch
2. **迁移活跃页面的 MaterialPageRoute**：优先处理 `music_library_page.dart`（9 处）和 `media_item_detail_page.dart`（5 处）
3. **清理 deprecated 页面**：考虑直接移除带 `@Deprecated` 标记的旧页面
4. **提交工作区变更**：处理根目录残留的旧文档文件删除状态
5. **更新基线值**：每迁移一批 MaterialPageRoute 后更新 `materialPageRouteBaseline`
