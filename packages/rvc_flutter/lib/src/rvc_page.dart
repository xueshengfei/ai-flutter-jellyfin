import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rvc_sdk/rvc_sdk.dart';

/// RVC 语音转换页面
///
/// 提供完整的服务连接、模型选择、音频转换 UI。
///
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const RvcPage(rvcServerUrl: 'http://192.168.1.100:9880')),
/// );
/// ```
class RvcPage extends StatefulWidget {
  /// RVC 服务地址，如 `http://192.168.1.100:9880`
  final String rvcServerUrl;

  /// 预设的音频本地路径（同机场景，RVC 服务端直接读取）
  final String? audioPath;

  const RvcPage({
    super.key,
    required this.rvcServerUrl,
    this.audioPath,
  });

  @override
  State<RvcPage> createState() => _RvcPageState();
}

class _RvcPageState extends State<RvcPage> {
  late RVCClient _client;

  // ---- 服务状态 ----
  ServiceStatus? _status;
  List<ModelInfo> _models = [];
  bool _isConnecting = false;
  String? _selectedModel;

  // ---- 错误 ----
  String? _errorMessage;

  // ---- 音频文件 ----
  String? _selectedFilePath;  // 本地路径（同机场景，RVC 服务端直接读取）
  String? _selectedFileName;
  Uint8List? _selectedAudioBytes;

  // ---- 转换参数 ----
  int _f0UpKey = 0;
  F0Method _f0Method = F0Method.rmvpe;
  double _indexRate = 0.75;
  int _filterRadius = 3;
  double _protect = 0.33;
  int _resampleSr = 0; // 0 = 不重采样，保留原始采样率

  // ---- 转换状态 ----
  bool _isConverting = false;
  dynamic _convertResult; // ConvertResult 或 CoverResult
  String? _convertError;
  String _convertMode = 'convert'; // 'convert' 或 'cover'

  // 翻唱参数
  double _vocalVol = 1.0;
  double _instVol = 0.8;

  // ---- 播放 ----
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  // ---- 服务地址（可修改） ----
  late String _rvcServerUrl;

  @override
  void initState() {
    super.initState();
    _rvcServerUrl = widget.rvcServerUrl;
    _client = RVCClient(baseUrl: _rvcServerUrl);

    // 处理透传的音频路径
    if (widget.audioPath != null) {
      _selectedFilePath = widget.audioPath;
      _selectedFileName = widget.audioPath!.split(Platform.pathSeparator).last;
    }

    _connect();

    // 监听播放状态
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _client.close();
    super.dispose();
  }

  // =========================================================================
  // 网络请求
  // =========================================================================

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _client.getStatus(),
        _client.listModels(),
      ]);

      if (!mounted) return;

      setState(() {
        _status = results[0] as ServiceStatus;
        _models = results[1] as List<ModelInfo>;
        _isConnecting = false;
        if (_models.isNotEmpty && _selectedModel == null) {
          _selectedModel = _models.first.name;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _errorMessage = e.toString();
      });
    }
  }

  // =========================================================================
  // 转换逻辑
  // =========================================================================

  Future<void> _doConvert() async {
    if (_selectedModel == null) return;
    if (_selectedFilePath == null && _selectedAudioBytes == null) return;

    setState(() {
      _isConverting = true;
      _convertResult = null;
      _convertError = null;
    });

    try {
      final dynamic result;
      if (_convertMode == 'cover') {
        result = await _client.cover(
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
        result = await _client.convert(
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

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _convertError = '转换失败';
          _isConverting = false;
        });
        return;
      }

      setState(() {
        _convertResult = result;
        _isConverting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _convertError = e.toString();
        _isConverting = false;
      });
    }
  }

  // =========================================================================
  // 播放与保存
  // =========================================================================

  Future<void> _togglePlayback() async {
    final result = _convertResult;
    if (result == null) return;

    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }

    try {
      // 用服务端返回的 play_url 直接播放
      final playUrl = _client.getPlayUrl(result);
      await _audioPlayer.setUrl(playUrl);
      await _audioPlayer.play();
      setState(() => _isPlaying = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }

  Future<void> _saveResult() async {
    final result = _convertResult;
    if (result == null) return;

    // 通过浏览器/系统打开下载链接
    final downloadUrl = _client.getDownloadUrl(result);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('下载链接: ${result.filename}'),
          action: SnackBarAction(
            label: '复制链接',
            onPressed: () {
              // 复制到剪贴板
              // ignore: avoid_print
              print(downloadUrl);
            },
          ),
        ),
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
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // 正在连接
    if (_isConnecting) {
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

    // 连接失败 -> 错误状态
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                '连接失败',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _connect,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 已连接 -> 主界面
    return RefreshIndicator(
      onRefresh: _connect,
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
          if (_isConverting || _convertResult != null || _convertError != null)
            const SizedBox(height: 16),
          _buildResultSection(theme),
        ],
      ),
    );
  }

  // ---- 服务状态卡片 ----
  Widget _buildStatusCard(ThemeData theme) {
    final status = _status!;
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
                  Text(
                    '${status.service} v${status.version}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '状态: ${status.status}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_models.length} 个模型',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
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
              items: _models.map((model) {
                return DropdownMenuItem(
                  value: model.name,
                  child: Text(
                    model.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedModel = value);
              },
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
              // 未选择文件 -> 显示选择按钮
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickAudioFile,
                  icon: const Icon(Icons.audio_file),
                  label: const Text('选择音频文件'),
                ),
              )
            else
              // 已选择文件 -> 显示路径/文件名 + 清除按钮
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedFilePath != null) ...[
                    // 本地路径模式（RVC 服务端直接读取）
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_open, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFilePath!,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // 字节上传模式
                    Row(
                      children: [
                        Icon(Icons.audiotrack, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedFileName!,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('移除'),
                      onPressed: () {
                        setState(() {
                          _selectedFilePath = null;
                          _selectedFileName = null;
                          _selectedAudioBytes = null;
                        });
                      },
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

            // 音高偏移
            Row(
              children: [
                const SizedBox(
                  width: 100,
                  child: Text('音高偏移'),
                ),
                Expanded(
                  child: Slider(
                    value: _f0UpKey.toDouble(),
                    min: -24,
                    max: 24,
                    divisions: 48,
                    label: '$_f0UpKey',
                    onChanged: (v) =>
                        setState(() => _f0UpKey = v.toInt()),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '$_f0UpKey',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // F0 算法
            Row(
              children: [
                const SizedBox(
                  width: 100,
                  child: Text('F0 算法'),
                ),
                Expanded(
                  child: SegmentedButton<F0Method>(
                    segments: const [
                      ButtonSegment(
                        value: F0Method.rmvpe,
                        label: Text('rmvpe'),
                      ),
                      ButtonSegment(
                        value: F0Method.pm,
                        label: Text('pm'),
                      ),
                      ButtonSegment(
                        value: F0Method.harvest,
                        label: Text('harvest'),
                      ),
                    ],
                    selected: {_f0Method},
                    onSelectionChanged: (v) =>
                        setState(() => _f0Method = v.first),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 检索比率
            Row(
              children: [
                const SizedBox(
                  width: 100,
                  child: Text('检索比率'),
                ),
                Expanded(
                  child: Slider(
                    value: _indexRate,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: _indexRate.toStringAsFixed(2),
                    onChanged: (v) =>
                        setState(() => _indexRate = v),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _indexRate.toStringAsFixed(2),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 辅音保护
            Row(
              children: [
                const SizedBox(
                  width: 100,
                  child: Text('辅音保护'),
                ),
                Expanded(
                  child: Slider(
                    value: _protect,
                    min: 0,
                    max: 0.5,
                    divisions: 50,
                    label: _protect.toStringAsFixed(2),
                    onChanged: (v) =>
                        setState(() => _protect = v),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _protect.toStringAsFixed(2),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 输出采样率
            Row(
              children: [
                const SizedBox(
                  width: 100,
                  child: Text('输出采样率'),
                ),
                Expanded(
                  child: Slider(
                    value: _resampleSr.toDouble(),
                    min: 0,
                    max: 48000,
                    divisions: 8,
                    label: _resampleSr == 0 ? '原始' : '$_resampleSr',
                    onChanged: (v) =>
                        setState(() => _resampleSr = v.toInt()),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    _resampleSr == 0 ? '原始' : '$_resampleSr Hz',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- 转换按钮 ----
  Widget _buildConvertButton(ThemeData theme) {
    final canConvert =
        _selectedModel != null && (_selectedFilePath != null || _selectedAudioBytes != null) && !_isConverting;

    return Column(
      children: [
        // 模式切换
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'convert', label: Text('音色转换'), icon: Icon(Icons.auto_fix_high)),
            ButtonSegment(value: 'cover', label: Text('一键翻唱'), icon: Icon(Icons.music_note)),
          ],
          selected: {_convertMode},
          onSelectionChanged: (v) => setState(() {
            _convertMode = v.first;
            _convertResult = null;
            _convertError = null;
          }),
        ),
        // 翻唱模式额外参数
        if (_convertMode == 'cover') ...[
          const SizedBox(height: 12),
          _buildCoverParams(theme),
        ],
        const SizedBox(height: 12),
        // 转换/翻唱按钮
        FilledButton.icon(
          onPressed: canConvert ? _doConvert : null,
          icon: _isConverting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Icon(_convertMode == 'cover' ? Icons.music_note : Icons.auto_fix_high),
          label: Text(_isConverting
              ? (_convertMode == 'cover' ? '正在翻唱...' : '正在转换...')
              : (_convertMode == 'cover' ? '一键翻唱' : '开始转换')),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  /// 翻唱模式参数：人声音量、伴奏音量
  Widget _buildCoverParams(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 80, child: Text('人声音量')),
                Expanded(
                  child: Slider(
                    value: _vocalVol,
                    min: 0,
                    max: 2,
                    divisions: 20,
                    label: _vocalVol.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _vocalVol = v),
                  ),
                ),
                SizedBox(width: 40, child: Text(_vocalVol.toStringAsFixed(1), textAlign: TextAlign.end)),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 80, child: Text('伴奏音量')),
                Expanded(
                  child: Slider(
                    value: _instVol,
                    min: 0,
                    max: 2,
                    divisions: 20,
                    label: _instVol.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _instVol = v),
                  ),
                ),
                SizedBox(width: 40, child: Text(_instVol.toStringAsFixed(1), textAlign: TextAlign.end)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- 结果区 ----
  Widget _buildResultSection(ThemeData theme) {
    // 转换中
    if (_isConverting) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(width: 16),
              Text(
                '正在转换音频，请稍候...',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    // 转换出错
    if (_convertError != null) {
      return Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Text(
                    '转换失败',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _convertError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 转换成功
    final result = _convertResult;
    if (result != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('转换完成', style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _infoChip('采样率', '${result.sampleRate} Hz'),
                  _infoChip('时长', '${result.durationSec.toStringAsFixed(1)}s'),
                  _infoChip(
                    '大小',
                    '${(result.fileSize / 1024).toStringAsFixed(1)} KB',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _togglePlayback,
                      icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                      label: Text(_isPlaying ? '停止播放' : '播放结果'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveResult,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('保存文件'),
                    ),
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

  // ---- 信息标签 ----
  Widget _infoChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
        withData: true, // 同时读取字节
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      setState(() {
        _selectedFileName = file.name;
        _selectedAudioBytes = file.bytes;
        // 选择新文件时清除上次转换结果
        _convertResult = null;
        _convertError = null;
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
    final controller = TextEditingController(text: _rvcServerUrl);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('服务器设置'),
        content: TextField(
          controller: controller,
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
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null || result == _rvcServerUrl || result.isEmpty) return;

    setState(() {
      _rvcServerUrl = result;
      _client.close();
      _client = RVCClient(baseUrl: _rvcServerUrl);
      // 重置所有状态
      _status = null;
      _models = [];
      _selectedModel = null;
      _errorMessage = null;
      _convertResult = null;
      _convertError = null;
    });

    _connect();
  }
}
