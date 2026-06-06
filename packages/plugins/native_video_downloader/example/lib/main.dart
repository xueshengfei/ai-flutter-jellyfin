import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_video_downloader/native_video_downloader.dart';

void main() {
  runApp(const NativeVideoDownloaderExampleApp());
}

class NativeVideoDownloaderExampleApp extends StatefulWidget {
  const NativeVideoDownloaderExampleApp({super.key});

  @override
  State<NativeVideoDownloaderExampleApp> createState() =>
      _NativeVideoDownloaderExampleAppState();
}

class _NativeVideoDownloaderExampleAppState
    extends State<NativeVideoDownloaderExampleApp> {
  static const String _testVideoUrl =
      'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_5MB.mp4';

  final NativeVideoDownloader _plugin = NativeVideoDownloader();

  StreamSubscription<Map<Object?, Object?>>? _eventSubscription;

  String _platformVersion = 'Unknown';
  String _taskId = 'No task yet';
  String _progressText = 'No progress yet';
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _loadPlatformVersion();
    _listenDownloadEvents();
  }

  void _listenDownloadEvents() {
    _eventSubscription = _plugin.watchDownloadEvents().listen(
      (event) {
        if (!mounted) return;

        final taskId = event['taskId'] ?? 'unknown';
        final progress = event['progress'] ?? '-';
        final state = event['state'] ?? 'unknown';
        final speedBytesPerSecond = event['speedBytesPerSecond'] ?? 0;

        setState(() {
          _progressText =
              'task=$taskId progress=$progress% state=$state speed=$speedBytesPerSecond B/s';
        });
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          _progressText = 'Event error: $error';
        });
      },
    );
  }

  Future<void> _loadPlatformVersion() async {
    try {
      final platformVersion =
          await _plugin.getPlatformVersion() ?? 'Unknown platform version';
      if (!mounted) return;

      setState(() {
        _platformVersion = platformVersion;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;

      setState(() {
        _platformVersion = 'Failed: ${error.message ?? error.code}';
      });
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isStarting = true;
      _taskId = 'Starting...';
    });

    try {
      final taskId =
          await _plugin.startDownload(_testVideoUrl) ?? 'No task id returned';
      if (!mounted) return;

      setState(() {
        _taskId = taskId;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;

      setState(() {
        _taskId = 'Failed: ${error.message ?? error.code}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Native Video Downloader')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform: $_platformVersion'),
              const SizedBox(height: 16),
              Text('Task: $_taskId'),
              const SizedBox(height: 16),
              Text('Progress: $_progressText'),
              const SizedBox(height: 16),
              const Text('Test URL: $_testVideoUrl'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isStarting ? null : _startDownload,
                child: Text(_isStarting ? 'Starting...' : 'Start Download'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
