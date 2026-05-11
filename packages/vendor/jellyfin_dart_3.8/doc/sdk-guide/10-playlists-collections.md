# 10 播放列表与合集 — PlaylistsApi / CollectionApi

---

## PlaylistsApi — 播放列表

获取方式：`client.getPlaylistsApi()`

### createPlaylist — 创建播放列表

```
POST /Playlists
返回: Response<PlaylistCreationResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String? | query | 否 | 播放列表名称 |
| `ids` | List\<String\>? | query | 否 | 初始条目 ID 列表 |
| `userId` | String? | query | 否 | 用户 ID |
| `mediaType` | String? | query | 否 | 媒体类型（如 Audio、Video） |
| `contentType` | String? | query | 否 | 内容类型 |
| `createPlaylistDto` | CreatePlaylistDto? | body | 否 | 创建请求体（推荐方式） |

**PlaylistCreationResult 返回：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String? | 新创建的播放列表 ID |

### addToPlaylist — 向播放列表添加条目

```
POST /Playlists/{playlistId}/Items
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playlistId` | String | path | **是** | 播放列表 ID |
| `ids` | List\<String\>? | query | 否 | 要添加的条目 ID 列表 |
| `userId` | String? | query | 否 | 用户 ID |

### getPlaylistItems — 获取播放列表内容

```
GET /Playlists/{playlistId}/Items
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playlistId` | String | path | **是** | 播放列表 ID |
| `userId` | String? | query | 否 | 用户 ID |
| `startIndex` | int? | query | 否 | 分页起始索引 |
| `limit` | int? | query | 否 | 最大返回数 |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
| `enableImages` | bool? | query | 否 | 是否返回图片 |
| `enableUserData` | bool? | query | 否 | 是否返回用户数据 |
| `imageTypeLimit` | int? | query | 否 | 图片类型限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | 启用的图片类型 |

### removeFromPlaylist — 从播放列表移除条目

```
DELETE /Playlists/{playlistId}/Items
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playlistId` | String | path | **是** | 播放列表 ID |
| `entryIds` | List\<String\>? | query | 否 | 要移除的条目 ID 列表（播放列表中的 ID，非原始条目 ID） |

### updatePlaylist — 更新播放列表信息

```
POST /Playlists/{playlistId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playlistId` | String | path | **是** | 播放列表 ID |
| `updatePlaylistDto` | UpdatePlaylistDto | body | **是** | 更新信息 |

**UpdatePlaylistDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | String? | 新名称 |
| `ids` | List\<String\>? | 重新设置的全部条目 ID（会替换） |
| `userId` | String? | 用户 ID |
| `mediaType` | String? | 媒体类型 |

### getPlaylistUsers — 获取播放列表的共享用户

```
GET /Playlists/{playlistId}/Users
返回: Response<List<PlaylistUserPermissions>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playlistId` | String | path | **是** | 播放列表 ID |

### getPlaylistUser — 获取特定用户的播放列表权限

```
GET /Playlists/{playlistId}/Users/{userId}
返回: Response<PlaylistUserPermissions>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playlistId` | String | path | **是** | 播放列表 ID |
| `userId` | String | path | **是** | 用户 ID |

**PlaylistUserPermissions 返回：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `userId` | String? | 用户 ID |
| `canEdit` | bool? | 是否可以编辑 |
| `canManage` | bool? | 是否可以管理 |

### updatePlaylistUser — 更新用户的播放列表权限

```
POST /Playlists/{playlistId}/Users/{userId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playlistId` | String | path | **是** | 播放列表 ID |
| `userId` | String | path | **是** | 用户 ID |
| `updatePlaylistUserDto` | UpdatePlaylistUserDto | body | **是** | 权限更新信息 |

---

## CollectionApi — 合集

获取方式：`client.getCollectionApi()`

### addToCollection — 向合集添加条目

```
POST /Collections/{collectionId}/Items
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `collectionId` | String | path | **是** | 合集 ID |
| `ids` | List\<String\> | query | **是** | 要添加的条目 ID 列表 |

### removeFromCollection — 从合集移除条目

```
DELETE /Collections/{collectionId}/Items
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `collectionId` | String | path | **是** | 合集 ID |
| `ids` | List\<String\> | query | **是** | 要移除的条目 ID 列表 |

### createCollection — 创建合集

```
POST /Collections
返回: Response<CollectionCreationResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | query | **是** | 合集名称 |
| `ids` | List\<String\>? | query | 否 | 初始条目 ID 列表 |
| `parentId` | String? | query | 否 | 父级 ID |
| `isLocked` | bool? | query | 否 | 是否锁定 |

**CollectionCreationResult 返回：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String? | 新合集 ID |

### updateCollection — 更新合集

```
POST /Collections/{collectionId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `collectionId` | String | path | **是** | 合集 ID |
| `name` | String? | query | 否 | 新名称 |
| `parentId` | String? | query | 否 | 父级 ID |
| `isLocked` | bool? | query | 否 | 是否锁定 |
