# Phase 4 实施报告：App Shell 与兼容层收敛

## 概览

Phase 4 完成了 `media_libraries_page.dart` 的编排职责外迁、Auth Shell 化、音乐播放解耦和 Facade 清理。

## 任务完成状态

| Task | 状态 | 说明 |
|------|------|------|
| 20-A 基础类提取 | ✅ | AppSession, MovieFilterAdapter, PlaybackDelegateFactory |
| 20-B FeaturePageFactory | ✅ | FeaturePageFactory + MusicPlaybackAdapter + 简化 media_libraries_page |
| 20-C 验证与清理 | ✅ | barrel export 添加，media_libraries_page 659→135 行 |
| 21 Auth Shell 化 | ✅ | AppSessionController + LoginPage onLoginSuccess 回调 |
| 22 音乐解耦 | ✅ | AudioPlaybackPort 注入到 4 个页面 |
| 23 Facade 清理 | ✅ | 移除 6 个 deprecated 页面 export + 边界检查增强 |

## 新建文件（7 个）

| 文件 | 行数 | 说明 |
|------|------|------|
| `lib/src/app_shell/app_session.dart` | 16 | 封装 JellyfinClient + UserProfile |
| `lib/src/app_shell/movie_filter_adapter.dart` | 59 | MovieFilter 双向转换 |
| `lib/src/app_shell/playback_delegate_factory.dart` | 55 | PlaybackDelegate 工厂 |
| `lib/src/app_shell/music_playback_adapter.dart` | 77 | 音乐模型双向转换 + 播放委托 |
| `lib/src/app_shell/feature_page_factory.dart` | 287 | 所有 feature 页面构建编排 |
| `lib/src/app_shell/app_session_controller.dart` | 43 | ChangeNotifier 认证会话管理 |
| `lib/src/app_shell/app_shell.dart` | 7 | barrel 文件 |

## 修改文件（8 个）

| 文件 | 改动 |
|------|------|
| `lib/src/ui/pages/media_libraries_page.dart` | 659→135 行，删除全部工厂/转换/播放方法 |
| `lib/src/ui/pages/login_page.dart` | 添加 `onLoginSuccess` 回调 + AppSession 创建 |
| `lib/src/ui/pages/music_library_page.dart` | 注入 AudioPlaybackPort 到 MusicLibraryPage/_SongsTab/AudioPlayerPage |
| `lib/src/ui/pages/lyrics_page.dart` | 注入 AudioPlaybackPort，替换 7 处 AudioPlaybackManager.instance |
| `lib/src/ui/pages/music_search_page.dart` | 传递 audioPlayback 到 AudioPlayerPage |
| `lib/src/ui/widgets/mini_player_card.dart` | 注入 AudioPlaybackPort |
| `lib/jellyfin_service.dart` | 添加 app_shell export，移除 6 个 deprecated 页面 export |
| `scripts/check_module_boundaries.dart` | 增加 3 条规则（hide 阈值 + shared/foundation 禁 feature） |

## 额外修改

| 文件 | 说明 |
|------|------|
| `lib/src/ui/pages/test_api_page.dart` | 添加直接 import（因为 MovieFilterPage 从 barrel 移除） |

## 新建测试（2 个）

| 文件 | 测试数 |
|------|--------|
| `test/app_shell_test.dart` | 8 |
| `test/audio_playback_port_injection_test.dart` | 7 |

## 验证结果

- **测试**: 44 个全部通过（29 原有 + 8 app_shell + 7 port_injection）
- **边界检查**: 所有模块边界检查通过（6 条规则全绿）
- **hide 数量**: 18 个（阈值 20）
- **dart analyze**: 0 error, 0 warning（仅 info 级别的 deprecated 使用）

## 关键架构变化

```
Before:                              After:
MediaLibrariesPage (659 行)          MediaLibrariesPage (135 行)
  ├── _buildNewMovieFilterPage()       └── _pages = FeaturePageFactory(session)
  ├── _buildNewMediaItemsPage()            ├── movieFilterPage()
  ├── _createPlaybackDelegate()            ├── mediaItemsPage()
  ├── _convertMovieFilter()                ├── episodesPage()
  ├── _toMusicAlbum/Artist/Song()          ├── albumDetailPage()
  ├── _playMusicSongs()                    └── aiRecommendPage()
  └── ...全部在同一个 State 里           + AppSessionController (login/logout)
                                        + AudioPlaybackPort 注入（4 个页面）
```
