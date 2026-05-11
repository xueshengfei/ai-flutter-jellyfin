# 第二阶段模块化进展报告

> 对应计划：`MODULARIZATION_EXECUTION_PLAN.md`
> 更新日期：2026-05-12（Task 14 完成后更新）

---

## 一、已完成内容

### Task 16: 抽 jellyfin_ai_recommendation

**状态：完成**（2026-05-11）

使用 `flutter create --template=package` 命令创建独立业务模块，完成 AI 对话推荐功能的完整解耦。

#### 模块结构

```
packages/features/jellyfin_ai_recommendation/
├── lib/
│   ├── jellyfin_ai_recommendation.dart                (barrel export)
│   └── src/
│       ├── models/ai_recommendation_models.dart       (253行) SSE事件、卡片、对话模型
│       ├── services/
│       │   ├── ai_recommendation_service.dart         (183行) AiStreamService 流式通信
│       │   ├── sse_fetch.dart                         (11行)  SSE stub
│       │   ├── sse_fetch_native.dart                  (22行)  Dio 流式（原生/鸿蒙）
│       │   └── sse_fetch_web.dart                     (44行)  XHR 流式（Web）
│       ├── pages/ai_recommend_page.dart               (846行) 解耦后的 AI 推荐页面
│       └── widgets/ai_recommend_pill.dart             (145行) 胶囊动画入口按钮
├── test/jellyfin_ai_recommendation_test.dart          (211行) 19个测试
└── pubspec.yaml
```

**依赖关系：**

```yaml
dependencies:
  jellyfin_core:       path: ../../foundation/jellyfin_core
  jellyfin_models:     path: ../../shared/jellyfin_models
  jellyfin_ui_kit:     path: ../../shared/jellyfin_ui_kit
  dio: ^5.4.0
  flutter_markdown: ^0.7.0
  equatable: ^2.0.5
```

#### 业务解耦设计（核心改动）

原始 `ai_recommend_page.dart`（871行）直接 import 5 个 feature 页面和服务：

```dart
// 解耦前 — 直接依赖具体 feature
import 'media_item_detail_page.dart';
import 'album_detail_page.dart';
import 'artist_detail_page.dart';
import 'audio_player_page.dart';
import 'audio_playback_manager.dart';
```

**解耦后**，`AiRecommendPage` 通过 4 个回调 + 2 个抽象接口实现完全解耦：

| 解耦点 | 原始耦合方式 | 解耦后方式 |
|--------|------------|-----------|
| 图片加载 | `JellyfinImageWithClient(client: widget.client)` | `JellyfinImageProvider` 抽象接口（来自 jellyfin_ui_kit） |
| 媒体详情获取 | `widget.client.mediaLibrary.getMediaItemDetail()` | `MediaItemDetailFetcher` 回调函数 |
| 视频详情页跳转 | `Navigator.push(MediaItemDetailPage(...))` | `onNavigateToMediaItem` 回调 |
| 专辑详情页跳转 | `Navigator.push(AlbumDetailPage(...))` | `onNavigateToAlbum` 回调 |
| 歌手详情页跳转 | `Navigator.push(ArtistDetailPage(...))` | `onNavigateToArtist` 回调 |
| 歌曲播放 | `AudioPlaybackManager.instance.play(...)` + `AudioPlayerPage(...)` | `onPlaySong` 回调 |

---

### Task 10: 抽 jellyfin_media

**状态：完成**（2026-05-12）

使用 `flutter create --template=package` 命令创建独立业务模块，完成通用媒体能力的解耦（媒体详情页、人物详情页、媒体项列表页、人物头像卡片）。

#### 模块结构

```
packages/features/jellyfin_media/
├── lib/
│   ├── jellyfin_media.dart                  (barrel — 仅导出 typedef)
│   ├── jellyfin_media_pages.dart            (sub-barrel — 页面)
│   ├── jellyfin_media_models.dart           (sub-barrel — 子模型)
│   ├── jellyfin_media_widgets.dart          (sub-barrel — 组件)
│   └── src/
│       ├── models/person_models.dart        (83行) Person, PersonCreditsResult
│       ├── pages/
│       │   ├── media_item_detail_page.dart  (393行) 解耦后的通用媒体详情页
│       │   ├── person_detail_page.dart      (281行) 解耦后的人物详情页
│       │   └── media_items_page.dart        (192行) 解耦后的媒体项列表页
│       └── widgets/person_avatar_card.dart  (331行) PersonAvatarCard + PersonListRow
├── test/jellyfin_media_test.dart            (425行) 19个测试
└── pubspec.yaml
```

**依赖关系：** `jellyfin_models` + `jellyfin_ui_kit`。不依赖 `jellyfin_dart`、`jellyfin_core`、`jellyfin_api`。

---

### Task 10.5: Media 契约与集成收敛

**状态：完成**（2026-05-12）

在 Task 10 基础上收敛跨模块共享契约，完成真实页面链路切换。

#### 关键改动

1. **共享 typedef 提取到 jellyfin_models**：新建 `media_contracts.dart`，集中定义 `MediaItemDetailFetcher`、`MediaItemsFetcher`、`SeasonsFetcher`
2. **统一 MediaItem DTO 映射器**：新建 `lib/src/adapters/media_item_mapper.dart`，提供 `toShared()` / `toLocal()` / `toSharedPerson()` / `toSharedSeason()` / `toSharedEpisode()` 方法
3. **子 barrel 模式**：各 feature 包拆分为模型/页面/组件独立 barrel
4. **集成点切换**：`media_libraries_page.dart` 已切换为使用新模块页面

---

### Task 12: 抽 jellyfin_movies

**状态：完成**（2026-05-12）

使用 `flutter create --template=package` 命令创建独立业务模块，完成电影筛选和详情功能的完整解耦。

#### 模块结构

```
packages/features/jellyfin_movies/
├── lib/
│   ├── jellyfin_movies.dart                  (barrel — 模型 + MovieDetailPage)
│   ├── jellyfin_movies_pages.dart            (sub-barrel — 两个页面)
│   └── src/
│       ├── models/movie_filter_models.dart   (173行) 纯 Dart 枚举 + MovieFilter
│       ├── pages/movie_filter_page.dart      (648行) 解耦后的电影筛选页
│       └── pages/movie_detail_page.dart      (237行) 解耦后的电影详情页
├── test/jellyfin_movies_test.dart            (201行) 11个测试
└── pubspec.yaml
```

**依赖关系：** `jellyfin_models`。不依赖 `jellyfin_dart`（纯 Dart `MovieSortField`/`MovieSortOrder` 枚举替代）。

#### 业务解耦设计

| 解耦点 | 原始耦合 | 解耦方式 |
|--------|---------|---------|
| 电影列表获取 | `JellyfinClient.mediaLibrary.getMovies()` | `MoviesFetcher` 回调 |
| 电影详情获取 | `JellyfinClient.mediaLibrary.getMediaItemDetail()` | `MovieDetailFetcher` 回调 |
| 播放跳转 | `Navigator.push(VideoPlayerPage(...))` | `onStartPlayback` 回调 |
| 列表布局 | `MediaListBuilder(client, ...)` | `listBuilder` 回调注入 |
| 排序/过滤类型 | `jellyfin_dart.ItemSortBy`/`ItemFilter` | 纯 Dart 枚举 |

---

### Task 13: 抽 jellyfin_series

**状态：完成**（2026-05-12）

使用 `flutter create --template=package` 命令创建独立业务模块，完成季/集导航的完整解耦。

#### 模块结构

```
packages/features/jellyfin_series/
├── lib/
│   ├── jellyfin_series.dart                  (barrel — 模型/typedef)
│   ├── jellyfin_series_pages.dart            (sub-barrel — 页面)
│   └── src/
│       ├── models/series_models.dart         (8行) EpisodesFetcher typedef
│       ├── pages/seasons_page.dart           (167行) 解耦后的季列表页
│       ├── pages/episodes_page.dart          (215行) 解耦后的集列表页
│       └── widgets/
│           ├── season_card.dart              (130行) 季卡片组件
│           ├── episode_card.dart             (143行) 集卡片（无 JellyfinClient）
│           └── episode_detail_sheet.dart     (123行) 集详情底部弹窗
├── test/jellyfin_series_test.dart            (340行) 11个测试
└── pubspec.yaml
```

**依赖关系：** `jellyfin_models`。不依赖 `jellyfin_dart`。

#### 业务解耦设计

| 解耦点 | 原始耦合 | 解耦方式 |
|--------|---------|---------|
| 季列表获取 | `JellyfinClient.mediaLibrary.getSeasons()` | `SeasonsFetcher` 回调（来自 jellyfin_models） |
| 集列表获取 | `JellyfinClient.mediaLibrary.getEpisodes()` | `EpisodesFetcher` 回调 |
| 季→集导航 | `Navigator.push(EpisodesPage(client, ...))` | `onNavigateToEpisodes` 回调 |
| 集播放 | `Navigator.push(VideoPlayerPage(client, ...))` | `onStartPlayback` 回调 |
| 列表布局 | `MediaListBuilder(client, ...)` + ViewModeManager | `listBuilder` 回调注入 |
| 视图模式 | `ViewModeSelector` + `ViewModeManager` | `appBarActions` 回调注入 |
| 集卡片图片 | `JellyfinClient` 传参 | 移除，Episode 模型自带 `getThumbnailImageUrl()` |

---

### Task 14: 抽 jellyfin_playback

**状态：完成**（2026-05-12）

使用 `flutter create --template=package` 命令创建独立业务模块，完成视频播放器和画质切换的完整解耦。

#### 模块结构

```
packages/features/jellyfin_playback/
├── lib/
│   ├── jellyfin_playback.dart                (barrel — 模型)
│   ├── jellyfin_playback_pages.dart          (sub-barrel — 页面)
│   └── src/
│       ├── models/
│       │   ├── video_quality_models.dart     (178行) VideoQuality/NetworkQualityMonitor/AutoQualityDecider
│       │   └── playback_models.dart          (64行) PlaybackInfo/PlaybackDelegate
│       └── pages/video_player_page.dart      (520行) 解耦后的视频播放页
├── test/jellyfin_playback_test.dart          (205行) 19个测试
└── pubspec.yaml
```

**依赖关系：** `jellyfin_models` + `video_player` + `chewie`。不依赖 `jellyfin_dart`。

#### 业务解耦设计（PlaybackDelegate 模式）

与之前的模块不同，播放模块使用 **委托类模式** 而非独立回调函数。`PlaybackDelegate` 将 6 个操作聚合为一个类型：

| 解耦点 | 原始耦合 | 解耦方式 |
|--------|---------|---------|
| 获取播放 URL | `PlaybackService(client).getPlaybackUrl()` | `delegate.getPlaybackUrl` |
| 开始播放会话 | `PlaybackService(client).startPlaybackSession()` | `delegate.startSession` |
| 切换画质 | `PlaybackService(client).switchQuality()` | `delegate.switchQuality` |
| 停止转码 | `PlaybackService(client).stopActiveEncodings()` | `delegate.stopEncoding` |
| 停止会话 | `PlaybackService(client).stopPlaybackSession()` | `delegate.stopSession` |
| 资源清理 | `PlaybackService(client).dispose()` | `delegate.dispose` |

**PlaybackService 保留在根包**：深度耦合 `jellyfin_dart`（DeviceProfile、PlaybackInfoDto、PlaybackProgressInfo 等），不随模块外移。

**根包集成**：`media_libraries_page.dart` 新增 `_createPlaybackDelegate()` 工厂方法，将 `PlaybackService` 实例包装为 `PlaybackDelegate`，处理类型转换（root `PlaybackInfo` ↔ playback `PlaybackInfo`，root `VideoQuality` ↔ playback `VideoQuality`）。

---

## 二、未完成内容

- **Task 11 jellyfin_home** — 首页独立成包（**延后至 Round 4**，依赖 Auth/App Shell 稳定，Leader 建议）
- **Task 15 jellyfin_music** — 音乐业务模块（依赖 Task 14，现已解锁）
- 根包旧文件保留在原位作为兼容层（Task 18 facade 收敛时清理）

---

## 三、已解决的问题

### 问题 1：根包 MediaItem 与 jellyfin_models MediaItem 类型冲突（已解决）

**方案：** 创建统一 `MediaItemMapper`（`lib/src/adapters/media_item_mapper.dart`），提供 `toShared()` / `toLocal()` / `toSharedPerson()` / `toSharedSeason()` / `toSharedEpisode()` 方法。所有集成点统一使用此映射器。

### 问题 2：typedef 跨模块重复定义（已解决）

**方案：** 提取通用 typedef 到 `jellyfin_models/media_contracts.dart`。`MediaItemDetailFetcher`、`MediaItemsFetcher`、`SeasonsFetcher` 等共享一份定义。

### 问题 3：barrel export 与根包旧版同名类（当前方案：hide + 子 barrel）

**方案：** 根包 `jellyfin_service.dart` 使用 `hide` 隐藏同名类型（如 `hide MovieFilter, MovieFilterResult, MovieDetailPage`；`hide VideoQuality, NetworkQualityMonitor, AutoQualityDecider, PlaybackInfo, VideoPlayerPage`）。新模块通过子 barrel 导出页面。Task 18 facade 收敛时统一处理。

### 问题 4：PlaybackDelegate 类型桥接（已解决）

**方案：** 根包 `_createPlaybackDelegate()` 工厂方法将 root 的 `PlaybackService` 包装为 playback 包的 `PlaybackDelegate`。通过 `.name` 属性匹配完成 `VideoQuality` 枚举跨包转换，通过手动构造完成 `PlaybackInfo` 类型转换。

---

## 四、当前文件变更清单

### 新增独立包

| 包 | 文件数 | 代码行 | 说明 |
|----|--------|--------|------|
| `packages/features/jellyfin_ai_recommendation/**` | 9 lib + 1 test | 1534 行 lib + 211 行 test | AI 推荐业务模块 |
| `packages/features/jellyfin_media/**` | 6 lib + 1 test | 1280 行 lib + 425 行 test | 通用媒体业务模块 |
| `packages/features/jellyfin_movies/**` | 5 lib + 1 test | 1058 行 lib + 201 行 test | 电影业务模块 |
| `packages/features/jellyfin_series/**` | 7 lib + 1 test | 786 行 lib + 340 行 test | 剧集业务模块 |
| `packages/features/jellyfin_playback/**` | 5 lib + 1 test | 762 行 lib + 205 行 test | 播放业务模块 |

### 根包改动

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `pubspec.yaml` | 修改 | 新增 5 个 feature 包依赖 |
| `lib/jellyfin_service.dart` | 修改 | 新增各 feature 包 export（hide 同名类型避免 ambiguous_export） |
| `lib/src/adapters/media_item_mapper.dart` | 新增 | 统一 DTO 映射器（MediaItem/Person/Season/Episode） |
| `lib/src/ui/pages/media_libraries_page.dart` | 修改 | 集成点切换到新模块页面（AI/Media/Movies/Series/Playback） |

### 根包保留（兼容层，未删除）

以下旧文件仍被根包其他页面直接引用，暂时保留：

| 文件 | 说明 |
|------|------|
| `lib/src/ui/pages/media_item_detail_page.dart` | 旧版媒体详情页（接收 `JellyfinClient`） |
| `lib/src/ui/pages/person_detail_page.dart` | 旧版人物详情页（接收 `JellyfinClient`） |
| `lib/src/ui/pages/media_items_page.dart` | 旧版媒体列表页（接收 `JellyfinClient`） |
| `lib/src/ui/pages/seasons_page.dart` | 旧版季列表页（接收 `JellyfinClient`） |
| `lib/src/ui/pages/episodes_page.dart` | 旧版集列表页（接收 `JellyfinClient`） |
| `lib/src/ui/pages/movie_detail_page.dart` | 旧版电影详情页（接收 `JellyfinClient`） |
| `lib/src/ui/pages/movie_filter_page.dart` | 旧版电影筛选页（接收 `JellyfinClient`） |
| `lib/src/ui/pages/video_player_page.dart` | 旧版视频播放页（接收 `JellyfinClient`） |
| `lib/src/ui/widgets/person_avatar_card.dart` | 旧版人物头像卡片 |
| `lib/src/models/person_models.dart` | 旧版人物模型（`type` 为 `jellyfin_dart.PersonKind`） |
| `lib/src/ui/pages/ai_recommend_page.dart` | 旧版 AI 页面 |
| `lib/src/services/ai_recommendation_service.dart` | 旧版 SSE 服务 |
| `lib/src/models/ai_recommendation_models.dart` | 旧版 AI 模型 |

---

## 五、验证结果

| 检查项 | 结果 |
|--------|------|
| `jellyfin_ai_recommendation` 独立 `flutter test` | 19/19 通过 |
| `jellyfin_media` 独立 `flutter test` | 19/19 通过 |
| `jellyfin_movies` 独立 `flutter test` | 11/11 通过 |
| `jellyfin_series` 独立 `flutter test` | 11/11 通过 |
| `jellyfin_playback` 独立 `flutter test` | 19/19 通过 |
| `jellyfin_core` 独立 `flutter test` | 17/17 通过 |
| `jellyfin_api` 独立 `flutter test` | 8/8 通过 |
| `jellyfin_models` 独立 `flutter test` | 8/8 通过 |
| `jellyfin_ui_kit` 独立 `flutter test` | 14/14 通过 |
| 根包 `flutter test` | 24/24 通过 |
| `jellyfin_playback` 不依赖 `jellyfin_dart` | **确认** — 零 vendor 依赖 |
| `jellyfin_playback` 不依赖 `JellyfinClient` | **确认** — 通过 PlaybackDelegate 解耦 |
| **10 包总测试数** | **150 个全部通过** |

---

## 六、下一步

1. Task 15（jellyfin_music）— 音乐业务模块
2. Task 11（jellyfin_home）— **Round 4**（依赖 Auth/App Shell）

---

## 七、依赖关系图（当前实际）

```
jellyfin_dart (vendor)
    ↑
jellyfin_api ──→ jellyfin_core
    ↑                  ↑
jellyfin_ui_kit ──→ jellyfin_models
    ↑                  ↑
jellyfin_testing ──→ jellyfin_models + jellyfin_core
    ↑
jellyfin_ai_recommendation ──→ jellyfin_core + jellyfin_models + jellyfin_ui_kit
    ↑
jellyfin_media ──→ jellyfin_models + jellyfin_ui_kit
jellyfin_movies ──→ jellyfin_models
jellyfin_series ──→ jellyfin_models
jellyfin_playback ──→ jellyfin_models + video_player + chewie

根包 jellyfin_service ──→ 上述所有包
    ├── jellyfin_service.dart export 旧版页面/组件（兼容层，hide 同名类型）
    ├── media_libraries_page.dart → AiRecommendPage（已切换）
    ├── media_libraries_page.dart → jellyfin_media pages（已切换）
    ├── media_libraries_page.dart → jellyfin_movies pages（已切换）
    ├── media_libraries_page.dart → jellyfin_series pages（已切换）
    └── media_libraries_page.dart → jellyfin_playback pages（已切换）
```

---

## 八、阶段评估

| 子阶段 | 状态 | 内容 |
|--------|------|------|
| Phase 1-A：基础包抽取与目录重组 | **完成** | Task 1, 2, 4 |
| Phase 1-B：API/UI Kit/Testing 补齐 | **完成** | Task 3, 5, 6, 7 |
| Phase 1-C：App Shell + Auth 验证闭环 | **待开始** | Task 8, 9 |
| Phase 2-A：AI 推荐业务解耦 | **完成** | Task 16 |
| Phase 2-B：通用媒体能力解耦 | **完成** | Task 10, 10.5 |
| Phase 2-C：电影/剧集模块 | **完成** | Task 12, 13 |
| Phase 2-D：播放模块 | **完成** | Task 14 |
| Phase 2-E：音乐模块 | **待开始** | Task 15 |
| Phase 2-F：首页模块 | **Round 4** | Task 11（延后，依赖 Auth/App Shell） |
