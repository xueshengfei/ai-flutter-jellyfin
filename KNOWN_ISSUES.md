# 已知问题 & 待解决困难

## EPUB 阅读器性能问题

**文件**: `lib/src/ui/pages/epub_reader_page.dart`
**状态**: 已做优化但仍有问题
**日期**: 2026-04-10

### 现象
点击"阅读"按钮后，加载页面卡住或体验不佳。

### 已尝试的优化
1. ~~`Isolate.run()` 离线解析~~ → ohos/web 平台不支持 isolate，报 `Unsupported operation: dart:isolate is not supported on dart4web`
2. 改为 try-catch 回退主线程解析
3. 下载进度节流（200ms 间隔）
4. 章节懒加载（只提取目录，HTML→纯文本按需转换）
5. 邻居章节预读（当前 ±2 章同步预计算）

### 仍存在的问题
- **EPUB 下载本身耗时**：Jellyfin 返回整个 EPUB 文件（ZIP），无法按章节下载，大文件（>10MB）下载慢
- **ohos 平台无 Isolate**：`dart:isolate` 不可用，解析和文本转换都在主线程，大书仍会卡顿
- **单章 HTML 可能很大**：部分书整本书就一个 HTML 文件，懒加载无法拆分

### 可能的后续方案
- [ ] 用 `archive` 包手动解析 EPUB ZIP，只解压当前章节的 HTML（跳过图片、CSS、字体等），减少解析量
- [ ] 将 EPUB 文件缓存到本地，二次打开免下载
- [ ] 大章节按段落分页，避免一次性渲染超长文本
- [ ] 调研 ohos 平台的并发方案（Worker？）
