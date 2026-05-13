# Jellyfin App 架构分层说明

本文档用于指导 `Product/jellyfin_app` 后续开发。当前策略是：不再继续围绕旧根包 `lib/` 做拆解，而是以新产品 App 为顶部入口，自顶向下逐步接入已有 feature 模块。

这版分层采用“产品层 + 业务编排层 + Feature 能力层 + 通用组件/基础能力层 + 基础设施层”的规则。它比单纯四层更适合当前项目，因为：

- `Product/jellyfin_app` 既有表现层，也有业务编排逻辑。
- 媒体库首页这种“产品导航枢纽”不适合拆成通用 feature 包。
- `video_player`、`just_audio`、`dio` 这类不是业务模块，而是平台/基础能力。
- 业务层内部可能有嵌套编排，但必须禁止循环依赖和直接页面互相 import。

---

## 1. 推荐分层

```text
┌──────────────────────────────────────────────────────────────┐
│                产品表现层（Product Presentation）             │
│  Product/jellyfin_app/lib/main.dart                           │
│  Product/jellyfin_app/lib/src/app/*                           │
│  App 启动、主题、根路由、登录重定向、全局状态注入               │
├──────────────────────────────────────────────────────────────┤
│              产品业务编排层（App Business）                    │
│  Product/jellyfin_app/lib/src/features/*                      │
│  Product/jellyfin_app/lib/src/session/*                       │
│  Product/jellyfin_app/lib/src/data/*                          │
│  首页、媒体库、route page、session、gateway、跨模块流程编排      │
├──────────────────────────────────────────────────────────────┤
│              通用业务能力层（Domain Feature）                  │
│  packages/features/*                                          │
│  登录 UI、电影、通用媒体、剧集、音乐、播放器、AI 推荐、RVC        │
├──────────────────────────────────────────────────────────────┤
│              通用 UI 组件层（Shared UI）                       │
│  packages/shared/jellyfin_ui_kit                              │
│  媒体卡片、图片组件、基础列表/索引控件、可复用纯 UI              │
├──────────────────────────────────────────────────────────────┤
│             通用基础能力层（Shared Capability）                │
│  packages/shared/jellyfin_models                              │
│  packages/foundation/jellyfin_core                            │
│  video_player、just_audio、dio、shared_preferences 等能力原语   │
│  模型、协议、配置、路由契约、播放/音频/网络/缓存等基础能力        │
├──────────────────────────────────────────────────────────────┤
│              基础设施层（Infrastructure）                      │
│  packages/foundation/jellyfin_api                             │
│  packages/shared/jellyfin_testing                             │
│  legacy_jellyfin_gateway、旧 jellyfin_service 过渡桥            │
│  API SDK、网络实现、测试工具、旧实现兼容                         │
└──────────────────────────────────────────────────────────────┘

依赖方向：上层可以依赖下层，下层不能知道上层。
```

注意：`video_player`、`just_audio` 不是 Flutter SDK 自带能力，它们是 Flutter 生态插件。架构上应把它们视为“平台能力原语”，不能让业务页面到处直接依赖。

---

## 2. 层级定义

| 层级 | 当前项目位置 | 主要职责 | 可以依赖 | 禁止依赖 |
|---|---|---|---|---|
| 产品表现层 | `Product/jellyfin_app/lib/main.dart` | App 启动入口 | `src/app` | 旧根包 UI、feature `src` |
| 产品表现层 | `Product/jellyfin_app/lib/src/app/jellyfin_app.dart` | 创建根 Widget、持有 controller/gateway/router | session、data、router | feature 内部实现 |
| 产品表现层 | `Product/jellyfin_app/lib/src/app/app_router.dart` | `go_router` 路由表、登录重定向、route page 组装 | App 业务层、feature public barrel、core 协议 | feature `src`、旧根包 UI |
| 产品业务编排层 | `Product/jellyfin_app/lib/src/session/*` | 当前登录态、token、serverUrl、服务地址生命周期 | core/shared model | UI 页面、feature、网络实现细节 |
| 产品业务编排层 | `Product/jellyfin_app/lib/src/data/*` | App 统一数据访问、gateway、旧 SDK 过渡桥 | `jellyfin_api` 或短期 `jellyfin_service` | feature 页面实现 |
| 产品业务编排层 | `Product/jellyfin_app/lib/src/features/home/*` | 首页、媒体库、继续观看、入口编排 | gateway、session、route names、shared UI | 直接 new `JellyfinClient`、直接 import 电影/音乐/播放页 |
| 产品业务编排层 | `Product/jellyfin_app/lib/src/features/media/*` | 媒体/电影/剧集 route page，按 id 拉数据并组装 feature 页面 | gateway、movies/media/series public API | 旧根包 UI、其他业务 route page |
| 产品业务编排层 | `Product/jellyfin_app/lib/src/features/music/*` | 音乐 route page、音乐库/专辑/艺术家/搜索编排 | gateway、music public API、音频 adapter | 视频播放页面、旧音乐 UI |
| 产品业务编排层 | `Product/jellyfin_app/lib/src/features/playback/*` | 播放 route page，准备 item 和播放 delegate | gateway、playback public API | 电影/剧集页面实现 |
| 产品业务编排层 | `Product/jellyfin_app/lib/src/features/ai/*` | AI 推荐 route page，注入 AI 地址和跳转回调 | gateway、AI feature public API | AppSession 泄露给 feature |
| 通用业务能力层 | `packages/features/jellyfin_auth` | 登录/注册 UI 组件 | Flutter、必要时 core 协议 | `JellyfinClient`、AppSession、go_router |
| 通用业务能力层 | `packages/features/jellyfin_movies` | 电影列表、筛选、电影详情 UI | shared models、shared UI、core 协议 | App、其他 feature `src` |
| 通用业务能力层 | `packages/features/jellyfin_media` | 通用媒体列表、详情、人物详情 UI | shared models、shared UI、core 协议 | App、旧根包 |
| 通用业务能力层 | `packages/features/jellyfin_series` | 季列表、集列表、剧集 UI | shared models、shared UI | movies/playback 页面 |
| 通用业务能力层 | `packages/features/jellyfin_music` | 音乐专辑、艺术家、歌曲、音频播放端口 | shared models、shared UI | video playback 页面、App route table |
| 通用业务能力层 | `packages/features/jellyfin_playback` | 视频播放 UI、画质、播放模型 | shared models、播放器能力 adapter | 电影/剧集/AI 页面 |
| 通用业务能力层 | `packages/features/jellyfin_ai_recommendation` | AI 推荐页、SSE、TTS 交互 | shared models、基础网络能力 | AppSession、go_router、旧根包 UI |
| 通用业务能力层 | `packages/features/rvc_flutter` | RVC 语音转换能力 | Flutter/网络基础能力 | App 页面、其他 feature 页面 |
| 通用 UI 组件层 | `packages/shared/jellyfin_ui_kit` | 纯 UI 组件、图片组件、卡片、列表、索引条 | Flutter、shared models | App session、gateway、业务请求 |
| 通用基础能力层 | `packages/shared/jellyfin_models` | 跨模块共享模型、契约、DTO-like model | pure Dart | App、feature 页面 |
| 通用基础能力层 | `packages/foundation/jellyfin_core` | 配置、异常、导航协议、路由名、模块协议 | pure Dart / Flutter foundation | App、feature、go_router |
| 通用基础能力层 | 第三方能力原语 | `video_player`、`chewie`、`just_audio`、`dio`、`shared_preferences`、`path_provider`、`logger`、`cached_network_image` | Flutter/平台 | 产品业务页面直接散用 |
| 基础设施层 | `packages/foundation/jellyfin_api` | API client、鉴权头、异常转换、网络 SDK 封装 | `jellyfin_core`、`dio`、`jellyfin_dart` | App 页面、feature 页面 |
| 基础设施层 | `packages/shared/jellyfin_testing` | fixture、fake navigator、测试辅助 | core、shared models | 产品运行时代码 |
| 基础设施层 | `Product/jellyfin_app/lib/src/data/legacy_jellyfin_gateway.dart` | 旧 `jellyfin_service` 过渡桥 | 旧根包 public API | 旧 UI 页面 |
| 基础设施层 | 根包 `jellyfin_service/lib` | 旧 SDK/旧 UI/历史实现 | 历史依赖 | 新增产品业务 |

---

## 3. 模块依赖关系

### 3.1 产品 App

```text
Product/jellyfin_app
  -> packages/features/jellyfin_auth
  -> packages/features/jellyfin_movies
  -> packages/features/jellyfin_media
  -> packages/features/jellyfin_series
  -> packages/features/jellyfin_music
  -> packages/features/jellyfin_playback
  -> packages/features/jellyfin_ai_recommendation
  -> packages/features/rvc_flutter
  -> packages/shared/jellyfin_ui_kit
  -> packages/shared/jellyfin_models
  -> packages/foundation/jellyfin_core
  -> packages/foundation/jellyfin_api
  -> jellyfin_service（短期只允许 legacy_jellyfin_gateway 使用）
```

规则：

- `Product/jellyfin_app` 是唯一可以组合多个 feature 页面的位置。
- `go_router` 只允许放在 `Product/jellyfin_app/lib/src/app` 或 `Product/jellyfin_app/lib/src/navigation`。
- `Product/jellyfin_app` 可以 import feature public barrel，例如 `jellyfin_movies_pages.dart`。
- `Product/jellyfin_app` 不允许 import `packages/features/*/lib/src/...`。
- `Product/jellyfin_app` 不允许直接 import 旧根包 `lib/src/ui/pages/...`。

### 3.2 通用业务能力层

```text
jellyfin_auth
  -> Flutter

jellyfin_movies
  -> jellyfin_models
  -> jellyfin_ui_kit
  -> jellyfin_core（仅协议/导航意图）

jellyfin_media
  -> jellyfin_models
  -> jellyfin_ui_kit
  -> jellyfin_core（仅协议/导航意图）

jellyfin_series
  -> jellyfin_models
  -> jellyfin_ui_kit

jellyfin_music
  -> jellyfin_models
  -> jellyfin_ui_kit
  -> AudioPlaybackPort（本模块内协议）

jellyfin_playback
  -> jellyfin_models
  -> video_player / chewie（限制在播放模块内部）

jellyfin_ai_recommendation
  -> jellyfin_models
  -> SSE / TTS 基础能力
```

规则：

- feature 模块不持有 `AppSession`。
- feature 模块不直接创建 `JellyfinClient`。
- feature 模块不直接依赖 `go_router`。
- feature 模块需要数据时，由 App 层通过 `fetchXxx` 回调注入。
- feature 模块需要跳转时，由 App 层通过回调、`AppNavigator` 或 `RouteNavigationIntent` 注入。
- feature 模块可以依赖自己的内部 model/service，但不能 import 其他 feature 的 `src`。

### 3.3 通用 UI 与基础能力

```text
jellyfin_ui_kit
  -> Flutter
  -> jellyfin_models

jellyfin_models
  -> pure Dart

jellyfin_core
  -> pure Dart / Flutter foundation

第三方能力原语
  -> video_player
  -> chewie
  -> just_audio
  -> dio
  -> shared_preferences
  -> path_provider
  -> logger
  -> cached_network_image
```

规则：

- `jellyfin_ui_kit` 只做纯 UI，不发请求、不读 token、不知道 App session。
- `jellyfin_models` 不依赖 Flutter UI，不依赖网络。
- `jellyfin_core` 只定义协议，不实现产品路由，不依赖 `go_router`。
- `video_player` 只应该出现在 `jellyfin_playback` 或播放 adapter 中。
- `just_audio` 只应该出现在音乐播放 adapter/manager 中。
- `dio` 主要出现在 `jellyfin_api` 或极少数基础服务中。
- `shared_preferences` 只应该出现在 session/storage/settings adapter 中。

---

## 4. 业务层允许嵌套，但要按“编排依赖”管理

业务层不是完全平铺的，确实可能出现嵌套依赖。比如：

```text
home 媒体库页
  -> 点击电影库
  -> media/movie route page
  -> jellyfin_movies MovieFilterPage
  -> 点击电影详情
  -> movie detail route
  -> 点击播放
  -> playback route
```

这种流程是允许的，但必须遵守下面规则。

### 4.1 业务层内部角色

| 角色 | 示例 | 允许做什么 | 禁止做什么 |
|---|---|---|---|
| 入口编排页 | `features/home/media_libraries_page.dart` | 展示首页、发起路由、调用 gateway | 直接 import 详情页/播放页 |
| Route Page | `features/media/media_route_pages.dart` | 按 route 参数拉数据、组装 feature 页面 | 调用另一个 route page 的 Widget |
| Flow Coordinator | `app_router.dart` 或未来 `navigation/*` | 维护跨业务跳转规则 | 放业务 UI |
| Gateway | `data/jellyfin_gateway.dart` | 统一处理请求和 session | 依赖页面 |
| Adapter | `data/mappers/*`、播放/音乐 adapter | 模型转换、第三方能力适配 | 持有 UI 状态 |

### 4.2 业务层嵌套依赖规则

允许：

```text
home 页面 -> AppNavigator / route name
route page -> gateway
route page -> feature public page
route page -> mapper/adapter
feature page -> App 注入的 callback
```

禁止：

```text
home 页面 -> media_route_pages.dart
media route page -> playback route page
music route page -> video playback page
AI route page -> media route page Widget
任意业务页 -> 旧根包 UI 页面
```

跨业务跳转只能这样表达：

```text
业务页面
  -> route name / RouteNavigationIntent / callback
  -> app_router
  -> 对应 route page
```

不要这样写：

```text
业务页面
  -> import 另一个业务页面
  -> Navigator.push(MaterialPageRoute(builder: ...))
```

### 4.3 判断是否需要抽公共业务服务

如果两个业务模块都需要同一段逻辑，不要让它们互相依赖。按下面顺序处理：

```text
1. 是数据请求？放到 JellyfinGateway。
2. 是模型转换？放到 data/mappers。
3. 是播放/音频能力？放到 adapter 或对应 feature 的 port。
4. 是纯 UI？放到 jellyfin_ui_kit。
5. 是协议/路由名？放到 jellyfin_core。
```

---

## 5. 媒体库页面放哪一层

当前决定：媒体库页面不单独拆成 `packages/features/jellyfin_libraries`。

媒体库页面属于新 App 的业务编排层：

```text
Product/jellyfin_app/lib/src/features/home/media_libraries_page.dart
```

原因：

- 它是 App 首页和导航枢纽，不是独立通用能力。
- 它需要知道登录后的当前 session。
- 它要决定电影库、音乐库、普通媒体库分别跳到哪里。
- 它更像产品编排页，而不是可复用业务组件。

媒体库页允许：

```text
调用 App gateway 获取媒体库列表
调用 App gateway 获取继续观看
展示首页 UI
点击 library 后发起 App 路由跳转
点击继续观看后跳播放路由
展示 AI 推荐入口
```

媒体库页禁止：

```text
直接 new JellyfinClient
直接 import 电影详情页
直接 import 音乐详情页
直接 import 播放页
直接管理 token
```

---

## 6. Session 与 Token 规则

登录成功后，`Product/jellyfin_app` 必须生成唯一的 `AppSession`。

建议 `AppSession` 至少包含：

```dart
class AppSession {
  final String serverUrl;
  final String accessToken;
  final String userId;
  final String username;
  final String aiServiceUrl;
  final String rvcServiceUrl;
}
```

规则：

- `serverUrl` 是 Jellyfin 服务器地址，必须标准化，去掉尾部 `/`。
- `accessToken` 必须来自登录成功后的真实 token。
- 后续媒体库、详情、音乐、播放、AI 请求都不能自己保存 token。
- 后续请求必须通过 App gateway 或由 App 注入的 fetcher 使用当前 `AppSession`。
- `aiServiceUrl` 默认从 Jellyfin IP 推导，端口默认 `5005`。
- `rvcServiceUrl` 默认从 Jellyfin IP 推导，端口默认 `9880`。

示例：

```text
Jellyfin: http://192.168.1.100:8096
AI:       http://192.168.1.100:5005
RVC:      http://192.168.1.100:9880
```

如果用户手动配置 AI/RVC 地址，则以用户配置为准。

---

## 7. 请求流向

### 7.1 登录请求

```text
jellyfin_auth LoginPage
  -> onLogin(serverUrl, username, password)
  -> Product/jellyfin_app app_router
  -> JellyfinGateway.login
  -> LegacyJellyfinGateway / future JellyfinApiGateway
  -> AppSessionController.setSession
  -> go_router redirect 到 /libraries
```

### 7.2 媒体库请求

```text
MediaLibrariesPage
  -> JellyfinGateway.getMediaLibraries(currentSession)
  -> gateway 使用 session.serverUrl + session.accessToken
  -> 返回 jellyfin_models.MediaLibrary
  -> 页面展示
```

### 7.3 详情页请求

```text
go_router /media/items/:itemId
  -> App route page
  -> JellyfinGateway.getMediaItemDetail(itemId)
  -> App route page 转成 feature 所需模型
  -> jellyfin_media MediaItemDetailPage
```

### 7.4 播放请求

```text
任意播放入口
  -> /playback/video/:itemId
  -> Product/jellyfin_app playback route page
  -> gateway 获取 item + playback delegate
  -> jellyfin_playback VideoPlayerPage
```

---

## 8. 开发时判断模块放哪一层

| 你要写的东西 | 放哪里 |
|---|---|
| App 启动、主题、根路由、登录重定向 | `Product/jellyfin_app/lib/src/app` |
| 当前用户 session、token、serverUrl | `Product/jellyfin_app/lib/src/session` |
| App 对 Jellyfin 服务的统一访问 | `Product/jellyfin_app/lib/src/data` |
| 媒体库首页、首页编排、入口页 | `Product/jellyfin_app/lib/src/features/home` |
| 路由页，按 id 拉数据再组装 feature 页面 | `Product/jellyfin_app/lib/src/features/<area>` |
| 可复用登录/注册 UI | `packages/features/jellyfin_auth` |
| 可复用电影 UI | `packages/features/jellyfin_movies` |
| 可复用媒体详情 UI | `packages/features/jellyfin_media` |
| 可复用剧集 UI | `packages/features/jellyfin_series` |
| 可复用音乐 UI | `packages/features/jellyfin_music` |
| 可复用视频播放 UI | `packages/features/jellyfin_playback` |
| 可复用 AI 推荐 UI | `packages/features/jellyfin_ai_recommendation` |
| 纯 UI 组件、卡片、图片组件 | `packages/shared/jellyfin_ui_kit` |
| 共享模型 | `packages/shared/jellyfin_models` |
| 路由协议、配置、基础异常 | `packages/foundation/jellyfin_core` |
| HTTP/API SDK 封装 | `packages/foundation/jellyfin_api` |
| 视频播放插件封装 | `packages/features/jellyfin_playback` 或 App playback adapter |
| 音频播放插件封装 | `Product/jellyfin_app` 的 audio adapter 或未来 `jellyfin_audio` |
| 本地存储、偏好设置 | `Product/jellyfin_app/lib/src/session` 或 settings storage |

---

## 9. 禁止事项

后续开发禁止：

```text
feature 模块 import Product/jellyfin_app
feature 模块 import 其他 feature 的 src
feature 模块直接创建 JellyfinClient
feature 模块直接依赖 go_router
foundation/shared 层依赖 feature
Product/jellyfin_app 直接 import 旧根包 UI 页面
Product/jellyfin_app 业务页直接散用 video_player/just_audio/dio
旧根包 lib/src/app_shell 继续新增产品路由
旧 FeaturePageFactory 继续扩展新业务
```

允许的短期例外：

```text
Product/jellyfin_app/lib/src/data/legacy_jellyfin_gateway.dart
  -> import package:jellyfin_service/jellyfin_service.dart
```

这个例外只用于过渡，目标是后续替换为直接基于 `jellyfin_api` 的 gateway。

---

## 10. 当前阶段开发重点

当前不要急着把所有页面都拆成 package。

优先级：

```text
1. 保证 Product/jellyfin_app 登录后能形成完整 AppSession。
2. 保证 token/serverUrl/aiServiceUrl/rvcServiceUrl 是后续请求唯一来源。
3. 媒体库首页留在 App 业务编排层，不单独拆包。
4. 逐步把电影、音乐、剧集、播放、AI 推荐接入已有 feature。
5. 每接一个 feature，都通过 App route page 注入数据和导航回调。
6. 第三方插件能力只能在 adapter 或专门 feature 内使用，不能扩散到业务页面。
```

判断标准：

```text
能放 App 编排层的，不急着拆 feature。
能通过回调注入的，不让 feature 直接知道 App。
能通过 route name 表达的，不直接 import 目标页面。
能包装成 adapter 的，不让业务页面直接碰第三方插件。
```

