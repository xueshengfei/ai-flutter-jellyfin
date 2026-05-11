# 14 音乐 — ArtistsApi / InstantMixApi / LyricsApi / MusicGenresApi / GenresApi

---

## ArtistsApi — 艺术家查询

获取方式：`client.getArtistsApi()`

### getAlbumArtists — 获取专辑艺术家

```
GET /Artists/AlbumArtists
返回: Response<BaseItemDtoQueryResult>
```

### getArtists — 获取所有艺术家

```
GET /Artists
返回: Response<BaseItemDtoQueryResult>
```

以上两个方法共享相同的参数列表：

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `minCommunityRating` | double? | query | 否 | 最低社区评分 |
| `startIndex` | int? | query | 否 | 分页起始索引 |
| `limit` | int? | query | 否 | 最大返回数 |
| `searchTerm` | String? | query | 否 | 搜索关键词 |
| `parentId` | String? | query | 否 | 父级文件夹 ID |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
| `excludeItemTypes` | List\<BaseItemKind\>? | query | 否 | 排除的类型 |
| `includeItemTypes` | List\<BaseItemKind\>? | query | 否 | 包含的类型 |
| `filters` | List\<ItemFilter\>? | query | 否 | 过滤器 |
| `isFavorite` | bool? | query | 否 | 是否收藏 |
| `mediaTypes` | List\<MediaType\>? | query | 否 | 媒体类型 |
| `genres` | List\<String\>? | query | 否 | 流派过滤 |
| `genreIds` | List\<String\>? | query | 否 | 流派 ID 过滤 |
| `officialRatings` | List\<String\>? | query | 否 | 官方评级 |
| `tags` | List\<String\>? | query | 否 | 标签 |
| `years` | List\<int\>? | query | 否 | 年份 |
| `enableUserData` | bool? | query | 否 | 是否返回用户数据 |
| `imageTypeLimit` | int? | query | 否 | 图片类型限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | 启用的图片类型 |
| `userId` | String? | query | 否 | 用户 ID |
| `nameStartsWith` | String? | query | 否 | 名称前缀 |
| `nameStartsWithOrGreater` | String? | query | 否 | 名称前缀或更大 |
| `nameLessThan` | String? | query | 否 | 名称小于 |
| `enableImages` | bool? | query | 否 | 是否返回图片 |
| `enableTotalRecordCount` | bool? | query | 否 | 是否返回总数 |

### getArtistItem — 获取单个艺术家

```
GET /Artists/{name}
返回: Response<BaseItemDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | path | **是** | 艺术家名称 |
| `userId` | String? | query | 否 | 用户 ID |

---

## InstantMixApi — 即时混音

获取方式：`client.getInstantMixApi()`

从指定条目生成推荐混音播放列表。

### getInstantMixFromItem — 从条目生成混音

```
GET /Items/{id}/InstantMix
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `id` | String | path | **是** | 条目 ID |
| `userId` | String? | query | 否 | 用户 ID |
| `limit` | int? | query | 否 | 最大返回数 |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
| `enableImages` | bool? | query | 否 | 是否返回图片 |
| `enableUserData` | bool? | query | 否 | 是否返回用户数据 |
| `imageTypeLimit` | int? | query | 否 | 图片类型限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | 启用的图片类型 |

### getInstantMixFromArtist — 从艺术家生成混音

```
GET /Artists/{name}/InstantMix
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | path | **是** | 艺术家名称 |
| 其余参数同 getInstantMixFromItem | | | | |

### getInstantMixFromMusicGenre — 从音乐流派生成混音

```
GET /MusicGenres/{name}/InstantMix
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | path | **是** | 流派名称 |
| 其余参数同 getInstantMixFromItem | | | | |

### getInstantMixFromPlaylist — 从播放列表生成混音

```
GET /Playlists/{id}/InstantMix
返回: Response<BaseItemDtoQueryResult>
```

参数同 getInstantMixFromItem。

### getInstantMixFromSong — 从歌曲生成混音

```
GET /Songs/{id}/InstantMix
返回: Response<BaseItemDtoQueryResult>
```

参数同 getInstantMixFromItem。

### getInstantMixFromAlbum — 从专辑生成混音

```
GET /Albums/{id}/InstantMix
返回: Response<BaseItemDtoQueryResult>
```

参数同 getInstantMixFromItem。

---

## LyricsApi — 歌词

获取方式：`client.getLyricsApi()`

### getLyrics — 获取歌词

```
GET /Audio/{itemId}/Lyrics
返回: Response<List<LyricDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 音频条目 ID |

**LyricDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `metadata` | LyricMetadata? | 歌词元数据 |
| `lyrics` | List\<LyricLine\>? | 歌词行列表 |

### uploadLyrics — 上传歌词

```
POST /Audio/{itemId}/Lyrics
返回: Response<LyricDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 音频条目 ID |
| `uploadLyricDto` | UploadLyricDto | body | **是** | 歌词上传信息 |

### deleteLyrics — 删除歌词

```
DELETE /Audio/{itemId}/Lyrics
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 音频条目 ID |

### searchRemoteLyrics — 搜索远程歌词

```
GET /Audio/{itemId}/RemoteLyrics
返回: Response<List<RemoteLyricInfoDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 音频条目 ID |

### downloadRemoteLyrics — 下载远程歌词

```
POST /Audio/{itemId}/RemoteLyrics/{lyricId}
返回: Response<LyricDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 音频条目 ID |
| `lyricId` | String | path | **是** | 歌词 ID |

---

## MusicGenresApi — 音乐流派

获取方式：`client.getMusicGenresApi()`

### getMusicGenres — 获取音乐流派列表

```
GET /MusicGenres
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `startIndex` | int? | query | 否 | 分页起始索引 |
| `limit` | int? | query | 否 | 最大返回数 |
| `searchTerm` | String? | query | 否 | 搜索关键词 |
| `parentId` | String? | query | 否 | 父级 ID |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
| `excludeItemTypes` | List\<BaseItemKind\>? | query | 否 | 排除的类型 |
| `includeItemTypes` | List\<BaseItemKind\>? | query | 否 | 包含的类型 |
| `isFavorite` | bool? | query | 否 | 是否收藏 |
| `imageTypeLimit` | int? | query | 否 | 图片类型限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | 启用的图片类型 |
| `userId` | String? | query | 否 | 用户 ID |
| `nameStartsWith` | String? | query | 否 | 名称前缀 |
| `nameStartsWithOrGreater` | String? | query | 否 | 名称前缀或更大 |
| `nameLessThan` | String? | query | 否 | 名称小于 |
| `enableImages` | bool? | query | 否 | 是否返回图片 |
| `enableTotalRecordCount` | bool? | query | 否 | 是否返回总数 |

### getMusicGenre — 获取单个音乐流派

```
GET /MusicGenres/{genreName}
返回: Response<BaseItemDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `genreName` | String | path | **是** | 流派名称 |
| `userId` | String? | query | 否 | 用户 ID |

---

## GenresApi — 流派查询

获取方式：`client.getGenresApi()`

### getGenres — 获取流派列表

```
GET /Genres
返回: Response<BaseItemDtoQueryResult>
```

参数与 MusicGenresApi.getMusicGenres 完全相同。

### getGenre — 获取单个流派

```
GET /Genres/{genreName}
返回: Response<BaseItemDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `genreName` | String | path | **是** | 流派名称 |
| `userId` | String? | query | 否 | 用户 ID |
