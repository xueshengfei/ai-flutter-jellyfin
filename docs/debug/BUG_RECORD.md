# 🐛 Bug 记录本

> 项目运行过程中发现并修复的 bug 记录。每条按时间倒序排列。

---

## BUG-002 | 详情页回退后重新加载（FutureBuilder 反模式）

**修复提交**：`31d9958` · **修复时间**：2026-06-14

### 现象

从视频详情页（电影详情 / 通用详情 / 季列表 / 集列表）`context.push` 到播放页，`context.pop` 返回详情页时：

- 详情页**短暂闪过 loading 圈**
- 又一次发起网络请求拉取详情数据
- 数据返回后才恢复正常显示

同样问题影响 7 个路由：电影详情、通用详情、季列表、集列表、播放页、专辑详情、艺术家详情。

### 根因

`Product/jellyfin_app/lib/src/app/app_router.dart` 里 7 个 `_XxxRouteContent` 都是 **StatelessWidget**，build 方法里直接这样写：

```dart
// ❌ 反模式
return FutureBuilder<MediaItem>(
  future: gateway.getMediaItemDetail(itemId),  // 每次 build 都新建 future
  builder: (context, snapshot) { ... },
);
```

这是 **FutureBuilder 反模式**——future 在 build 期间创建，父级 widget 树每次重建都会重新触发请求。

### 触发链

```
sessionController.notifyListeners()
        ↓
ListenableBuilder (JellyfinApp.build) 整树 rebuild
        ↓
GoRouter 检测到父级 rebuild，重新调用当前匹配路由的 builder 函数
        ↓
GoRoute.builder(context, state) 被重新调用
        ↓
_MovieDetailRouteContent.build 执行（StatelessWidget 没 State，每次都执行）
        ↓
gateway.getMediaItemDetail(itemId) 新建一个 Future 实例
        ↓
FutureBuilder.didUpdateWidget 检测到 oldWidget.future != widget.future
        ↓
_snapshot 重置成 waiting，重新 subscribe → 重新发 HTTP 请求
        ↓
用户看到 loading 圈
```

### FutureBuilder 内部原理

`FutureBuilder` 的 State 用 `oldWidget.future != widget.future` 判断是否重新订阅。如果两次 build 传的是**不同的 Future 实例**（哪怕两个 future 干的事一样），就认为 future 变了，重置 snapshot 并重新发请求。

### 修复方式

把 7 个类全部改成 **StatefulWidget**，在 `initState` 里把 Future 缓存到 State 字段：

```dart
// ✅ 正解
class _MovieDetailRouteContentState extends State<_MovieDetailRouteContent> {
  late final Future<MediaItem> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.gateway.getMediaItemDetail(widget.itemId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MediaItem>(
      future: _detailFuture,  // 引用稳定，不会变
      builder: (context, snapshot) { ... },
    );
  }
}
```

Flutter 的 Element 树复用规则保证：父级 widget 重建时，类型一致 + key 一致 → 复用 Element + 保留 State。State 字段 `_detailFuture` 是 `late final`，赋一次后不再变，FutureBuilder 每次拿到的是同一个 future 实例，不会重置、不会重新订阅。

### 涉及类

| 类 | future 数 | 修复方式 |
|---|---|---|
| `_MovieDetailRouteContent` | 1 | StatefulWidget + `_detailFuture` |
| `_MediaDetailRouteContent` | 1 | 同上 |
| `_SeasonsRouteContent` | 1 | 同上 |
| `_EpisodesRouteContent` | 2（季列表 + 剧集详情） | StatefulWidget + `_seasonsFuture` + `_seriesFuture` |
| `_PlaybackRouteContent` | 1 | 同上 |
| `_AlbumDetailRouteContent` | 1 | 同上 |
| `_ArtistDetailRouteContent` | 1 | 同上 |

文件变化：`app_router.dart` +143 / -38

### 不需要修的

- `_MoviesRouteContent` / `_SeriesListRouteContent`：已经是 StatefulWidget
- `_MusicLibraryRouteContent` / `_MusicSearchRouteContent` / `_AiRecommendRouteContent`：StatelessWidget 但 build 里不创建 future，只是给 Feature 页面注入回调（Feature 页面内部自己管理 state）

### 已知风险源（修复后已免疫）

`JellyfinApp.build` 的 `ListenableBuilder` 不是唯一触发源，理论上任何导致 router 父级 widget 树 rebuild 的因素都会触发同样问题：

- 系统主题切换（light/dark mode）
- 横竖屏切换（MediaQuery 变化）
- 键盘弹出（viewInsets 变化）
- 文字缩放比例调整（textScaleFactor 变化）

修复后这些都免疫。

### 参考

Flutter 官方文档专门警告这个反模式：[FutureBuilder class - API docs](https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html)

> **DO NOT** create the future inside the build method...

---

## BUG-001 | 登录后图片全部显示占位图（JellyfinImageProviderScope 未挂载）

**修复提交**：`3086c8d`（master）/ `0a1b4c8`（feat/liquid-glass-vendor）· **修复时间**：2026-06-14

### 现象

登录后所有 JellyfinImage 都显示 `Icons.broken_image` 占位图，封面、海报、人物头像全部不显示。

### 根因

提交 `89f83d0`（视频播放 MVVM 重构）的回归：把路由层的 `wrapWithProviders()` 改名成 `wrapWithServices()`，**顺手删掉了里面的 `JellyfinImageProviderScope` 包裹**，注释误称"图片 Scope 已在 App 根层包裹"，但 `JellyfinApp.build` 实际未挂载。

结果：所有 `JellyfinImage.maybeOf(context)` 返回 null → 走 `widget.errorWidget ?? _defaultError()` → 全屏占位图。

### 触发链

```
JellyfinImage.build
    ↓
JellyfinImageProviderScope.maybeOf(context)  → null（Scope 没挂载）
    ↓
return widget.errorWidget ?? _defaultError()  → 占位图
```

### 修复方式

在 `JellyfinApp.build` 用 `ListenableBuilder` 监听 `_sessionController`，登录态时用 `JellyfinImageProviderScope` 包 `MaterialApp.router`，未登录时返回裸 `MaterialApp.router`。session 变化时 provider 实例自动跟随重建。

```dart
return ListenableBuilder(
  listenable: _sessionController,
  builder: (context, _) {
    final session = _sessionController.currentSession;
    final imageProvider = (session != null && session.isValid)
        ? JellyfinAppImageProvider.fromSession(session)
        : null;

    final materialApp = MaterialApp.router(...);

    if (imageProvider == null) return materialApp;

    return JellyfinImageProviderScope(
      imageProvider: imageProvider,
      child: materialApp,
    );
  },
);
```

文件变化：`jellyfin_app.dart` +24 / -3，`app_router.dart` 注释 1 行

### 验证

- `flutter analyze` → 0 issues
- `flutter test` → 19/19 passed
- 真机实测：登录后所有图片正常加载

### 关联

- 修复引入了 BUG-002（ListenableBuilder 整树 rebuild 触发 FutureBuilder 反模式），随后由 BUG-002 修复一并解决
