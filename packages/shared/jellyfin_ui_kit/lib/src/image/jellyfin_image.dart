import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'jellyfin_image_provider.dart';

/// Jellyfin 认证图片 Widget
///
/// 使用 [JellyfinImageProvider] 加载需要认证的图片。
/// 不直接依赖任何具体 service 或 client 实现。
class JellyfinImage extends StatefulWidget {
  final JellyfinImageProvider imageProvider;
  final String itemId;
  final String? imageTag;
  final int? fillWidth;
  final int? fillHeight;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const JellyfinImage({
    super.key,
    required this.imageProvider,
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
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant JellyfinImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId ||
        oldWidget.imageTag != widget.imageTag ||
        oldWidget.fillWidth != widget.fillWidth ||
        oldWidget.fillHeight != widget.fillHeight ||
        oldWidget.imageProvider != widget.imageProvider) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final imageData = await widget.imageProvider.getPrimaryImage(
        itemId: widget.itemId,
        tag: widget.imageTag,
        fillWidth: widget.fillWidth,
        fillHeight: widget.fillHeight,
      );

      if (mounted) {
        setState(() {
          _imageData = imageData;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
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
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(color: Colors.white),
          );
    }

    if (_hasError) {
      return widget.errorWidget ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white54),
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
