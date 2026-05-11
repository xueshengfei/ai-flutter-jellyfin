# 04 媒体库管理 — LibraryApi / LibraryStructureApi

## LibraryApi

获取方式：`client.getLibraryApi()`

---

### getMediaFolders — 获取媒体文件夹

```
GET /Library/MediaFolders
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `isHidden` | bool? | query | 否 | 是否包含隐藏文件夹 |

---

### getItemCounts — 获取条目统计

```
GET /Items/Counts
返回: Response<ItemCounts>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String? | query | 否 | 用户 ID |
| `isFavorite` | bool? | query | 否 | 是否只统计收藏 |

**ItemCounts 返回字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `movieCount` | int? | 电影数 |
| `seriesCount` | int? | 剧集数 |
| `episodeCount` | int? | 单集数 |
| `artistCount` | int? | 艺术家数 |
| `programCount` | int? | 节目数 |
| `songCount` | int? | 歌曲数 |
| `albumCount` | int? | 专辑数 |
| `bookCount` | int? | 书籍数 |
| `itemCount` | int? | 总条目数 |

---

### getSimilarItems — 获取相似条目

```
GET /Items/{itemId}/Similar
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 源条目 ID |
| `userId` | String? | query | 否 | 用户 ID |
| `limit` | int? | query | 否 | 返回最大数量 |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
| `excludeArtistIds` | List\<String\>? | query | 否 | 排除的艺术家 ID |

---

### getAncestors — 获取条目的父级链

```
GET /Items/{itemId}/Ancestors
返回: Response<List<BaseItemDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `userId` | String? | query | 否 | 用户 ID |

---

### getThemeSongs — 获取主题音乐

```
GET /Items/{itemId}/ThemeSongs
返回: Response<ThemeMediaResult>
```

| 参数 | 类型 | 位置 | 必填 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| `itemId` | String | path | **是** | | 条目 ID |
| `userId` | String? | query | 否 | | 用户 ID |
| `inheritFromParent` | bool? | query | 否 | false | 是否从父级继承 |
| `sortBy` | List\<ItemSortBy\>? | query | 否 | | 排序字段 |
| `sortOrder` | List\<SortOrder\>? | query | 否 | | 排序方向 |

---

### getThemeVideos — 获取主题视频

```
GET /Items/{itemId}/ThemeVideos
返回: Response<ThemeMediaResult>
```

参数同 getThemeSongs。

---

### getThemeMedia — 获取所有主题媒体（音频+视频）

```
GET /Items/{itemId}/ThemeMedia
返回: Response<AllThemeMediaResult>
```

参数同 getThemeSongs。

---

### getDownload — 下载条目

```
GET /Items/{itemId}/Download
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |

---

### getFile — 获取文件

```
GET /Items/{itemId}/File
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |

---

### deleteItem — 删除单个条目

```
DELETE /Items/{itemId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 要删除的条目 ID |

---

### deleteItems — 批量删除条目

```
DELETE /Items
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `ids` | List\<String\>? | query | 否 | 要删除的条目 ID 列表 |

---

### getLibraryOptionsInfo — 获取媒体库可用选项

```
GET /Libraries/AvailableOptions
返回: Response<LibraryOptionsResultDto>
```

| 参数 | 类型 | 位置 | 必填 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| `libraryContentType` | CollectionType? | query | 否 | | 媒体库内容类型 |
| `isNewLibrary` | bool? | query | 否 | false | 是否为新媒体库 |

---

### postUpdatedMedia — 通知媒体已更新

```
POST /Library/Media/Updated
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `mediaUpdateInfoDto` | MediaUpdateInfoDto | body | **是** | 更新信息 |

---

### refreshLibrary — 刷新整个媒体库

```
POST /Library/Refresh
返回: Response<void>
```

无额外参数。

---

## LibraryStructureApi

获取方式：`client.getLibraryStructureApi()`

### getVirtualFolderList — 获取虚拟文件夹列表

```
GET /Library/VirtualFolders
返回: Response<List<VirtualFolderInfo>>
```

无额外参数。

### getVirtualFolderInfo — 获取虚拟文件夹详情

```
GET /Library/VirtualFolders/Info
返回: Response<List<VirtualFolderInfo>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String? | query | 否 | 文件夹名称 |

### addVirtualFolder — 添加虚拟文件夹（新媒体库）

```
POST /Library/VirtualFolders
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String? | query | 否 | 媒体库名称 |
| `collectionType` | CollectionType? | query | 否 | 内容类型（movies、tvshows、music 等） |
| `paths` | List\<String\>? | query | 否 | 文件夹路径列表 |
| `refreshLibrary` | bool? | query | 否 | 是否刷新媒体库 |
| `libraryOptionsDto` | LibraryOptions? | body | 否 | 媒体库选项 |

### removeVirtualFolder — 移除虚拟文件夹

```
DELETE /Library/VirtualFolders
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String? | query | 否 | 文件夹名称 |
| `refreshLibrary` | bool? | query | 否 | 是否刷新媒体库 |

### addMediaPath — 添加媒体路径

```
POST /Library/VirtualFolders/Paths
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String? | query | 否 | 虚拟文件夹名 |
| `path` | String? | query | 否 | 要添加的路径 |
| `pathInfo` | MediaPathInfo? | body | 否 | 路径信息 |

### removeMediaPath — 移除媒体路径

```
DELETE /Library/VirtualFolders/Paths
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String? | query | 否 | 虚拟文件夹名 |
| `path` | String? | query | 否 | 要移除的路径 |
| `refreshLibrary` | bool? | query | 否 | 是否刷新媒体库 |

### updateLibraryOptions — 更新媒体库选项

```
POST /Library/VirtualFolders/LibraryOptions
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `id` | String? | query | 否 | 虚拟文件夹 ID |
| `libraryOptions` | LibraryOptions? | body | 否 | 新的媒体库选项 |

### renameVirtualFolder — 重命名虚拟文件夹

```
POST /Library/VirtualFolders/Name
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String? | query | 否 | 当前名称 |
| `newName` | String? | query | 否 | 新名称 |
| `refreshLibrary` | bool? | query | 否 | 是否刷新媒体库 |

### updateMediaPath — 更新媒体路径

```
POST /Library/VirtualFolders/Paths/Update
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String? | query | 否 | 虚拟文件夹名 |
| `pathInfo` | MediaPathInfo? | body | 否 | 更新后的路径信息 |
