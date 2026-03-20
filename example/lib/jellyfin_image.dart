import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// Jellyfin认证图片Widget
///
/// 使用ImageService来下载需要认证的图片
class JellyfinImage extends StatefulWidget {
  final String itemId;
  final String? imageTag;
  final int? fillWidth;
  final int? fillHeight;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const JellyfinImage({
    super.key,
    required this.itemId,
    this.imageTag,
    this.fillWidth,
    this.fillHeight,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<JellyfinImage> createState() => _JellyfinImageState();
}

class _JellyfinImageState extends State<JellyfinImage> {
  final JellyfinClient _client = JellyfinClient(
    serverUrl: 'http://localhost:8096',
    enableLogging: false,
  );

  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      print('🖼️ JellyfinImage: 开始加载图片 ${widget.itemId}');

      final imageData = await _client.image.getPrimaryImage(
        itemId: widget.itemId,
        tag: widget.imageTag,
        fillWidth: widget.fillWidth,
        fillHeight: widget.fillHeight,
      );

      print('✅ JellyfinImage: 图片加载成功，大小: ${imageData.length} bytes');

      if (mounted) {
        setState(() {
          _imageData = imageData;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ JellyfinImage: 图片加载失败: $e');
      print('   堆栈: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
    }

    if (_hasError) {
      return widget.errorWidget ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.error, color: Colors.red),
            ),
          );
    }

    if (_imageData != null) {
      return Image.memory(
        _imageData!,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    }

    return widget.placeholder ??
        Container(
          color: Colors.grey[300],
        );
  }
}

/// 简化版的Jellyfin图片Widget，需要传入client
class JellyfinImageWithClient extends StatefulWidget {
  final JellyfinClient client;
  final String itemId;
  final String? imageTag;
  final int? fillWidth;
  final int? fillHeight;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const JellyfinImageWithClient({
    super.key,
    required this.client,
    required this.itemId,
    this.imageTag,
    this.fillWidth,
    this.fillHeight,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<JellyfinImageWithClient> createState() => _JellyfinImageWithClientState();
}

class _JellyfinImageWithClientState extends State<JellyfinImageWithClient> {
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      print('🖼️ JellyfinImageWithClient: 开始加载图片 ${widget.itemId}');
      print('   fillWidth: ${widget.fillWidth}, fillHeight: ${widget.fillHeight}');

      final imageData = await widget.client.image.getPrimaryImage(
        itemId: widget.itemId,
        tag: widget.imageTag,
        fillWidth: widget.fillWidth,
        fillHeight: widget.fillHeight,
        quality: 96,
      );

      print('✅ JellyfinImageWithClient: 图片加载成功，大小: ${imageData.length} bytes');

      if (mounted) {
        setState(() {
          _imageData = imageData;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ JellyfinImageWithClient: 图片加载失败: $e');
      print('   堆栈: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
    }

    if (_hasError) {
      return widget.errorWidget ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.error, color: Colors.red),
            ),
          );
    }

    if (_imageData != null) {
      return Image.memory(
        _imageData!,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    }

    return widget.placeholder ??
        Container(
          color: Colors.grey[300],
        );
  }
}
