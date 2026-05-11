import 'package:flutter/material.dart';
import 'package:rainfall_tts_sdk/rainfall_tts_sdk.dart';

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
  late TextEditingController _urlController;
  late double _speed;
  String _selectedVoice = '';
  List<VoiceInfo> _voices = [];
  bool _loadingVoices = false;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.current.ttsBaseUrl);
    _speed = widget.current.speed;
    _selectedVoice = widget.current.voiceName;
    _loadVoices();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadVoices() async {
    setState(() => _loadingVoices = true);
    try {
      final client = RainfallTTS(baseUrl: _urlController.text.trim());
      try {
        final voices = await client.listVoices();
        if (mounted) {
          setState(() {
            _voices = voices;
            _loadingVoices = false;
            if (voices.isNotEmpty &&
                !voices.any((v) => v.name == _selectedVoice)) {
              _selectedVoice = voices.first.name;
            }
          });
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingVoices = false;
          _testResult = '加载音色失败: $e';
        });
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final client = RainfallTTS(baseUrl: _urlController.text.trim());
      try {
        final alive = await client.isServerAlive();
        if (mounted) {
          setState(() {
            _testing = false;
            _testResult = alive ? '连接成功' : '服务未响应';
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
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'TTS 服务地址',
                hintText: 'http://localhost:7861',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('雨落 AI 语音 Gradio 服务',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_find, size: 16),
                  label: Text(_testing ? '测试中...' : '测试连接'),
                ),
              ],
            ),
            if (_testResult != null) ...[
              Text(_testResult!,
                  style: TextStyle(
                      fontSize: 12,
                      color: _testResult == '连接成功' ? Colors.green : Colors.red)),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            Text('音色', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            _loadingVoices
                ? const Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('加载音色列表...'),
                  ])
                : DropdownButtonFormField<String>(
                    value: _voices.any((v) => v.name == _selectedVoice) ? _selectedVoice : null,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: _voices
                        .map((v) => DropdownMenuItem(value: v.name, child: Text(v.name, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedVoice = val);
                    },
                  ),
            const SizedBox(height: 16),
            Text('语速: ${_speed.toStringAsFixed(1)}x', style: Theme.of(context).textTheme.titleSmall),
            Slider(
              value: _speed,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${_speed.toStringAsFixed(1)}x',
              onChanged: (val) => setState(() => _speed = val),
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
              speed: _speed,
              ttsBaseUrl: _urlController.text.trim(),
            ));
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
