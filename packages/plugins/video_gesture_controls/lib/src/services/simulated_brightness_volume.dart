/// 模拟亮度/音量值
///
/// 纯 Dart 实现，不依赖原生 MethodChannel。
/// 维护 0.0 ~ 1.0 范围的模拟值，供 UI 指示器使用。
class SimulatedBrightnessVolume {
  double _brightness;
  double _volume;

  SimulatedBrightnessVolume({
    double brightness = 0.5,
    double volume = 0.8,
  })  : _brightness = brightness.clamp(0.0, 1.0),
        _volume = volume.clamp(0.0, 1.0);

  /// 当前亮度 (0.0 ~ 1.0)
  double get brightness => _brightness;

  /// 当前音量 (0.0 ~ 1.0)
  double get volume => _volume;

  /// 调节亮度，返回调节后的值
  double adjustBrightness(double delta) {
    _brightness = (_brightness + delta).clamp(0.0, 1.0);
    return _brightness;
  }

  /// 调节音量，返回调节后的值
  double adjustVolume(double delta) {
    _volume = (_volume + delta).clamp(0.0, 1.0);
    return _volume;
  }
}
