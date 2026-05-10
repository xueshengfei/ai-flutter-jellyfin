# RVC 语音转换模块 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在音乐页面添加 RVC 语音转换入口，作为独立 package `rvc_flutter` 实现 UI 层，复用已有的 `rvc_sdk` 做推理通信。

**Architecture:** 新建 `packages/rvc_flutter` 独立 Flutter package，包含 RVC 页面 UI 和业务逻辑。依赖 `rvc_sdk`（HTTP API 客户端）。在音乐库页面的 AppBar 添加一个按钮，点击后 `Navigator.push` 跳转到 RVC 页面。主项目 `jellyfin_service` 通过 path 依赖引入 `rvc_flutter`。

**Tech Stack:** Flutter/Dart, `rvc_sdk`（已有）, `just_audio`（播放转换结果）, `file_picker`（选择音频文件）, `http` package

---

## 前置依赖

- RVC 服务端已本地部署（端口 9880）
- `packages/rvc_sdk/` 已存在且可用
- 音乐页面 `MusicLibraryPage` 已实现

---

### Task 1: 创建 `rvc_flutter` package 骨架

**Files:**
- Create: `packages/rvc_flutter/pubspec.yaml`
- Create: `packages/rvc_flutter/lib/rvc_flutter.dart`
- Create: `packages/rvc_flutter/lib/src/rvc_page.dart`

**Step 1: 创建 pubspec.yaml**

```yaml
name: rvc_flutter
description: RVC 语音转换 Flutter UI 模块
version: 0.1.0
publish_to: 'none'

environment:
  sdk: '>=3.2.0 <4.0.0'
  flutter: ">=3.22.0"

dependencies:
  flutter:
    sdk: flutter
  rvc_sdk:
    path: ../rvc_sdk
  just_audio: ^0.9.42
  file_picker: ^8.0.0
  path_provider: ^2.1.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

**Step 2: 创建主导出文件 `lib/rvc_flutter.dart`**

```dart
/// RVC 语音转换 Flutter UI 模块
library;

export 'src/rvc_page.dart';
```

**Step 3: 创建页面骨架 `lib/src/rvc_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:rvc_sdk/rvc_sdk.dart';

/// RVC 语音转换页面
///
/// 功能：
/// 1. 选择/上传音频文件
/// 2. 选择 RVC 模型
/// 3. 调整转换参数（音高、算法等）
/// 4. 执行转换并播放结果
class RvcPage extends StatefulWidget {
  /// RVC 服务地址，如 http://192.168.1.100:9880
  final String rvcServerUrl;

  const RvcPage({super.key, required this.rvcServerUrl});

  @override
  State<RvcPage> createState() => _RvcPageState();
}

class _RvcPageState extends State<RvcPage> {
  late RVCClient _client;

  // 服务状态
  ServiceStatus? _status;
  List<ModelInfo> _models = [];
  bool _isConnecting = false;

  // 选中的模型
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    _client = RVCClient(baseUrl: widget.rvcServerUrl);
    _checkService();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _checkService() async {
    setState(() => _isConnecting = true);
    try {
      final status = await _client.getStatus();
      final models = await _client.listModels();
      if (mounted) {
        setState(() {
          _status = status;
          _models = models;
          _selectedModel = models.isNotEmpty ? models.first.name : null;
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接 RVC 服务失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RVC 语音转换')),
      body: _isConnecting
          ? const Center(child: CircularProgressIndicator())
          : _status == null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('无法连接 RVC 服务', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(widget.rvcServerUrl, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _checkService,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 服务状态
          _buildStatusCard(),
          const SizedBox(height: 16),
          // 模型选择
          _buildModelSelector(),
          const SizedBox(height: 16),
          // 音频输入
          _buildAudioInput(),
          const SizedBox(height: 16),
          // 参数调整
          _buildParams(),
          const SizedBox(height: 24),
          // 转换按钮
          _buildConvertButton(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_status!.service} ${_status!.version}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(_status!.status, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    if (_models.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('暂无可用模型'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择模型', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedModel,
              isExpanded: true,
              items: _models.map((m) => DropdownMenuItem(
                value: m.name,
                child: Text('${m.name} (${m.sizeMb.toStringAsFixed(1)} MB)'),
              )).toList(),
              onChanged: (v) => setState(() => _selectedModel = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('音频输入', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            // 占位 - Task 2 实现
            const Text('待实现'),
          ],
        ),
      ),
    );
  }

  Widget _buildParams() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('转换参数', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            // 占位 - Task 3 实现
            const Text('待实现'),
          ],
        ),
      ),
    );
  }

  Widget _buildConvertButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: null, // Task 4 实现
        icon: const Icon(Icons.auto_fix_high),
        label: const Text('开始转换'),
      ),
    );
  }
}
```

**Step 4: Commit**

```bash
git add packages/rvc_flutter/
git commit -m "feat(rvc_flutter): 创建 RVC Flutter package 骨架"
```

---

### Task 2: 主项目引入 rvc_flutter 依赖

**Files:**
- Modify: `pubspec.yaml`（主项目）
- Modify: `lib/jellyfin_service.dart`

**Step 1: 在主项目 pubspec.yaml 添加依赖**

在 `dependencies` 中添加：

```yaml
  # RVC 语音转换
  rvc_flutter:
    path: packages/rvc_flutter
```

**Step 2: 在 jellyfin_service.dart 添加导出**

在 UI 页面导出区域末尾添加：

```dart
// RVC 语音转换
export 'package:rvc_flutter/rvc_flutter.dart';
```

**Step 3: 验证依赖解析**

Run: `cd D:/claudeProject/flutter_video_project/ai-video-project/Jellyfin_Service && flutter pub get`
Expected: 成功解析所有依赖

**Step 4: Commit**

```bash
git add pubspec.yaml lib/jellyfin_service.dart pubspec.lock
git commit -m "feat: 主项目引入 rvc_flutter 依赖"
```

---

### Task 3: 音乐页面添加 RVC 入口按钮

**Files:**
- Modify: `lib/src/ui/pages/music_library_page.dart:65-79`（AppBar actions 区域）

**Step 1: 在音乐页面 AppBar 添加 RVC 按钮**

在 `actions` 列表中，搜索按钮之后添加 RVC 按钮：

```dart
        actions: [
          ViewModeSelector(
            libraryId: widget.libraryId,
            onViewModeChanged: _saveViewModeConfig,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MusicSearchPage(
                client: widget.client,
                libraryId: widget.libraryId,
              ),
            )),
          ),
          // RVC 语音转换入口
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'RVC 语音转换',
            onPressed: () {
              // RVC 服务地址：与 Jellyfin 同 IP，端口 9880
              final jellyfinUrl = widget.client.configuration.serverUrl;
              final uri = Uri.parse(jellyfinUrl);
              final rvcUrl = '${uri.scheme}://${uri.host}:9880';
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => RvcPage(rvcServerUrl: rvcUrl),
              ));
            },
          ),
        ],
```

注意：`RvcPage` 由 `rvc_flutter` package 导出，已通过 `jellyfin_service.dart` 的 `export 'package:rvc_flutter/rvc_flutter.dart'` 引入。由于 `music_library_page.dart` 已经 `import 'package:jellyfin_service/jellyfin_service.dart'`，所以 `RvcPage` 可直接使用。

**Step 2: 验证编译**

Run: `cd D:/claudeProject/flutter_video_project/ai-video-project/Jellyfin_Service && flutter analyze`
Expected: 无错误

**Step 3: Commit**

```bash
git add lib/src/ui/pages/music_library_page.dart
git commit -m "feat(music): 音乐页面添加 RVC 语音转换入口按钮"
```

---

### Task 4: 完善 RVC 页面 - 音频输入区域

**Files:**
- Modify: `packages/rvc_flutter/lib/src/rvc_page.dart`

**Step 1: 添加文件选择和录音功能**

在 `_RvcPageState` 中添加状态变量和方法：

```dart
import 'package:file_picker/file_picker.dart';
import 'dart:io';

// 状态变量
String? _selectedFilePath;
String? _selectedFileName;
Uint8List? _selectedAudioBytes;

Future<void> _pickAudioFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.audio,
    allowMultiple: false,
  );
  if (result != null && result.files.single.path != null) {
    final file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();
    setState(() {
      _selectedFilePath = result.files.single.path;
      _selectedFileName = result.files.single.name;
      _selectedAudioBytes = bytes;
    });
  }
}

void _clearAudioFile() {
  setState(() {
    _selectedFilePath = null;
    _selectedFileName = null;
    _selectedAudioBytes = null;
  });
}
```

替换 `_buildAudioInput()` 的占位实现：

```dart
Widget _buildAudioInput() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('音频输入', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_selectedFileName != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.audio_file, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selectedFileName!, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _clearAudioFile,
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickAudioFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('选择音频文件'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
```

**Step 2: Commit**

```bash
git add packages/rvc_flutter/lib/src/rvc_page.dart
git commit -m "feat(rvc_flutter): 实现音频文件选择功能"
```

---

### Task 5: 完善 RVC 页面 - 转换参数调整

**Files:**
- Modify: `packages/rvc_flutter/lib/src/rvc_page.dart`

**Step 1: 添加参数状态变量**

```dart
int _f0UpKey = 0;
F0Method _f0Method = F0Method.rmvpe;
double _indexRate = 0.75;
int _filterRadius = 3;
double _protect = 0.33;
```

**Step 2: 替换 `_buildParams()` 的占位实现**

```dart
Widget _buildParams() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('转换参数', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),

          // 音高偏移
          Row(
            children: [
              const Expanded(flex: 2, child: Text('音高偏移')),
              Expanded(
                flex: 3,
                child: Slider(
                  value: _f0UpKey.toDouble(),
                  min: -24,
                  max: 24,
                  divisions: 48,
                  label: '$_f0UpKey',
                  onChanged: (v) => setState(() => _f0UpKey = v.toInt()),
                ),
              ),
              SizedBox(width: 48, child: Text('$_f0UpKey 半音', style: const TextStyle(fontSize: 12))),
            ],
          ),

          // F0 算法
          Row(
            children: [
              const Expanded(flex: 2, child: Text('F0 算法')),
              Expanded(
                flex: 3,
                child: SegmentedButton<F0Method>(
                  segments: const [
                    ButtonSegment(value: F0Method.rmvpe, label: Text('rmvpe')),
                    ButtonSegment(value: F0Method.pm, label: Text('pm')),
                    ButtonSegment(value: F0Method.harvest, label: Text('harvest')),
                  ],
                  selected: {_f0Method},
                  onSelectionChanged: (s) => setState(() => _f0Method = s.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 特征检索比率
          Row(
            children: [
              const Expanded(flex: 2, child: Text('检索比率')),
              Expanded(
                flex: 3,
                child: Slider(
                  value: _indexRate,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: _indexRate.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _indexRate = v),
                ),
              ),
              SizedBox(width: 48, child: Text(_indexRate.toStringAsFixed(2), style: const TextStyle(fontSize: 12))),
            ],
          ),

          // 辅音保护
          Row(
            children: [
              const Expanded(flex: 2, child: Text('辅音保护')),
              Expanded(
                flex: 3,
                child: Slider(
                  value: _protect,
                  min: 0,
                  max: 0.5,
                  divisions: 10,
                  label: _protect.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _protect = v),
                ),
              ),
              SizedBox(width: 48, child: Text(_protect.toStringAsFixed(2), style: const TextStyle(fontSize: 12))),
            ],
          ),
        ],
      ),
    ),
  );
}
```

**Step 2: Commit**

```bash
git add packages/rvc_flutter/lib/src/rvc_page.dart
git commit -m "feat(rvc_flutter): 实现转换参数调整 UI"
```

---

### Task 6: 完善 RVC 页面 - 转换执行与结果播放

**Files:**
- Modify: `packages/rvc_flutter/lib/src/rvc_page.dart`

**Step 1: 添加转换和播放状态/逻辑**

```dart
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// 状态
bool _isConverting = false;
double _convertProgress = 0;
ConvertResult? _convertResult;
String? _errorMessage;

// 音频播放器
final AudioPlayer _audioPlayer = AudioPlayer();
bool _isPlaying = false;

@override
void dispose() {
  _client.close();
  _audioPlayer.dispose();
  super.dispose();
}

Future<void> _startConvert() async {
  if (_selectedModel == null || (_selectedFilePath == null && _selectedAudioBytes == null)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请选择模型和音频文件')),
    );
    return;
  }

  setState(() {
    _isConverting = true;
    _convertResult = null;
    _errorMessage = null;
    _convertProgress = 0;
  });

  try {
    final result = await _client.convert(
      modelName: _selectedModel!,
      inputPath: _selectedFilePath,
      audioBytes: _selectedAudioBytes,
      f0UpKey: _f0UpKey,
      f0Method: _f0Method,
      indexRate: _indexRate,
      filterRadius: _filterRadius,
      protect: _protect,
    );

    if (mounted) {
      setState(() {
        _convertResult = result;
        _isConverting = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _errorMessage = '$e';
        _isConverting = false;
      });
    }
  }
}

Future<void> _playResult() async {
  if (_convertResult == null) return;
  try {
    // 写入临时文件
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/rvc_output_${DateTime.now().millisecondsSinceEpoch}.wav');
    await tempFile.writeAsBytes(_convertResult!.audioBytes);

    await _audioPlayer.setFilePath(tempFile.path);
    await _audioPlayer.play();
    setState(() => _isPlaying = true);

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _isPlaying = false);
      }
    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败: $e')),
      );
    }
  }
}

void _stopPlayback() {
  _audioPlayer.stop();
  setState(() => _isPlaying = false);
}

Future<void> _saveResult() async {
  if (_convertResult == null) return;
  // 使用 file_picker 的 saveFile 或直接保存到下载目录
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/rvc_output_${DateTime.now().millisecondsSinceEpoch}.wav');
    await file.writeAsBytes(_convertResult!.audioBytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存到: ${file.path}')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }
}
```

**Step 2: 更新 `_buildConvertButton()` 并添加结果区域**

```dart
Widget _buildConvertButton() {
  final canConvert = _selectedModel != null &&
      (_selectedFilePath != null || _selectedAudioBytes != null) &&
      !_isConverting;

  return SizedBox(
    width: double.infinity,
    height: 48,
    child: FilledButton.icon(
      onPressed: canConvert ? _startConvert : null,
      icon: _isConverting
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.auto_fix_high),
      label: Text(_isConverting ? '转换中...' : '开始转换'),
    ),
  );
}

Widget _buildResultArea() {
  if (_isConverting) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在转换，请耐心等待...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  if (_errorMessage != null) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))),
          ],
        ),
      ),
    );
  }

  if (_convertResult != null) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('转换完成', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.green[700])),
            const SizedBox(height: 4),
            Text('采样率: ${_convertResult!.sampleRate} Hz | 耗时: ${_convertResult!.durationSec.toStringAsFixed(1)}s'),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isPlaying ? _stopPlayback : _playResult,
                  icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                  label: Text(_isPlaying ? '停止' : '播放'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saveResult,
                  icon: const Icon(Icons.save),
                  label: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  return const SizedBox.shrink();
}
```

**Step 3: 在 `_buildContent()` 的 Column 中添加结果区域**

在 `_buildConvertButton()` 之后添加：

```dart
          // 转换结果
          if (_isConverting || _convertResult != null || _errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildResultArea(),
          ],
```

**Step 4: Commit**

```bash
git add packages/rvc_flutter/lib/src/rvc_page.dart
git commit -m "feat(rvc_flutter): 实现音频转换与结果播放"
```

---

### Task 7: 添加 RVC 服务地址设置弹窗

**Files:**
- Modify: `packages/rvc_flutter/lib/src/rvc_page.dart`

**Step 1: 在 AppBar 添加设置按钮和弹窗方法**

在 `build()` 的 `appBar` 中添加 actions：

```dart
      appBar: AppBar(
        title: const Text('RVC 语音转换'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'RVC 服务地址',
            onPressed: _showServerUrlDialog,
          ),
        ],
      ),
```

添加弹窗方法（复用状态变量 `_rvcServerUrl`）：

```dart
  String _rvcServerUrl = '';

  // initState 中：
  _rvcServerUrl = widget.rvcServerUrl;

  void _showServerUrlDialog() {
    final controller = TextEditingController(text: _rvcServerUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.language),
        title: const Text('RVC 服务地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'IP:端口',
                hintText: 'http://192.168.1.100:9880',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                setState(() => _rvcServerUrl = url);
                _client.close();
                _client = RVCClient(baseUrl: url);
                _checkService();
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
```

**Step 2: Commit**

```bash
git add packages/rvc_flutter/lib/src/rvc_page.dart
git commit -m "feat(rvc_flutter): 添加 RVC 服务地址设置弹窗"
```

---

### Task 8: 端到端验证

**Step 1: 静态分析**

Run: `cd D:/claudeProject/flutter_video_project/ai-video-project/Jellyfin_Service && flutter analyze`
Expected: 无错误

**Step 2: 运行示例应用**

Run: `cd D:/claudeProject/flutter_video_project/ai-video-project/Jellyfin_Service/example && flutter run -d windows`
Expected:
- 登录后进入媒体库首页
- 进入音乐库页面
- AppBar 右侧可见 RVC 按钮（auto_fix_high 图标）
- 点击可进入 RVC 页面
- RVC 页面显示服务状态、模型列表

**Step 3: 修复编译问题（如有）**

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(rvc_flutter): RVC 语音转换模块完成"
```

---

## 文件变更汇总

| 操作 | 文件 |
|------|------|
| Create | `packages/rvc_flutter/pubspec.yaml` |
| Create | `packages/rvc_flutter/lib/rvc_flutter.dart` |
| Create | `packages/rvc_flutter/lib/src/rvc_page.dart` |
| Modify | `pubspec.yaml` |
| Modify | `lib/jellyfin_service.dart` |
| Modify | `lib/src/ui/pages/music_library_page.dart` |

## 注意事项

1. **RVC 地址推断**：从 Jellyfin 服务地址提取 IP，端口固定 9880。用户可在 RVC 页面设置弹窗中修改。
2. **不修改 rvc_sdk**：`rvc_flutter` 只是 UI 层，底层 HTTP 通信完全复用已有的 `rvc_sdk`。
3. **鸿蒙兼容**：`file_picker` 和 `just_audio` 在鸿蒙上可能需要适配，但当前先确保 Android/Windows 可用。
4. **超时处理**：RVC 转换可能耗时较长（几十秒到几分钟），`rvc_sdk` 默认 5 分钟超时已覆盖。
