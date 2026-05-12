# 第二阶段模块化进展报告

> 对应计划：`MODULARIZATION_EXECUTION_PLAN.md`
> 更新日期：2026-05-12（Task 15 完成后更新）

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
- **Task 15 jellyfin_music** — 音乐业务模块（专辑详情、艺术家详情和部分音乐模型已抽取完成；音乐主库、搜索、歌词、音频播放状态仍保留在根包）
- 根包旧文件保留在原位作为兼容层（Task 18 facade 收敛时清理）

### Task 15: 抽 jellyfin_music

**状态：完成**（2026-05-12）

抽取音乐专辑详情页和艺术家详情页为独立模块。采用回调模式解耦，模型复制（纯数据类，无 fromDto）。

#### 模块结构

```
packages/features/jellyfin_music/
├── lib/
│   ├── jellyfin_music.dart            (barrel: models + typedefs)
│   ├── jellyfin_music_pages.dart      (sub-barrel: pages)
│   └── src/
│       ├── models/music_models.dart   (280行) MusicAlbum/Artist/Song/Genre + 列表结果 + 回调 typedef
│       ├── pages/album_detail_page.dart  (220行) 解耦版专辑详情页
│       └── pages/artist_detail_page.dart (280行) 解耦版艺术家详情页
├── test/jellyfin_music_test.dart      (283行) 21个测试
└── pubspec.yaml
```

**依赖关系：**

```yaml
dependencies:
  flutter: sdk: flutter
  equatable: ^2.0.5
  cached_network_image: ^3.4.0
```

#### 解耦设计

- **回调 typedef**: `AlbumDetailFetcher`, `AlbumSongsFetcher`, `ArtistDetailFetcher`, `ArtistAlbumsFetcher`, `OnPlaySong`, `OnNavigateToAlbum`
- **根包集成**: media_libraries_page.dart 中 AI 推荐回调转换为 `music.MusicAlbum` / `music.MusicArtist`，通过工厂方法构建新页面
- **hide 模式**: 根 barrel `hide MusicAlbum, MusicArtist, MusicSong, MusicGenre, ArtistRef, MusicAlbumListResult, MusicArtistListResult, MusicSongListResult` 避免同名冲突
- **保留在根包**: MusicLibraryPage (1609行)、MusicSearchPage、LyricsPage、AudioPlaybackManager、MusicService

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
| `packages/features/jellyfin_music/**` | 5 lib + 1 test | 780 行 lib + 283 行 test | 音乐业务模块 |

### 根包改动

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `pubspec.yaml` | 修改 | 新增 6 个 feature 包依赖 |
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
| `jellyfin_music` 独立 `flutter test` | 21/21 通过 |
| `jellyfin_core` 独立 `flutter test` | 17/17 通过 |
| `jellyfin_api` 独立 `flutter test` | 8/8 通过 |
| `jellyfin_models` 独立 `flutter test` | 8/8 通过 |
| `jellyfin_ui_kit` 独立 `flutter test` | 14/14 通过 |
| 根包 `flutter test` | 24/24 通过 |
| `jellyfin_playback` 不依赖 `jellyfin_dart` | **确认** — 零 vendor 依赖 |
| `jellyfin_playback` 不依赖 `JellyfinClient` | **确认** — 通过 PlaybackDelegate 解耦 |
| **11 包总测试数** | **171 个全部通过** |

---

## 六、下一步

1. Task 11（jellyfin_home）— **Round 4**（依赖 Auth/App Shell）

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
jellyfin_music ──→ equatable + cached_network_image

根包 jellyfin_service ──→ 上述所有包
    ├── jellyfin_service.dart export 旧版页面/组件（兼容层，hide 同名类型）
    ├── media_libraries_page.dart → AiRecommendPage（已切换）
    ├── media_libraries_page.dart → jellyfin_media pages（已切换）
    ├── media_libraries_page.dart → jellyfin_movies pages（已切换）
    ├── media_libraries_page.dart → jellyfin_series pages（已切换）
    ├── media_libraries_page.dart → jellyfin_playback pages（已切换）
    └── media_libraries_page.dart → jellyfin_music pages（AI 推荐入口已切换）
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
| Phase 2-E：音乐模块 | **完成** | Task 15 |
| Phase 2-F：首页模块 | **Round 4** | Task 11（延后，依赖 Auth/App Shell） |

---

## 九、Phase 2 总体进度汇报

> 汇报日期：2026-05-12

### 9.1 完成概况

**Phase 2 可执行部分已全部完成。** 6 个 feature 包已抽取并集成到根包，所有包共 171 个测试全部通过。

| 包 | 测试数 | 解耦模式 |
|----|--------|---------|
| jellyfin_ai_recommendation | 19 | 回调（4个导航回调 + 2个抽象接口） |
| jellyfin_media | 19 | 回调（typedef + 子 barrel） |
| jellyfin_movies | 11 | 回调（5个 typedef） |
| jellyfin_series | 11 | 回调（7个 typedef） |
| jellyfin_playback | 19 | 委托类（PlaybackDelegate，6个操作） |
| jellyfin_music | 21 | 回调（6个 typedef） |
| jellyfin_core | 17 | — |
| jellyfin_api | 8 | — |
| jellyfin_models | 8 | — |
| jellyfin_ui_kit | 14 | — |
| 根包 jellyfin_service | 24 | — |
| **总计** | **171** | — |

### 9.2 核心成果

1. **零 jellyfin_dart 依赖**：所有 6 个 feature 包均不依赖第三方接口 SDK，完全通过回调/委托解耦
2. **统一解耦模式**：回调 typedef（5个模块）+ 委托类（1个模块），形成可复用的抽取范式
3. **子 barrel 分层**：每个包拆分模型 barrel 和页面 barrel，下游按需引入
4. **渐进式集成**：旧版文件保留为兼容层，新页面通过集成点逐步切换，不影响现有功能

### 9.3 当前架构

```
jellyfin_dart (vendor)                    ← 第三方接口 SDK
    ↑
jellyfin_core ──→ jellyfin_api            ← 基础层（Phase 1）
    ↑                  ↑
jellyfin_models ←── jellyfin_ui_kit       ← 共享层（Phase 1）
    ↑
    ├── jellyfin_ai_recommendation        ← Feature 层（Phase 2）
    ├── jellyfin_media
    ├── jellyfin_movies
    ├── jellyfin_series
    ├── jellyfin_playback
    └── jellyfin_music
    ↑
根包 jellyfin_service                      ← 业务聚合层
    ├── barrel export + hide（兼容层）
    ├── 旧版页面保留（兼容层，13个文件）
    ├── MusicService / AudioPlaybackManager（深度耦合 jellyfin_dart，保留）
    └── MusicLibraryPage / LyricsPage（体量大，保留）
```

---

## 十、遇到的问题

### 问题 1：根包与子包同名类型导致 ambiguous_export

根包和 feature 包都导出 `MusicAlbum`、`MovieFilter`、`VideoQuality` 等同名类型，Dart 编译器报 ambiguous export 错误。

**解决：** 根 barrel 使用 `hide` 隐藏子包的同名类型。保留根包模型（含 `fromDto` 工厂），子包模型为纯数据类。hide 列表随模块增多持续增长，计划在 Task 18（facade 收敛）时统一处理。

### 问题 2：跨包枚举类型转换

根包 `VideoQuality` 与 playback 包 `VideoQuality` 是不同 class，无法直接赋值。

**解决：** 通过 `.name` 属性字符串匹配完成跨包枚举互转。在根包工厂方法 `_createPlaybackDelegate()` 中统一处理。

### 问题 3：typedef 跨模块重复定义

多个 feature 包各自定义了类似的 `MediaItemDetailFetcher` 等 typedef。

**解决：** 提取通用 typedef 到 `jellyfin_models/media_contracts.dart`，各包共享一份定义。

### 问题 4：PlaybackService 深度耦合无法外移

`PlaybackService` 使用了 `jellyfin_dart` 的 `DeviceProfile`、`PlaybackInfoDto`、`PlaybackProgressInfo` 等内部类型，无法随 playback 包一起抽取。

**解决：** 设计 `PlaybackDelegate` 委托类，根包工厂方法将 `PlaybackService` 实例包装为委托。播放包只依赖委托接口，不感知底层实现。

### 问题 5：Widget 测试中 Pending Timer 和元素离屏

`Future.delayed` 导致测试结束后仍有 pending timer 报错；Grid 子元素超出 600px 视口无法被 `tap()` 命中。

**解决：** 使用 `Completer<T>` 替代 `Future.delayed`，手动控制异步完成时机；用 `ensureVisible()` 先滚动到可见再执行 `tap()`。

### 问题 6：并行 Agent 改动冲突

另一个 Agent 在同步修改 `jellyfin_ai_recommendation`（新增 TTS 功能），与我的 Phase 2 改动在同一文件上有交叉。

**解决：** 提交时避开 `jellyfin_ai_recommendation` 的改动，只提交当前 Task 涉及的文件。两边的并行分支需后续合并同步。

---

## 十一、未完成 / 遗留项

### 11.1 Task 11: jellyfin_home（延后至 Round 4）

首页依赖 Auth/App Shell 的导航结构，当前 Phase 1-C（Task 8, 9）未开始，故延后。

### 11.2 保留在根包的大型组件

| 组件 | 估算行数 | 保留原因 |
|------|---------|---------|
| MusicLibraryPage | ~1609 | 内嵌 AudioPlayerPage，耦合 AudioPlaybackManager |
| AudioPlaybackManager | ~500 | just_audio 单例，深度耦合根包 MusicSong |
| MusicService | ~800 | 深度耦合 jellyfin_dart（BaseItemDto） |
| MusicSearchPage / LyricsPage | ~600 | 依赖 AudioPlaybackManager |

这些组件的抽取需要额外设计（可能需要先抽 AudioPlaybackManager 接口层），建议 Phase 3 或 Round 4 处理。

### 11.3 兼容层旧文件（13 个）

根包保留 13 个旧版文件作为兼容层。当前根 barrel 同时导出新旧两套，通过 `hide` 避免冲突。Task 18（facade 收敛）时统一清理。

---

## 十二、需要 Leader 协助的事项

### 1. Phase 1-C 的优先级确认

Phase 2-F（首页模块 Task 11）依赖 Phase 1-C（Task 8 Auth + Task 9 App Shell）。如果后续要做首页，需要先完成 Auth/App Shell。请确认 Round 3 的优先级排序。

### 2. 兼容层清理时机

当前根包同时保留新旧两套文件，`hide` 列表越来越长（累计隐藏约 20 个类型）。建议明确 **Task 18（facade 收敛）** 的执行时机——是 Round 3 还是等所有 feature 都抽取完毕后统一做？

### 3. MusicLibraryPage / AudioPlaybackManager 的抽取策略

这些是根包中最重的组件（合计 ~3000 行），耦合度也最高。两种路线：

- **方案 A**：先抽 AudioPlaybackManager 接口层（定义播放器抽象），再逐步解耦 MusicLibraryPage
- **方案 B**：保持现状，等 App Shell 稳定后一次性重构

请确认倾向哪种方案，或者是否暂不处理。

### 4. jellyfin_ai_recommendation 的并行开发同步

当前有另一个 Agent 在修改 `jellyfin_ai_recommendation`（新增 TTS 功能）。我的提交已避开该模块的改动。请确认两边的并行开发是否需要在某个时间点做一次同步合并。

### 5. Round 3 方向确认

Phase 2 feature 模块已全部完成，请确认 Round 3 的方向：

- **选项 A**：Phase 1-C（Auth + App Shell） → 解锁 Task 11（首页）
- **选项 B**：Phase 3（性能优化 / 构建优化 / CI 流水线）
- **选项 C**：其他方向

---

## 十三、Task 18 小步收敛 — hide 清单与旧文件清理计划

> 更新日期：2026-05-12（Round 3）

### 13.1 当前 hide 类型清单

根 barrel `lib/jellyfin_service.dart` 中 `hide` 隐藏的同名类型共 **18 个**：

| 来源包 | hide 的类型 | 数量 |
|--------|-----------|------|
| `jellyfin_movies` | `MovieFilter`, `MovieFilterResult`, `MovieDetailPage` | 3 |
| `jellyfin_playback` | `VideoQuality`, `NetworkQualityMonitor`, `AutoQualityDecider`, `PlaybackInfo` | 4 |
| `jellyfin_playback_pages` | `VideoPlayerPage` | 1 |
| `jellyfin_music` | `MusicAlbum`, `MusicArtist`, `MusicSong`, `MusicGenre`, `ArtistRef`, `MusicAlbumListResult`, `MusicArtistListResult`, `MusicSongListResult` | 8 |
| `jellyfin_music_pages` | `AlbumDetailPage`, `ArtistDetailPage` | 2 |

### 13.2 旧文件 → 新包映射

| 旧文件（根包 `lib/src/ui/pages/`） | 新包版本 | 状态 |
|--------------------------------------|---------|------|
| `media_item_detail_page.dart` | `jellyfin_media/pages/media_item_detail_page.dart` | @Deprecated 已标记 |
| `person_detail_page.dart` | `jellyfin_media/pages/person_detail_page.dart` | @Deprecated 已标记 |
| `media_items_page.dart` | `jellyfin_media/pages/media_items_page.dart` | @Deprecated 已标记 |
| `seasons_page.dart` | `jellyfin_series/pages/seasons_page.dart` | @Deprecated 已标记 |
| `episodes_page.dart` | `jellyfin_series/pages/episodes_page.dart` | @Deprecated 已标记 |
| `movie_detail_page.dart` | `jellyfin_movies/pages/movie_detail_page.dart` | @Deprecated 已标记 |
| `movie_filter_page.dart` | `jellyfin_movies/pages/movie_filter_page.dart` | @Deprecated 已标记 |
| `video_player_page.dart` | `jellyfin_playback/pages/video_player_page.dart` | @Deprecated 已标记 |
| `album_detail_page.dart` | `jellyfin_music/pages/album_detail_page.dart` | @Deprecated 已标记 |
| `artist_detail_page.dart` | `jellyfin_music/pages/artist_detail_page.dart` | @Deprecated 已标记 |
| `ai_recommend_page.dart` | `jellyfin_ai_recommendation/pages/ai_recommend_page.dart` | @Deprecated 已标记 |

### 13.3 清理条件

当以下条件全部满足时，可删除旧文件并移除 barrel 中的 hide：
1. 所有下游引用（`media_libraries_page.dart` 等）已切换到新包版本
2. 根包内不再有代码 import 旧文件
3. `dart analyze` 无 deprecated 使用警告
4. 全量测试通过

### 13.4 模块边界检查

运行 `dart scripts/check_module_boundaries.dart` 可自动检查：
- feature 包 `src/` 是否被外部 import
- feature 包是否 import 了根包 `jellyfin_service`
- feature 包之间是否 import 了彼此的 `src/`
