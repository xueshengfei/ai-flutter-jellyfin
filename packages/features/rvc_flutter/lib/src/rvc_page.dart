import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:rvc_sdk/rvc_sdk.dart';

import 'controllers/rvc_task_controller.dart';
import 'models/rvc_task.dart';

/// RVC 语音转换页面
///
/// 接收 [RvcTaskController]，不持有任务生命周期。
/// 页面退出后 controller 仍在 App 内存中，下次进入可恢复上次任务状态。
class RvcPage extends StatefulWidget {
  final RvcTaskController controller;

  /// 预设的音频本地路径（同机场景，RVC 服务端直接读取）
  final String? audioPath;

  const RvcPage({
    super.key,
    required this.controller,
    this.audioPath,
  });

  @override
  State<RvcPage> createState() => _RvcPageState();
}

class _RvcPageState extends State<RvcPage> {
  RvcTaskController get controller => widget.controller;

  // ---- 页面级临时 UI 状态（不放在 controller 里） ----
  String? _selectedModel;
  String? _selectedFilePath;
  String? _selectedFileName;
  Uint8List? _selectedAudioBytes;
  String _convertMode = 'convert';

  // ---- 转换参数 ----
  int _f0UpKey = 0;
  F0Method _f0Method = F0Method.rmvpe;
  double _indexRate = 0.75;
  int _filterRadius = 3;
  double _protect = 0.33;
  int _resampleSr = 0;
  double _vocalVol = 1.0;
  double _instVol = 0.8;

  @override
  void initState() {
    super.initState();
    // 处理透传的音频路径
    if (widget.audioPath != null) {
      _selectedFilePath = widget.audioPath;
      _selectedFileName =
          widget.audioPath!.split(Platform.pathSeparator).last;
    }
    // 首次连接（controller 未连接时）
    if (!controller.isConnected && !controller.isConnecting) {
      controller.connect();
    }
  }

  // =========================================================================
  // 转换调度
  // =========================================================================

  void _startConvert() {
    if (_selectedModel == null) return;
    if (_selectedFilePath == null && _selectedAudioBytes == null) return;

    if (_convertMode == 'cover') {
      controller.startCover(
        modelName: _selectedModel!,
        inputPath: _selectedFilePath,
        audioBytes: _selectedAudioBytes,
        audioFilename: _selectedFileName ?? 'audio.wav',
        f0UpKey: _f0UpKey,
        f0Method: _f0Method,
        indexRate: _indexRate,
        filterRadius: _filterRadius,
        resampleSr: _resampleSr,
        protect: _protect,
        vocalVol: _vocalVol,
        instVol: _instVol,
      );
    } else {
      controller.startConvert(
        modelName: _selectedModel!,
        inputPath: _selectedFilePath,
        audioBytes: _selectedAudioBytes,
        audioFilename: _selectedFileName ?? 'audio.wav',
        f0UpKey: _f0UpKey,
        f0Method: _f0Method,
        indexRate: _indexRate,
        filterRadius: _filterRadius,
        resampleSr: _resampleSr,
        protect: _protect,
      );
    }
  }

  // =========================================================================
  // 构建
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RVC 语音转换'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '服务器设置',
            onPressed: _showServerUrlDialog,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // 正在连接
    if (controller.isConnecting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在连接 RVC 服务...'),
          ],
        ),
      );
    }

    // 连接失败
    if (controller.connectionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('连接失败', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                controller.connectionError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => controller.connect(),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 已连接
    // 自动选中第一个模型
    if (_selectedModel == null && controller.models.isNotEmpty) {
      _selectedModel = controller.models.first.name;
    }

    return RefreshIndicator(
      onRefresh: () => controller.connect(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(theme),
          const SizedBox(height: 16),
          _buildModelSelector(theme),
          const SizedBox(height: 16),
          _buildAudioInputSection(theme),
          const SizedBox(height: 16),
          _buildParamsSection(theme),
          const SizedBox(height: 24),
          _buildConvertButton(theme),
          if (controller.currentTask != null)
            const SizedBox(height: 16),
          _buildResultSection(theme),
        ],
      ),
    );
  }

  // ---- 服务状态卡片 ----
  Widget _buildStatusCard(ThemeData theme) {
    final status = controller.status!;
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${status.service} v${status.version}',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('状态: ${status.status}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text('${controller.models.length} 个模型',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ---- 模型选择 ----
  Widget _buildModelSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择模型', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedModel,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '请选择模型',
                prefixIcon: Icon(Icons.record_voice_over),
              ),
              items: controller.models.map((model) {
                return DropdownMenuItem(
                  value: model.name,
                  child: Text(model.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedModel = value),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 音频输入区 ----
  Widget _buildAudioInputSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('音频输入', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            if (_selectedFileName == null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickAudioFile,
                  icon: const Icon(Icons.audio_file),
                  label: const Text('选择音频文件'),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedFilePath != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_open,
                              size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_selectedFilePath!,
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.audiotrack,
                            size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_selectedFileName!,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('移除'),
                      onPressed: () => setState(() {
                        _selectedFilePath = null;
                        _selectedFileName = null;
                        _selectedAudioBytes = null;
                      }),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ---- 参数区 ----
  Widget _buildParamsSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('转换参数', style: theme.textTheme.titleSmall),
            const SizedBox(height: 16),
            Row(children: [
              const SizedBox(width: 100, child: Text('音高偏移')),
              Expanded(
                child: Slider(
                  value: _f0UpKey.toDouble(),
                  min: -24, max: 24, divisions: 48,
                  label: '$_f0UpKey',
                  onChanged: (v) => setState(() => _f0UpKey = v.toInt()),
                ),
              ),
              SizedBox(width: 48, child: Text('$_f0UpKey', textAlign: TextAlign.end, style: theme.textTheme.bodySmall)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const SizedBox(width: 100, child: Text('F0 算法')),
              Expanded(
                child: SegmentedButton<F0Method>(
                  segments: const [
                    ButtonSegment(value: F0Method.rmvpe, label: Text('rmvpe')),
                    ButtonSegment(value: F0Method.pm, label: Text('pm')),
                    ButtonSegment(value: F0Method.harvest, label: Text('harvest')),
                  ],
                  selected: {_f0Method},
                  onSelectionChanged: (v) => setState(() => _f0Method = v.first),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const SizedBox(width: 100, child: Text('检索比率')),
              Expanded(
                child: Slider(
                  value: _indexRate, min: 0, max: 1, divisions: 20,
                  label: _indexRate.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _indexRate = v),
                ),
              ),
              SizedBox(width: 48, child: Text(_indexRate.toStringAsFixed(2), textAlign: TextAlign.end, style: theme.textTheme.bodySmall)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const SizedBox(width: 100, child: Text('辅音保护')),
              Expanded(
                child: Slider(
                  value: _protect, min: 0, max: 0.5, divisions: 50,
                  label: _protect.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _protect = v),
                ),
              ),
              SizedBox(width: 48, child: Text(_protect.toStringAsFixed(2), textAlign: TextAlign.end, style: theme.textTheme.bodySmall)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const SizedBox(width: 100, child: Text('输出采样率')),
              Expanded(
                child: Slider(
                  value: _resampleSr.toDouble(), min: 0, max: 48000, divisions: 8,
                  label: _resampleSr == 0 ? '原始' : '$_resampleSr',
                  onChanged: (v) => setState(() => _resampleSr = v.toInt()),
                ),
              ),
              SizedBox(width: 64, child: Text(_resampleSr == 0 ? '原始' : '$_resampleSr Hz', textAlign: TextAlign.end, style: theme.textTheme.bodySmall)),
            ]),
          ],
        ),
      ),
    );
  }

  // ---- 转换按钮 ----
  Widget _buildConvertButton(ThemeData theme) {
    final task = controller.currentTask;
    final isRunning = task?.status == RvcTaskStatus.running;

    final canConvert =
        _selectedModel != null &&
        (_selectedFilePath != null || _selectedAudioBytes != null) &&
        !isRunning;

    return Column(
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'convert', label: Text('音色转换'), icon: Icon(Icons.auto_fix_high)),
            ButtonSegment(value: 'cover', label: Text('一键翻唱'), icon: Icon(Icons.music_note)),
          ],
          selected: {_convertMode},
          onSelectionChanged: (v) => setState(() {
            _convertMode = v.first;
            controller.clearTask();
          }),
        ),
        if (_convertMode == 'cover') ...[
          const SizedBox(height: 12),
          _buildCoverParams(theme),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: canConvert ? _startConvert : null,
          icon: isRunning
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
              : Icon(_convertMode == 'cover' ? Icons.music_note : Icons.auto_fix_high),
          label: Text(isRunning
              ? (_convertMode == 'cover' ? '正在翻唱...' : '正在转换...')
              : (_convertMode == 'cover' ? '一键翻唱' : '开始转换')),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }

  Widget _buildCoverParams(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            const SizedBox(width: 80, child: Text('人声音量')),
            Expanded(child: Slider(value: _vocalVol, min: 0, max: 2, divisions: 20, label: _vocalVol.toStringAsFixed(1), onChanged: (v) => setState(() => _vocalVol = v))),
            SizedBox(width: 40, child: Text(_vocalVol.toStringAsFixed(1), textAlign: TextAlign.end)),
          ]),
          Row(children: [
            const SizedBox(width: 80, child: Text('伴奏音量')),
            Expanded(child: Slider(value: _instVol, min: 0, max: 2, divisions: 20, label: _instVol.toStringAsFixed(1), onChanged: (v) => setState(() => _instVol = v))),
            SizedBox(width: 40, child: Text(_instVol.toStringAsFixed(1), textAlign: TextAlign.end)),
          ]),
        ]),
      ),
    );
  }

  // ---- 结果区 ----
  Widget _buildResultSection(ThemeData theme) {
    final task = controller.currentTask;
    if (task == null) return const SizedBox.shrink();

    // 转换中
    if (task.status == RvcTaskStatus.running) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(width: 16),
              Text('正在${task.mode == 'cover' ? '翻唱' : '转换'}音频，请稍候...',
                  style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    // 转换失败
    if (task.status == RvcTaskStatus.failed) {
      return Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Text('转换失败', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onErrorContainer)),
              ]),
              const SizedBox(height: 8),
              Text(task.errorMessage ?? '未知错误',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer)),
            ],
          ),
        ),
      );
    }

    // 转换成功
    if (task.status == RvcTaskStatus.succeeded && task.result != null) {
      final result = task.result!;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('转换完成', style: theme.textTheme.titleSmall),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16, runSpacing: 4,
                children: [
                  _infoChip('采样率', '${result.sampleRate} Hz'),
                  _infoChip('时长', '${result.durationSec.toStringAsFixed(1)}s'),
                  _infoChip('大小', '${(result.fileSize / 1024).toStringAsFixed(1)} KB'),
                ],
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => controller.togglePlayback(),
                    icon: Icon(controller.isPlaying ? Icons.stop : Icons.play_arrow),
                    label: Text(controller.isPlaying ? '停止播放' : '播放结果'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('下载链接: ${result.filename}')),
                      );
                    },
                    icon: const Icon(Icons.save_alt),
                    label: const Text('保存文件'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _infoChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value),
      ],
    );
  }

  // =========================================================================
  // 文件选择
  // =========================================================================

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      setState(() {
        _selectedFileName = file.name;
        _selectedAudioBytes = file.bytes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  // =========================================================================
  // 服务器地址对话框
  // =========================================================================

  Future<void> _showServerUrlDialog() async {
    final textController = TextEditingController(text: controller.serverUrl);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('服务器设置'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: '服务器地址',
            hintText: 'http://192.168.1.100:9880',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.dns),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    textController.dispose();

    if (result == null || result == controller.serverUrl || result.isEmpty) return;
    controller.updateServerUrl(result);
  }
}
