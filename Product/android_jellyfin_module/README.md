# android_jellyfin_module

Android 原生宿主集成用 Flutter 模块。当前模块使用 `FlutterBoostApp + routeFactory` 注册页面，宿主侧通过稳定页面名打开 Flutter 页面，适合按 CI/CD 产物版本进行多团队协作。

## 路由入口

入口文件：

- `lib/main.dart`：初始化 `BoostFlutterBinding`，启动 `BoostModuleApp`
- `lib/boost_app.dart`：维护 FlutterBoost 路由工厂和页面名映射

当前页面名：

| 页面名 | Flutter 页面 | 说明 |
|---|---|---|
| `login` | `_LoginPage` | 登录页，复用 `jellyfin_auth` 的 `LoginPage` |
| `media_home` | `_MediaHomePage` | 媒体库首页占位页 |

宿主侧应只依赖这些稳定页面名和参数结构，不直接依赖 Flutter 内部页面类。新增页面时先在这里补充页面名、参数、返回值，再同步 Android 侧打开逻辑。

## 版本化协作

- 以本模块的 `pubspec.yaml` `version` 作为宿主可集成版本号。
- 每次新增页面名、修改参数结构或调整跨端回调时，同步更新本文档和 changelog。
- CI/CD 可将该 Flutter module 打包成 Android 可消费产物，宿主侧锁定版本接入。
- Feature 包继续通过 public barrel、Repository/Port、回调和导航意图暴露能力，不把 `go_router` 或 `flutter_boost` 泄露到业务包。

## 开发约定

- FlutterBoost 页面名使用小写下划线或简短英文名，保持跨端稳定。
- 路由参数使用 `Map<String, Object?>` 可序列化数据，避免传 Dart 对象实例给宿主侧。
- 登录、媒体库、播放等真实能力由产品层注入 Gateway/Session/Adapter，业务 feature 不直接创建 Jellyfin API client。
