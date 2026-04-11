---
name: flutter-ohos-expert
description: Flutter适配鸿蒙(OpenHarmony/HarmonyOS)平台专家。指导Flutter项目的ohos平台适配全流程、三方库鸿蒙化、Plugin开发、PlatformView开发、混合开发集成、环境搭建与常用命令。当用户提到Flutter适配鸿蒙、ohos平台适配、flutter create --platforms ohos、Plugin鸿蒙适配、MethodChannel鸿蒙、flutter build hap、Platform.isOhos等关键词时触发。
---

# Flutter 适配鸿蒙(OpenHarmony)平台专家

当用户涉及以下场景时使用本 Skill：
- Flutter 适配鸿蒙 / ohos 平台适配
- `flutter create --platforms ohos`、`flutter build hap/har`
- 三方库鸿蒙化适配
- Flutter Plugin / PlatformView 鸿端开发
- 已有 Flutter 项目迁移到 ohos
- OpenHarmony 应用集成 Flutter 混合开发
- `Platform.isOhos`、`FlutterAbility`、`FlutterEntry` 等相关代码

## 知识体系

本 Skill 包含以下章节，按需查阅：

| 文件 | 主题 | 关键内容 |
|------|------|----------|
| [01-environment-setup.md](01-environment-setup.md) | 环境搭建 | DevEco Studio、JDK 17、Flutter OH SDK、环境变量、常见问题 |
| [02-core-commands.md](02-core-commands.md) | 核心命令 | 创建项目、构建 HAP/HAR、运行调试、签名配置 |
| [03-library-ohos-check.md](03-library-ohos-check.md) | 判断是否需鸿蒙化 | pubspec.yaml 识别、目录结构识别、纯Dart平台判断 |
| [04-library-adaptation.md](04-library-adaptation.md) | 三方库适配全流程 | 创建ohos模块、编写Dart接口、ETS原生代码、打HAR包（含完整代码示例） |
| [05-plugin-development.md](05-plugin-development.md) | Plugin 开发 | MethodChannel/EventChannel/BasicMessageChannel 通信、PlatformView、FFI Plugin（含完整代码示例） |
| [06-project-migration.md](06-project-migration.md) | 已有项目适配 ohos | 添加ohos平台、依赖替换、构建运行 |
| [07-hybrid-development.md](07-hybrid-development.md) | 混合开发 | Flutter Module、HAR集成、FlutterEntry/FlutterPage（含完整代码示例） |
| [08-project-structure.md](08-project-structure.md) | 工程结构与关键文件 | ohos目录规范、build-profile.json5、可删除的过时文件 |
| [09-faq.md](09-faq.md) | 常见问题 | 环境问题、构建失败、签名问题、模拟器限制 |

## 参考资源

- Flutter OH SDK: https://gitcode.com/openharmony-tpc/flutter_flutter
- OH 适配三方库: https://gitcode.com/openharmony-tpc/
- 示例项目: https://gitcode.com/openharmony-tpc/flutter_samples
- 项目内完整文档: `ohos/docs/` 目录
