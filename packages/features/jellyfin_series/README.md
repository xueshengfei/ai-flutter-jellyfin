# jellyfin_series — 剧集业务模块

剧集（Series）Feature 包，提供季列表页和集列表页。通过回调注入数据和导航，不依赖 Jellyfin 客户端实例，可独立测试和复用。

## 功能清单

- 季列表页（GridView 展示，支持下拉刷新）
- 集列表页（ListView 展示，支持自定义 listBuilder）
- 集详情底部弹窗（DraggableScrollableSheet，含缩略图、评分、简介）
- 错误状态展示与重试
- 空状态提示
- 图片加载支持 `JellyfinImageProvider` 注入

## 目录结构

```
lib/
├── jellyfin_series.dart           # 主 barrel：导出模型/typedef
├── jellyfin_series_pages.dart     # 页面 barrel：导出 SeasonsPage、EpisodesPage
└── src/
    ├── models/
    │   └── series_models.dart     # EpisodesFetcher 回调类型
    ├── pages/
    │   ├── seasons_page.dart      # 季列表页
    │   └── episodes_page.dart     # 集列表页
    └── widgets/
        ├── season_card.dart       # 季卡片组件
        ├── episode_card.dart      # 集卡片组件
        └── episode_detail_sheet.dart  # 集详情底部弹窗
```

## 核心类说明

### 页面

| 类名 | 文件 | 说明 |
|------|------|------|
| `SeasonsPage` | `src/pages/seasons_page.dart` | 季列表页。接收 `series`（MediaItem）和 `fetchSeasons` 回调，GridView 展示季卡片，点击触发 `onNavigateToEpisodes` |
| `EpisodesPage` | `src/pages/episodes_page.dart` | 集列表页。接收 `series` + `season` 和 `fetchEpisodes` 回调，支持自定义 `listBuilder`，点击集卡片弹出详情，播放按钮触发 `onStartPlayback` |

### 组件

| 类名 | 文件 | 说明 |
|------|------|------|
| `SeasonCard` | `src/widgets/season_card.dart` | 季卡片。封面图 + 季名 + 集数，支持 `JellyfinImageProvider` |
| `EpisodeCard` | `src/widgets/episode_card.dart` | 集卡片。缩略图 + 集名 + 集号 + 时长 + 评分 + 简介 + 播放按钮 |
| `EpisodeDetailSheet` | `src/widgets/episode_detail_sheet.dart` | 集详情底部弹窗。标题、集号、缩略图、时长/评分/播放状态 Chip、剧情简介 |

### 回调类型

| 类型 | 文件 | 签名 | 说明 |
|------|------|------|------|
| `EpisodesFetcher` | `src/models/series_models.dart` | `Future<EpisodeListResult> Function({required String seasonId, required String seriesId})` | 获取某季的集列表 |
| `SeasonsFetcher` | `jellyfin_models` | `Future<SeasonListResult> Function(String seriesId)` | 获取某剧集的季列表（定义在 jellyfin_models 包） |

### 依赖的模型（来自 jellyfin_models）

| 模型 | 说明 |
|------|------|
| `MediaItem` | 媒体项，表示一部剧集 |
| `Season` | 季信息（id、名称、集数、封面） |
| `Episode` | 集信息（id、名称、集号、时长、评分、简介、缩略图） |
| `SeasonListResult` | 季列表结果（seasons + totalCount） |
| `EpisodeListResult` | 集列表结果（episodes + totalCount） |

## 依赖关系

```
jellyfin_series
  ├── flutter
  ├── equatable
  ├── jellyfin_models       （MediaItem, Season, Episode, SeasonsFetcher 等）
  └── jellyfin_ui_kit       （JellyfinImage, JellyfinImageProvider）
```

无直接依赖 `jellyfin_api` 或 `jellyfin_dart`，数据获取通过回调注入。

## 使用示例

### 导入

```dart
import 'package:jellyfin_series/jellyfin_series.dart';       // EpisodesFetcher
import 'package:jellyfin_series/jellyfin_series_pages.dart'; // SeasonsPage, EpisodesPage
```

### 季列表页

```dart
SeasonsPage(
  series: mediaItem,                  // MediaItem，类型为 'series'
  fetchSeasons: gateway.getSeasons,   // SeasonsFetcher 回调
  onNavigateToEpisodes: (context, series, season) {
    // 导航到集列表页（由 Product App 的 route page 处理）
    context.go('/series/${series.id}/seasons/${season.id}/episodes');
  },
  imageProvider: myImageProvider,     // JellyfinImageProvider（可选）
)
```

### 集列表页

```dart
EpisodesPage(
  series: mediaItem,
  season: season,
  fetchEpisodes: ({required seasonId, required seriesId}) {
    return gateway.getEpisodes(seasonId: seasonId, seriesId: seriesId);
  },
  onStartPlayback: (context, episode) {
    // 导航到播放页
    context.go('/playback/video/${episode.id}');
  },
  imageProvider: myImageProvider,     // 可选
  appBarActions: [...],               // 可选，额外 AppBar 按钮
  listBuilder: (context, episodes, onTap, onPlay) {
    // 可选，自定义列表布局
    return ListView.builder(...);
  },
)
```

### 路由接入（Product App 层）

在 Product App 的 `media_route_pages.dart` 中，使用 FutureBuilder 包装注入：

```dart
// 季列表路由页
class SeasonsRoutePage extends StatelessWidget {
  final MediaItem series;
  final JellyfinGateway gateway;

  @override
  Widget build(BuildContext context) {
    return SeasonsPage(
      series: series,
      fetchSeasons: gateway.getSeasons,
      onNavigateToEpisodes: (ctx, s, season) {
        context.go('/series/${s.id}/seasons/${season.id}/episodes');
      },
      imageProvider: imageProvider,
    );
  }
}
```

## 测试

```bash
cd packages/features/jellyfin_series
flutter test
```

共 9 个测试，覆盖：

| 测试组 | 用例数 | 覆盖内容 |
|--------|--------|----------|
| `SeasonsPage` | 5 | 加载状态、季列表显示、空状态、点击回调、错误重试 |
| `EpisodesPage` | 4 | 加载状态、集列表显示、空状态、播放回调、自定义 listBuilder |
| `EpisodeCard` | 1 | 集信息显示（名称、集号 S02E05、时长、评分） |
