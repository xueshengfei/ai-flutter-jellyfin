# 架构调用链路详解

> **适用范围更新**：本文档主要描述全功能独立 App（`Product/jellyfin_app`）中的 GoRouter 调用链。当前 `Product/jellyfin_video_app` 和 `Product/android_jellyfin_module` 已采用 `FlutterBoostApp + routeFactory` 作为宿主集成入口；阅读本文中的 `app_router.dart`、GoRouter、path 示例时，应把它们视为独立 App 路由链路示例，不作为视频宿主模块的唯一现状。

本文档详细记录 Jellyfin Service SDK 中各组件如何被上层调用，涵盖：
1. 登录 Token 全链路
2. 四层架构与组件调用关系
3. 场景一：点击播放视频
4. 场景二：跳转到详情页（电影/歌手）
5. 图片组件（jellyfin_ui_kit）使用全貌

---

## 一、登录 Token 全链路

### 1.1 整体流程图

```
┌──────────────────────────────────────────────────────────────────────┐
│                        用户输入账号密码                                │
│  LoginPage (jellyfin_auth 包)                                        │
│  serverUrl: http://localhost:8096                                     │
│  username: xue13 / password: 123456                                  │
└────────────────────────────┬─────────────────────────────────────────┘
                             │ 调用 onLogin 回调
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│  AppRouter (jellyfin_app)                                            │
│  调用 effectiveGateway.login(serverUrl, username, password)           │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│  LegacyJellyfinGateway.login()                                       │
│  ① new JellyfinConfiguration(serverUrl)                              │
│  ② new ApiClient(config) — 注册 Dio 拦截器                           │
│  ③ client.jellyfinClient.getUserApi().authenticateUserByName()        │
│     → HTTP POST /Users/AuthenticateByName                            │
│     → body: { Username, Pw }                                         │
│  ④ 响应返回 accessToken + user.id                                    │
│  ⑤ config.accessToken = data.accessToken                             │
│  ⑥ client.updateAccessToken(data.accessToken)                        │
│  ⑦ 返回 AppSession(serverUrl, accessToken, userId, username)         │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│  AppSessionController.setSession(session)                             │
│  → 存到内存（ChangeNotifier，未持久化到磁盘）                           │
│  → notifyListeners() → GoRouter 刷新路由 → 跳转到首页                 │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.2 登录 UI 入口

> 文件：`packages/features/jellyfin_auth/lib/src/pages/login_page.dart`

LoginPage 是纯 UI 组件，认证能力通过 `onLogin` 回调注入，不依赖任何具体服务实现：

```dart
// packages/features/jellyfin_auth/lib/src/pages/login_page.dart:12-18
class LoginPage extends StatefulWidget {
  /// 登录回调，返回 null 表示成功，返回错误信息字符串表示失败
  final Future<String?> Function({
    required String serverUrl,
    required String username,
    required String password,
  }) onLogin;

  const LoginPage({
    super.key,
    required this.onLogin,
    this.defaultServerUrl = 'http://localhost:8096',
    this.defaultUsername = 'xue13',
    this.defaultPassword = '123456',
    this.discoveryService,
  });
```

用户点击登录按钮后：

```dart
// packages/features/jellyfin_auth/lib/src/pages/login_page.dart:130-134
final error = await widget.onLogin(
  serverUrl: serverUrl,
  username: username,
  password: password,
);
```

### 1.3 Gateway 登录实现

> 文件：`Product/jellyfin_app/lib/src/data/legacy_jellyfin_gateway.dart:22-55`

```dart
@override
Future<AppSession> login({
  required String serverUrl,
  required String username,
  required String password,
}) async {
  // ① 创建配置（此时没有 token）
  final config = JellyfinConfiguration(
    serverUrl: serverUrl,
    enableLogging: false,
  );
  // ② 创建 ApiClient（内部注册 Dio 拦截器）
  final client = ApiClient(config);

  // ③ 调用 Jellyfin 认证 API
  final response = await client.jellyfinClient
      .getUserApi()
      .authenticateUserByName(
        authenticateUserByName: jellyfin_dart.AuthenticateUserByName(
          username: username,
          pw: password,
        ),
      );

  // ④ 从响应中提取 token
  final data = response.data!;
  // ⑤ 将 token 写入配置对象
  config.accessToken = data.accessToken;
  config.userId = data.user?.id;
  // ⑥ 将 token 同步到 Dio 的默认 header
  client.updateAccessToken(data.accessToken);

  // ⑦ 保存 client 实例供后续使用
  _apiClient = client;

  // ⑧ 返回 AppSession 给上层
  return AppSession(
    serverUrl: serverUrl,
    accessToken: data.accessToken!,    // ← token 在这里提取
    userId: data.user?.id ?? '',
    username: data.user?.name ?? '',
  );
}
```

### 1.4 Session 存储（仅内存）

> 文件：`Product/jellyfin_app/lib/src/session/app_session.dart`

```dart
/// 应用会话 — 持有当前登录态信息
class AppSession {
  final String serverUrl;
  final String accessToken;   // ← token 存在这里
  final String userId;
  final String username;

  const AppSession({
    required this.serverUrl,
    required this.accessToken,
    required this.userId,
    required this.username,
  });

  bool get isValid =>
      serverUrl.isNotEmpty &&
      accessToken.isNotEmpty &&
      userId.isNotEmpty;
}
```

> 文件：`Product/jellyfin_app/lib/src/session/app_session_controller.dart`

```dart
class AppSessionController extends ChangeNotifier {
  AppSession? _session;

  AppSession? get currentSession => _session;
  bool get isLoggedIn => _session?.isValid == true;

  void setSession(AppSession session) {
    _session = session;
    notifyListeners();  // 触发 GoRouter 刷新路由
  }

  void clearSession() {
    _session = null;
    notifyListeners();
  }
}
```

### 1.5 Token 注入机制 — 核心原理

> 文件：`packages/foundation/jellyfin_api/lib/src/api_client.dart`

ApiClient 在构造时做了两件事：
1. 创建主 Dio 实例（`_dio`），在默认 header 中设置 `X-Emby-Authorization`
2. 为 `jellyfin_dart` SDK 创建独立 Dio 实例，注册 **请求拦截器** 动态注入 token

```dart
// packages/foundation/jellyfin_api/lib/src/api_client.dart:44-59
void _initializeDio() {
  _dio = Dio(BaseOptions(
    baseUrl: _config.baseUrl,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      _authHeaderKey: _config.buildAuthHeader(),  // ← 默认 header 带 token
    },
  ));
  _setupInterceptors();
}
```

```dart
// packages/foundation/jellyfin_api/lib/src/api_client.dart:62-84
void _initializeJellyfinClient() {
  final customDio = Dio(BaseOptions(
    baseUrl: _config.serverUrl,
  ));

  // ★ 关键：每次请求前，拦截器动态读取 config 中的 token 并注入
  customDio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers[_authHeaderKey] = _config.buildAuthHeader();
        handler.next(options);
      },
    ),
  );

  _jellyfinClient = jellyfin_dart.JellyfinDart(
    dio: customDio,
    basePathOverride: _config.serverUrl,
  );
}
```

主 Dio 的拦截器也做同样的事：

```dart
// packages/foundation/jellyfin_api/lib/src/api_client.dart:87-95
void _setupInterceptors() {
  _dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers[_authHeaderKey] = _config.buildAuthHeader();
        handler.next(options);
      },
      // ... onResponse, onError 省略
    ),
  );
}
```

**更新 token 的方法**：登录成功后调用 `updateAccessToken`，同时更新 config 和 Dio 默认 header：

```dart
// packages/foundation/jellyfin_api/lib/src/api_client.dart:120-123
void updateAccessToken(String? token) {
  _config.accessToken = token;
  _dio.options.headers[_authHeaderKey] = _config.buildAuthHeader();
}
```

### 1.6 Auth Header 的拼装

> 文件：`packages/foundation/jellyfin_core/lib/src/configuration/jellyfin_configuration.dart:144-155`

```dart
/// 构建鉴权请求头值
String buildAuthHeader() {
  final parts = <String>[
    'MediaBrowser Client="$clientName"',         // "Jellyfin Flutter"
    'Device="${deviceName ?? 'Dart Client'}"',
    'DeviceId="${deviceId ?? 'dart-client-default'}"',
    'Version="$applicationVersion"',              // "0.1.0"
  ];
  if (accessToken != null && accessToken!.isNotEmpty) {
    parts.add('Token="$accessToken"');             // ← token 在这里拼入
  }
  return parts.join(', ');
}
```

最终 HTTP 请求 header：
```
X-Emby-Authorization: MediaBrowser Client="Jellyfin Flutter", Device="Dart Client", DeviceId="dart-client-default", Version="0.1.0", Token="xxxxxxxxxxxxx"
```

### 1.7 Token 流转总结图

```
┌─────────────┐     onLogin()      ┌──────────────────────┐
│  LoginPage   │ ───────────────── │  AppRouter            │
│  (UI 层)     │                   │  (产品层入口)          │
└─────────────┘                    └──────────┬───────────┘
                                              │ gateway.login()
                                              ▼
                                   ┌──────────────────────┐
                                   │  LegacyJellyfinGateway│
                                   │  (Gateway 层)         │
                                   │  ① ApiClient(config)  │
                                   │  ② authenticateUser() │
                                   │  ③ 提取 accessToken   │
                                   │  ④ updateAccessToken()│
                                   └──────────┬───────────┘
                                              │
                          ┌───────────────────┤
                          │                   │
                          ▼                   ▼
               ┌─────────────────┐  ┌───────────────────┐
               │  JellyfinConfig │  │  AppSession        │
               │  .accessToken   │  │  .accessToken      │
               │  (给 Dio 用)    │  │  (给 UI 层用)      │
               └────────┬────────┘  └────────┬──────────┘
                        │                    │
                        ▼                    ▼
               ┌─────────────────┐  ┌───────────────────┐
               │  Dio Interceptor│  │ SessionController  │
               │  自动注入 header │  │ .setSession()      │
               │  X-Emby-Token   │  │ notifyListeners()  │
               └─────────────────┘  └───────────────────┘
```

---

## 二、四层架构与组件调用关系

### 2.1 架构分层图

```
┌────────────────────────────────────────────────────────────────────────┐
│  产品层 Product                                                         │
│  Product/jellyfin_app / jellyfin_video_app / jellyfin_music_app        │
│  职责: 路由注册、Gateway 实现、Session 管理、ImageProvider 实现          │
│  依赖: 所有 feature 包 + shared 包 + foundation 包                     │
├────────────────────────────────────────────────────────────────────────┤
│  业务层 packages/features/*                                             │
│  jellyfin_movies / jellyfin_music / jellyfin_series / jellyfin_playback│
│  jellyfin_media / jellyfin_personal / jellyfin_auth / rvc_flutter      │
│  职责: 纯 UI 页面 + 业务模型，通过回调解耦                               │
│  规则: feature 之间禁止互相 import                                      │
├────────────────────────────────────────────────────────────────────────┤
│  基础组件层 packages/shared/*                                           │
│  jellyfin_models   → 纯 Dart 数据模型（MediaItem, MediaLibrary 等）     │
│  jellyfin_ui_kit   → 跨业务复用 UI 组件（卡片、图片、列表布局）          │
│  jellyfin_testing  → 测试 fixtures、fake navigator                     │
├────────────────────────────────────────────────────────────────────────┤
│  基础工具层 packages/foundation/*                                       │
│  jellyfin_core → 配置(JellyfinConfiguration)、异常基类、模块协议        │
│  jellyfin_api  → ApiClient + Dio + 鉴权拦截器 + jellyfin_dart 适配     │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.2 调用规则

| 规则 | 说明 |
|------|------|
| feature 之间禁止互相 import | 通过回调/协议解耦 |
| feature 只接受 `jellyfin_models.MediaItem` | 不依赖旧根包的 BaseItemDto |
| DTO → Model 转换在 Gateway 层 | `BaseItemDto → mapMediaItem() → MediaItem` |
| 外部禁止 `import src/` | 使用 public sub-barrel 导出 |
| 页面跳转用注入回调或 AppNavigator | 不直接 import 别的 feature 页面 |
| 图片加载通过 `JellyfinImageProvider` 接口 | 具体 URL 构建和鉴权由 Product App 注入 |

### 2.3 各层调用关系图

```
Product App (jellyfin_app)
  │
  ├── import ──→ jellyfin_api        (创建 ApiClient, 调用 jellyfin_dart)
  ├── import ──→ jellyfin_models     (使用 MediaItem, MediaLibrary 等模型)
  ├── import ──→ jellyfin_ui_kit     (使用 JellyfinImage, LibraryCard 等)
  ├── import ──→ jellyfin_core       (使用 JellyfinConfiguration, ServiceRegistry)
  │
  ├── import ──→ jellyfin_auth       (登录页 LoginPage)
  ├── import ──→ jellyfin_movies     (电影筛选/详情 MovieDetailPage)
  ├── import ──→ jellyfin_music      (音乐三Tab/专辑/播放 MusicLibraryPage)
  ├── import ──→ jellyfin_series     (季列表/集列表 SeasonsPage)
  ├── import ──→ jellyfin_playback   (视频播放器 VideoPlayerPage)
  ├── import ──→ jellyfin_media      (通用媒体详情 MediaItemDetailPage)
  ├── import ──→ jellyfin_personal   (个人中心 PersonalPage)
  └── import ──→ rvc_flutter         (RVC 任务中心 RvcPage)

Feature 包内部:
  jellyfin_movies
    ├── import ──→ jellyfin_models   (使用 MediaItem 模型)
    ├── import ──→ jellyfin_ui_kit   (使用 JellyfinImage, MediaItemCard)
    ├── import ──→ jellyfin_core     (使用 ServiceRegistry, AppNavigator)
    └── × 不 import 其他 feature 包

  jellyfin_music
    ├── import ──→ jellyfin_models   (使用 MediaItem 模型)
    ├── import ──→ jellyfin_ui_kit   (使用 JellyfinImage)
    ├── import ──→ jellyfin_core     (使用 ServiceRegistry, AppNavigator)
    └── × 不 import jellyfin_movies / jellyfin_series 等
```

---

## 三、场景一：点击播放视频

### 3.1 流程图

```
用户点击「播放」按钮
       │
       ▼
MovieDetailPage._buildContent() 中的 FilledButton:
  ServiceRegistry.get<AppNavigator>(context).pushIntent(
    JellyfinRouteIntents.playbackVideo(itemId: movie.id),
  )
       │
       ▼
GoRouterAppNavigator.pushIntent()
  → 解析 intent → context.push('/playback/video/$itemId')
       │
       ▼
GoRouter 匹配路由 path: '/playback/video/:itemId'
  → 构建 _PlaybackRouteContent(gateway, itemId)
       │
       ▼
_PlaybackRouteContent.build():
  FutureBuilder<MediaItem>(
    future: gateway.getMediaItemDetail(itemId),   ← ① 加载媒体详情
  )
       │ future 完成
       ▼
  ② final adapter = PlaybackAdapter(apiClient);
     final delegate = adapter.createDelegate();
       │
       ▼
  ③ return VideoPlayerPage(item, playback: delegate)
       │
       ▼
VideoPlayerPage._initializePlayer():
  ④ await playback.getPlaybackUrl(itemId, startTimeTicks)
       │
       ▼
PlaybackAdapter._getPlaybackUrl():
  ⑤ _apiClient.jellyfinClient.getMediaInfoApi().getPostedPlaybackInfo(...)
     → Dio 拦截器自动注入 X-Emby-Authorization header
     → 服务端返回 PlaybackResponse (含 mediaSources, playSessionId)
       │
       ▼
  ⑥ 构建视频 URL（token 拼在 URL 里）:
     DirectPlay:  "$serverUrl/Videos/$itemId/stream.mp4?Static=true&api_key=$accessToken"
     Transcode:   "$serverUrl$transcodingUrl"
       │
       ▼
  ⑦ VideoPlayerController.networkUrl(url) → ChewieController 包装
  ⑧ 启动播放会话，每 10 秒上报进度
```

### 3.2 播放按钮触发（Feature 层）

> 文件：`packages/features/jellyfin_movies/lib/src/pages/movie_detail_page.dart:180-185`

```dart
FilledButton.icon(
  onPressed: () {
    ServiceRegistry.get<AppNavigator>(context).pushIntent(
      JellyfinRouteIntents.playbackVideo(itemId: movie.id),
    );
  },
  icon: const Icon(Icons.play_arrow),
  label: const Text('播放'),
),
```

### 3.3 路由匹配与 FutureBuilder（Product 层）

> 文件：`Product/jellyfin_app/lib/src/app/app_router.dart:999-1074`

```dart
class _PlaybackRouteContent extends StatelessWidget {
  final JellyfinGateway gateway;
  final String itemId;
  final String? aiServiceUrl;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.MediaItem>(
      future: gateway.getMediaItemDetail(itemId),  // ← 加载数据
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        // ... 错误处理 ...

        final item = snapshot.data!;
        final apiClient = _getApiClient(gateway);

        // 创建播放适配器
        final adapter = PlaybackAdapter(apiClient);
        final delegate = adapter.createDelegate();

        return VideoPlayerPage(
          item: item,
          playback: delegate,
          fetchWatchAssist: watchAssistClient?.fetchWatchAssist,
          onStartDownload: onStartDownload,
        );
      },
    );
  }
}
```

### 3.4 播放 URL 获取（Gateway → API 层）

> 文件：`Product/jellyfin_app/lib/src/data/playback_adapter.dart:45-140`

```dart
Future<PlaybackInfo> _getPlaybackUrl({
  required String itemId,
  int? startTimeTicks,
  int? maxStreamingBitrate,
}) async {
  final config = _apiClient.config;
  final accessToken = config.accessToken;  // ← 从 config 读取 token

  // ① 调 Jellyfin API 获取播放信息
  final response = await _apiClient.jellyfinClient.getMediaInfoApi()
      .getPostedPlaybackInfo(
    itemId: itemId,
    playbackInfoDto: jellyfin_dart.PlaybackInfoDto(
      userId: config.userId,
      startTimeTicks: startTimeTicks ?? 0,
      maxStreamingBitrate: maxStreamingBitrate ?? 120000000,
      enableDirectPlay: true,
      enableDirectStream: true,
      enableTranscoding: true,
      // ...
    ),
  );

  // ② 获取媒体源
  final source = response.data!.mediaSources!.first;
  final serverUrl = config.serverUrl;

  // ③ DirectPlay：直接拼接 URL，token 放在 api_key 参数
  if (source.supportsDirectPlay == true && maxStreamingBitrate == null) {
    final container = source.container ?? 'mp4';
    final directUrl = '$serverUrl/Videos/$itemId/stream.$container'
        '?Static=true'
        '&MediaSourceId=${source.id ?? itemId}'
        '&api_key=$accessToken';          // ← token 拼在 URL 里
    return PlaybackInfo(url: directUrl, playSessionId: _playSessionId!, isTranscoded: false);
  }

  // ④ Transcode：使用服务端返回的转码 URL
  if (source.transcodingUrl != null) {
    String transcodingUrl = source.transcodingUrl!;
    if (transcodingUrl.startsWith('/')) {
      transcodingUrl = '$serverUrl$transcodingUrl';
    }
    return PlaybackInfo(url: transcodingUrl, playSessionId: _playSessionId!, isTranscoded: true);
  }
  // ...
}
```

### 3.5 视频播放的特殊性

视频流 Token 注入方式与普通 API 请求不同：

| 场景 | Token 注入方式 | 原因 |
|------|--------------|------|
| 普通 API 请求 | `X-Emby-Authorization` header（Dio 拦截器） | 标准 HTTP 请求 |
| 图片加载 | `X-Emby-Token` header（CachedNetworkImage） | 需要缓存的图片请求 |
| 视频流 URL | URL 参数 `api_key=$accessToken` | 播放器不支持自定义 header |
| 文件下载 | URL 参数 `api_key=$token` | 下载器不支持自定义 header |

---

## 四、场景二：跳转到详情页

以用户在电影筛选页点击一张电影卡片 → 跳转到电影详情页为例。

### 4.1 流程图

```
用户点击电影卡片 (MediaItemCard)
       │
       ▼
MediaItemCard.onTap 回调触发
  → context.push('/movies/${item.id}')
       │
       ▼
GoRouter 匹配路由 path: '/movies/:itemId'
  → 从 session 创建 imageProvider
  → ServiceRegistry 包裹 (注入 AppNavigator + Gateway + ImageProvider)
  → 构建 _MovieDetailRouteContent(gateway, itemId, imageProvider)
       │
       ▼
_MovieDetailRouteContent.build():
  FutureBuilder<MediaItem>(
    future: gateway.getMediaItemDetail(itemId),  ← ① 发起 API 请求
  )
       │
       ▼
LegacyJellyfinGateway.getMediaItemDetail():
  ② _apiClient!.jellyfinClient.getItemsApi().getItems(
       userId: config.userId,
       ids: [itemId],
       fields: [overview, people, studios, genres],
     )
     → Dio 拦截器自动注入 X-Emby-Authorization header  ← token 在这里注入
     → 服务端返回 BaseItemDto
       │
       ▼
  ③ mapMediaItem(BaseItemDto) → 转换为 jellyfin_models.MediaItem
     提取: id, name, type, overview, genres, directors, actors,
           primaryImageTag, backdropImageTag, runTimeTicks, studios ...
       │
       ▼
FutureBuilder builder 回调:
  ④ return MovieDetailPage(
       movie: snapshot.data!,         ← MediaItem 数据
       fetchDetail: gateway.getMediaItemDetail,  ← 刷新用回调
       imageProvider: imageProvider,   ← 图片加载抽象
     )
       │
       ▼
MovieDetailPage 渲染:
  ⑤ SliverAppBar + JellyfinImage(背景图)      ← 图片加载链路见第五节
     FutureBuilder(详细数据)                     ← 二次加载演员等信息
     播放按钮 → pushIntent(playbackVideo)
     剧情简介 / 类型标签 / 评分 / 导演 / 演员
```

### 4.2 路由注册（Product 层）

> 文件：`Product/jellyfin_app/lib/src/app/app_router.dart:278-300`

```dart
// ─── 电影详情 ───
GoRoute(
  path: '/movies/:itemId',
  name: JellyfinRouteNames.movieDetail,
  builder: (context, state) {
    final itemId = state.pathParameters['itemId']!;
    final session = sessionController.currentSession;
    return ServiceRegistry(
      services: buildServices(session),    // 注入所有服务
      child: Builder(builder: (context) {
        return _MovieDetailRouteContent(
          gateway: effectiveGateway,
          itemId: itemId,
          imageProvider: JellyfinAppImageProvider(    // 创建图片加载器
            serverUrl: session?.serverUrl ?? '',
            accessToken: session?.accessToken ?? '',  // ← 传入 token
          ),
          onStartDownload: startMediaDownload,
        );
      }),
    );
  },
),
```

### 4.3 FutureBuilder 加载数据（Product 层）

> 文件：`Product/jellyfin_app/lib/src/app/app_router.dart:815-851`

```dart
class _MovieDetailRouteContent extends StatelessWidget {
  final JellyfinGateway gateway;
  final String itemId;
  final JellyfinAppImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.MediaItem>(
      future: gateway.getMediaItemDetail(itemId),  // ← 触发数据加载
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _ErrorScaffold(error: '${snapshot.error}');
        }
        return MovieDetailPage(
          movie: snapshot.data!,              // ← 加载完成的 MediaItem
          fetchDetail: gateway.getMediaItemDetail,
          imageProvider: imageProvider,        // ← 传给 Feature 页面
          onStartDownload: onStartDownload,
        );
      },
    );
  }
}
```

### 4.4 Gateway 数据获取（Gateway 层）

> 文件：`Product/jellyfin_app/lib/src/data/legacy_jellyfin_gateway.dart:136-156`

```dart
@override
Future<models.MediaItem> getMediaItemDetail(String itemId) async {
  _requireClient();  // 确保已登录
  final config = _apiClient!.config;

  // 调用 jellyfin_dart SDK
  final response = await _apiClient!.jellyfinClient.getItemsApi().getItems(
    userId: config.userId,
    ids: [itemId],
    fields: [
      jellyfin_dart.ItemFields.overview,
      jellyfin_dart.ItemFields.people,
      jellyfin_dart.ItemFields.studios,
      jellyfin_dart.ItemFields.genres,
    ],
  );
  // ★ 此时的 HTTP 请求，Dio 拦截器已自动注入 X-Emby-Authorization header

  final items = response.data?.items ?? [];
  if (items.isEmpty) {
    throw StateError('找不到媒体项: $itemId');
  }
  // BaseItemDto → MediaItem 模型转换
  return mapMediaItem(items.first, config.serverUrl);
}
```

### 4.5 DTO → Model 转换（Gateway 层）

> 文件：`Product/jellyfin_app/lib/src/data/legacy_jellyfin_gateway.dart:622-738`

```dart
/// BaseItemDto → MediaItem（公开，供 adapter 复用）
static models.MediaItem mapMediaItem(
  jellyfin_dart.BaseItemDto dto,
  String serverUrl,
) {
  // 提取图片标签
  final imageTags = dto.imageTags;
  final primaryImageTag = imageTags?['Primary'];
  // ...

  // 提取人员信息 → 导演/编剧/演员
  for (final person in (dto.people ?? [])) {
    if (person.type == jellyfin_dart.PersonKind.director) {
      directors.add(person.name!);
    } else if (person.type == jellyfin_dart.PersonKind.actor) {
      actorInfos.add(models.ActorInfo(
        name: person.name!,
        role: person.role,
        imageUrl: '$serverUrl/Items/${person.id}/Images/Primary?tag=$personImageTag',
        id: person.id,
      ));
    }
  }

  return models.MediaItem(
    id: dto.id ?? '',
    name: dto.name ?? '未知媒体',
    type: typeString,
    serverUrl: serverUrl,
    primaryImageTag: hasImageTag ? primaryImageTag : (hasImage ? 'has_image' : null),
    backdropImageTag: backdropTag,
    genres: dto.genres,
    communityRating: dto.communityRating,
    overview: dto.overview,
    directors: directors,
    actors: actors,
    actorInfos: actorInfos,
    // ... 更多字段
  );
}
```

### 4.6 Feature 页面渲染

> 文件：`packages/features/jellyfin_movies/lib/src/pages/movie_detail_page.dart:54-122`

MovieDetailPage 接收已加载好的 `MediaItem` 和 `imageProvider` 回调：

```dart
class MovieDetailPage extends StatefulWidget {
  final MediaItem movie;
  final MovieDetailFetcher fetchDetail;
  final JellyfinImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ① 顶部大图（使用 JellyfinImage 加载带鉴权的背景图）
          SliverAppBar(
            expandedHeight: 300,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.movie.name),
              background: _buildBackdrop(),  // ← JellyfinImage(imageProvider: ...)
            ),
          ),
          // ② 详细信息（二次 FutureBuilder 加载完整数据）
          FutureBuilder<MediaItem>(
            future: _detailFuture,
            builder: (context, snapshot) {
              return SliverToBoxAdapter(child: _buildContent(snapshot.data!));
            },
          ),
        ],
      ),
    );
  }
}
```

### 4.7 歌手详情页（同理）

路径: `/music/artists/${artistId}`

区别只在 Gateway 方法不同：
- `gateway.getArtistDetail(artistId)` → `BaseItemDto → _mapMusicArtist() → MusicArtist`
- `gateway.getArtistAlbums(artistId)` → 获取该艺术家的专辑列表

链路与电影详情完全一致：路由匹配 → FutureBuilder → Gateway → API → 模型转换 → 页面渲染。

---

## 五、图片组件（jellyfin_ui_kit）使用全貌

### 5.1 图片加载架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│  业务页面 (Feature 层)                                               │
│  MovieDetailPage / MusicLibraryPage / PersonalPage / ...            │
│                                                                     │
│  使用 JellyfinImage(imageProvider: provider, itemId: 'xxx')         │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  JellyfinImage (jellyfin_ui_kit 包)                                 │
│  ① imageProvider.buildImageUrl(itemId, imageType, tag, w, h)       │
│     → 拼出: "$serverUrl/Items/$itemId/Images/Primary?tag=xxx"      │
│  ② imageProvider.authHeaders                                        │
│     → 返回: { 'X-Emby-Token': accessToken }                        │
│  ③ CachedNetworkImage(imageUrl: url, httpHeaders: headers)          │
│     → HTTP GET + 磁盘缓存 + 内存缓存                                │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ 依赖抽象接口
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  JellyfinImageProvider (抽象接口)                                    │
│  buildImageUrl()  → 构建图片 URL                                    │
│  authHeaders      → 返回鉴权 header                                 │
│  getImage()       → 降级方案: 手动 HTTP + Image.memory              │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ 由 Product App 实现
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  JellyfinAppImageProvider (jellyfin_app)                            │
│  JellyfinVideoImageProvider (jellyfin_video_app)                    │
│  JellyfinMusicImageProvider (jellyfin_music_app)                    │
│                                                                     │
│  构造参数: serverUrl + accessToken (从 AppSession 获取)              │
│  buildImageUrl: "$serverUrl/Items/$itemId/Images/${type.pathSegment}│
│  authHeaders: {'X-Emby-Token': accessToken}                        │
│  getImage: http.get(url, headers: {'X-Emby-Token': accessToken})   │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 JellyfinImageProvider 抽象接口

> 文件：`packages/shared/jellyfin_ui_kit/lib/src/image/jellyfin_image_provider.dart`

```dart
/// 图片加载抽象接口
abstract class JellyfinImageProvider {
  /// 获取图片的完整 URL（供 CachedNetworkImage 使用）
  String buildImageUrl({
    required String itemId,
    JellyfinImageType imageType = JellyfinImageType.primary,
    String? imageTag,
    int? fillWidth,
    int? fillHeight,
  });

  /// 请求图片时需要的认证 header
  Map<String, String>? get authHeaders => null;

  /// 获取图片原始字节（降级方案）
  Future<Uint8List> getImage({
    required String itemId,
    JellyfinImageType imageType = JellyfinImageType.primary,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  });
}

enum JellyfinImageType {
  primary('Primary'),     // 封面
  backdrop('Backdrop'),   // 背景大图
  thumb('Thumb'),         // 缩略图
  logo('Logo'),           // Logo
  banner('Banner');       // Banner
  final String pathSegment;
  const JellyfinImageType(this.pathSegment);
}
```

### 5.3 JellyfinImage Widget 实现

> 文件：`packages/shared/jellyfin_ui_kit/lib/src/image/jellyfin_image.dart`

```dart
class JellyfinImage extends StatefulWidget {
  final JellyfinImageProvider imageProvider;
  final String itemId;
  final JellyfinImageType imageType;
  final String? imageTag;
  final int? fillWidth;
  final int? fillHeight;
  // ...
}

class _JellyfinImageState extends State<JellyfinImage> {
  bool _useFallback = false;
  Uint8List? _imageData;

  void _initImage() {
    final url = widget.imageProvider.buildImageUrl(
      itemId: widget.itemId,
      imageType: widget.imageType,
      imageTag: widget.imageTag,
      fillWidth: widget.fillWidth,
      fillHeight: widget.fillHeight,
    );

    if (url.isEmpty) {
      // URL 为空 → 降级到手动 http + Image.memory
      _useFallback = true;
      _loadFallback();
    }
  }

  // ★ 主路径：CachedNetworkImage（磁盘+内存缓存）
  Widget _buildCachedNetworkImage() {
    final url = widget.imageProvider.buildImageUrl(...);
    final headers = widget.imageProvider.authHeaders;  // {'X-Emby-Token': token}

    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,     // ← 鉴权 header 在这里传入
      fit: widget.fit,
      placeholder: (_, __) => Shimmer(...),
      errorWidget: (_, __, ___) => Icon(Icons.broken_image),
      memCacheWidth: widget.fillWidth,
      memCacheHeight: widget.fillHeight,
    );
  }

  // 降级路径：手动 HTTP 请求
  Future<void> _loadFallback() async {
    final imageData = await widget.imageProvider.getImage(
      itemId: widget.itemId,
      imageType: widget.imageType,
      tag: widget.imageTag,
    );
    setState(() { _imageData = imageData; });
  }
}
```

### 5.4 Product App 的 ImageProvider 实现

> 文件：`Product/jellyfin_app/lib/src/ui/jellyfin_app_image_provider.dart`

```dart
class JellyfinAppImageProvider implements JellyfinImageProvider {
  final String serverUrl;
  final String accessToken;

  JellyfinAppImageProvider({
    required this.serverUrl,
    required this.accessToken,
  });

  factory JellyfinAppImageProvider.fromSession(AppSession session) {
    return JellyfinAppImageProvider(
      serverUrl: session.serverUrl,
      accessToken: session.accessToken,
    );
  }

  @override
  String buildImageUrl({
    required String itemId,
    JellyfinImageType imageType = JellyfinImageType.primary,
    String? imageTag,
    int? fillWidth,
    int? fillHeight,
  }) {
    if (serverUrl.isEmpty) return '';
    // URL 格式: {serverUrl}/Items/{itemId}/Images/{type}?tag=xxx&fillWidth=200
    var url = '$serverUrl/Items/$itemId/Images/${imageType.pathSegment}';
    final params = <String, String>{};
    if (imageTag != null && imageTag.isNotEmpty) params['tag'] = imageTag;
    if (fillWidth != null) params['fillWidth'] = '$fillWidth';
    if (fillHeight != null) params['fillHeight'] = '$fillHeight';
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    return url;
  }

  @override
  Map<String, String>? get authHeaders {
    if (accessToken.isEmpty) return null;
    return {'X-Emby-Token': accessToken};  // ← 图片鉴权用 X-Emby-Token
  }

  @override
  Future<Uint8List> getImage({...}) async {
    // 降级方案：手动 HTTP GET + X-Emby-Token header
    final response = await http.get(
      Uri.parse(url),
      headers: {'X-Emby-Token': accessToken},
    );
    return response.bodyBytes;
  }
}
```

### 5.5 ImageProvider 的注入点

ImageProvider 在 **路由层**（app_router.dart）创建，注入到每个 Route Content：

```dart
// Product/jellyfin_app/lib/src/app/app_router.dart:122-140
Map<Type, Object> buildServices(AppSession? session) {
  final imageProvider = JellyfinAppImageProvider(
    serverUrl: session?.serverUrl ?? '',
    accessToken: session?.accessToken ?? '',  // ← 从 session 拿 token
  );
  return <Type, Object>{
    AppNavigator: goRouterNavigator,
    JellyfinGateway: effectiveGateway,
    JellyfinImageProvider: imageProvider,  // ← 注册到 ServiceRegistry
    // ...
  };
}
```

每个路由也单独创建 imageProvider 传给 Route Content：

```dart
// Product/jellyfin_app/lib/src/app/app_router.dart:282-296
GoRoute(
  path: '/movies/:itemId',
  builder: (context, state) {
    final session = sessionController.currentSession;
    return ServiceRegistry(
      services: buildServices(session),
      child: Builder(builder: (context) {
        return _MovieDetailRouteContent(
          gateway: effectiveGateway,
          itemId: itemId,
          imageProvider: JellyfinAppImageProvider(   // ← 直接传给 Route Content
            serverUrl: session?.serverUrl ?? '',
            accessToken: session?.accessToken ?? '',
          ),
        );
      }),
    );
  },
),
```

### 5.6 ui_kit 组件使用位置汇总

#### 核心 Widget

| 组件 | 文件 | 用途 |
|------|------|------|
| `JellyfinImage` | `ui_kit/.../image/jellyfin_image.dart` | 带鉴权的图片 Widget |
| `JellyfinImageProvider` | `ui_kit/.../image/jellyfin_image_provider.dart` | 图片加载抽象接口 |
| `LibraryCard` | `ui_kit/.../widgets/library_card.dart` | 媒体库卡片（首页用） |
| `MediaItemCard` | `ui_kit/.../widgets/media_item_card.dart` | 通用媒体项卡片 |
| `MediaItemCardWithActions` | `ui_kit/.../widgets/media_item_card_with_actions.dart` | 带操作的卡片 |
| `ContinueWatchingCard` | `ui_kit/.../widgets/continue_watching_card.dart` | 继续观看卡片 |
| `PersonAvatarCard` | `ui_kit/.../widgets/person_avatar_card.dart` | 人物头像卡片 |
| `MediaListBuilder` | `ui_kit/.../widgets/media_list_builder.dart` | 列表构建器 |
| `BannerListView` | `ui_kit/.../widgets/media_list_layouts/banner_list_view.dart` | Banner 横滑列表 |
| `VerticalListView` | `ui_kit/.../widgets/media_list_layouts/vertical_list_view.dart` | 垂直列表 |
| `PosterGridView` | `ui_kit/.../widgets/media_list_layouts/poster_grid_view.dart` | 海报网格 |
| `CardGridView` | `ui_kit/.../widgets/media_list_layouts/card_grid_view.dart` | 卡片网格 |

#### Feature 包中的使用位置

| Feature 包 | 使用了哪些 ui_kit 组件 | 页面文件 |
|------------|----------------------|---------|
| **jellyfin_movies** | `JellyfinImage` | `movie_detail_page.dart` — 背景图、封面海报 |
| **jellyfin_series** | `JellyfinImage` | `seasons_page.dart` / `episodes_page.dart` / `season_card.dart` / `episode_card.dart` |
| **jellyfin_media** | `JellyfinImage`, `PersonAvatarCard`, `MediaItemCard` | `media_item_detail_page.dart` / `person_detail_page.dart` |
| **jellyfin_music** | `JellyfinImage` | `music_library_page.dart` — 专辑封面、艺术家头像 |
| **jellyfin_personal** | `JellyfinImage`, `MediaItemCard` | `personal_page.dart` / `personal_media_card.dart` / `personal_settings_page.dart` / `personal_stats_page.dart` |
| **jellyfin_ai_recommendation** | `JellyfinImage` | `ai_recommend_page.dart` |
| **jellyfin_download** | `JellyfinImage` | `downloads_page.dart` / `download_task_tile.dart` |
| **jellyfin_app 首页** | `LibraryCard`, `ContinueWatchingCard` | `media_libraries_page.dart` |
| **jellyfin_video_app** | `LibraryCard`, `MediaItemCard`, `ContinueWatchingCard` | `recommend_tab.dart` |

### 5.7 LibraryCard 中 JellyfinImage 的使用示例

> 文件：`packages/shared/jellyfin_ui_kit/lib/src/widgets/library_card.dart:89-125`

```dart
class _LibraryCover extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final MediaLibrary library;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(7)),
      clipBehavior: Clip.antiAlias,
      child: library.hasCoverImage
          ? JellyfinImage(
              imageProvider: imageProvider,  // ← 注入的图片加载器
              itemId: library.id,
              imageTag: library.primaryImageTag,
              fillWidth: 96,
              fillHeight: 96,
              fit: BoxFit.cover,
            )
          : Center(child: Text(library.type.icon)),  // 无图时显示 emoji
    );
  }
}
```

### 5.8 MediaItemCard 中 JellyfinImage 的使用示例

> 文件：`packages/shared/jellyfin_ui_kit/lib/src/widgets/media_item_card.dart:111-124`

```dart
Widget _buildCoverImage(BuildContext context) {
  if (item.hasCoverImage) {
    return JellyfinImage(
      imageProvider: imageProvider,    // ← 注入的图片加载器
      itemId: item.id,
      imageTag: item.primaryImageTag,
      fillWidth: 200,
      fillHeight: 300,
      fit: BoxFit.cover,
      placeholder: _buildPlaceholder(context),
      errorWidget: _buildPlaceholder(context),
    );
  }
  return _buildPlaceholder(context);
}
```

### 5.9 三个 Product App 的 ImageProvider 实现

每个 App 各自提供一个实现，从各自的 session 获取 token：

| App | 实现文件 | token 来源 |
|-----|---------|-----------|
| jellyfin_app | `Product/jellyfin_app/lib/src/ui/jellyfin_app_image_provider.dart` | `AppSession.accessToken` |
| jellyfin_video_app | `Product/jellyfin_video_app/lib/src/ui/jellyfin_video_image_provider.dart` | video_app 自己的 session |
| jellyfin_music_app | `Product/jellyfin_music_app/lib/src/ui/jellyfin_music_image_provider.dart` | music_app 自己的 session |

三个实现的逻辑完全一致：`buildImageUrl()` 拼接 REST URL，`authHeaders` 返回 `{'X-Emby-Token': accessToken}`。

---

## 附录：Token 注入方式汇总

```
┌─────────────────────────────────────────────────────────────────┐
│                    Token 注入方式对比                             │
├──────────────┬──────────────────────┬──────────────────────────┤
│  场景         │  注入方式             │  代码位置                 │
├──────────────┼──────────────────────┼──────────────────────────┤
│  普通 API 请求│  X-Emby-Authorization │  api_client.dart:69-76   │
│  (jellyfin_  │  header               │  拦截器自动注入           │
│  dart SDK)   │  (Dio Interceptor)    │                          │
├──────────────┼──────────────────────┼──────────────────────────┤
│  图片加载     │  X-Emby-Token header  │  jellyfin_app_image_     │
│  (CachedNet- │  (httpHeaders 参数)   │  provider.dart:49-52     │
│  workImage)  │                       │                          │
├──────────────┼──────────────────────┼──────────────────────────┤
│  视频流 URL  │  api_key URL 参数      │  playback_adapter.dart:  │
│  (DirectPlay)│                       │  98-101                  │
├──────────────┼──────────────────────┼──────────────────────────┤
│  文件下载 URL│  api_key URL 参数      │  app_router.dart:48-56   │
│              │                       │  _buildMediaDownloadUrl() │
└──────────────┴──────────────────────┴──────────────────────────┘
```
