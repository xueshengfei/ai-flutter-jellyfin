# jellyfin_music -- 音乐业务模块

Jellyfin 音乐浏览、播放、搜索与歌词展示的 Flutter Feature 包。通过回调注入实现完全解耦，不依赖 `go_router`、`JellyfinClient`、`just_audio` 等外部实现。

## 功能清单

- 音乐库三 Tab 浏览（专辑 / 艺术家 / 歌曲），分页加载
- 专辑详情页（封面 + 歌曲列表 + 播放全部）
- 艺术家详情页（头像 + 专辑网格）
- 音乐播放详情页（黑胶唱片旋转 + 动态取色 + 进度控制 + 播放模式切换）
- 迷你播放器条（音乐模块范围内显示）
- 音乐搜索页（500ms 防抖，按艺术家/专辑/歌曲分类展示）
- 歌词页面（背景模糊 + 同步滚动 + 点击跳转）
- 歌词面板组件（可嵌入，支持远程歌词搜索与下载）
- 宽屏布局自适应（播放页内嵌歌词面板）

## 目录结构

```
lib/
├── jellyfin_music.dart          # 主 barrel（模型 + 服务接口）
├── jellyfin_music_pages.dart    # 页面子 barrel（所有页面和组件）
└── src/
    ├── models/
    │   ├── music_models.dart    # 音乐模型 + 回调 typedef
    │   └── lyrics_models.dart   # 歌词模型
    ├── services/
    │   ├── audio_playback_port.dart  # 播放器抽象接口 + AudioTrack
    │   └── lyrics_port.dart         # 歌词回调 typedef
    ├── pages/
    │   ├── music_library_page.dart   # 音乐库（三 Tab）
    │   ├── album_detail_page.dart    # 专辑详情
    │   ├── artist_detail_page.dart   # 艺术家详情
    │   ├── music_player_page.dart    # 播放详情页
    │   ├── music_search_page.dart    # 音乐搜索
    │   └── lyrics_page.dart          # 歌词完整页面
    └── widgets/
        ├── mini_player_bar.dart      # 迷你播放器条
        ├── music_area_shell.dart     # 音乐模块壳（页面 + 迷你播放器）
        └── lyrics_panel.dart         # 歌词面板组件
```

## 核心类一览

### 模型

| 类名 | 文件 | 说明 |
|------|------|------|
| `MusicAlbum` | `music_models.dart` | 音乐专辑（封面 URL、艺术家列表、歌曲数、流派等） |
| `MusicArtist` | `music_models.dart` | 音乐艺术家（头像 URL、专辑数、歌曲数、流派等） |
| `MusicSong` | `music_models.dart` | 歌曲/音轨（流 URL、封面 URL、时长、收藏状态等） |
| `ArtistRef` | `music_models.dart` | 艺术家引用（id + name） |
| `MusicGenre` | `music_models.dart` | 音乐类型 |
| `MusicAlbumListResult` | `music_models.dart` | 专辑列表分页结果 |
| `MusicArtistListResult` | `music_models.dart` | 艺术家列表分页结果 |
| `MusicSongListResult` | `music_models.dart` | 歌曲列表分页结果 |
| `MusicSearchResult` | `music_models.dart` | 搜索结果（艺术家 + 专辑 + 歌曲） |
| `AudioTrack` | `audio_playback_port.dart` | 播放器使用的音轨抽象（与 MusicSong 解耦） |
| `PlayMode` | `audio_playback_port.dart` | 播放模式枚举：sequential / shuffle / repeatOne |
| `LyricsLine` | `lyrics_models.dart` | 歌词行（文本 + 时间戳 ticks） |
| `LyricsMetadata` | `lyrics_models.dart` | 歌词元数据（是否同步、艺术家、专辑、标题等） |
| `LyricsData` | `lyrics_models.dart` | 歌词数据（元数据 + 行列表） |
| `RemoteLyricsInfo` | `lyrics_models.dart` | 远程歌词信息（id + 来源 + 歌词预览） |

### 回调 typedef

| typedef | 文件 | 说明 |
|---------|------|------|
| `AlbumsFetcher` | `music_models.dart` | 获取专辑列表（分页） |
| `ArtistsFetcher` | `music_models.dart` | 获取艺术家列表（分页） |
| `SongsFetcher` | `music_models.dart` | 获取歌曲列表（分页） |
| `AlbumDetailFetcher` | `music_models.dart` | 获取专辑详情 |
| `AlbumSongsFetcher` | `music_models.dart` | 获取专辑歌曲列表 |
| `ArtistDetailFetcher` | `music_models.dart` | 获取艺术家详情 |
| `ArtistAlbumsFetcher` | `music_models.dart` | 获取艺术家专辑列表 |
| `MusicSearchFetcher` | `music_models.dart` | 音乐搜索（关键词 + parentId） |
| `OnOpenAlbum` | `music_models.dart` | 打开专辑详情回调 |
| `OnOpenArtist` | `music_models.dart` | 打开艺术家详情回调 |
| `OnNavigateToAlbum` | `music_models.dart` | 导航到专辑详情回调 |
| `OnPlaySong` | `music_models.dart` | 播放歌曲回调（MusicSong 版） |
| `OnPlayTracks` | `audio_playback_port.dart` | 播放音轨列表回调（AudioTrack 版） |
| `LyricsFetcher` | `lyrics_port.dart` | 获取歌词数据 |
| `RemoteLyricsSearcher` | `lyrics_port.dart` | 搜索远程歌词 |
| `RemoteLyricsDownloader` | `lyrics_port.dart` | 下载远程歌词 |

### 服务接口

| 类名 | 文件 | 说明 |
|------|------|------|
| `AudioPlaybackPort` | `audio_playback_port.dart` | 音频播放器抽象接口（继承 ChangeNotifier），App 层实现 |

`AudioPlaybackPort` 提供的接口分组：
- **播放控制**：`playSong` / `pause` / `resume` / `seek` / `playNext` / `playPrevious`
- **状态查询**：`currentTrack` / `isPlaying` / `isLoading` / `error` / `position` / `duration` / `playlist` / `currentIndex`
- **播放模式**：`playMode` / `cyclePlayMode` / `toggleShuffle` / `cycleRepeatMode`
- **事件流**：`onPositionChanged`（供歌词同步使用）
- **收藏**：`updateTrackFavorite`

### 页面

| 页面 | 文件 | 必需参数 | 说明 |
|------|------|----------|------|
| `MusicLibraryPage` | `music_library_page.dart` | `libraryName`, `libraryId`, `fetchAlbums`, `fetchArtists`, `fetchSongs` | 音乐库三 Tab 页面 |
| `AlbumDetailPage` | `album_detail_page.dart` | `album`, `fetchAlbumDetail`, `fetchAlbumSongs` | 专辑详情（歌曲列表 + 播放全部） |
| `ArtistDetailPage` | `artist_detail_page.dart` | `artist`, `fetchArtistDetail`, `fetchArtistAlbums` | 艺术家详情（专辑网格） |
| `MusicPlayerPage` | `music_player_page.dart` | `playbackPort` | 播放详情页（黑胶唱片 + 控制栏） |
| `MusicSearchPage` | `music_search_page.dart` | `search` | 音乐搜索（防抖 + 分类展示） |
| `LyricsPage` | `lyrics_page.dart` | `playbackPort`, `fetchLyrics` | 歌词完整页面（背景模糊） |

### 组件

| 组件 | 文件 | 说明 |
|------|------|------|
| `MiniPlayerBar` | `mini_player_bar.dart` | 底部迷你播放器条（封面 + 歌名 + 播放控制 + 进度条） |
| `MusicAreaShell` | `music_area_shell.dart` | 音乐模块壳：`Column(child + MiniPlayerBar)` |
| `LyricsPanel` | `lyrics_panel.dart` | 可嵌入的歌词面板（同步滚动 + 远程搜索 + 点击跳转） |

## 依赖关系

```
jellyfin_music
  ├── flutter
  ├── equatable              # 模型值比较
  ├── cached_network_image   # 专辑封面/艺术家头像缓存加载
  ├── palette_generator      # 播放页动态取色
  └── jellyfin_ui_kit        # JellyfinImage / PaginatedList 等共享组件
```

本模块**不依赖**：
- `go_router` -- 导航通过回调注入
- `jellyfin_api` / `jellyfin_dart` -- 数据获取通过回调注入
- `just_audio` -- 播放通过 `AudioPlaybackPort` 接口抽象

## 使用示例

### 1. 注册路由（Product App 层）

在 `app_router.dart` 中注册音乐相关路由，通过 `FutureBuilder` + Gateway 注入回调：

```dart
GoRoute(
  path: '/libraries/:libraryId/music',
  builder: (context, state) {
    final libraryId = state.pathParameters['libraryId']!;
    final libraryName = state.uri.queryParameters['name'] ?? '音乐';
    return MusicLibraryRoutePage(
      libraryId: libraryId,
      libraryName: libraryName,
      gateway: gateway,
      audioPlaybackPort: audioPlaybackPort,
      onOpenAlbum: (ctx, album) => ctx.push('/music/album/${album.id}'),
      onOpenArtist: (ctx, artist) => ctx.push('/music/artist/${artist.id}'),
      onSearch: () => context.push('/libraries/$libraryId/music/search'),
    );
  },
),
```

### 2. 注入 AudioPlaybackPort

在 App 级别创建 `AudioPlaybackPort` 实现（如 `AudioPlaybackAdapter`，基于 `just_audio`），作为单例传入各音乐路由页：

```dart
final audioPlaybackPort = AudioPlaybackAdapter();
```

播放回调中完成 `MusicSong -> AudioTrack` 转换：

```dart
OnPlayTracks onPlayTracks = (context, tracks, startIndex) {
  audioPlaybackPort.playSong(tracks[startIndex], tracks, startIndex);
  context.push('/playback/music');
};
```

### 3. 使用 MusicAreaShell

音乐路由页用 `MusicAreaShell` 包裹，在页面底部挂载迷你播放器：

```dart
MusicAreaShell(
  audioPlaybackPort: audioPlaybackPort,
  onOpenMusicPlayer: () => context.push('/playback/music'),
  child: MusicLibraryPage(
    libraryName: libraryName,
    libraryId: libraryId,
    fetchAlbums: fetchAlbums,
    fetchArtists: fetchArtists,
    fetchSongs: fetchSongs,
    onOpenAlbum: onOpenAlbum,
    onOpenArtist: onOpenArtist,
    onPlayTracks: onPlayTracks,
    imageProvider: imageProvider,
  ),
)
```

### 4. 歌词接入

播放详情页和歌词页面分别注入歌词回调：

```dart
MusicPlayerPage(
  playbackPort: audioPlaybackPort,
  fetchLyrics: (itemId) => gateway.getLyrics(itemId),
  onOpenLyrics: () => context.push('/music/lyrics'),
  onOpenRvc: () => context.push('/rvc'),
)

LyricsPage(
  playbackPort: audioPlaybackPort,
  fetchLyrics: (itemId) => gateway.getLyrics(itemId),
  searchRemoteLyrics: (itemId) => gateway.searchRemoteLyrics(itemId),
  downloadRemoteLyrics: ({required itemId, required lyricId}) =>
      gateway.downloadRemoteLyrics(itemId: itemId, lyricId: lyricId),
  albumCoverUrl: currentTrack?.coverUrl,
)
```

## 迷你播放器说明

迷你播放器遵循"音乐模块范围"设计：

- `MiniPlayerBar`：纯展示组件，监听 `AudioPlaybackPort` 状态变化，无播放列表时自动隐藏
- `MusicAreaShell`：组合容器（`Column: child + MiniPlayerBar`），在音乐路由页中使用
- 只在音乐库/专辑/艺术家页面显示，非音乐页面不感知此组件
- `AudioPlaybackPort` 仍为 App 级单例，离开音乐模块后音乐继续播放
- 播放详情页通过 `showMiniPlayer: false` 隐藏迷你播放器

## 测试

```bash
cd packages/features/jellyfin_music && flutter test
```

测试覆盖：
- 模型构造与字段访问（MusicAlbum / MusicArtist / MusicSong / AudioTrack / ArtistRef / MusicGenre）
- URL 构建（封面图 URL、音频流 URL、universal/stream 端点切换）
- Equatable 值比较
- 列表结果（isEmpty / isNotEmpty / length）
- 页面 Widget 测试（AlbumDetailPage 显示歌曲、点击播放回调、加载状态）
- 艺术家详情页（专辑网格、导航回调、空状态）
- 音乐库歌曲 Tab 点击播放（MusicSong -> AudioTrack 转换，含 path 字段保留）
- 播放详情页 RVC 按钮
- AudioPlaybackPort 抽象接口验证（通过 `_FakePlaybackPort` 最小实现）
