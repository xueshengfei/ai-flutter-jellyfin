# 03 媒体条目查询 — ItemsApi

获取方式：`client.getItemsApi()`

这是参数最多的核心 API，用于查询 Jellyfin 中的所有媒体条目。

---

## getItems — 查询媒体条目（核心方法）

```
GET /Items
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| `userId` | String? | query | 否 | | 用户 ID，关联用户观看状态和权限 |
| `startIndex` | int? | query | 否 | | 分页起始索引（从 0 开始） |
| `limit` | int? | query | 否 | | 每页返回的最大条目数 |
| `searchTerm` | String? | query | 否 | | 搜索关键词 |
| `parentId` | String? | query | 否 | | 父级文件夹/媒体库 ID，限定查询范围 |
| `recursive` | bool? | query | 否 | | 是否递归查询所有子项 |
| **排序参数** | | | | | |
| `sortBy` | List\<ItemSortBy\>? | query | 否 | | 排序字段列表，如 `[ItemSortBy.sortName]` |
| `sortOrder` | List\<SortOrder\>? | query | 否 | | 排序方向：`SortOrder.ascending` / `SortOrder.descending` |
| **类型过滤** | | | | | |
| `includeItemTypes` | List\<BaseItemKind\>? | query | 否 | | 只包含这些类型（如 movie、episode、series） |
| `excludeItemTypes` | List\<BaseItemKind\>? | query | 否 | | 排除这些类型 |
| `mediaTypes` | List\<MediaType\>? | query | 否 | | 按媒体类型过滤（如 video、audio、book） |
| `videoTypes` | List\<VideoType\>? | query | 否 | | 视频类型过滤（如 VideoFile、Dvd、bluRay） |
| **标志过滤** | | | | | |
| `isMovie` | bool? | query | 否 | | 是否为电影 |
| `isSeries` | bool? | query | 否 | | 是否为剧集 |
| `isNews` | bool? | query | 否 | | 是否为新闻 |
| `isKids` | bool? | query | 否 | | 是否为儿童节目 |
| `isSports` | bool? | query | 否 | | 是否为体育节目 |
| `isFavorite` | bool? | query | 否 | | 是否为收藏 |
| `isPlayed` | bool? | query | 否 | | 是否已播放 |
| `isHd` | bool? | query | 否 | | 是否为高清 |
| `is4K` | bool? | query | 否 | | 是否为 4K |
| `is3D` | bool? | query | 否 | | 是否为 3D |
| `isMissing` | bool? | query | 否 | | 是否缺失文件 |
| `isUnaired` | bool? | query | 否 | | 是否未播出 |
| `isLocked` | bool? | query | 否 | | 是否已锁定（禁止元数据更新） |
| `isPlaceHolder` | bool? | query | 否 | | 是否为占位条目 |
| `hasSubtitles` | bool? | query | 否 | | 是否有字幕 |
| `hasThemeSong` | bool? | query | 否 | | 是否有主题曲 |
| `hasThemeVideo` | bool? | query | 否 | | 是否有主题视频 |
| `hasSpecialFeature` | bool? | query | 否 | | 是否有特别花絮 |
| `hasTrailer` | bool? | query | 否 | | 是否有预告片 |
| `hasOverview` | bool? | query | 否 | | 是否有简介 |
| `hasImdbId` | bool? | query | 否 | | 是否有 IMDB ID |
| `hasTmdbId` | bool? | query | 否 | | 是否有 TMDB ID |
| `hasTvdbId` | bool? | query | 否 | | 是否有 TVDB ID |
| `hasParentalRating` | bool? | query | 否 | | 是否有家长分级 |
| `hasOfficialRating` | bool? | query | 否 | | 是否有官方评级 |
| **评级与日期过滤** | | | | | |
| `minCommunityRating` | double? | query | 否 | | 最低社区评分 |
| `minCriticRating` | double? | query | 否 | | 最低评论家评分 |
| `minPremiereDate` | DateTime? | query | 否 | | 最早首播日期 |
| `maxPremiereDate` | DateTime? | query | 否 | | 最晚首播日期 |
| `minDateLastSaved` | DateTime? | query | 否 | | 最小最后保存日期 |
| `minDateLastSavedForUser` | DateTime? | query | 否 | | 最小用户最后保存日期 |
| `minOfficialRating` | String? | query | 否 | | 最低官方评级 |
| `maxOfficialRating` | String? | query | 否 | | 最高官方评级 |
| **尺寸过滤（像素）** | | | | | |
| `minWidth` | int? | query | 否 | | 最小宽度 |
| `minHeight` | int? | query | 否 | | 最小高度 |
| `maxWidth` | int? | query | 否 | | 最大宽度 |
| `maxHeight` | int? | query | 否 | | 最大高度 |
| **编号过滤** | | | | | |
| `indexNumber` | int? | query | 否 | | 索引编号（如第几集） |
| `parentIndexNumber` | int? | query | 否 | | 父级索引编号（如第几季） |
| **位置类型** | | | | | |
| `locationTypes` | List\<LocationType\>? | query | 否 | | 包含的位置类型（FileSystem、Virtual、Offline） |
| `excludeLocationTypes` | List\<LocationType\>? | query | 否 | | 排除的位置类型 |
| **ID 列表过滤** | | | | | |
| `ids` | List\<String\>? | query | 否 | | 指定条目 ID 列表 |
| `excludeItemIds` | List\<String\>? | query | 否 | | 排除的条目 ID 列表 |
| `studioIds` | List\<String\>? | query | 否 | | 工作室 ID 列表 |
| `genreIds` | List\<String\>? | query | 否 | | 流派 ID 列表 |
| `personIds` | List\<String\>? | query | 否 | | 人物 ID 列表 |
| `artistIds` | List\<String\>? | query | 否 | | 艺术家 ID 列表 |
| `albumArtistIds` | List\<String\>? | query | 否 | | 专辑艺术家 ID 列表 |
| `contributingArtistIds` | List\<String\>? | query | 否 | | 参与艺术家 ID 列表 |
| `excludeArtistIds` | List\<String\>? | query | 否 | | 排除的艺术家 ID 列表 |
| `albumIds` | List\<String\>? | query | 否 | | 专辑 ID 列表 |
| **名称过滤** | | | | | |
| `nameStartsWithOrGreater` | String? | query | 否 | | 名称以指定字符开头或更大 |
| `nameStartsWith` | String? | query | 否 | | 名称前缀 |
| `nameLessThan` | String? | query | 否 | | 名称小于指定值 |
| **关联过滤** | | | | | |
| `person` | String? | query | 否 | | 人物姓名 |
| `personTypes` | List\<String\>? | query | 否 | | 人物类型（如 Actor、Director） |
| `studios` | List\<String\>? | query | 否 | | 工作室名称列表 |
| `artists` | List\<String\>? | query | 否 | | 艺术家名称列表 |
| `albums` | List\<String\>? | query | 否 | | 专辑名称列表 |
| `genres` | List\<String\>? | query | 否 | | 流派名称列表 |
| `tags` | List\<String\>? | query | 否 | | 标签列表 |
| `years` | List\<int\>? | query | 否 | | 年份列表 |
| `officialRatings` | List\<String\>? | query | 否 | | 官方评级列表 |
| `seriesStatus` | List\<SeriesStatus\>? | query | 否 | | 剧集状态（Continuing、Ended） |
| `adjacentTo` | String? | query | 否 | | 获取相邻条目（给定条目 ID 的前后条目） |
| **过滤器与字段** | | | | | |
| `filters` | List\<ItemFilter\>? | query | 否 | | 预设过滤器：`isNotFolder`、`isUnplayed`、`isPlayed`、`isFavorite`、`isFavoriteOrLikes`、`likes`、`dislikes` |
| `fields` | List\<ItemFields\>? | query | 否 | | 指定返回的额外字段，减少数据传输 |
| `collapseBoxSetItems` | bool? | query | 否 | | 是否将合集折叠为单条目 |
| **图片控制** | | | | | |
| `enableImages` | bool? | query | 否 | true | 是否返回图片信息 |
| `imageTypeLimit` | int? | query | 否 | | 每种图片类型返回的最大数量 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | | 指定启用的图片类型 |
| `imageTypes` | List\<ImageType\>? | query | 否 | | 过滤的图片类型 |
| **其他** | | | | | |
| `enableUserData` | bool? | query | 否 | | 是否返回用户数据（播放进度、收藏等） |
| `enableTotalRecordCount` | bool? | query | 否 | true | 是否返回总记录数（设 false 可提高性能） |

### ItemSortBy 枚举值

| 值 | 说明 |
|----|------|
| `default` | 默认排序 |
| `sortName` | 按排序名称 |
| `name` | 按名称 |
| `communityRating` | 按社区评分 |
| `criticRating` | 按评论家评分 |
| `dateCreated` | 按创建日期 |
| `dateLastContentAdded` | 按最后添加内容日期 |
| `playCount` | 按播放次数 |
| `datePlayed` | 按播放日期 |
| `premiereDate` | 按首播日期 |
| `productionYear` | 按出品年份 |
| `runtime` | 按时长 |
| `random` | 随机排序 |
| `airTime` | 按播出时间 |
| `studio` | 按工作室 |
| `officialRating` | 按官方评级 |

### BaseItemKind 枚举值（常用）

| 值 | 说明 |
|----|------|
| `aggregateFolder` | 聚合文件夹 |
| `audio` | 音频 |
| `audioBook` | 有声书 |
| `book` | 书籍 |
| `boxSet` | 合集 |
| `channel` | 频道 |
| `collectionFolder` | 收藏文件夹 |
| `episode` | 剧集单集 |
| `folder` | 文件夹 |
| `genre` | 流派 |
| `liveTvChannel` | 直播频道 |
| `liveTvProgram` | 直播节目 |
| `movie` | 电影 |
| `musicAlbum` | 音乐专辑 |
| `musicArtist` | 音乐艺术家 |
| `musicGenre` | 音乐流派 |
| `musicVideo` | 音乐视频 |
| `person` | 人物 |
| `photo` | 照片 |
| `photoAlbum` | 相册 |
| `playlist` | 播放列表 |
| `program` | 节目 |
| `recording` | 录制 |
| `season` | 季 |
| `series` | 电视剧系列 |
| `studio` | 工作室 |
| `trailer` | 预告片 |
| `userRootFolder` | 用户根文件夹 |
| `userView` | 用户视图 |
| `video` | 视频 |
| `year` | 年份 |

### ItemFields 枚举值（常用）

| 值 | 说明 |
|----|------|
| `airDays` | 播出日期 |
| `airTime` | 播出时间 |
| `canDelete` | 能否删除 |
| `canDownload` | 能否下载 |
| `channelInfo` | 频道信息 |
| `chapters` | 章节信息 |
| `childCount` | 子项数量 |
| `cumulativeRunTimeTicks` | 累计时长 |
| `customRating` | 自定义评级 |
| `dateCreated` | 创建日期 |
| `dateLastMediaAdded` | 最后添加媒体日期 |
| `displayPreferencesId` | 显示偏好 ID |
| `etag` | ETag |
| `externalUrls` | 外部链接 |
| `genres` | 流派 |
| `homePageUrl` | 主页 URL |
| `itemCounts` | 条目计数 |
| `mediaSourceCount` | 媒体源数量 |
| `mediaSources` | 媒体源（含播放 URL） |
| `overview` | 简介 |
| `originalTitle` | 原始标题 |
| `people` | 参与人员 |
| `playAccess` | 播放权限 |
| `productionLocations` | 制作地点 |
| `providerIds` | 外部提供商 ID（IMDB、TMDB 等） |
| `primaryImageAspectRatio` | 主图宽高比 |
| `recursiveItemCount` | 递归子项数 |
| `screenshotImageTags` | 截图标签 |
| `seriesPrimaryImage` | 剧集主图 |
| `seriesStudio` | 剧集工作室 |
| `sortName` | 排序名称 |
| `specialEpisodeNumbers` | 特别集编号 |
| `studios` | 工作室 |
| `taglines` | 标语 |
| `tags` | 标签 |
| `trailers` | 预告片 |

---

## getResumeItems — 获取继续观看列表

```
GET /UserItems/Resume
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| `userId` | String? | query | 否 | | 用户 ID |
| `startIndex` | int? | query | 否 | | 分页起始索引 |
| `limit` | int? | query | 否 | | 每页最大条目数 |
| `searchTerm` | String? | query | 否 | | 搜索关键词 |
| `parentId` | String? | query | 否 | | 父级 ID |
| `fields` | List\<ItemFields\>? | query | 否 | | 返回的额外字段 |
| `mediaTypes` | List\<MediaType\>? | query | 否 | | 媒体类型过滤 |
| `enableUserData` | bool? | query | 否 | | 是否返回用户数据 |
| `imageTypeLimit` | int? | query | 否 | | 图片类型数量限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | | 启用的图片类型 |
| `excludeItemTypes` | List\<BaseItemKind\>? | query | 否 | | 排除的条目类型 |
| `includeItemTypes` | List\<BaseItemKind\>? | query | 否 | | 包含的条目类型 |
| `enableTotalRecordCount` | bool? | query | 否 | true | 是否返回总记录数 |
| `enableImages` | bool? | query | 否 | true | 是否返回图片信息 |
| `excludeActiveSessions` | bool? | query | 否 | false | 是否排除活跃会话中正在播放的 |

---

## getItemUserData — 获取条目的用户数据

```
GET /UserItems/{itemId}/UserData
返回: Response<UserItemDataDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `userId` | String? | query | 否 | 用户 ID |

**返回 UserItemDataDto 包含：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `playbackPositionTicks` | int? | 播放位置（刻度，1 秒 = 10000000） |
| `playCount` | int? | 播放次数 |
| `isFavorite` | bool? | 是否收藏 |
| `likes` | bool? | 是否点赞 |
| `lastPlayedDate` | DateTime? | 最后播放时间 |
| `played` | bool? | 是否已看完 |
| `unplayedItemCount` | int? | 未播放子项数 |

---

## updateItemUserData — 更新条目的用户数据

```
POST /UserItems/{itemId}/UserData
返回: Response<UserItemDataDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `updateUserItemDataDto` | UpdateUserItemDataDto | body | **是** | 用户数据更新体 |
| `userId` | String? | query | 否 | 用户 ID |

**UpdateUserItemDataDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `playbackPositionTicks` | int? | 播放位置 |
| `playCount` | int? | 播放次数 |
| `isFavorite` | bool? | 是否收藏 |
| `likes` | bool? | 是否点赞 |
| `lastPlayedDate` | DateTime? | 最后播放时间 |
| `played` | bool? | 是否已看完 |
