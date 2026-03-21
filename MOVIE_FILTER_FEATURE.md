# 电影过滤功能使用文档

## 功能概述

新增了强大的电影过滤功能，支持多种筛选条件，帮助用户快速找到想看的电影。

## 主要功能

### 1. 支持的过滤条件

- **类型过滤**：动作、喜剧、科幻、爱情、恐怖、剧情、动画、犯罪等
- **年份过滤**：支持选择多个年份（近20年）
- **首字母过滤**：按电影名称首字母快速筛选
- **工作室过滤**：漫威、迪士尼、华纳兄弟、环球影业、派拉蒙等
- **评分过滤**：按最低评分筛选（6.0+、7.0+、8.0+、8.5+、9.0+分）
- **其他选项**：
  - 只显示高清（HD）
  - 只显示4K
  - 只显示未观看

### 2. UI 特性

- **筛选对话框**：直观的筛选条件选择界面
- **结果统计**：显示找到的电影数量和当前筛选条件
- **筛选标签**：以Chip形式展示已应用的筛选条件，可一键清除
- **分页加载**：支持上拉加载更多电影
- **网格展示**：3列网格布局，展示电影封面和基本信息
- **搜索功能**：支持按首字母快速搜索

## 使用示例

### 方式1：通过UI界面使用

1. 登录后进入媒体库页面
2. 点击电影类型的媒体库
3. 自动进入电影过滤页面
4. 点击右上角的筛选图标打开筛选对话框
5. 选择筛选条件后点击"应用"
6. 浏览筛选结果

### 方式2：直接使用SDK

```dart
import 'package:jellyfin_service/jellyfin_service.dart';

// 创建客户端
final client = JellyfinClient(
  serverUrl: 'http://localhost:8096',
);

// 登录
final result = await client.auth.authenticate(
  username: 'user',
  password: 'pass',
);

// 创建过滤器
final filter = MovieFilter(
  parentId: 'library-id',
  startIndex: 0,
  limit: 20,
  genres: ['动作', '科幻'],  // 类型
  years: [2024, 2023],       // 年份
  nameStartsWith: 'A',       // 首字母
  studios: ['漫威'],          // 工作室
  minCommunityRating: 7.0,   // 最低评分
  isHD: true,                // 只看高清
);

// 获取电影列表
final movies = await client.mediaLibrary.getMovies(filter);

// 遍历结果
for (final movie in movies.items) {
  print('${movie.name} (${movie.productionYear})');
  print('  评分: ${movie.communityRating}');
  print('  类型: ${movie.genres?.join(", ")}');
}
```

### 方式3：使用默认过滤器

```dart
// 使用默认过滤器（已配置好排序和字段）
final filter = MovieFilter.defaultFilter(
  parentId: 'library-id',
  startIndex: 0,
  limit: 20,
);

// 添加筛选条件
final customFilter = filter.copyWith(
  genres: ['动作'],
  years: [2024],
);

// 获取电影
final movies = await client.mediaLibrary.getMovies(customFilter);
```

## 高级用法

### 组合多个筛选条件

```dart
final filter = MovieFilter(
  parentId: 'library-id',
  genres: ['动作', '科幻'],      // 动作或科幻
  years: [2024, 2023],          // 2024或2023年
  studios: ['漫威', '迪士尼'],   // 漫威或迪士尼
  minCommunityRating: 8.0,      // 评分8.0以上
  isHD: true,                   // 高清
  isUnplayed: true,             // 未观看
);
```

### 自定义排序

```dart
final filter = MovieFilter(
  parentId: 'library-id',
  sortBy: [
    ItemSortBy.productionYear,  // 按年份
    ItemSortBy.sortName,        // 再按名称
  ],
  sortOrder: [
    SortOrder.descending,       // 年份降序
    SortOrder.ascending,        // 名称升序
  ],
);
```

### 分页加载

```dart
// 第一页
final filter1 = MovieFilter(
  parentId: 'library-id',
  startIndex: 0,
  limit: 20,
);
final page1 = await client.mediaLibrary.getMovies(filter1);

// 第二页
final filter2 = filter1.copyWith(startIndex: 20);
final page2 = await client.mediaLibrary.getMovies(filter2);
```

## API 参考

### MovieFilter

过滤参数类，封装所有电影过滤条件。

#### 构造函数参数

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| parentId | String | ✅ | 媒体库ID |
| startIndex | int | ❌ | 起始索引（默认0）|
| limit | int | ❌ | 返回数量（默认20）|
| genres | List<String>? | ❌ | 类型列表 |
| tags | List<String>? | ❌ | 标签列表 |
| years | List<int>? | ❌ | 年份列表 |
| nameStartsWith | String? | ❌ | 首字母 |
| studios | List<String>? | ❌ | 工作室列表 |
| productionLocations | List<String>? | ❌ | 制作地区 |
| minCommunityRating | double? | ❌ | 最低评分 |
| minOfficialRating | String? | ❌ | 最低分级 |
| maxOfficialRating | String? | ❌ | 最高分级 |
| isHD | bool? | ❌ | 只看高清 |
| is4K | bool? | ❌ | 只看4K |
| isPlayed | bool? | ❌ | 只看已观看 |
| isUnplayed | bool? | ❌ | 只看未观看 |
| isFavorite | bool? | ❌ | 只看收藏 |
| sortBy | List<ItemSortBy>? | ❌ | 排序字段 |
| sortOrder | List<SortOrder>? | ❌ | 排序顺序 |
| fields | List<ItemFields>? | ❌ | 额外字段 |
| recursive | bool? | ❌ | 递归搜索（默认true）|

#### 方法

- `copyWith()` - 复制并修改过滤器
- `defaultFilter()` - 创建默认过滤器（工厂方法）

### MediaLibraryService.getMovies()

获取电影列表的方法。

#### 参数

- `filter` (MovieFilter) - 电影过滤器

#### 返回值

- `Future<MediaItemListResult>` - 包含电影列表的结果

#### 抛出

- `ApiException` - 请求失败时

## 技术实现

### 架构设计

```
┌─────────────────────────────────────┐
│   MovieFilterPage (UI层)            │
│   - 筛选对话框                       │
│   - 电影列表展示                     │
│   - 分页加载                         │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│   MediaLibraryService (业务层)      │
│   - getMovies(MovieFilter)          │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│   ItemsApi.getItems() (接口层)      │
│   - jellyfin_dart SDK               │
└─────────────────────────────────────┘
```

### 设计原则

1. **分层清晰**：UI → 业务SDK → 接口SDK
2. **类型安全**：使用枚举类型（ItemSortBy、ItemFields等）
3. **易于扩展**：通过MovieFilter类封装，易于添加新过滤条件
4. **用户友好**：UI直观，支持多种筛选方式

## 更新日志

### v0.2.0 (2025-03-22)

- ✅ 新增 MovieFilter 模型类
- ✅ 新增 MediaLibraryService.getMovies() 方法
- ✅ 新增 MovieFilterPage UI页面
- ✅ 支持类型、年份、首字母、工作室、评分等多种过滤条件
- ✅ 支持分页加载
- ✅ 支持自定义排序
- ✅ 集成到现有导航流程

## 下一步计划

- [ ] 添加更多过滤条件（导演、演员等）
- [ ] 支持保存常用的筛选条件
- [ ] 添加高级搜索功能
- [ ] 优化性能（缓存、预加载等）
