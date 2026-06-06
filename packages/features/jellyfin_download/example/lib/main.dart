import 'package:flutter/material.dart';
import 'package:jellyfin_download/jellyfin_download.dart';

void main() {
  runApp(const JellyfinDownloadExampleApp());
}

class JellyfinDownloadExampleApp extends StatelessWidget {
  const JellyfinDownloadExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jellyfin Download Example',
      theme: ThemeData(useMaterial3: true),
      home: const JellyfinDownloadExampleHome(),
    );
  }
}

class JellyfinDownloadExampleHome extends StatefulWidget {
  const JellyfinDownloadExampleHome({super.key});

  @override
  State<JellyfinDownloadExampleHome> createState() =>
      _JellyfinDownloadExampleHomeState();
}

class _JellyfinDownloadExampleHomeState
    extends State<JellyfinDownloadExampleHome> {
  final DownloadController _controller = DownloadController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DownloadsPage(controller: _controller);
  }
}
