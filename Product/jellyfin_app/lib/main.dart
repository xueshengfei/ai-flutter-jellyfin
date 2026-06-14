import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'src/app/jellyfin_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 预热 Liquid Glass shader / Impeller 管线（Android 上避免首帧白闪）
  await LiquidGlassWidgets.initialize();
  runApp(
    LiquidGlassWidgets.wrap(
      child: const JellyfinApp(),
      // Android 设备自动降级到合适的质量档位（standard → premium 动态调整）
      adaptiveQuality: true,
    ),
  );
}
