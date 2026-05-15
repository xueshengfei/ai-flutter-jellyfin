# jellyfin_media - 通用媒体业务模块

通用媒体详情、人物详情、媒体项列表浏览的 Feature 模块。支持电影、剧集等所有媒体类型的详情展示与人员信息浏览。

## 功能清单

- 媒体项详情页（电影/剧集通用，含剧情简介、演员/导演/编剧列表、季列表、播放入口）
- 人物详情页（头像、简介、出生/逝世日期、类型标签、参与作品网格）
- 媒体项列表页（按媒体库分页浏览，支持自定义列表布局）
- 人物模型（`Person`、`PersonCreditsResult`）
- 人物头像卡片和横滚列表（`PersonAvatarCard`、`PersonListRow`，已迁移至 `jellyfin_ui_kit`）

## 核心类说明

### 页面

| 类名 | 文件 | 说明 |
|------|------|------|
| `MediaItemDetailPage` | `lib/src/pages/media_item_detail_page.dart` | 通用媒体详情页，支持电影/剧集等所有类型，通过回调注入数据获取和页面跳转 |
| `PersonDetailPage` | `lib/src/pages/person_detail_page.dart` | 人物详情页，显示演员/导演等人员的详细信息和参与作品 |
| `MediaItemsPage` | `lib/src/pages/media_items_page.dart` | 媒体项列表页，按媒体库分页加载，支持自定义列表布局 |

### 模型

| 类名 | 文件 | 说明 |
|------|------|------|
| `Person` | `lib/src/models/person_models.dart` | 人员模型（演员/导演/编剧等），包含姓名、类型、简介、头像、日期、类型标签 |
| `PersonCreditsResult` | `lib/src/models/person_models.dart` | 人员参与作品列表结果，包含 `items`（`List<MediaItem>`）和 `totalCount` |

### 回调类型

| 类型 | 文件 | 说明 |
|------|------|------|
| `PersonDetailFetcher` | `lib/src/pages/person_detail_page.dart` | `Future<Person> Function(String personId, String personType)` |
| `PersonCreditsFetcher` | `lib/src/pages/person_detail_page.dart` | `Future<PersonCreditsResult> Function(String personId, {List<String>? includeItemTypes})` |
| `MediaItemDetailFetcher` | `jellyfin_models` | `Future<MediaItem> Function(String itemId)` |
| `SeasonsFetcher` | `jellyfin_models` | `Future<SeasonListResult> Function(String seriesId)` |
| `MediaItemsFetcher` | `jellyfin_models` | 媒体项列表获取回调 |

## 依赖关系

```
jellyfin_media
  ├── jellyfin_models    （共享模型：MediaItem, MediaLibrary, Season, ActorInfo 等）
  ├── jellyfin_ui_kit    （UI 组件：JellyfinImage, MediaItemCard, PaginatedList, PersonAvatarCard, PersonListRow）
  ├── equatable          （模型值比较）
  └── flutter            （SDK）
```

## 导入方式

模块通过子 barrel 拆分，按需导入：

```dart
// 需要页面
import 'package:jellyfin_media/jellyfin_media_pages.dart';

// 需要模型（Person, PersonCreditsResult）
import 'package:jellyfin_media/jellyfin_media_models.dart';

// 需要回调 typedef（大部分已收敛到 jellyfin_models）
import 'package:jellyfin_models/jellyfin_models.dart';
```

## 使用示例

### 1. 媒体详情页 - 注入回调和跳转

```dart
MediaItemDetailPage(
  item: mediaItem,                          // 初始媒体项数据
  fetchDetail: gateway.getMediaItemDetail,  // MediaItemDetailFetcher
  fetchSeasons: gateway.getSeasons,         // SeasonsFetcher（剧集用）
  imageProvider: myImageProvider,           // JellyfinImageProvider
  onNavigateToPerson: (ctx, id, name, type) {
    // 跳转到人物详情页
    context.push('/person/$id?name=$name&type=$type');
  },
  onNavigateToEpisodes: (ctx, series, season) {
    // 跳转到剧集列表页
    context.push('/series/${series.id}/seasons/${season.id}');
  },
  onStartPlayback: (ctx, item) {
    // 跳转到播放页
    context.push('/playback/video/${item.id}');
  },
)
```

### 2. 人物详情页 - 注入数据获取回调

```dart
PersonDetailPage(
  personId: 'person_123',
  personName: '张三',
  personType: 'actor',
  fetchPersonDetail: gateway.getPersonDetail,   // PersonDetailFetcher
  fetchPersonCredits: gateway.getPersonCredits, // PersonCreditsFetcher
  imageProvider: myImageProvider,
  onNavigateToMediaItem: (ctx, item) {
    context.push('/media/${item.id}');
  },
)
```

### 3. 媒体项列表页 - 按媒体库浏览

```dart
MediaItemsPage(
  library: mediaLibrary,
  fetchMediaItems: gateway.getMediaItems,  // MediaItemsFetcher
  onNavigateToMediaItem: (ctx, item) {
    context.push('/media/${item.id}');
  },
  appBarActions: [
    // 可选：添加 ViewModeSelector 等操作按钮
  ],
)
```

### 4. 路由注册（在 Product App 中）

```dart
// media_route_pages.dart 中用 FutureBuilder 包装
GoRoute(
  path: '/media/:itemId',
  builder: (context, state) {
    final itemId = state.pathParameters['itemId']!;
    return MediaItemDetailRoutePage(itemId: itemId, gateway: gateway);
  },
),
```

## 测试

```bash
# 运行本模块全部测试
cd packages/features/jellyfin_media && flutter test

# 静态分析
cd packages/features/jellyfin_media && flutter analyze
```

测试覆盖：
- `Person` 模型：构造函数、属性、中文类型显示、Equatable props
- `PersonCreditsResult` 模型：空/非空状态、长度、props
- `MediaItemsPage`：加载状态、列表渲染、错误重试、空状态
- `MediaItemDetailPage`：加载状态、错误状态、详情内容渲染、播放回调触发
- `PersonDetailPage`：加载状态、人物信息显示
- `PersonAvatarCard` / `PersonListRow`（来自 `jellyfin_ui_kit`）：头像渲染、角色显示、空列表
