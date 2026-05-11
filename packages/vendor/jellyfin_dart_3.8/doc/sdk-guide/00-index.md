# Jellyfin Dart SDK 使用指南

> 本文档面向 AI Agent 及开发者，完整描述 `jellyfin_dart` SDK 的所有接口参数及用途。

## 文档目录

| 编号 | 文件 | 内容 |
|------|------|------|
| 01 | [quick-start.md](01-quick-start.md) | 客户端初始化、认证、通用参数说明 |
| 02 | [user-api.md](02-user-api.md) | 用户管理 (UserApi) |
| 03 | [items-api.md](03-items-api.md) | 媒体条目查询 (ItemsApi) — 参数最多的核心 API |
| 04 | [library-api.md](04-library-api.md) | 媒体库管理 (LibraryApi / LibraryStructureApi) |
| 05 | [search-api.md](05-search-api.md) | 搜索与推荐 (SearchApi / SuggestionsApi / FilterApi) |
| 06 | [playback.md](06-playback.md) | 播放控制与流媒体 (PlaystateApi / MediaInfoApi / VideosApi / AudioApi / DynamicHlsApi / UniversalAudioApi / HlsSegmentApi) |
| 07 | [tv-movies.md](07-tv-movies.md) | 剧集与电影 (TvShowsApi / MoviesApi / TrailersApi) |
| 08 | [images-api.md](08-images-api.md) | 图片管理 (ImageApi) |
| 09 | [live-tv.md](09-live-tv.md) | 直播电视 (LiveTvApi / ChannelsApi) |
| 10 | [playlists-collections.md](10-playlists-collections.md) | 播放列表与合集 (PlaylistsApi / CollectionApi) |
| 11 | [session-sync.md](11-session-sync.md) | 会话与同步播放 (SessionApi / SyncPlayApi) |
| 12 | [system-config.md](12-system-config.md) | 系统与配置 (SystemApi / ConfigurationApi / StartupApi / BrandingApi) |
| 13 | [subtitles.md](13-subtitles.md) | 字幕 (SubtitleApi / VideoAttachmentsApi) |
| 14 | [music.md](14-music.md) | 音乐相关 (ArtistsApi / InstantMixApi / LyricsApi / MusicGenresApi / GenresApi) |
| 15 | [other-apis.md](15-other-apis.md) | 其他 API（活动日志、API Key、备份、设备、定时任务、插件等） |

## 约定

- 参数类型 `[query]` = URL 查询参数, `[path]` = URL 路径参数, `[body]` = 请求体 JSON, `[header]` = HTTP 头
- 所有方法的最后 6 个参数是 Dio 内置的基础设施参数，文档中不再重复列出：
  - `cancelToken` (CancelToken?) — 取消请求
  - `headers` (Map\<String, dynamic\>?) — 自定义 HTTP 头
  - `extra` (Map\<String, dynamic\>?) — 附加标记
  - `validateStatus` (ValidateStatus?) — 自定义状态码校验
  - `onSendProgress` (ProgressCallback?) — 上传进度回调
  - `onReceiveProgress` (ProgressCallback?) — 下载进度回调
- 返回值统一为 `Future<Response<T>>`，通过 `response.data` 获取反序列化后的对象
