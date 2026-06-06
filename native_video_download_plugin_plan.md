# native video download plugin plan

## 目标

这个文档是手写练习路线，不是自动实现脚本。

目标是在当前 Jellyfin Flutter 项目里设计一个 Android 原生视频下载插件：

- Flutter 负责下载按钮、下载管理页、任务展示和用户操作。
- Android Kotlin 负责真实下载、缓存、断点续传、网速统计和任务状态。
- Flutter 通过 MethodChannel 发命令，通过 EventChannel 接收实时状态。
- 第一版先做最小闭环，再逐步进入多线程 Range 下载和 HLS/DASH 片段缓存。

本方案只写：

- 在哪个目录执行哪个命令。
- 创建哪些目录和文件。
- 每个文件写什么职责和内容提纲。
- 每一步完成后如何检查。

本方案不写：

- Dart 代码。
- Kotlin 代码。
- Gradle 具体配置内容。
- XML 具体内容。

## 本机 Flutter 技能和 CLI 依据

本机技能目录：

```text
C:\Users\xue13\.agents\skills
```

已看到的 Flutter 相关技能：

```text
flutter-add-integration-test
flutter-add-widget-preview
flutter-add-widget-test
flutter-apply-architecture-best-practices
flutter-build-responsive-layout
flutter-fix-layout-issues
flutter-implement-json-serialization
flutter-setup-declarative-routing
flutter-setup-localization
flutter-use-http-package
```

这些技能没有专门负责创建 Flutter 原生插件的 CLI 说明，但 `flutter-apply-architecture-best-practices` 的思路可以采用：

- UI 层只负责展示和交互。
- Controller/ViewModel 负责 UI 状态和命令分发。
- Service/Repository 负责外部能力封装。
- 平台插件属于底层 Service 能力，不应该直接塞到页面里。

本机 Flutter CLI 已确认支持：

```text
flutter create --template=plugin
flutter create --template=package
--platforms
--android-language
--org
--project-name
```

所以创建 Android 插件骨架时，优先使用 Flutter CLI，不手动从零创建插件目录。

如果当前项目使用 FVM，把下面命令里的 `flutter` 替换为：

```text
fvm flutter
```

## 核心架构

推荐拆成三块：

```text
packages/plugins/native_video_downloader
  Android 原生下载插件，负责 Kotlin 下载核心和 Channel 通信。

packages/features/jellyfin_download
  Flutter 下载业务模块，负责下载按钮、下载页面、状态模型和页面控制。

Product/jellyfin_app
  产品 App 接入点，负责引入下载 feature、注册路由、把下载按钮挂到详情页。
```

数据流：

```text
Flutter 下载按钮
  -> jellyfin_download feature
  -> native_video_downloader Dart API
  -> MethodChannel
  -> Android Kotlin plugin
  -> 下载任务管理器
  -> EventChannel
  -> Flutter 下载页面实时刷新
```

## 目录命名规则

新建目录和文件统一使用小写：

```text
native_video_downloader
jellyfin_download
download_task_snapshot.dart
native_video_download_client.dart
native_video_download_plugin.kt
```

不要使用大写方案文件名，例如不要再创建：

```text
NATIVE_VIDEO_DOWNLOAD_PLUGIN_PLAN.md
```

## 第 0 步：确认当前工作区

执行目录：

```text
D:\claudeProject\flutter_video_project\ai-video-project\Jellyfin_Service
```

执行命令：

```powershell
git status --short --branch
```

你要确认：

- 当前是否在 `master`。
- 是否有未提交修改。
- 是否有你不想动的文件。

如果只是练习手写，可以先不提交；如果后续准备正式实现，建议每个阶段完成后单独提交一次。

## 第 1 步：用 CLI 创建 Android 原生插件

执行目录：

```text
D:\claudeProject\flutter_video_project\ai-video-project\Jellyfin_Service
```

执行命令：

```powershell
flutter create `
  --template=plugin `
  --platforms=android `
  --android-language=kotlin `
  --org com.jellyfin `
  --project-name native_video_downloader `
  packages\plugins\native_video_downloader
```

如果你只想生成骨架、不想立刻执行 pub get，可以使用：

```powershell
flutter create `
  --template=plugin `
  --platforms=android `
  --android-language=kotlin `
  --org com.jellyfin `
  --project-name native_video_downloader `
  --no-pub `
  packages\plugins\native_video_downloader
```

CLI 会自动创建这些核心文件：

```text
packages/plugins/native_video_downloader/pubspec.yaml
packages/plugins/native_video_downloader/README.md
packages/plugins/native_video_downloader/analysis_options.yaml
packages/plugins/native_video_downloader/lib/native_video_downloader.dart
packages/plugins/native_video_downloader/lib/native_video_downloader_method_channel.dart
packages/plugins/native_video_downloader/lib/native_video_downloader_platform_interface.dart
packages/plugins/native_video_downloader/android/build.gradle
packages/plugins/native_video_downloader/android/src/main/AndroidManifest.xml
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/NativeVideoDownloaderPlugin.kt
packages/plugins/native_video_downloader/test
```

CLI 创建完成后，再手动新增这些文件：

```text
packages/plugins/native_video_downloader/lib/src/native_video_download_client.dart
packages/plugins/native_video_downloader/lib/src/download_command.dart
packages/plugins/native_video_downloader/lib/src/download_task_snapshot.dart
packages/plugins/native_video_downloader/lib/src/download_event_stream.dart
```

如果坚持项目文件名小写，可以把 CLI 生成的 Kotlin 文件重命名为：

```text
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/native_video_downloader_plugin.kt
```

注意：

- Kotlin 类名仍然可以保留 `NativeVideoDownloaderPlugin`。
- 文件名可以小写，类名按 Kotlin/Flutter 插件约定保留 PascalCase。
- `pubspec.yaml` 里的 Android plugin class 仍然指向插件类名，不是文件名。

## 第 2 步：插件 Dart 层文件职责

文件：

```text
packages/plugins/native_video_downloader/pubspec.yaml
```

写入内容提纲：

- 包名：`native_video_downloader`。
- 说明：Android native video download plugin for Jellyfin.
- SDK 约束：跟项目 Flutter/Dart 版本保持一致。
- Flutter 插件声明：只声明 Android 平台。
- Android package：使用 `com.jellyfin.native_video_downloader`。
- Android plugin class：指向 Kotlin 插件类。

文件：

```text
packages/plugins/native_video_downloader/lib/native_video_downloader.dart
```

写入内容提纲：

- 作为 public barrel file。
- 对外导出下载客户端。
- 对外导出命令模型。
- 对外导出任务快照模型。
- 对外导出事件流类型。
- 可以删除或改造 CLI 生成的示例 API，不保留无意义的示例方法。

文件：

```text
packages/plugins/native_video_downloader/lib/native_video_downloader_platform_interface.dart
```

写入内容提纲：

- 这是 CLI 生成的平台接口文件。
- 保留平台接口边界。
- 把示例方法替换成下载命令和事件流的抽象入口。
- 不写 UI。
- 不依赖 Jellyfin feature。

文件：

```text
packages/plugins/native_video_downloader/lib/native_video_downloader_method_channel.dart
```

写入内容提纲：

- 这是 CLI 生成的 MethodChannel 实现文件。
- 保留 MethodChannel 调用职责。
- 增加 EventChannel 状态流职责，或者把 EventChannel 逻辑委托给 `download_event_stream.dart`。
- 不写下载业务判断。
- 不写页面状态管理。

文件：

```text
packages/plugins/native_video_downloader/lib/src/native_video_download_client.dart
```

写入内容提纲：

- 封装 MethodChannel。
- 提供 `startDownload` 的概念入口。
- 提供 `pauseDownload` 的概念入口。
- 提供 `resumeDownload` 的概念入口。
- 提供 `cancelDownload` 的概念入口。
- 提供 `deleteDownload` 的概念入口。
- 提供 `queryTasks` 的概念入口。
- 暴露 EventChannel 的任务状态流。
- 不写 UI。
- 不直接依赖 Jellyfin feature。

文件：

```text
packages/plugins/native_video_downloader/lib/src/download_command.dart
```

写入内容提纲：

- 描述 Flutter 发给 Android 的下载命令参数。
- 字段包括 taskId、itemId、title、url、headers、downloadType、saveFileName。
- 后续可以扩展清晰度、码率、字幕、音轨等信息。
- 这个文件只表达命令数据，不负责执行下载。

文件：

```text
packages/plugins/native_video_downloader/lib/src/download_task_snapshot.dart
```

写入内容提纲：

- 描述 Android 推回 Flutter 的任务状态快照。
- 字段包括 taskId、itemId、title、state、downloadedBytes、totalBytes、progress、speedBytesPerSecond、downloadType、errorMessage、updatedAt。
- state 建议包含 pending、downloading、paused、completed、failed、cancelled。
- downloadType 建议包含 direct_file、hls_segments、dash_segments、unknown。

文件：

```text
packages/plugins/native_video_downloader/lib/src/download_event_stream.dart
```

写入内容提纲：

- 负责把 EventChannel 的原始事件转换成下载任务状态流。
- 只做事件解析和类型转换。
- 不做页面状态管理。
- 不做任务排序和分组。

## 第 3 步：Android 插件层文件职责

文件：

```text
packages/plugins/native_video_downloader/android/build.gradle
```

写入内容提纲：

- Android library 插件配置。
- Kotlin Android 插件配置。
- compileSdk、minSdk 与项目现有 Android 配置保持一致。
- 依赖 OkHttp。
- 后续如果做持久化，可以加入 Room 或 SQLite 相关依赖。
- 后续如果做 Compose debug 页面，再加入 Compose 相关配置。

文件：

```text
packages/plugins/native_video_downloader/android/src/main/AndroidManifest.xml
```

写入内容提纲：

- 声明插件需要的 Android 权限。
- 第一版至少考虑网络权限。
- 后台下载阶段再考虑前台服务权限和通知权限。
- 不要第一版就塞满所有权限。

文件：

```text
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/native_video_downloader_plugin.kt
```

写入内容提纲：

- 实现 FlutterPlugin 生命周期。
- 注册 MethodChannel。
- 注册 EventChannel。
- 接收 startDownload、pauseDownload、resumeDownload、cancelDownload、deleteDownload、queryTasks 等命令。
- 把命令转交给下载管理器。
- 把下载管理器的状态通过 EventChannel 推送给 Flutter。
- 不在这个文件里直接写复杂下载逻辑。

如果还保留 CLI 生成的文件名，则对应文件是：

```text
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/NativeVideoDownloaderPlugin.kt
```

二选一即可，不要两个插件入口文件同时存在。

后续建议继续创建这些 Kotlin 文件：

```text
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/download_manager.kt
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/download_task.kt
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/download_state.kt
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/download_strategy.kt
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/direct_file_download_strategy.kt
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/segment_cache_strategy.kt
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/progress_reporter.kt
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/local_cache_store.kt
```

这些 Kotlin 文件的职责：

- `download_manager.kt`：任务总调度，管理协程、任务生命周期、暂停恢复。
- `download_task.kt`：描述单个下载任务。
- `download_state.kt`：描述任务状态和状态变化。
- `download_strategy.kt`：定义下载策略边界。
- `direct_file_download_strategy.kt`：处理原文件 Range 下载。
- `segment_cache_strategy.kt`：处理 HLS/DASH segment 缓存。
- `progress_reporter.kt`：统计每秒进度和实时网速。
- `local_cache_store.kt`：保存任务状态、文件路径、分片进度。

## 第 4 步：用 CLI 创建 Flutter 下载 feature 包

执行目录：

```text
D:\claudeProject\flutter_video_project\ai-video-project\Jellyfin_Service
```

执行命令：

```powershell
flutter create `
  --template=package `
  --project-name jellyfin_download `
  packages\features\jellyfin_download
```

如果只想生成骨架、不想立刻执行 pub get，可以使用：

```powershell
flutter create `
  --template=package `
  --project-name jellyfin_download `
  --no-pub `
  packages\features\jellyfin_download
```

CLI 会自动创建这些核心文件：

```text
packages/features/jellyfin_download/pubspec.yaml
packages/features/jellyfin_download/README.md
packages/features/jellyfin_download/analysis_options.yaml
packages/features/jellyfin_download/lib/jellyfin_download.dart
packages/features/jellyfin_download/test/jellyfin_download_test.dart
```

CLI 创建完成后，再手动新增目录：

```powershell
New-Item -ItemType Directory -Force -Path `
  packages\features\jellyfin_download\lib\src, `
  packages\features\jellyfin_download\lib\src\pages, `
  packages\features\jellyfin_download\lib\src\widgets, `
  packages\features\jellyfin_download\lib\src\controllers, `
  packages\features\jellyfin_download\lib\src\models
```

再手动新增文件：

```text
packages/features/jellyfin_download/lib/jellyfin_download_pages.dart
packages/features/jellyfin_download/lib/src/pages/downloads_page.dart
packages/features/jellyfin_download/lib/src/widgets/download_button.dart
packages/features/jellyfin_download/lib/src/widgets/download_task_tile.dart
packages/features/jellyfin_download/lib/src/controllers/download_controller.dart
packages/features/jellyfin_download/lib/src/models/download_item_view_model.dart
packages/features/jellyfin_download/test/download_controller_test.dart
```

可以删除或改造 CLI 生成的示例 test 文件，避免保留无意义示例。

## 第 5 步：Flutter 下载 feature 文件职责

文件：

```text
packages/features/jellyfin_download/pubspec.yaml
```

写入内容提纲：

- 包名：`jellyfin_download`。
- 依赖 Flutter。
- 依赖 `native_video_downloader`。
- 需要 UI kit 时依赖 `jellyfin_ui_kit`。
- 需要共享模型时依赖 `jellyfin_models`。
- 不直接依赖产品 App。
- 不直接创建 JellyfinClient。

文件：

```text
packages/features/jellyfin_download/lib/jellyfin_download.dart
```

写入内容提纲：

- 作为 feature 的 public barrel file。
- 对外导出下载按钮。
- 对外导出下载控制器。
- 对外导出必要模型。

文件：

```text
packages/features/jellyfin_download/lib/jellyfin_download_pages.dart
```

写入内容提纲：

- 只导出页面。
- 对外暴露 downloads page。
- 让产品 App 通过 public API 使用页面，不 import `src`。

文件：

```text
packages/features/jellyfin_download/lib/src/pages/downloads_page.dart
```

写入内容提纲：

- 展示下载管理页。
- 页面分为“下载中”和“已缓存”两块。
- 中间用横线或分隔组件隔开。
- 每秒刷新进度和网速，数据来自 controller。
- 页面本身不直接调用 MethodChannel。

文件：

```text
packages/features/jellyfin_download/lib/src/widgets/download_button.dart
```

写入内容提纲：

- 放在影片详情页使用。
- 接收 itemId、title、downloadUrl 或可生成下载命令的数据。
- 点击后调用 controller 或回调。
- 按钮状态包含可下载、准备中、下载中、已缓存。

文件：

```text
packages/features/jellyfin_download/lib/src/widgets/download_task_tile.dart
```

写入内容提纲：

- 展示单个任务。
- 展示标题、进度、速度、状态、操作按钮。
- 操作按钮包含暂停、继续、取消、删除。
- 不负责查询任务。

文件：

```text
packages/features/jellyfin_download/lib/src/controllers/download_controller.dart
```

写入内容提纲：

- 持有 native_video_downloader client。
- 监听下载状态流。
- 把原生任务状态转换成页面列表。
- 区分下载中和已缓存。
- 提供 start、pause、resume、cancel、delete 方法。
- 不直接写 Android 逻辑。

文件：

```text
packages/features/jellyfin_download/lib/src/models/download_item_view_model.dart
```

写入内容提纲：

- 页面展示用模型。
- 包含标题、状态文本、进度文本、速度文本、是否可暂停、是否可继续、是否可删除。
- 不直接等同于原生返回模型。

文件：

```text
packages/features/jellyfin_download/test/download_controller_test.dart
```

写入内容提纲：

- 测试 controller 如何把任务状态分组。
- 测试 downloading、paused、completed 等状态如何映射到 UI。
- 测试速度和进度文本格式。
- 测试任务完成后从“下载中”移动到“已缓存”。

## 第 6 步：产品 App 接入目录和文件

执行目录：

```text
D:\claudeProject\flutter_video_project\ai-video-project\Jellyfin_Service\Product\jellyfin_app
```

需要修改文件：

```text
Product/jellyfin_app/pubspec.yaml
Product/jellyfin_app/lib/src/app_shell/jellyfin_go_router.dart
```

可能需要修改文件：

```text
Product/jellyfin_app/lib/src/app_shell/feature_page_factory.dart
```

需要查找下载按钮挂载位置：

执行目录：

```text
D:\claudeProject\flutter_video_project\ai-video-project\Jellyfin_Service
```

执行命令：

```powershell
rg -n "movie detail|MovieDetail|MediaDetail|detail|playback|button" Product\jellyfin_app\lib packages\features
```

修改 `Product/jellyfin_app/pubspec.yaml` 的内容提纲：

- 增加 `jellyfin_download` path dependency。
- 增加 `native_video_downloader` path dependency，或者只让 App 依赖 feature，feature 再依赖 plugin。
- 推荐产品 App 只直接依赖 `jellyfin_download`，减少 App 和插件细节耦合。

修改 `jellyfin_go_router.dart` 的内容提纲：

- 增加下载管理页路由。
- 路由路径建议：`/downloads`。
- 路由 name 建议：`downloads`。
- builder 里创建 downloads page。
- 不让 feature 内部直接依赖 go_router。

修改详情页相关文件的内容提纲：

- 在影片详情页增加下载按钮。
- 点击按钮时创建下载命令。
- 下载 URL、headers、token 由产品 App 或已注入服务提供。
- 不在详情页直接写 MethodChannel。

## 第 7 步：Channel 命名约定

插件 Dart 层和 Android 层需要使用一致的 channel 名称。

建议写入文档和代码注释中的命名：

```text
MethodChannel:
native_video_downloader/methods

EventChannel:
native_video_downloader/events
```

MethodChannel 命令名：

```text
startDownload
pauseDownload
resumeDownload
cancelDownload
deleteDownload
queryTasks
queryTask
```

EventChannel 事件字段：

```text
taskId
itemId
title
state
downloadedBytes
totalBytes
progress
speedBytesPerSecond
downloadType
errorMessage
updatedAt
```

第一版只需要实现概念上的：

```text
startDownload
queryTasks
events
```

暂停、恢复、取消、删除可以后面再写。

## 第 8 步：第一版最小闭环

目标：

```text
Flutter 点击下载按钮
  -> Android 收到 startDownload
  -> Android 每秒推送模拟进度
  -> Flutter 下载页显示进度和速度
```

执行目录：

```text
D:\claudeProject\flutter_video_project\ai-video-project\Jellyfin_Service\Product\jellyfin_app
```

执行命令：

```powershell
flutter pub get
```

检查命令：

```powershell
flutter analyze
```

如果只检查插件：

执行目录：

```text
D:\claudeProject\flutter_video_project\ai-video-project\Jellyfin_Service\packages\plugins\native_video_downloader
```

执行命令：

```powershell
flutter pub get
flutter analyze
```

如果只检查下载 feature：

执行目录：

```text
D:\claudeProject\flutter_video_project\ai-video-project\Jellyfin_Service\packages\features\jellyfin_download
```

执行命令：

```powershell
flutter pub get
flutter analyze
flutter test
```

第一版完成标准：

- 下载按钮能触发命令。
- Android 插件能收到命令。
- EventChannel 能持续返回模拟状态。
- 下载管理页能显示“下载中”和“已缓存”区域。
- 进度和速度每秒变化。

## 第 9 步：单文件下载阶段

目标：

```text
模拟进度
  -> OkHttp 单文件下载
  -> 文件写入本地缓存目录
  -> 实时上报 downloadedBytes 和 speedBytesPerSecond
```

Android 侧重点文件：

```text
download_manager.kt
download_task.kt
download_state.kt
progress_reporter.kt
local_cache_store.kt
```

文件职责：

- `download_manager.kt`：启动下载任务，管理任务 Job。
- `download_task.kt`：保存任务参数和运行状态。
- `download_state.kt`：定义状态快照。
- `progress_reporter.kt`：每秒计算增量字节数和速度。
- `local_cache_store.kt`：提供缓存目录和文件路径。

检查点：

- 取消任务时协程能停止。
- 文件写入失败时能返回 failed。
- 网络断开时能返回 failed。
- downloadedBytes 不倒退。
- speedBytesPerSecond 允许短时间为 0。

## 第 10 步：Range 多线程原文件下载阶段

目标：

```text
原文件直链
  -> HEAD 检测 Content-Length 和 Accept-Ranges
  -> 拆分 byte ranges
  -> 多协程并发下载
  -> 写入同一个目标文件的不同 offset
```

新增或重点文件：

```text
direct_file_download_strategy.kt
download_strategy.kt
local_cache_store.kt
progress_reporter.kt
```

内容提纲：

- `download_strategy.kt`：定义策略选择边界。
- `direct_file_download_strategy.kt`：负责原文件直链下载。
- `local_cache_store.kt`：记录每个 range 的完成进度。
- `progress_reporter.kt`：汇总所有 range 的下载速度。

判断逻辑：

```text
如果有稳定 Content-Length，并且支持 Accept-Ranges:
  使用 Range 多线程下载。

如果不支持:
  退回单线程顺序下载。
```

学习重点：

- HEAD 请求。
- HTTP Range 请求。
- 多协程并发。
- 任务取消。
- 文件随机位置写入。
- 分片进度持久化。

## 第 11 步：HLS/DASH 片段缓存阶段

目标：

```text
HLS/DASH manifest
  -> 解析 segment 列表
  -> 有限并发下载 segment
  -> 保存本地 manifest 和 segment
  -> 播放时从本地 manifest 读取
```

新增或重点文件：

```text
segment_cache_strategy.kt
local_cache_store.kt
download_task.kt
download_state.kt
```

内容提纲：

- `segment_cache_strategy.kt`：负责 manifest 解析和 segment 下载。
- `local_cache_store.kt`：保存 manifest、segment、metadata。
- `download_task.kt`：增加 segment 总数、已完成 segment 数。
- `download_state.kt`：支持 segment 缓存进度。

判断逻辑：

```text
如果资源是 HLS:
  使用 hls_segments。

如果资源是 DASH:
  使用 dash_segments。

如果是 Jellyfin 实时转码:
  限制并发数，不要一次请求太多未来片段。
```

核心理解：

```text
HLS/DASH 适合并发下载多个 segment。
它不适合把一个不存在的完整转码文件按 byte range 拆开下载。
```

## 第 12 步：任务持久化阶段

目标：

```text
App 关闭后再打开
  -> 能看到之前的下载任务
  -> 已缓存任务仍在已缓存列表
  -> 未完成任务可以恢复或重新开始
```

重点文件：

```text
local_cache_store.kt
download_task.kt
download_state.kt
```

内容提纲：

- 保存任务元数据。
- 保存本地文件路径。
- 保存任务状态。
- 保存原文件 Range 分片进度。
- 保存 HLS/DASH segment 完成列表。
- 保存创建时间和更新时间。

持久化可以分阶段：

```text
第一版：JSON 文件。
第二版：SQLite。
第三版：Room。
```

不建议第一版直接上 Room，先把下载状态机练明白。

## 第 13 步：Compose 学习阶段

Compose 不作为正式 Flutter 下载页的第一版。

建议新建 Android debug 页面：

```text
packages/plugins/native_video_downloader/android/src/main/kotlin/com/jellyfin/native_video_downloader/native_download_debug_activity.kt
```

写入内容提纲：

- 展示原生下载任务列表。
- 展示 StateFlow 或本地状态。
- 展示进度、速度、状态。
- 提供开始、暂停、继续、取消按钮。
- 只用于 Android 原生学习和调试。

如果要创建 Compose 文件，先在插件 android 配置里补 Compose 依赖和配置。

注意：

```text
正式用户页面仍然优先 Flutter。
Compose 页面只作为学习 Kotlin/Compose 的原生练习场。
```

## 第 14 步：推荐提交节奏

每个阶段都可以单独提交。

执行目录：

```text
D:\claudeProject\flutter_video_project\ai-video-project\Jellyfin_Service
```

查看变更：

```powershell
git status --short
```

建议提交点：

```text
1. 创建 native_video_downloader 插件骨架。
2. 创建 jellyfin_download feature 骨架。
3. 完成 MethodChannel 命令闭环。
4. 完成 EventChannel 模拟进度。
5. 完成 Flutter 下载页面展示。
6. 完成 OkHttp 单文件下载。
7. 完成 Range 多线程下载。
8. 完成 HLS/DASH segment 缓存。
9. 完成任务持久化。
10. 完成 Compose debug 页面。
```

## 最小推荐练习顺序

如果你想手写得稳，按这个顺序来：

```text
1. 只创建 native_video_downloader 插件。
2. 写 MethodChannel startDownload。
3. 写 EventChannel 模拟进度。
4. 创建 jellyfin_download feature。
5. 写下载页静态 UI。
6. 把模拟进度接到下载页。
7. 再开始写真实 OkHttp 下载。
8. 再写 Range 多线程。
9. 再写 HLS/DASH segment 缓存。
10. 最后写 Compose debug 页面。
```

不要一开始就同时写：

```text
多线程下载
HLS 缓存
Room
前台服务
Compose
离线播放
```

这些都值得学，但一起上会把问题搅在一起。

## 下载策略总结

原文件直链：

```text
有 Content-Length
有 Accept-Ranges
目标是完整文件
=> DirectFileDownloadStrategy
```

HLS/DASH：

```text
有 manifest
有 segment 列表
目标是缓存片段集合
=> SegmentCacheStrategy
```

Jellyfin 实时转码：

```text
未来片段可能还没生成
URL/session 可能过期
服务端还在边转边产出
=> 有限并发 segment 缓存，必要时顺序缓存
```

一句话：

```text
预转码流媒体适合并发下载多个媒体片段；
传统多线程下载适合稳定存在的完整文件。
```
