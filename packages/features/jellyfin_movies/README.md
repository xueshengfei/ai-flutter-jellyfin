# jellyfin_movies — 电影业务模块

电影筛选、电影详情、电影列表浏览。纯 UI feature 包，通过回调解耦，不依赖 Jellyfin 客户端实现。

## 功能清单

- 电影筛选页：按类型 / 年份 / 工作室 / 评分 / 高清4K / 观看状态等多维度筛选
- 关键词搜索与首字母过滤
- 分页加载电影列表，支持自定义列表布局注入
- 电影详情页：海报 / 背景图 / 元数据 / 播放按钮
- 筛选条件可视化（Chip 标签），一键清除

## 核心类一览

### 模型（`lib/src/models/movie_filter_models.dart`）

| 类/枚举 | 说明 |
|---------|------|
| `MovieFilter` | 电影过滤器，包含 parentId / genres / years / studios / searchTerm 等筛选维度。不可变，`copyWith` 更新，`defaultFilter` 工厂构造 |
| `MovieFilterResult` | 筛选结果，持有 `List<MediaItem>` movies / totalCount / startIndex |
| `MovieSortField` | 排序字段枚举：dateCreated / sortName / productionYear / premiereDate / random / communityRating |
| `MovieSortOrder` | 排序方向枚举：ascending / descending |
| `MoviesFetcher` | 回调类型：`Future<MovieFilterResult> Function(MovieFilter)` |

### 页面（`lib/src/pages/`）

| 页面 | 文件 | 说明 |
|------|------|------|
| `MovieFilterPage` | `movie_filter_page.dart` | 电影筛选页。SliverAppBar + PaginatedList，内置搜索对话框和筛选 BottomSheet。通过 `listBuilder` 注入自定义列表布局 |
| `MovieDetailPage` | `movie_detail_page.dart` | 电影详情页。SliverAppBar 背景图 + FutureBuilder 加载详情 + 元数据展示（简介 / 类型 / 评分 / 导演 / 编剧 / 工作室） |

### 回调类型

| typedef | 定义位置 | 用途 |
|---------|----------|------|
| `MoviesFetcher` | `movie_filter_models.dart` | 根据筛选条件获取电影列表 |
| `MovieDetailFetcher` | `movie_detail_page.dart` | 根据 itemId 获取电影完整详情 |

## 依赖关系

```
jellyfin_movies
  ├── flutter
  ├── equatable
  ├── jellyfin_models        （共享模型：MediaItem 等）
  └── jellyfin_ui_kit        （UI 组件：JellyfinImage / PaginatedList 等）
```

本包不依赖 `jellyfin_api`、`jellyfin_dart` 或其他 feature 包，所有外部数据通过回调注入。

## 使用示例

### 导入

```dart
// 模型 + 详情页
import 'package:jellyfin_movies/jellyfin_movies.dart';
// 所有页面（含 MovieFilterPage）
import 'package:jellyfin_movies/jellyfin_movies_pages.dart';
```

### MovieFilterPage — 注入回调和列表布局

```dart
MovieFilterPage(
  libraryId: 'library-123',
  libraryName: '电影库',
  fetchMovies: (filter) => gateway.fetchMovies(filter),
  onNavigateToMovie: (context, item) {
    context.push('/movies/${item.id}');
  },
  listBuilder: ({required items, required onTap}) {
    return MediaListBuilder(
      items: items,
      imageProvider: myImageProvider,
      onTap: onTap,
    );
  },
  appBarActions: [
    ViewModeSelector(key: viewModeKey),
  ],
);
```

### MovieDetailPage — 注入详情获取和播放回调

```dart
MovieDetailPage(
  movie: mediaItem,
  fetchDetail: (itemId) => gateway.getMovieDetail(itemId),
  onStartPlayback: (context, movie) {
    context.push('/playback/video/${movie.id}');
  },
  imageProvider: myImageProvider,
);
```

### 路由接入（GoRouter 示例）

```dart
GoRoute(
  path: '/libraries/:libraryId/movies',
  builder: (context, state) => MovieFilterRoutePage(
    libraryId: state.pathParameters['libraryId']!,
    libraryName: state.uri.queryParameters['name'] ?? '电影',
    gateway: gateway,
    imageProvider: imageProvider,
  ),
),
GoRoute(
  path: '/movies/:itemId',
  builder: (context, state) => MovieDetailRoutePage(
    itemId: state.pathParameters['itemId']!,
    gateway: gateway,
    imageProvider: imageProvider,
  ),
),
```

Route Page 层负责调用 Gateway 获取数据，然后注入到 `MovieFilterPage` / `MovieDetailPage`。

## 测试

```bash
cd packages/features/jellyfin_movies
flutter test
```

测试覆盖：

- `MovieFilter` — 默认构造、copyWith 修改字段、clear 参数清空
- `MovieFilterResult` — isEmpty / isNotEmpty / length
- `MovieFilterPage` — 加载状态、电影列表渲染、空状态、点击回调
- `MovieDetailPage` — 加载状态、详情内容渲染、播放按钮回调

共 8 个测试（3 单元测试 + 5 Widget 测试）。
