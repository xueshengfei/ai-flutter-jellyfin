# 01 快速开始 — 客户端初始化与认证

## 1. 安装与导入

```dart
import 'package:jellyfin_dart/jellyfin_dart.dart';
```

## 2. 创建客户端

```dart
final client = JellyfinDart(
  basePathOverride: 'https://your-jellyfin-server.com',
  // 可选：传入自定义 Dio 实例
  // dio: myDioInstance,
  // 可选：传入自定义拦截器列表（会替换默认的 MediaBrowserAuthInterceptor）
  // interceptors: [myInterceptor],
);
```

**构造参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `basePathOverride` | String? | 否 | 服务器地址，默认 `http://localhost` |
| `dio` | Dio? | 否 | 自定义 Dio 实例，不传则自动创建（连接超时 5s，接收超时 3s） |
| `interceptors` | List\<Interceptor\>? | 否 | 自定义拦截器列表。不传则自动添加 MediaBrowserAuthInterceptor |

## 3. 设置认证信息

Jellyfin 使用自定义的 MediaBrowser 认证头，格式为：
```
Authorization: MediaBrowser Client="...", Device="...", DeviceId="...", Version="...", Token="..."
```

### 方式一：一次性设置全部

```dart
client.setMediaBrowserAuth(
  deviceId: 'unique-device-id-12345',  // 必填
  version: '10.11.0',                   // 必填
  client: 'MyApp',                      // 可选，默认 'Jellyfin Dart'
  device: 'Windows PC',                 // 可选，默认 'Dart'
  token: 'your-access-token',           // 可选，登录后获取
);
```

### 方式二：逐项设置

```dart
client.setClient('MyApp');       // 客户端名称，默认 'Jellyfin Dart'
client.setDevice('Windows PC');  // 设备名称，默认 'Dart'
client.setDeviceId('unique-id'); // 设备 ID（必填）
client.setVersion('10.11.0');    // 客户端版本（必填）
client.setToken('access-token'); // 访问令牌（登录后必填）
```

**认证参数说明：**

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `client` | 客户端应用名称，显示在 Jellyfin 会话中 | `Jellyfin Dart` |
| `device` | 设备名称 | `Dart` |
| `deviceId` | 设备唯一标识符，用于区分不同设备 | 无 |
| `version` | 客户端版本号 | 无 |
| `token` | 访问令牌，通过 `authenticateUserByName` 获取 | 无 |

## 4. 登录获取 Token

```dart
final userApi = client.getUserApi();

final response = await userApi.authenticateUserByName(
  authenticateUserByName: AuthenticateUserByName(
    username: 'admin',
    pw: 'your-password',
  ),
);

final token = response.data?.accessToken;
client.setToken(token);  // 设置 token 后即可访问受保护的 API
```

## 5. 获取 API 实例

所有 API 实例通过工厂方法获取：

```dart
final userApi       = client.getUserApi();
final itemsApi      = client.getItemsApi();
final sessionApi    = client.getSessionApi();
final systemApi     = client.getSystemApi();
final mediaInfoApi  = client.getMediaInfoApi();
final imageApi      = client.getImageApi();
final playstateApi  = client.getPlaystateApi();
final libraryApi    = client.getLibraryApi();
final searchApi     = client.getSearchApi();
final videosApi     = client.getVideosApi();
final audioApi      = client.getAudioApi();
final liveTvApi     = client.getLiveTvApi();
final tvShowsApi    = client.getTvShowsApi();
final moviesApi     = client.getMoviesApi();
final subtitleApi   = client.getSubtitleApi();
final playlistsApi  = client.getPlaylistsApi();
final suggestionsApi = client.getSuggestionsApi();
final dynamicHlsApi = client.getDynamicHlsApi();
// ... 共 60 个 API，详见各章节
```

**完整工厂方法列表：**

| 工厂方法 | API 类 | 功能 |
|----------|--------|------|
| `getActivityLogApi()` | ActivityLogApi | 活动日志 |
| `getApiKeyApi()` | ApiKeyApi | API Key 管理 |
| `getArtistsApi()` | ArtistsApi | 艺术家查询 |
| `getAudioApi()` | AudioApi | 音频流 |
| `getBackupApi()` | BackupApi | 备份管理 |
| `getBrandingApi()` | BrandingApi | 品牌信息 |
| `getChannelsApi()` | ChannelsApi | 频道查询 |
| `getClientLogApi()` | ClientLogApi | 客户端日志 |
| `getCollectionApi()` | CollectionApi | 合集管理 |
| `getConfigurationApi()` | ConfigurationApi | 服务器配置 |
| `getDashboardApi()` | DashboardApi | 仪表盘 |
| `getDevicesApi()` | DevicesApi | 设备管理 |
| `getDisplayPreferencesApi()` | DisplayPreferencesApi | 显示偏好 |
| `getDynamicHlsApi()` | DynamicHlsApi | 动态 HLS 流 |
| `getEnvironmentApi()` | EnvironmentApi | 环境信息 |
| `getFilterApi()` | FilterApi | 过滤器查询 |
| `getGenresApi()` | GenresApi | 流派查询 |
| `getHlsSegmentApi()` | HlsSegmentApi | HLS 分片 |
| `getImageApi()` | ImageApi | 图片管理 |
| `getInstantMixApi()` | InstantMixApi | 即时混音 |
| `getItemLookupApi()` | ItemLookupApi | 条目元数据查找 |
| `getItemRefreshApi()` | ItemRefreshApi | 条目刷新 |
| `getItemUpdateApi()` | ItemUpdateApi | 条目更新 |
| `getItemsApi()` | ItemsApi | 媒体条目查询 |
| `getLibraryApi()` | LibraryApi | 媒体库操作 |
| `getLibraryStructureApi()` | LibraryStructureApi | 媒体库结构 |
| `getLiveTvApi()` | LiveTvApi | 直播电视 |
| `getLocalizationApi()` | LocalizationApi | 本地化 |
| `getLyricsApi()` | LyricsApi | 歌词 |
| `getMediaInfoApi()` | MediaInfoApi | 媒体信息 |
| `getMediaSegmentsApi()` | MediaSegmentsApi | 媒体片段 |
| `getMoviesApi()` | MoviesApi | 电影推荐 |
| `getMusicGenresApi()` | MusicGenresApi | 音乐流派 |
| `getPackageApi()` | PackageApi | 包管理 |
| `getPersonsApi()` | PersonsApi | 人物查询 |
| `getPlaylistsApi()` | PlaylistsApi | 播放列表 |
| `getPlaystateApi()` | PlaystateApi | 播放状态 |
| `getPluginsApi()` | PluginsApi | 插件管理 |
| `getQuickConnectApi()` | QuickConnectApi | 快速连接 |
| `getRemoteImageApi()` | RemoteImageApi | 远程图片 |
| `getScheduledTasksApi()` | ScheduledTasksApi | 定时任务 |
| `getSearchApi()` | SearchApi | 搜索 |
| `getSessionApi()` | SessionApi | 会话管理 |
| `getStartupApi()` | StartupApi | 初始设置 |
| `getStudiosApi()` | StudiosApi | 工作室查询 |
| `getSubtitleApi()` | SubtitleApi | 字幕管理 |
| `getSuggestionsApi()` | SuggestionsApi | 推荐 |
| `getSyncPlayApi()` | SyncPlayApi | 同步播放 |
| `getSystemApi()` | SystemApi | 系统信息 |
| `getTimeSyncApi()` | TimeSyncApi | 时间同步 |
| `getTmdbApi()` | TmdbApi | TMDB 数据 |
| `getTrailersApi()` | TrailersApi | 预告片 |
| `getTrickplayApi()` | TrickplayApi | Trickplay 缩略图 |
| `getTvShowsApi()` | TvShowsApi | 电视剧 |
| `getUniversalAudioApi()` | UniversalAudioApi | 通用音频 |
| `getUserApi()` | UserApi | 用户管理 |
| `getUserLibraryApi()` | UserLibraryApi | 用户媒体库 |
| `getUserViewsApi()` | UserViewsApi | 用户视图 |
| `getVideoAttachmentsApi()` | VideoAttachmentsApi | 视频附件 |
| `getVideosApi()` | VideosApi | 视频流 |
| `getYearsApi()` | YearsApi | 年份查询 |

## 6. 通用响应模式

所有 API 调用返回 `Future<Response<T>>`：

```dart
final response = await api.someMethod();
final data = response.data;       // 反序列化后的 Dart 对象
final statusCode = response.statusCode;  // HTTP 状态码
final headers = response.headers;        // 响应头
```

分页查询结果通常为 `BaseItemDtoQueryResult`：

```dart
class BaseItemDtoQueryResult {
  List<BaseItemDto>? items;       // 数据列表
  int? totalRecordCount;          // 总记录数
  int? startIndex;                // 起始索引
}
```

## 7. 错误处理

```dart
try {
  final response = await api.someMethod();
  // 处理成功
} on DioException catch (e) {
  // 网络错误、超时、HTTP 错误状态码等
  print('Error: ${e.message}');
  print('StatusCode: ${e.response?.statusCode}');
}
```
