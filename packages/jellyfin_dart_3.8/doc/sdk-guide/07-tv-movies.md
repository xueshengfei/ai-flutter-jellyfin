# 07 剧集与电影 — TvShowsApi / MoviesApi / TrailersApi

---

## TvShowsApi — 电视剧

获取方式：`client.getTvShowsApi()`

### getSeasons — 获取剧集的季列表

```
GET /Shows/{seriesId}/Seasons
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `seriesId` | String | path | **是** | 电视剧系列 ID |
| `userId` | String? | query | 否 | 用户 ID |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |

### getEpisodes — 获取某一季的剧集列表

```
GET /Shows/{seriesId}/Episodes
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `seriesId` | String | path | **是** | 电视剧系列 ID |
| `userId` | String? | query | 否 | 用户 ID |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
| `season` | int? | query | 否 | 季编号 |
| `seasonId` | String? | query | 否 | 季 ID |
| `isMissing` | bool? | query | 否 | 是否包含缺失的剧集 |
| `adjacentTo` | String? | query | 否 | 获取相邻剧集（给定条目 ID） |
| `startItemId` | String? | query | 否 | 起始条目 ID |
| `startIndex` | int? | query | 否 | 分页起始索引 |
| `limit` | int? | query | 否 | 每页最大数 |
| `enableImages` | bool? | query | 否 | 是否返回图片信息 |
| `imageTypeLimit` | int? | query | 否 | 图片类型数量限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | 启用的图片类型 |
| `enableUserData` | bool? | query | 否 | 是否返回用户数据 |
| `sortBy` | List\<ItemSortBy\>? | query | 否 | 排序字段 |

### getNextUp — 获取「下一集」

```
GET /Shows/NextUp
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String? | query | 否 | 用户 ID |
| `startIndex` | int? | query | 否 | 分页起始索引 |
| `limit` | int? | query | 否 | 最大返回数 |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
| `seriesId` | String? | query | 否 | 限定在某部剧集中 |
| `parentId` | String? | query | 否 | 限定在某个文件夹下 |
| `enableImages` | bool? | query | 否 | 是否返回图片 |
| `imageTypeLimit` | int? | query | 否 | 图片类型数量限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | 启用的图片类型 |
| `enableUserData` | bool? | query | 否 | 是否返回用户数据 |
| `enableTotalRecordCount` | bool? | query | 否 | 是否返回总记录数 |
| `disableFirstEpisode` | bool? | query | 否 | 禁止显示第一季第一集 |
| `nextUpDateCutoff` | DateTime? | query | 否 | 下一集日期截止时间 |
| `enableResumable` | bool? | query | 否 | 是否包含可恢复播放的 |

### getUpcoming — 获取即将播出的剧集

```
GET /Shows/Upcoming
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String? | query | 否 | 用户 ID |
| `startIndex` | int? | query | 否 | 分页起始索引 |
| `limit` | int? | query | 否 | 最大返回数 |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
| `parentId` | String? | query | 否 | 父级 ID |
| `enableImages` | bool? | query | 否 | 是否返回图片 |
| `imageTypeLimit` | int? | query | 否 | 图片类型限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | 启用的图片类型 |
| `enableUserData` | bool? | query | 否 | 是否返回用户数据 |
| `enableTotalRecordCount` | bool? | query | 否 | 是否返回总记录数 |

---

## MoviesApi — 电影推荐

获取方式：`client.getMoviesApi()`

### getMovieRecommendations — 获取电影推荐

```
GET /Movies/Recommendations
返回: Response<List<RecommendationDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String? | query | 否 | 用户 ID |
| `parentId` | String? | query | 否 | 限定文件夹 |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
| `categoryLimit` | int? | query | 否 | 推荐分类数上限 |
| `itemLimit` | int? | query | 否 | 每个分类的条目数上限 |
| `enableImages` | bool? | query | 否 | 是否返回图片 |
| `enableUserData` | bool? | query | 否 | 是否返回用户数据 |
| `imageTypeLimit` | int? | query | 否 | 图片类型限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | 启用的图片类型 |

**RecommendationDto 返回字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `items` | List\<BaseItemDto\>? | 推荐的电影列表 |
| `recommendationType` | RecommendationType? | 推荐类型 |
| `baselineItemName` | String? | 基准条目名称 |
| `categoryId` | String? | 分类 ID |

### getMovieTrailers — 获取电影预告片

```
GET /Movies/Trailers
返回: Response<BaseItemDtoQueryResult>
```

参数与 ItemsApi.getItems 完全相同（含所有过滤、排序、分页参数），参见 [03-items-api.md](03-items-api.md)。

---

## TrailersApi — 预告片

获取方式：`client.getTrailersApi()`

### getTrailers — 获取预告片

```
GET /Trailers
返回: Response<BaseItemDtoQueryResult>
```

参数与 ItemsApi.getItems 完全相同，参见 [03-items-api.md](03-items-api.md)。专门用于查询预告片类型的媒体条目。
