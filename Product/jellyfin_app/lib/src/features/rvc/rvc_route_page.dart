import 'package:flutter/material.dart';
import 'package:rvc_flutter/rvc_flutter.dart';

/// RVC 路由页面
///
/// 纯注入层 — 把 App 级 controller 传给 RvcPage。
class RvcRoutePage extends StatelessWidget {
  final RvcTaskController controller;
  final String? audioPath;

  const RvcRoutePage({
    super.key,
    required this.controller,
    this.audioPath,
  });

  @override
  Widget build(BuildContext context) {
    return RvcPage(
      controller: controller,
      audioPath: audioPath,
    );
  }
}
