# 第二阶段模块化进展报告

> 对应计划：`MODULARIZATION_EXECUTION_PLAN.md`
> 更新日期：2026-05-12

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
│   ├── jellyfin_media.dart                  (barrel export — 仅导出 typedef，不导出页面/组件)
│   └── src/
│       ├── models/person_models.dart        (83行) Person, PersonCreditsResult（使用 String 替代 jellyfin_dart.PersonKind）
│       ├── pages/
│       │   ├── media_item_detail_page.dart  (393行) 解耦后的通用媒体详情页
│       │   ├── person_detail_page.dart      (281行) 解耦后的人物详情页
│       │   └── media_items_page.dart        (192行) 解耦后的媒体项列表页
│       └── widgets/person_avatar_card.dart  (331行) PersonAvatarCard + PersonListRow
├── test/jellyfin_media_test.dart            (425行) 19个测试
└── pubspec.yaml
```

**依赖关系：**

```yaml
dependencies:
  flutter:
    sdk: flutter
  equatable: ^2.0.5
  jellyfin_models:
    path: ../../shared/jellyfin_models
  jellyfin_ui_kit:
    path: ../../shared/jellyfin_ui_kit
```

注意：不依赖 `jellyfin_core`、`jellyfin_api`、`jellyfin_dart`，也不依赖 `dio`/`cached_network_image` 等网络库。所有数据和图片通过网络 URL 字符串由调用方注入。

#### 业务解耦设计

**解耦前** — 根包 3 个页面直接依赖 JellyfinClient 和其他 feature 页面：

```
MediaItemDetailPage(client, item)
  ├── widget.client.mediaLibrary.getMediaItemDetail()
  ├── widget.client.mediaLibrary.getSeasons()
  ├── Navigator.push(VideoPlayerPage(client, item))
  ├── Navigator.push(PersonDetailPage(client, ...))
  └── Navigator.push(EpisodesPage(client, ...))

PersonDetailPage(client, personId, personName, personType)
  ├── widget.client.mediaLibrary.getPersonDetail()
  ├── widget.client.mediaLibrary.getPersonCredits()
  └── Navigator.push(MediaItemDetailPage(client, item))

MediaItemsPage(client, library)
  ├── widget.client.mediaLibrary.getMediaItems()
  └── Navigator.push(MediaItemDetailPage(client, item))
```

**解耦后** — 零 JellyfinClient 依赖，零页面间 import：

```dart
// MediaItemDetailPage — 7 个回调注入
class MediaItemDetailPage extends StatefulWidget {
  final MediaItem item;
  final MediaItemDetailFetcher fetchDetail;       // Future<MediaItem> Function(String)
  final SeasonsFetcher? fetchSeasons;              // Future<SeasonListResult> Function(String)
  final void Function(BuildContext, MediaItem)? onStartPlayback;
  final void Function(BuildContext, String, String, String)? onNavigateToPerson;
  final void Function(BuildContext, MediaItem, Season)? onNavigateToEpisodes;
}

// PersonDetailPage — 4 个回调 + 1 个抽象接口
class PersonDetailPage extends StatefulWidget {
  final String personId;
  final String personName;
  final String personType;                         // "actor" / "director" / "writer"
  final PersonDetailFetcher fetchPersonDetail;     // Future<Person> Function(String, String)
  final PersonCreditsFetcher fetchPersonCredits;   // Future<PersonCreditsResult> Function(String, ...)
  final JellyfinImageProvider imageProvider;       // 抽象图片接口
  final void Function(BuildContext, MediaItem)? onNavigateToMediaItem;
}

// MediaItemsPage — 2 个回调 + 可选自定义列表构建器
class MediaItemsPage extends StatefulWidget {
  final MediaLibrary library;
  final MediaItemsFetcher fetchMediaItems;         // Future<MediaItemListResult> Function(...)
  final void Function(BuildContext, MediaItem)? onNavigateToMediaItem;
  final Widget Function(List<MediaItem>, ValueChanged<MediaItem>)? listBuilder;
}
```

| 解耦点 | 原始耦合 | 解耦方式 |
|--------|---------|---------|
| 媒体详情获取 | `JellyfinClient.mediaLibrary.getMediaItemDetail()` | `MediaItemDetailFetcher` 回调 |
| 季列表获取 | `JellyfinClient.mediaLibrary.getSeasons()` | `SeasonsFetcher` 回调 |
| 播放跳转 | `Navigator.push(VideoPlayerPage(...))` | `onStartPlayback` 回调 |
| 人物详情跳转 | `Navigator.push(PersonDetailPage(...))` | `onNavigateToPerson` 回调 |
| 剧集列表跳转 | `Navigator.push(EpisodesPage(...))` | `onNavigateToEpisodes` 回调 |
| 人物详情数据 | `JellyfinClient.mediaLibrary.getPersonDetail()` | `PersonDetailFetcher` 回调 |
| 人物作品数据 | `JellyfinClient.mediaLibrary.getPersonCredits()` | `PersonCreditsFetcher` 回调 |
| 图片加载（人物页） | `MediaItemCard(client: widget.client, item: item)` | `JellyfinImageProvider` + `MediaItemCard`（来自 jellyfin_ui_kit） |
| 媒体列表数据 | `JellyfinClient.mediaLibrary.getMediaItems()` | `MediaItemsFetcher` 回调 |
| 列表布局 | `MediaListBuilder(client: widget.client, ...)` | `listBuilder` 回调（调用方注入布局组件） |
| Person.type 类型 | `jellyfin_dart.PersonKind`（依赖 jellyfin_dart） | `String`（"actor"/"director"/"writer"） |

---

## 二、未完成内容

- **Task 11 jellyfin_home** — 首页独立成包（依赖 Task 9 Auth，Task 9 未开始）
- **Task 12 jellyfin_movies** — 电影业务模块（依赖 Task 10，可开始）
- **Task 13 jellyfin_series** — 剧集业务模块（依赖 Task 10，可开始）
- **Task 14 jellyfin_playback** — 播放模块（依赖 Task 10）
- **Task 15 jellyfin_music** — 音乐业务模块（依赖 Task 14）
- 根包旧文件保留在原位作为兼容层（Task 18 facade 收敛时清理）

---

## 三、遇到的问题

### 问题 1：根包 MediaItem 与 jellyfin_models MediaItem 类型冲突

**背景：** Phase 1 遗留问题。根包 `lib/src/models/media_item_models.dart` 有自己的 `MediaItem`（含 `fromDto()` 工厂方法，依赖 `jellyfin_dart`），`jellyfin_models` 包也有同名 `MediaItem`（纯模型，无 DTO 依赖）。两者结构相似但属于不同 Dart 类型。

**现象：** 新模块页面使用 `jellyfin_models.MediaItem`，根包 `JellyfinClient` 服务返回根包 `MediaItem`。在新模块的回调中直接传递会导致类型不匹配编译错误。

**当前临时方案：** 在集成点（`media_libraries_page.dart`）中通过 `as local` / `as models` 前缀导入 + 手写转换函数 `toModelsMediaItem()` 适配。

**需要决策：** 这个双类型问题贯穿所有 feature 模块（每个模块的回调都会涉及 MediaItem 类型转换）。手动写转换函数可维护性差。建议统一为单一 MediaItem 类型：

- **方案 A**：根包 `MediaItem` 删除 `fromDto()` 工厂方法，统一使用 `jellyfin_models.MediaItem`，将 `fromDto()` 逻辑下沉到 `jellyfin_api` 层。所有业务模块直接使用 `jellyfin_models.MediaItem`。
- **方案 B**：保留双类型，在根包提供统一的 `MediaItemAdapter` 工具类，所有集成点复用。

### 问题 2：Person.type 从 jellyfin_dart.PersonKind 解耦为 String

**背景：** 根包 `Person` 模型的 `type` 字段使用 `jellyfin_dart.PersonKind` 枚举，这导致新模块必须依赖 `jellyfin_dart`（vendor 包），破坏分层。

**当前方案：** 新模块 `Person.type` 改为 `String`（"actor"/"director"/"writer" 等），在根包集成层完成 `jellyfin_dart.PersonKind` → `String` 的映射。

**需要确认：** 这个 String 方案是否可接受？还是有更好的抽象方式？

### 问题 3：barrel export 与根包旧版同名类 ambiguous_export

**背景：** 新模块中的页面（`MediaItemDetailPage`、`PersonDetailPage`、`MediaItemsPage`）和组件（`PersonAvatarCard`、`PersonListRow`）与根包旧文件同名。当根包 `jellyfin_service.dart` 同时 export 旧文件和新模块的 barrel 时，Dart 编译器报 `ambiguous_export` 错误。

**当前临时方案：** 新模块 `jellyfin_media.dart` 的 barrel export **不导出**页面、组件和模型类，仅导出不冲突的 typedef（`SeasonsFetcher`、`PersonDetailFetcher`、`PersonCreditsFetcher`、`MediaItemsFetcher`）。使用者需要通过直接 import 路径访问页面和组件：

```dart
import 'package:jellyfin_media/src/pages/media_item_detail_page.dart';
import 'package:jellyfin_media/src/models/person_models.dart';
```

根包 `jellyfin_service.dart` 保持导出根包旧版文件不变。

**需要决策：** 这个"barrel 不导出同名类"方案是否可接受？后续每个 feature 模块都会遇到同样问题。可选方案：

- **方案 A**（当前方案）：barrel 仅导出 typedef，页面/组件通过直接路径 import。简单但不够优雅。
- **方案 B**：根包旧文件在模块抽取后**立即删除**，所有引用改为使用新模块。一步到位但有风险。
- **方案 C**：在新模块中**重命名类**（如 `MediaMediaItemDetailPage`），避免与根包冲突。但命名冗长。
- **方案 D**：等到 Task 18（facade 收敛）统一处理。在此之前所有模块采用方案 A。

### 问题 4：MediaItemsPage 的列表布局组件（MediaListBuilder）未迁移

**背景：** 根包 `MediaItemsPage` 使用 `MediaListBuilder`（依赖 4 种布局组件：`BannerListView`、`VerticalListView`、`PosterGridView`、`CardGridView`），这些布局组件直接使用 `JellyfinImageWithClient(client: widget.client)` 加载图片，与 `JellyfinClient` 强耦合。同时 `ViewModeManager` 依赖 `shared_preferences`。

**当前方案：** 新模块的 `MediaItemsPage` 不包含 `MediaListBuilder`，改为通过 `listBuilder` 回调注入列表布局。如果调用方不提供 `listBuilder`，使用默认的简单网格布局。

**需要确认：** 后续是否需要将 `MediaListBuilder` + 4 种布局 + `ViewModeManager` 也迁移到 `jellyfin_media`？这会引入 `shared_preferences` 依赖和 `JellyfinClient` 解耦工作。

### 问题 5：typedef MediaItemDetailFetcher 跨模块重复定义

**背景：** `jellyfin_ai_recommendation` 和 `jellyfin_media` 都定义了 `MediaItemDetailFetcher`（签名完全相同：`Future<MediaItem> Function(String itemId)`）。当两个模块同时被根包 `jellyfin_service.dart` export 时，Dart 编译器报 `ambiguous_export`。

**当前方案：** `jellyfin_media` 的 barrel 不导出 `MediaItemDetailFetcher`，仅由 `jellyfin_ai_recommendation` 导出。模块内部直接使用自己的定义，不冲突。

**需要确认：** 后续是否应该将通用 typedef 提取到 `jellyfin_core` 或 `jellyfin_models`？这样所有 feature 模块共享一份定义，避免未来更多重复。

### 问题 6：根包旧文件仍然互相引用，形成"双轨并行"

**背景：** 根包的 `media_item_detail_page.dart`（旧版）仍然 `import 'package:jellyfin_service/jellyfin_service.dart'`，并且直接 import `person_detail_page.dart`、`person_avatar_card.dart` 等旧文件。新模块有同名但签名不同的版本。两套代码并存，集成点（`media_libraries_page.dart`）目前仍使用旧版。

**影响：** 新模块代码已通过独立测试验证，但尚未有任何页面实际切换到使用新模块。需要决策何时切换集成点。

---

## 四、当前文件变更清单

### 新增独立包

| 包 | 文件数 | 代码行 | 说明 |
|----|--------|--------|------|
| `packages/features/jellyfin_ai_recommendation/**` | 9 lib + 1 test | 1534 行 lib + 211 行 test | AI 推荐业务模块 |
| `packages/features/jellyfin_media/**` | 6 lib + 1 test | 1280 行 lib + 425 行 test | 通用媒体业务模块 |

### 根包改动

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `pubspec.yaml` | 修改 | 新增 `jellyfin_ai_recommendation` + `jellyfin_media` 依赖 |
| `lib/jellyfin_service.dart` | 修改 | 新增 `export 'package:jellyfin_media/jellyfin_media.dart'`（仅导出 typedef） |

### 根包保留（兼容层，未删除）

以下旧文件仍被根包其他页面直接引用，暂时保留：

| 文件 | 说明 |
|------|------|
| `lib/src/ui/pages/media_item_detail_page.dart` | 旧版媒体详情页（接收 `JellyfinClient`） |
| `lib/src/ui/pages/person_detail_page.dart` | 旧版人物详情页（接收 `JellyfinClient`） |
| `lib/src/ui/pages/media_items_page.dart` | 旧版媒体列表页（接收 `JellyfinClient`） |
| `lib/src/ui/widgets/person_avatar_card.dart` | 旧版人物头像卡片 |
| `lib/src/models/person_models.dart` | 旧版人物模型（`type` 为 `jellyfin_dart.PersonKind`） |
| `lib/src/ui/pages/ai_recommend_page.dart` | 旧版 AI 页面 |
| `lib/src/services/ai_recommendation_service.dart` | 旧版 SSE 服务 |
| `lib/src/models/ai_recommendation_models.dart` | 旧版 AI 模型 |

---

## 五、验证结果

| 检查项 | 结果 |
|--------|------|
| `jellyfin_ai_recommendation` 独立 `flutter analyze` | 0 error, 0 warning |
| `jellyfin_ai_recommendation` 独立 `flutter test` | 19/19 通过 |
| `jellyfin_media` 独立 `flutter analyze` | 0 error, 0 warning（15 info） |
| `jellyfin_media` 独立 `flutter test` | 19/19 通过 |
| `jellyfin_core` 独立 `flutter test` | 17/17 通过 |
| `jellyfin_api` 独立 `flutter test` | 8/8 通过 |
| `jellyfin_models` 独立 `flutter test` | 8/8 通过 |
| `jellyfin_ui_kit` 独立 `flutter test` | 14/14 通过 |
| 根包 `flutter test` | 19/19 通过 |
| 根包 `flutter analyze lib/` | 0 error（64 info 均为既有问题） |
| `jellyfin_media` 不 import 任何 feature 页面 | **确认** — 零直接 feature import |
| `jellyfin_media` 不依赖 `JellyfinClient` | **确认** — 通过回调 + `JellyfinImageProvider` 解耦 |
| `jellyfin_media` 不依赖 `jellyfin_dart` | **确认** — Person.type 使用 String |
| **7 包总测试数** | **104 个全部通过** |

---

## 六、需要决策的问题（请 Leader 确认）

### 决策 1：MediaItem 双类型统一方案

| 方案 | 描述 | 工作量 | 风险 |
|------|------|--------|------|
| **A（推荐）** | 删除根包 `MediaItem`，统一用 `jellyfin_models.MediaItem`；`fromDto()` 下沉到 `jellyfin_api` | 中 | 需要修改所有引用根包 MediaItem 的地方 |
| **B** | 保留双类型，根包提供统一 `MediaItemAdapter` 工具类 | 低 | 长期维护两套模型，类型转换散落各处 |

### 决策 2：barrel export 策略

| 方案 | 描述 | 工作量 | 风险 |
|------|------|--------|------|
| **D（推荐）** | Task 18 前，barrel 仅导出 typedef；Task 18 统一清理旧文件后恢复完整 barrel | 低 | 开发者需要记住直接 import 路径 |
| **B** | 每个模块抽取后立即删除根包旧文件 | 高 | 一次性大改动，回归测试压力大 |

### 决策 3：typedef 提取位置

| 方案 | 描述 |
|------|------|
| 提取到 `jellyfin_core` | 通用回调类型定义集中管理，但 core 不依赖 jellyfin_models，需改为泛型或移到新位置 |
| 提取到 `jellyfin_models` | models 已有 MediaItem，可以放 MediaItemDetailFetcher 等 |
| 保持各模块各自定义 | 简单但会有重复，barrel export 需要隐藏 |

### 决策 4：MediaListBuilder 迁移范围

是否将 `MediaListBuilder` + 4 种布局 + `ViewModeManager` 迁移到 `jellyfin_media`？这会引入 `shared_preferences` 依赖和大量 `JellyfinClient` 解耦工作。

---

## 七、下一步建议

1. **等待 Leader 对决策 1-4 的确认**
2. 确认后继续 Task 12（jellyfin_movies）和 Task 13（jellyfin_series）— 可并行
3. 然后 Task 14（jellyfin_playback）
4. 最后 Task 15（jellyfin_music）

---

## 八、依赖关系图（当前实际）

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

根包 jellyfin_service ──→ 上述所有包
    ├── jellyfin_service.dart export 旧版页面/组件（兼容层）
    ├── jellyfin_service.dart export jellyfin_ai_recommendation（完整 barrel）
    ├── jellyfin_service.dart export jellyfin_media（仅 typedef）
    ├── media_libraries_page.dart 注入回调到 AiRecommendPage（已切换）
    └── 其他页面仍使用旧版 MediaItemDetailPage / PersonDetailPage / MediaItemsPage（未切换）
```

---

## 九、阶段评估

| 子阶段 | 状态 | 内容 |
|--------|------|------|
| Phase 1-A：基础包抽取与目录重组 | **完成** | Task 1, 2, 4 |
| Phase 1-B：API/UI Kit/Testing 补齐 | **完成** | Task 3, 5, 6, 7 |
| Phase 1-C：App Shell + Auth 验证闭环 | **待开始** | Task 8, 9 |
| Phase 2-A：AI 推荐业务解耦 | **完成** | Task 16 |
| Phase 2-B：通用媒体能力解耦 | **完成** | Task 10 |
| Phase 2-C：电影/剧集/播放/音乐 | **待开始** | Task 12, 13, 14, 15（等 Leader 决策） |
