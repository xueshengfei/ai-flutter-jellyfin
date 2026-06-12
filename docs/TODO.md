# 待办任务

## P4 模型层清理
- 6 个模型类字段大量重复（id/name/serverUrl/accessToken/primaryImageTag 等）
- Jellyfin 官方用单一大类 `BaseItemDto` + type 枚举区分
- 两条路线：A 跟官方用一个大类 / B 保持拆分抽公共基类
- 详见 [模型重构笔记](../model-refactoring-notes.md)

## P5 jellyfin_ui_kit 图片层拆分
- **触发条件**：当 `packages/shared/jellyfin_ui_kit/lib/src/image/` 目录膨胀到 7-8 个文件
- **当前状态**：4 个文件，URL 构建协议（`buildImageUrl`/`authHeaders`）和 UI 组件（`JellyfinImage`/`JellyfinImageProviderScope`）混在同一目录
- **目标**：将 URL 构建协议与认证逻辑拆到独立的协议/服务目录，UI 组件保留在 image 目录
- **背景**：`JellyfinImageProvider` 同时承担 URL 拼接规则、认证 header、降级加载三种职责，后续加图片缓存策略、多分辨率适配、预加载等会更混乱

## Personal 模块三期
- DTO 映射抽取
- Gateway 层 `BaseItemDto → jellyfin_models` 转换逻辑集中化

## 已完成

### 视频播放 MVVM 改造（提交 7781a5f）
- `VideoPlayerViewModel`(ChangeNotifier) 持有全部状态 + 业务逻辑
- `VideoPlayerPage` 纯 View，用 `ListenableBuilder` 监听 ViewModel
- Model 层不变：`PlaybackInfo` + `PlaybackDelegate` + `NetworkQualityMonitor` + `AutoQualityDecider`
