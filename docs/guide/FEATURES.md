# 功能清单 & 技术文档

> 本文档记录 jellyfin_service SDK 已实现的功能、核心模型、关键解决方案。
> 按模块组织，替代之前分散的各个 FEATURE/FIX 文档。

---

## 架构概览

```
Flutter App → jellyfin_service(业务SDK) → jellyfin_dart(接口SDK) → Dio/HTTP → Jellyfin Server
```

- **接口SDK** `jellyfin_dart`：1:1 API 映射，DTO 模型（BaseItemDto 等）
- **业务SDK** `jellyfin_service`：业务逻辑组合、自有模型（MediaItem / Book 等）、UI 组件

---

## 1. 媒体库管理

### 核心模型 — `MediaLibrary`
```dart
class MediaLibrary {
  final String id, name;
  final MediaLibraryType type;       // movies | tvshows | music | musicVideos | homeVideos | boxSets | books | unknown
  final String? primaryImageTag;     // 封面图标签
  final int? itemCount;              // 子项数量
  String? getCoverImageUrl();        // 带认证的封面 URL
}
```

### 服务方法 — `MediaLibraryService`
| 方法 | 说明 |
|------|------|
| `getMediaLibraries()` | 获取所有媒体库 |
| `getMediaLibraryDetail(id)` | 获取单个详情 |
| `getMediaLibrariesByType(type)` | 按类型过滤 |
| `getMediaItems(parentId)` | 获取媒体项列表 |
| `getMediaItemDetail(id)` | 获取单个详情 |
| `getMovies(filter)` | 电影过滤查询 |
| `getSeasons(seriesId)` | 获取剧集的季列表 |
| `getEpisodes(seasonId, seriesId)` | 获取季的集列表 |

---

## 2. 电影模块

### 过滤器 — `MovieFilter`
支持：类型、年份、首字母、工作室、评分、HD/4K、已看/未看、收藏。

```dart
final movies = await client.mediaLibrary.getMovies(MovieFilter(
  parentId: libraryId,
  genres: ['动作', '科幻'],
  years: [2024],
  minCommunityRating: 8.0,
  isHD: true,
));
```

### 详情页
SliverAppBar + 背景海报 + 元数据（评分、导演、演员、工作室、类型标签）。
路由：`MovieFilterPage` 点击卡片 → 详情页。

---

## 3. 电视剧模块

### 层级导航
```
电视剧媒体库 → 剧集(Series) → 季(Season) → 集(Episode)
```

### 核心模型
```dart
class Season  { id, seriesId, name, indexNumber, episodeCount, ... }
class Episode { id, seriesId, seasonId, name, episodeNumber, runTimeMinutes, playedPercentage, ... }
```

---

## 4. 音乐模块

`MusicLibraryPage`：专辑浏览 → 歌曲列表 → `AudioPlayerPage` 播放。
`AudioPlaybackManager`：全局播放状态，底部 MiniPlayer。

---

## 5. 书籍模块

### 核心模型 — `Book`
```dart
class Book {
  final String id, name;
  final List<String>? authors;
  final double? playedPercentage;    // 阅读进度
  String getDownloadUrl();           // EPUB 下载 URL
}
```

### 阅读器 — `EpubReaderPage`
- **懒加载**：Isolate 只提取目录，章节文本按需 HTML→纯文本
- **主题切换**：深色 / 护眼 / 浅色
- **进度上报**：翻页时 `updateUserItemData(playedPercentage)`，退出时上报
- **位置恢复**：进入时从 `playedPercentage` 计算目标章节并跳转
- **兼容**：Isolate 不可用时（ohos/web）自动回退主线程

### 首页
- 书籍库卡片路由到 `BookLibraryPage`（电子书 | 有声书 | 系列 三 Tab）
- "继续阅读"横滑区：从 `getContinueWatching` 按 `type=='book'` 过滤

---

## 6. 用户服务 — `UserService`

| 方法 | 说明 |
|------|------|
| `authenticate(username, password)` | 登录 |
| `logout()` | 登出 |
| `getContinueWatching(limit)` | 获取继续观看/阅读列表 |
| `updateUserItemData(itemId, playedPercentage)` | 更新播放/阅读进度 |
| `toggleFavorite(itemId)` | 切换收藏 |

---

## 7. 图片认证方案

Jellyfin 图片需要认证，URL 格式：
```
/Items/{id}/Images/Primary?tag={imageTag}         // 有标签时
/Items/{id}/Images/Primary?api_key={accessToken}  // 无标签时
```

封装在 `JellyfinImageWithClient` 组件中，自动处理认证和占位图。

---

## 8. 关键修复记录

### 横向滚动列表抖动
**问题**：演员列表、季列表横向滚动时卡顿。
**方案**：`ListView.separated` 替代 `Row + SingleChildScrollView`，设置固定 item 高度。

### 电影详情元数据不全
**问题**：导演、作者、工作室字段为空。
**方案**：API 请求增加 `fields: [ItemFields.people, ItemFields.studios]`，从 `people` 按 `PersonKind` 过滤。

### FLAC 播放进度不动
**问题**：流媒体格式时长显示 0:00，进度条不动。
**方案**：从响应头 `Content-Range` 解析总字节数换算时长，而非依赖 `runTimeTicks`。
