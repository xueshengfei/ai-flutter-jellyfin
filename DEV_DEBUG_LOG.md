# 开发问题排查记录

记录开发过程中遇到的 bug、性能问题，包括现象描述、排查思路和最终解决方案。

---

## #1 播放页切歌时唱片旋转动画严重卡顿

**日期**: 2026-04-11
**文件**: `lib/src/ui/pages/music_library_page.dart`, `lib/src/ui/services/audio_playback_manager.dart`
**状态**: 已解决

### 现象

在播放页面点击"下一首"切歌时，唱片旋转动画出现明显掉帧/卡顿，严重时动画完全冻结。退出播放页后从 MiniPlayer 重新进入，动画恢复正常。

### 排查过程

#### 1. 定位动画刷新机制

找到唱片旋转的实现（`initState` line 657-660）：

```dart
_vinylController = AnimationController(...)
  ..addListener(() => setState(() => _vinylAngle = _vinylController.value * 2 * pi));
```

**问题**: `addListener` 在动画每一帧（60fps）都回调，而回调里直接 `setState()` 会触发整个 `_AudioPlayerPageState.build()` 重建，包括唱片、进度条、控制栏、歌词面板等所有子 widget。

#### 2. 检查 build() 内的副作用

发现 `build()` 被 `ListenableBuilder(_manager, ...)` 包裹，其中有一段取色逻辑：

```dart
final coverUrl = song.getAlbumCoverUrl(fillWidth: 480, fillHeight: 480);
if (coverUrl != null && (song.id != widget.song.id || _dynamicColorScheme == null)) {
  _extractColors(coverUrl);
}
```

**问题**: `_extractColors` 在 `build()` 内被调用，没有任何防重入保护。每次 rebuild 都可能重新触发 `PaletteGenerator.fromImageProvider`（CPU 密集的图片解码 + 取色），导致以下恶性循环：

```
动画帧 → setState → rebuild → 触发取色 → CPU 占用 → 下一帧延迟 → 卡顿
```

#### 3. 分析切歌时的并发负载

切歌瞬间主线程同时执行：
- 音频加载（`_playSong`）
- 封面图片解码 + `PaletteGenerator` 取色
- 动画每帧 `setState` rebuild

三者叠加导致主线程过载，动画帧被阻塞。

#### 4. 验证"退出重进恢复正常"

退出播放页时 `dispose()` 销毁了 `_vinylController`，重新进入时 `initState` 创建新的 controller。此时只有初始取色一次，没有重复触发的问题，所以动画流畅。这进一步确认了 build() 内副作用重复触发是主因。

### 解决方案

#### 改动 1: 唱片动画隔离（消除每帧 setState）

移除 `_vinylAngle` 字段和 `addListener`，`_buildVinyl` 改用 `AnimatedBuilder`：

```dart
// 之前：每帧 setState 重建整个页面
_vinylController..addListener(() => setState(() => _vinylAngle = ...));

// 之后：AnimatedBuilder 只重建 Transform.rotate
AnimatedBuilder(
  animation: _vinylController,
  builder: (context, child) => Transform.rotate(
    angle: _vinylController.value * 2 * pi,
    child: child,  // 静态内容不会重建
  ),
  child: vinylContent,
);
```

效果：动画帧只重建一个 `Transform.rotate`，不再触发页面级 rebuild。

#### 改动 2: 取色防重入

新增 `_extractedSongId` 字段追踪已取色的歌曲，`_extractColors` 入口判断同一首歌只取一次：

```dart
Future<void> _extractColors(String imageUrl, String songId) async {
  if (_extractedSongId == songId) return;  // 防重入
  _extractedSongId = songId;
  // ...
}
```

#### 改动 3: 切歌时暂停动画 + 重置状态

在 `build()` 的 `ListenableBuilder` 内检测歌曲变化，切歌时先停动画、重置歌词：

```dart
if (song.id != _extractedSongId) {
  _vinylController.stop();     // 停动画减少并发
  _lyricsData = null;          // 重置歌词
  _positionSub?.cancel();
  if (_showWebLyrics) _loadLyrics();
  if (coverUrl != null) _extractColors(coverUrl, song.id);
}
```

#### 改动 4: 预加载相邻歌曲封面

新增 `_preloadAdjacentSongs()`，用 `precacheImage` 预加载前后各一首的封面到内存缓存，切歌时封面图片无需从网络解码：

```dart
void _preloadAdjacentSongs() {
  for (final i in [_manager.currentIndex - 1, _manager.currentIndex + 1]) {
    if (i < 0 || i >= playlist.length) continue;
    final url = playlist[i].getAlbumCoverUrl(fillWidth: 480, fillHeight: 480);
    if (url != null) precacheImage(NetworkImage(url), context);
  }
}
```

### 附带修复：收藏按钮点击无效

**现象**: 播放页点击心形收藏按钮，图标不变化。

**排查**: `_toggleFavorite` 中调 API 后执行 `setState(() {})`，但 `MusicSong.isFavorite` 是 `final` 字段，对象本身没被修改，所以 rebuild 后图标读取的还是旧值。

**修复**: 在 `AudioPlaybackManager` 新增 `updateSongFavorite()` 方法，用新的 `MusicSong` 实例替换 playlist 中旧对象，实现乐观更新 + 失败回滚。

### 经验总结

- **永远不要在 AnimationController.addListener 里直接 setState**，应使用 `AnimatedBuilder` 局部重建
- **build() 内不应有异步副作用**（如网络请求、图片解码），必须加防重入保护
- **不可变数据模型的状态更新**需要替换整个对象实例，不能期望 `setState` 自动生效
