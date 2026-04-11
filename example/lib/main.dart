import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

void main() {
  FlutterDebugPanel.init(enable: !kReleaseMode);
  SlowNetSimulator.configure(speed: NetworkSpeed.lte4g, failureProbability: 0.0);
  runApp(FlutterDebugPanel.wrap(const JellyfinExampleApp()));
}

class JellyfinExampleApp extends StatelessWidget {
  const JellyfinExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jellyfin Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
