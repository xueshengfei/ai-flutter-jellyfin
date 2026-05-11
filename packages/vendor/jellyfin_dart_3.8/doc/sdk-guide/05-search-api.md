# 05 搜索与推荐 — SearchApi / SuggestionsApi / FilterApi

## SearchApi

获取方式：`client.getSearchApi()`

---

### getSearchHints — 全局搜索

```
GET /Search/Hints
返回: Response<SearchHintResult>
```

| 参数 | 类型 | 位置 | 必填 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| `searchTerm` | String | query | **是** | | 搜索关键词 |
| `startIndex` | int? | query | 否 | | 分页起始索引 |
| `limit` | int? | query | 否 | | 最大返回数 |
| `userId` | String? | query | 否 | | 用户 ID |
| `includeItemTypes` | List\<BaseItemKind\>? | query | 否 | | 只搜索这些类型 |
| `excludeItemTypes` | List\<BaseItemKind\>? | query | 否 | | 排除这些类型 |
| `mediaTypes` | List\<MediaType\>? | query | 否 | | 媒体类型过滤 |
| `parentId` | String? | query | 否 | | 限定在指定文件夹下搜索 |
| `isMovie` | bool? | query | 否 | | 只搜电影 |
| `isSeries` | bool? | query | 否 | | 只搜剧集 |
| `isNews` | bool? | query | 否 | | 只搜新闻 |
| `isKids` | bool? | query | 否 | | 只搜儿童内容 |
| `isSports` | bool? | query | 否 | | 只搜体育内容 |
| `includePeople` | bool? | query | 否 | true | 是否包含人物搜索结果 |
| `includeMedia` | bool? | query | 否 | true | 是否包含媒体搜索结果 |
| `includeGenres` | bool? | query | 否 | true | 是否包含流派搜索结果 |
| `includeStudios` | bool? | query | 否 | true | 是否包含工作室搜索结果 |
| `includeArtists` | bool? | query | 否 | true | 是否包含艺术家搜索结果 |

**SearchHintResult 返回字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `searchHints` | List\<SearchHint\>? | 搜索提示列表 |
| `totalRecordCount` | int? | 总结果数 |

---

## SuggestionsApi

获取方式：`client.getSuggestionsApi()`

---

### getSuggestions — 获取推荐内容

```
GET /Users/{userId}/Suggestions
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String | path | **是** | 用户 ID |
| `mediaType` | String? | query | 否 | 媒体类型过滤 |
| `type` | List\<BaseItemKind\>? | query | 否 | 条目类型过滤 |
| `startIndex` | int? | query | 否 | 分页起始索引 |
| `limit` | int? | query | 否 | 最大返回数 |
| `enableTotalRecordCount` | bool? | query | 否 | 是否返回总记录数 |

---

## FilterApi

获取方式：`client.getFilterApi()`

---

### getQueryFiltersLegacy — 获取旧版查询过滤器

```
GET /Items/Filters
返回: Response<QueryFiltersLegacy>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `parentId` | String? | query | 否 | 父级 ID |
| `includeItemTypes` | List\<BaseItemKind\>? | query | 否 | 条目类型 |
| `isAiring` | bool? | query | 否 | 是否正在播出 |
| `isMovie` | bool? | query | 否 | 是否为电影 |
| `isMovieRecommendation` | bool? | query | 否 | 是否为电影推荐 |
| `isPlayed` | bool? | query | 否 | 是否已播放 |
| `isSeries` | bool? | query | 否 | 是否为剧集 |
| `isSports` | bool? | query | 否 | 是否为体育 |

---

### getQueryFilters — 获取查询过滤器

```
GET /Items/Filters2
返回: Response<QueryFilters>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String? | query | 否 | 用户 ID |
| `parentId` | String? | query | 否 | 父级 ID |
| `includeItemTypes` | List\<BaseItemKind\>? | query | 否 | 条目类型 |
| `isAiring` | bool? | query | 否 | 是否正在播出 |
| `isMovie` | bool? | query | 否 | 是否为电影 |
| `isSeries` | bool? | query | 否 | 是否为剧集 |
| `isSports` | bool? | query | 否 | 是否为体育 |
| `isKids` | bool? | query | 否 | 是否为儿童内容 |
| `isNews` | bool? | query | 否 | 是否为新闻 |

**QueryFilters 返回可用过滤选项：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `genres` | List\<NameGuidPair\>? | 可用流派 |
| `tags` | List\<String\>? | 可用标签 |
| `years` | List\<int\>? | 可用年份 |
