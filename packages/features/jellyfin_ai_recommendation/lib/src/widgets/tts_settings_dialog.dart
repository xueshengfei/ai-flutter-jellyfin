import 'package:flutter/material.dart';
import 'package:rainfall_tts_cloud_sdk/rainfall_tts_cloud_sdk.dart';

import '../models/tts_models.dart';

/// TTS 设置弹窗
Future<TtsSettings?> showTtsSettingsDialog(
  BuildContext context,
  TtsSettings current,
) {
  return showDialog<TtsSettings>(
    context: context,
    builder: (ctx) => _TtsSettingsDialog(current: current),
  );
}

class _TtsSettingsDialog extends StatefulWidget {
  final TtsSettings current;
  const _TtsSettingsDialog({required this.current});

  @override
  State<_TtsSettingsDialog> createState() => _TtsSettingsDialogState();
}

class _TtsSettingsDialogState extends State<_TtsSettingsDialog> {
  late String _selectedVoice;
  final List<VoiceInfo> _voices = RainfallCloudTTS.voices;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _selectedVoice = widget.current.voiceName;
    // 确保默认选中的音色在列表中
    if (!_voices.any((v) => v.name == _selectedVoice)) {
      _selectedVoice = _voices.first.name;
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final client = RainfallCloudTTS();
      try {
        final alive = await client.isServerAlive();
        if (mounted) {
          setState(() {
            _testing = false;
            _testResult = alive ? '云端连接成功' : '云端服务未响应';
          });
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = '连接失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.record_voice_over),
      title: const Text('语音播报设置'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 云端状态
            Row(
              children: [
                Text('雨落 AI 语音（云端）',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_done, size: 16),
                  label: Text(_testing ? '测试中...' : '测试连接'),
                ),
              ],
            ),
            if (_testResult != null) ...[
              Text(_testResult!,
                  style: TextStyle(
                      fontSize: 12,
                      color: _testResult == '云端连接成功' ? Colors.green : Colors.red)),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            // 音色选择
            Text('音色', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedVoice,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: _voices
                  .map((v) => DropdownMenuItem(
                      value: v.name,
                      child: Text(v.name,
                          overflow: TextOverflow.ellipsis, maxLines: 1)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedVoice = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, TtsSettings(
              voiceName: _selectedVoice,
            ));
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
