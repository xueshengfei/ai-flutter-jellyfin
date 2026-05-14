import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'jellyfin_image_provider.dart';

/// Jellyfin 认证图片 Widget
///
/// 优先使用 CachedNetworkImage（磁盘+内存缓存），
/// 如果 URL 为空则降级到 http 请求 + Image.memory。
/// 不直接依赖任何具体 service 或 client 实现。
class JellyfinImage extends StatefulWidget {
  final JellyfinImageProvider imageProvider;
  final String itemId;
  final JellyfinImageType imageType;
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
    this.imageType = JellyfinImageType.primary,
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
  /// 是否降级到手动 http + Image.memory
  bool _useFallback = false;
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initImage();
  }

  @override
  void didUpdateWidget(covariant JellyfinImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId ||
        oldWidget.imageType != widget.imageType ||
        oldWidget.imageTag != widget.imageTag ||
        oldWidget.fillWidth != widget.fillWidth ||
        oldWidget.fillHeight != widget.fillHeight ||
        oldWidget.imageProvider != widget.imageProvider) {
      _initImage();
    }
  }

  void _initImage() {
    final url = widget.imageProvider.buildImageUrl(
      itemId: widget.itemId,
      imageType: widget.imageType,
      imageTag: widget.imageTag,
      fillWidth: widget.fillWidth,
      fillHeight: widget.fillHeight,
    );

    if (url.isEmpty) {
      // URL 为空，降级到手动加载
      setState(() {
        _useFallback = true;
        _isLoading = true;
        _hasError = false;
      });
      _loadFallback();
    } else {
      setState(() {
        _useFallback = false;
      });
    }
  }

  Future<void> _loadFallback() async {
    if (!mounted) return;
    try {
      final imageData = await widget.imageProvider.getImage(
        itemId: widget.itemId,
        imageType: widget.imageType,
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
    if (_useFallback) {
      return _buildFallback();
    }
    return _buildCachedNetworkImage();
  }

  Widget _buildCachedNetworkImage() {
    final url = widget.imageProvider.buildImageUrl(
      itemId: widget.itemId,
      imageType: widget.imageType,
      imageTag: widget.imageTag,
      fillWidth: widget.fillWidth,
      fillHeight: widget.fillHeight,
    );

    final headers = widget.imageProvider.authHeaders;

    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      fit: widget.fit,
      placeholder: (_, __) => widget.placeholder ?? _defaultPlaceholder(),
      errorWidget: (_, __, ___) => widget.errorWidget ?? _defaultError(),
      memCacheWidth: widget.fillWidth,
      memCacheHeight: widget.fillHeight,
    );
  }

  Widget _buildFallback() {
    if (_isLoading) {
      return widget.placeholder ?? _defaultPlaceholder();
    }
    if (_hasError) {
      return widget.errorWidget ?? _defaultError();
    }
    if (_imageData != null) {
      return Image.memory(
        _imageData!,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    }
    return widget.placeholder ?? const SizedBox.shrink();
  }

  Widget _defaultPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(color: Colors.white),
    );
  }

  Widget _defaultError() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.white54),
      ),
    );
  }
}
