# 15 其他 API

---

## ActivityLogApi — 活动日志

获取方式：`client.getActivityLogApi()`

### getLogEntries — 获取活动日志

```
GET /System/ActivityLog/Entries
返回: Response<ActivityLogEntryQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `startIndex` | int? | query | 否 | 分页起始索引 |
| `limit` | int? | query | 否 | 最大返回数 |
| `minDate` | DateTime? | query | 否 | 最早日期 |
| `hasUserId` | bool? | query | 否 | 是否有用户 ID |

---

## ApiKeyApi — API Key 管理

获取方式：`client.getApiKeyApi()`

### getKeys — 获取所有 API Key

```
GET /Auth/Keys
返回: Response<AuthenticationInfoQueryResult>
```

无参数。

### createKey — 创建 API Key

```
POST /Auth/Keys
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `app` | String | query | **是** | 应用名称 |

### revokeKey — 撤销 API Key

```
DELETE /Auth/Keys/{key}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `key` | String | path | **是** | API Key |

---

## BackupApi — 备份管理

获取方式：`client.getBackupApi()`

### getBackup — 获取备份文件

```
GET /System/Backup/{backupId}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `backupId` | String | path | **是** | 备份 ID |

### getBackups — 获取备份列表

```
GET /System/Backups
返回: Response<List<BackupInfo>>
```

无参数。

### createBackup — 创建备份

```
POST /System/Backup
返回: Response<BackupInfo>
```

无参数。

### restoreBackup — 恢复备份

```
POST /System/Backup/{backupId}/Restore
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `backupId` | String | path | **是** | 备份 ID |

---

## ClientLogApi — 客户端日志

获取方式：`client.getClientLogApi()`

### logFile — 上传客户端日志

```
POST /ClientLog/Document
返回: Response<ClientLogDocumentResponseDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `body` | Uint8List | body | **是** | 日志文件内容 |

---

## DashboardApi — 仪表盘

获取方式：`client.getDashboardApi()`

### getConfigurationPage — 获取配置页面

```
GET /web/ConfigurationPage
返回: Response<String>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | query | **是** | 页面名称 |

### getConfigurationPages — 获取配置页面列表

```
GET /web/ConfigurationPages
返回: Response<List<ConfigurationPageInfo>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `pageType` | ConfigurationPageType? | query | 否 | 页面类型 |
| `enableInMainMenu` | bool? | query | 否 | 是否在主菜单中显示 |

---

## DevicesApi — 设备管理

获取方式：`client.getDevicesApi()`

### getDevices — 获取设备列表

```
GET /Devices
返回: Response<QueryResult<DeviceInfoDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String? | query | 否 | 用户 ID |

### getDeviceInfo — 获取设备详情

```
GET /Devices/Info
返回: Response<DeviceInfoDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `id` | String | query | **是** | 设备 ID |

### deleteDevice — 删除设备

```
DELETE /Devices
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `id` | String | query | **是** | 设备 ID |

### updateDevice — 更新设备信息

```
POST /Devices/Info
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `id` | String | query | **是** | 设备 ID |
| `deviceInfoDto` | DeviceInfoDto | body | **是** | 设备信息 |

---

## DisplayPreferencesApi — 显示偏好

获取方式：`client.getDisplayPreferencesApi()`

### getDisplayPreferences — 获取显示偏好

```
GET /DisplayPreferences/{displayPreferencesId}
返回: Response<DisplayPreferencesDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `displayPreferencesId` | String | path | **是** | 偏好 ID |
| `userId` | String | query | **是** | 用户 ID |
| `client` | String | query | **是** | 客户端标识 |

### updateDisplayPreferences — 更新显示偏好

```
POST /DisplayPreferences/{displayPreferencesId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `displayPreferencesId` | String | path | **是** | 偏好 ID |
| `displayPreferencesDto` | DisplayPreferencesDto | body | **是** | 偏好数据 |
| `userId` | String | query | **是** | 用户 ID |
| `client` | String | query | **是** | 客户端标识 |

---

## EnvironmentApi — 环境信息

获取方式：`client.getEnvironmentApi()`

### getDirectoryContents — 获取目录内容

```
GET /Environment/DirectoryContents
返回: Response<List<FileSystemEntryInfo>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `path` | String | query | **是** | 目录路径 |
| `includeFiles` | bool? | query | 否 | 包含文件（默认 true） |
| `includeDirectories` | bool? | query | 否 | 包含目录（默认 true） |

### getDrives — 获取驱动器列表

```
GET /Environment/Drives
返回: Response<List<FileSystemEntryInfo>>
```

无参数。

### getDefaultDirectoryBrowser — 获取默认目录

```
GET /Environment/DefaultDirectoryBrowser
返回: Response<DefaultDirectoryBrowserInfoDto>
```

无参数。

### getParentPath — 获取父路径

```
GET /Environment/ParentPath
返回: Response<String>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `path` | String | query | **是** | 当前路径 |

### validatePath — 验证路径

```
POST /Environment/ValidatePath
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `validatePathDto` | ValidatePathDto | body | **是** | 路径验证请求 |

---

## ItemLookupApi — 条目元数据查找

获取方式：`client.getItemLookupApi()`

### getExternalIdInfos — 获取外部 ID 信息

```
GET /Items/{itemId}/ExternalIdInfos
返回: Response<List<ExternalIdInfo>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |

### getMovieRecommendations — 获取电影外部推荐

```
POST /Items/RemoteSearch/Movie
返回: Response<List<ExternalSearchResult>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `externalSeriesRequest` | ExternalSeriesRequest? | body | 否 | 搜索条件 |

### getSeriesRecommendations — 获取剧集外部推荐

```
POST /Items/RemoteSearch/Series
返回: Response<List<ExternalSearchResult>>
```

### applySearchResult — 应用搜索结果

```
POST /Items/RemoteSearch/Apply/{itemId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `body` | ExternalSearchResult? | body | 否 | 搜索结果 |

---

## ItemRefreshApi — 条目刷新

获取方式：`client.getItemRefreshApi()`

### refreshItem — 刷新条目元数据

```
POST /Items/{itemId}/Refresh
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `metadataRefreshMode` | MetadataRefreshMode? | query | 否 | 元数据刷新模式 |
| `imageRefreshMode` | MetadataRefreshMode? | query | 否 | 图片刷新模式 |
| `replaceAllMetadata` | bool? | query | 否 | 替换所有元数据 |
| `replaceAllImages` | bool? | query | 否 | 替换所有图片 |
| `regenerateTrickplay` | bool? | query | 否 | 重新生成 Trickplay |

---

## ItemUpdateApi — 条目更新

获取方式：`client.getItemUpdateApi()`

### updateItem — 更新条目信息

```
POST /Items/{itemId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `baseItemDto` | BaseItemDto | body | **是** | 更新后的条目数据 |

### getItem — 获取条目详情

```
GET /Items/{itemId}
返回: Response<BaseItemDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `userId` | String? | query | 否 | 用户 ID |

---

## LocalizationApi — 本地化

获取方式：`client.getLocalizationApi()`

### getCountries — 获取国家列表

```
GET /Localization/Countries
返回: Response<List<CountryInfo>>
```

### getCultures — 获取文化/语言列表

```
GET /Localization/Cultures
返回: Response<List<CountryInfo>>
```

### getParentalRatings — 获取家长评级列表

```
GET /Localization/ParentalRatings
返回: Response<List<ParentalRating>>
```

### getLocalizationOptions — 获取本地化选项

```
GET /Localization/Options
返回: Response<List<LocalizationOption>>
```

以上方法均无额外参数。

---

## MediaSegmentsApi — 媒体片段

获取方式：`client.getMediaSegmentsApi()`

### getMediaSegments — 获取媒体片段

```
GET /MediaSegments/{itemId}
返回: Response<MediaSegmentsResponse>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |

---

## PackageApi — 包管理（插件安装）

获取方式：`client.getPackageApi()`

### getPackages — 获取可用包列表

```
GET /Packages
返回: Response<List<PackageInfo>>
```

无参数。

### getPackageInfo — 获取包详情

```
GET /Packages/{name}
返回: Response<PackageInfo>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | path | **是** | 包名 |

### installPackage — 安装包

```
POST /Packages/Installed/{name}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | path | **是** | 包名 |
| `assemblyGuid` | String? | query | 否 | 程序集 GUID |
| `version` | String? | query | 否 | 版本 |

### cancelPackageInstallation — 取消包安装

```
DELETE /Packages/Installing/{packageId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `packageId` | String | path | **是** | 安装 ID |

### getRepositories — 获取仓库列表

```
GET /Repositories
返回: Response<List<RepositoryInfo>>
```

### setRepositories — 设置仓库列表

```
POST /Repositories
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `repositoryInfo` | List\<RepositoryInfo\> | body | **是** | 仓库列表 |

---

## PersonsApi — 人物查询

获取方式：`client.getPersonsApi()`

### getPersons — 获取人物列表

```
GET /Persons
返回: Response<BaseItemDtoQueryResult>
```

参数与 ArtistsApi.getArtists 类似（startIndex、limit、searchTerm、parentId、fields、filters、isFavorite、userId、nameStartsWith 等通用过滤参数）。

### getPerson — 获取单个人物

```
GET /Persons/{name}
返回: Response<BaseItemDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | path | **是** | 人物名称 |
| `userId` | String? | query | 否 | 用户 ID |

---

## PluginsApi — 插件管理

获取方式：`client.getPluginsApi()`

### getPlugins — 获取已安装插件

```
GET /Plugins
返回: Response<List<PluginInfo>>
```

### uninstallPlugin — 卸载插件

```
DELETE /Plugins/{pluginId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `pluginId` | String | path | **是** | 插件 ID |

### enablePlugin — 启用插件

```
POST /Plugins/{pluginId}/{version}/Enable
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `pluginId` | String | path | **是** | 插件 ID |
| `version` | String | path | **是** | 版本号 |

### disablePlugin — 禁用插件

```
POST /Plugins/{pluginId}/{version}/Disable
返回: Response<void>
```

参数同 enablePlugin。

---

## QuickConnectApi — 快速连接

获取方式：`client.getQuickConnectApi()`

### getQuickConnectState — 获取快速连接状态

```
GET /QuickConnect/Enabled
返回: Response<bool>
```

无参数。

### initiateQuickConnect — 发起快速连接

```
POST /QuickConnect/Initiate
返回: Response<QuickConnectResult>
```

无参数。

**QuickConnectResult 返回字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `secret` | String? | 用于认证的密钥 |
| `authenticated` | bool? | 是否已认证 |

### holdQuickConnect — 等待快速连接认证

```
GET /QuickConnect/Connect
返回: Response<QuickConnectResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `secret` | String | query | **是** | 快速连接密钥 |

### authorizeQuickConnect — 授权快速连接

```
POST /QuickConnect/Authorize
返回: Response<bool>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `code` | String | query | **是** | 用户输入的验证码 |

---

## RemoteImageApi — 远程图片

获取方式：`client.getRemoteImageApi()`

### getRemoteImages — 获取远程图片列表

```
GET /Items/{itemId}/RemoteImages
返回: Response<RemoteImageResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `type` | ImageType? | query | 否 | 图片类型 |
| `providerName` | String? | query | 否 | 提供商名称 |
| `includeAllLanguages` | bool? | query | 否 | 包含所有语言 |

### downloadRemoteImage — 下载远程图片

```
POST /Items/{itemId}/RemoteImages/Download
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `type` | ImageType | query | **是** | 图片类型 |
| `providerName` | String? | query | 否 | 提供商名称 |

### getRemoteImageProviders — 获取远程图片提供商

```
GET /Items/{itemId}/RemoteImages/Providers
返回: Response<List<ImageProviderInfo>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |

---

## ScheduledTasksApi — 定时任务

获取方式：`client.getScheduledTasksApi()`

### getTasks — 获取任务列表

```
GET /ScheduledTasks
返回: Response<List<TaskInfo>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `isHidden` | bool? | query | 否 | 是否包含隐藏任务 |
| `isEnabled` | bool? | query | 否 | 是否包含禁用任务 |

### getTask — 获取任务详情

```
GET /ScheduledTasks/{taskId}
返回: Response<TaskInfo>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `taskId` | String | path | **是** | 任务 ID |

### startTask — 启动任务

```
POST /ScheduledTasks/Running/{taskId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `taskId` | String | path | **是** | 任务 ID |

### stopTask — 停止任务

```
DELETE /ScheduledTasks/Running/{taskId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `taskId` | String | path | **是** | 任务 ID |

### updateTask — 更新任务配置

```
POST /ScheduledTasks/{taskId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `taskId` | String | path | **是** | 任务 ID |
| `taskConfiguration` | TaskConfiguration | body | **是** | 任务配置 |

---

## StudiosApi — 工作室查询

获取方式：`client.getStudiosApi()`

### getStudios — 获取工作室列表

```
GET /Studios
返回: Response<BaseItemDtoQueryResult>
```

参数同通用列表查询（startIndex、limit、searchTerm、parentId、fields、userId 等）。

### getStudio — 获取单个工作室

```
GET /Studios/{name}
返回: Response<BaseItemDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | path | **是** | 工作室名称 |
| `userId` | String? | query | 否 | 用户 ID |

---

## TimeSyncApi — 时间同步

获取方式：`client.getTimeSyncApi()`

### getUtcTime — 获取服务器 UTC 时间

```
GET /GetUtcTime
返回: Response<DateTime>
```

无参数。

---

## TmdbApi — TMDB 数据

获取方式：`client.getTmdbApi()`

### getTmdbMovieImage — 获取 TMDB 电影图片

```
POST /Tmdb/Movie/{tmdbId}/Image
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `tmdbId` | String | path | **是** | TMDB 电影 ID |

---

## TrickplayApi — Trickplay 缩略图

获取方式：`client.getTrickplayApi()`

### getTrickplayTileImage — 获取 Trickplay 缩略图瓦片

```
GET /Videos/{itemId}/Trickplay/{width}/{index}.jpg
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `width` | int | path | **是** | 缩略图宽度 |
| `index` | int | path | **是** | 瓦片索引 |

### getTrickplayHlsPlaylist — 获取 Trickplay HLS 播放列表

```
GET /Videos/{itemId}/Trickplay/{width}/tiles.m3u8
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `width` | int | path | **是** | 缩略图宽度 |
| `mediaSourceId` | String? | query | 否 | 媒体源 ID |

### getTrickplayVideoImages — 获取 Trickplay 缩略图信息

```
GET /Videos/{itemId}/Trickplay/{width}/tiles
返回: Response<TrickplayTileInfo>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `width` | int | path | **是** | 缩略图宽度 |

---

## UserLibraryApi — 用户媒体库

获取方式：`client.getUserLibraryApi()`

### getItem — 获取条目详情（用户视图）

```
GET /Users/{userId}/Items/{itemId}
返回: Response<BaseItemDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String | path | **是** | 用户 ID |
| `itemId` | String | path | **是** | 条目 ID |

### getIntros — 获取条目片头

```
GET /Users/{userId}/Items/{itemId}/Intros
返回: Response<IntrosInfo>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String | path | **是** | 用户 ID |
| `itemId` | String | path | **是** | 条目 ID |

### getLocalTrailers — 获取本地预告片

```
GET /Users/{userId}/Items/{itemId}/LocalTrailers
返回: Response<List<BaseItemDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String | path | **是** | 用户 ID |
| `itemId` | String | path | **是** | 条目 ID |

### getSpecialFeatures — 获取特别花絮

```
GET /Users/{userId}/Items/{itemId}/SpecialFeatures
返回: Response<List<BaseItemDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String | path | **是** | 用户 ID |
| `itemId` | String | path | **是** | 条目 ID |

### getLatestMedia — 获取最新媒体

```
GET /Users/{userId}/Items/Latest
返回: Response<List<BaseItemDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String | path | **是** | 用户 ID |
| `parentId` | String? | query | 否 | 父级 ID |
| `fields` | List\<ItemFields\>? | query | 否 | 返回的额外字段 |
| `includeItemTypes` | List\<BaseItemKind\>? | query | 否 | 条目类型 |
| `isPlayed` | bool? | query | 否 | 是否已播放 |
| `enableImages` | bool? | query | 否 | 是否返回图片 |
| `imageTypeLimit` | int? | query | 否 | 图片类型限制 |
| `enableImageTypes` | List\<ImageType\>? | query | 否 | 启用的图片类型 |
| `enableUserData` | bool? | query | 否 | 是否返回用户数据 |
| `limit` | int? | query | 否 | 最大返回数 |
| `groupItems` | bool? | query | 否 | 是否分组 |

---

## UserViewsApi — 用户视图

获取方式：`client.getUserViewsApi()`

### getUserViews — 获取用户视图（首页布局）

```
GET /Users/{userId}/Views
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String | path | **是** | 用户 ID |
| `includeExternalContent` | bool? | query | 否 | 是否包含外部内容 |
| `presetViews` | List\<CollectionType\>? | query | 否 | 预设视图类型 |
| `includeHidden` | bool? | query | 否 | 是否包含隐藏视图 |

---

## YearsApi — 年份查询

获取方式：`client.getYearsApi()`

### getYears — 获取年份列表

```
GET /Years
返回: Response<BaseItemDtoQueryResult>
```

参数同通用列表查询（startIndex、limit、parentId、fields、userId、excludeItemTypes、includeItemTypes 等）。

### getYear — 获取单个年份

```
GET /Years/{year}
返回: Response<BaseItemDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `year` | int | path | **是** | 年份 |
| `userId` | String? | query | 否 | 用户 ID |
