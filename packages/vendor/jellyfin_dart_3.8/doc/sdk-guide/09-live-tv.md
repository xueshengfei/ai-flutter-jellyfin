# 09 直播电视 — LiveTvApi / ChannelsApi

---

## LiveTvApi

获取方式：`client.getLiveTvApi()`

### getChannel — 获取频道详情

```
GET /LiveTv/Channels/{channelId}
返回: Response<BaseItemDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `channelId` | String | path | **是** | 频道 ID |
| `userId` | String? | query | 否 | 用户 ID |

### getRecommendedPrograms — 获取推荐节目

```
GET /LiveTv/Programs/Recommended
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String? | query | 否 | 用户 ID |
| `limit` | int? | query | 否 | 最大返回数 |
| `isAiring` | bool? | query | 否 | 是否正在播出 |
| `hasAired` | bool? | query | 否 | 是否已播出 |
| `isMovie` | bool? | query | 否 | 是否为电影 |
| `isSeries` | bool? | query | 否 | 是否为剧集 |
| `isSports` | bool? | query | 否 | 是否为体育 |
| `isKids` | bool? | query | 否 | 是否为儿童节目 |
| `isNews` | bool? | query | 否 | 是否为新闻 |
| `enableImages` | bool? | query | 否 | 是否返回图片 |
| `imageTypeLimit` | int? | query | 否 | 图片类型数量限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | 启用的图片类型 |
| `enableUserData` | bool? | query | 否 | 是否返回用户数据 |
| `enableTotalRecordCount` | bool? | query | 否 | 是否返回总记录数 |

### getPrograms — 获取节目列表

```
POST /LiveTv/Programs
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `getProgramsDto` | GetProgramsDto | body | **是** | 查询条件 |

**GetProgramsDto 关键字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `channelIds` | List\<String\>? | 频道 ID 列表 |
| `userId` | String? | 用户 ID |
| `minStartDate` | DateTime? | 最早开始时间 |
| `hasAired` | bool? | 是否已播出 |
| `isAiring` | bool? | 是否正在播出 |
| `maxStartDate` | DateTime? | 最晚开始时间 |
| `minEndDate` | DateTime? | 最早结束时间 |
| `maxEndDate` | DateTime? | 最晚结束时间 |
| `isMovie` | bool? | 是否为电影 |
| `isSeries` | bool? | 是否为剧集 |
| `isSports` | bool? | 是否为体育 |
| `isKids` | bool? | 是否为儿童节目 |
| `isNews` | bool? | 是否为新闻 |
| `sortBy` | String? | 排序字段 |
| `sortOrder` | SortOrder? | 排序方向 |
| `genres` | List\<String\>? | 流派列表 |
| `genreIds` | List\<String\>? | 流派 ID 列表 |
| `enableImages` | bool? | 是否返回图片 |
| `enableTotalRecordCount` | bool? | 是否返回总数 |

### getRecordings — 获取录像列表

```
GET /LiveTv/Recordings
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `channelId` | String? | query | 否 | 频道 ID |
| `userId` | String? | query | 否 | 用户 ID |
| `startIndex` | int? | query | 否 | 分页起始索引 |
| `limit` | int? | query | 否 | 最大返回数 |
| `status` | RecordingStatus? | query | 否 | 录像状态 |
| `isInProgress` | bool? | query | 否 | 是否正在进行 |
| `seriesTimerId` | String? | query | 否 | 系列定时器 ID |
| `enableImages` | bool? | query | 否 | 是否返回图片 |
| `imageTypeLimit` | int? | query | 否 | 图片类型限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | 启用的图片类型 |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
| `enableTotalRecordCount` | bool? | query | 否 | 是否返回总记录数 |
| `enableUserData` | bool? | query | 否 | 是否返回用户数据 |

### getRecording — 获取录像详情

```
GET /LiveTv/Recordings/{recordingId}
返回: Response<BaseItemDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `recordingId` | String | path | **是** | 录像 ID |
| `userId` | String? | query | 否 | 用户 ID |

### deleteRecording — 删除录像

```
DELETE /LiveTv/Recordings/{recordingId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `recordingId` | String | path | **是** | 录像 ID |

### getRecordingsSeries — 获取录像系列

```
GET /LiveTv/Recordings/Series
返回: Response<BaseItemDtoQueryResult>
```

参数与 getRecordings 类似（channelId、userId、startIndex、limit、status、isInProgress、seriesTimerId、enableImages 等）。

### getTimers — 获取定时器列表

```
GET /LiveTv/Timers
返回: Response<QueryResult<TimerInfoDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `channelId` | String? | query | 否 | 频道 ID |
| `seriesTimerId` | String? | query | 否 | 系列定时器 ID |
| `isActive` | bool? | query | 否 | 是否活跃 |
| `isScheduled` | bool? | query | 否 | 是否已安排 |

### getTimer — 获取定时器详情

```
GET /LiveTv/Timers/{timerId}
返回: Response<TimerInfoDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `timerId` | String | path | **是** | 定时器 ID |

### getDefaultTimer — 获取默认定时器设置

```
GET /LiveTv/Timers/Defaults
返回: Response<SeriesTimerInfoDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `programId` | String? | query | 否 | 节目 ID |

### createTimer — 创建定时录像

```
POST /LiveTv/Timers
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `timerInfoDto` | TimerInfoDto | body | **是** | 定时器信息 |

### updateTimer — 更新定时器

```
POST /LiveTv/Timers/{timerId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `timerId` | String | path | **是** | 定时器 ID |
| `timerInfoDto` | TimerInfoDto | body | **是** | 定时器信息 |

### cancelTimer — 取消定时器

```
DELETE /LiveTv/Timers/{timerId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `timerId` | String | path | **是** | 定时器 ID |

### getSeriesTimers — 获取系列定时器列表

```
GET /LiveTv/SeriesTimers
返回: Response<QueryResult<SeriesTimerInfoDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `sortBy` | String? | query | 否 | 排序字段 |
| `sortOrder` | SortOrder? | query | 否 | 排序方向 |

### getSeriesTimer — 获取系列定时器详情

```
GET /LiveTv/SeriesTimers/{timerId}
返回: Response<SeriesTimerInfoDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `timerId` | String | path | **是** | 定时器 ID |

### createSeriesTimer — 创建系列定时器

```
POST /LiveTv/SeriesTimers
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `seriesTimerInfoDto` | SeriesTimerInfoDto | body | **是** | 系列定时器信息 |

### updateSeriesTimer — 更新系列定时器

```
POST /LiveTv/SeriesTimers/{timerId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `timerId` | String | path | **是** | 定时器 ID |
| `seriesTimerInfoDto` | SeriesTimerInfoDto | body | **是** | 系列定时器信息 |

### cancelSeriesTimer — 取消系列定时器

```
DELETE /LiveTv/SeriesTimers/{timerId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `timerId` | String | path | **是** | 定时器 ID |

### addTunerHost — 添加调谐器

```
POST /LiveTv/TunerHosts
返回: Response<TunerHostInfo>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `tunerHostInfo` | TunerHostInfo | body | **是** | 调谐器信息 |

### addListingProvider — 添加节目指南提供商

```
POST /LiveTv/ListingProviders
返回: Response<ListingsProviderInfo>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `pw` | String? | query | 否 | 密码 |
| `validateListings` | bool? | query | 否 | 是否验证列表 |
| `validateLogin` | bool? | query | 否 | 是否验证登录 |
| `listingsProviderInfo` | ListingsProviderInfo | body | **是** | 提供商信息 |

### getChannelMappingOptions — 获取频道映射选项

```
GET /LiveTv/ChannelMappingOptions
返回: Response<ChannelMappingOptionsDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `providerId` | String | query | **是** | 提供商 ID |

### setChannelMapping — 设置频道映射

```
POST /LiveTv/ChannelMappings
返回: Response<ChannelMappingOptionsDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `setChannelMappingDto` | SetChannelMappingDto | body | **是** | 映射设置 |

### getLineups — 获取节目阵容

```
GET /LiveTv/ListingProviders/Lineups
返回: Response<List<NameIdPair>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `id` | String? | query | 否 | 提供商 ID |
| `type` | String? | query | 否 | 类型 |
| `location` | String? | query | 否 | 位置 |
| `channelId` | String? | query | 否 | 频道 ID |

### getDefaultListingProvider — 获取默认节目指南提供商

```
GET /LiveTv/ListingProviders/Default
返回: Response<ListingsProviderInfo>
```

无参数。

### getLiveRecordingFile — 获取实时录像文件流

```
GET /LiveTv/LiveRecordings/{recordingId}/stream
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `recordingId` | String | path | **是** | 录像 ID |

### getLiveStreamFile — 获取直播流文件

```
GET /LiveTv/LiveStreams/{streamId}/stream.{container}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `streamId` | String | path | **是** | 流 ID |
| `container` | String | path | **是** | 容器格式 |

---

## ChannelsApi — 频道查询

获取方式：`client.getChannelsApi()`

### getChannelFeatures — 获取频道功能

```
GET /Channels/Features
返回: Response<List<ChannelFeatures>>
```

无参数。

### getChannelItems — 获取频道内容

```
GET /Channels/{channelId}/Items
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `channelId` | String | path | **是** | 频道 ID |
| `folderId` | String? | query | 否 | 文件夹 ID |
| `userId` | String? | query | 否 | 用户 ID |
| `startIndex` | int? | query | 否 | 分页起始索引 |
| `limit` | int? | query | 否 | 最大返回数 |
| `sortOrder` | SortOrder? | query | 否 | 排序方向 |
| `sortBy` | List\<ItemSortBy\>? | query | 否 | 排序字段 |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |

### getChannels — 获取频道列表

```
GET /Channels
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String? | query | 否 | 用户 ID |
| `startIndex` | int? | query | 否 | 分页起始索引 |
| `limit` | int? | query | 否 | 最大返回数 |
| `isFavorite` | bool? | query | 否 | 是否只返回收藏的频道 |
| `enableUserData` | bool? | query | 否 | 是否返回用户数据 |
| `sortOrder` | SortOrder? | query | 否 | 排序方向 |
| `sortBy` | List\<ItemSortBy\>? | query | 否 | 排序字段 |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
