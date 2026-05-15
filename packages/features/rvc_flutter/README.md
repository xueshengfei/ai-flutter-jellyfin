# rvc_flutter — RVC 语音转换 UI 模块

RVC（Retrieval-based Voice Conversion）语音转换的 Flutter Feature 模块。提供音色转换和一键 AI 翻唱的完整交互界面，包括服务连接管理、任务调度、参数调节、结果播放等能力。

基于 [rvc_sdk](../../vendor/rvc_sdk/) HTTP 客户端构建，遵循项目模块化约定：页面通过注入 `RvcTaskController` 工作，不依赖其他 Feature 包。

## 功能清单

- **服务连接** — 自动获取 RVC 服务状态和可用模型列表，支持在线切换服务器地址
- **音色转换** — 选择模型 + 音频文件，调节音高偏移 / F0 算法 / 检索比率等参数，执行单人声转换
- **一键翻唱** — 完整流水线（人声分离 → 去混响 → RVC 转换 → AI 混音），可调节人声/伴奏音量
- **任务管理** — 内存级任务中心，支持多源音频按 `sourceKey` 跟踪，页面退出后任务状态不丢失
- **结果播放** — 转换完成后通过 `just_audio` 在线播放结果音频
- **音频输入** — 支持本地文件路径（同机场景）和文件选择器上传音频字节

## 核心类说明

### 模型

| 类 / 枚举 | 文件 | 说明 |
|---|---|---|
| `RvcTaskStatus` | `lib/src/models/rvc_task.dart` | 任务状态枚举：`idle` / `running` / `succeeded` / `failed` |
| `RvcTaskSnapshot` | `lib/src/models/rvc_task.dart` | 不可变任务快照，记录 id、状态、源文件、模型、结果、时间戳等。提供 `playUrl` / `downloadUrl` 便捷访问器和 `copyWith` 方法 |

### 控制器

| 类 | 文件 | 说明 |
|---|---|---|
| `RvcTaskController` | `lib/src/controllers/rvc_task_controller.dart` | `ChangeNotifier`，App 级生命周期。管理三块能力：**服务连接**（`connect` / `updateServerUrl`）、**任务执行**（`startConvert` / `startCover` / `clearTask`）、**结果播放**（`togglePlayback`）。按 `sourceKey` 维护任务 Map，同一源文件的任务可覆盖更新 |

### 页面

| Widget | 文件 | 说明 |
|---|---|---|
| `RvcPage` | `lib/src/rvc_page.dart` | 主页面，接收 `RvcTaskController`。包含服务状态卡片、模型选择器、音频输入区、参数面板（音高偏移/F0 算法/检索比率/辅音保护/采样率）、转换模式切换、结果展示区、任务中心弹窗和服务器设置对话框。页面只管临时 UI 状态（选中的模型/文件/参数），不持有任务数据 |

### 公开导出（barrel）

`lib/rvc_flutter.dart` 导出：

- `RvcTaskController`
- `RvcTaskSnapshot` / `RvcTaskStatus`
- `RvcPage`

## 依赖关系

```
rvc_flutter
  ├── rvc_sdk          (vendor，RVC HTTP API 客户端)
  │     └── http
  ├── just_audio        (^0.9.42，结果音频播放)
  ├── file_picker       (^8.0.0，音频文件选择)
  └── path_provider     (^2.1.5)
```

不依赖 `jellyfin_models`、`jellyfin_ui_kit` 或其他 Feature 包。

## 使用示例

### 1. App 层创建并持有 Controller

```dart
// Product/jellyfin_app/lib/src/app/jellyfin_app.dart
class JellyfinApp extends StatefulWidget { ... }

class _JellyfinAppState extends State<JellyfinApp> {
  late final RvcTaskController _rvcController;

  @override
  void initState() {
    super.initState();
    _rvcController = RvcTaskController(
      serverUrl: 'http://192.168.1.100:9880',
    );
  }

  @override
  void dispose() {
    _rvcController.dispose();
    super.dispose();
  }
}
```

### 2. 路由注册

```dart
// Product/jellyfin_app/lib/src/app/app_router.dart
GoRoute(
  path: '/rvc',
  builder: (context, state) => RvcRoutePage(
    controller: rvcController,
    audioPath: state.uri.queryParameters['audioPath'],
  ),
),
```

### 3. Route Page 注入

```dart
// Product/jellyfin_app/lib/src/features/rvc/rvc_route_page.dart
class RvcRoutePage extends StatelessWidget {
  final RvcTaskController controller;
  final String? audioPath;

  const RvcRoutePage({
    super.key,
    required this.controller,
    this.audioPath,
  });

  @override
  Widget build(BuildContext context) {
    return RvcPage(controller: controller, audioPath: audioPath);
  }
}
```

## RvcTaskController 关键 API

| 方法 / 属性 | 说明 |
|---|---|
| `connect()` | 连接服务，获取状态 + 模型列表 |
| `updateServerUrl(url)` | 切换服务器地址并自动重连 |
| `startConvert(...)` | 执行音色转换 |
| `startCover(...)` | 执行一键翻唱（含人声分离+混音） |
| `togglePlayback()` | 播放 / 停止当前任务结果 |
| `clearTask()` / `clearTaskForSource(key)` | 清除任务 |
| `tasks` | 所有任务列表（按创建时间排序） |
| `activeTask` | 当前活跃源的任务 |
| `isConnected` / `isConnecting` / `models` | 连接状态和模型列表 |
| `isPlaying` | 是否正在播放结果 |

## 测试说明

```bash
# 运行模块测试（目前无独立测试文件，可后续补充）
cd packages/features/rvc_flutter && flutter test

# 静态分析
cd packages/features/rvc_flutter && flutter analyze
```

模块测试通过集成测试验证：`Product/jellyfin_app` 下 15 个测试全部通过，`rvc_flutter` 作为依赖参与全链路验证。

## 文件结构

```
rvc_flutter/
├── lib/
│   ├── rvc_flutter.dart                        # barrel 文件
│   └── src/
│       ├── models/
│       │   └── rvc_task.dart                    # RvcTaskStatus + RvcTaskSnapshot
│       ├── controllers/
│       │   └── rvc_task_controller.dart         # RvcTaskController
│       └── rvc_page.dart                        # RvcPage 主页面
├── pubspec.yaml
└── README.md
```
