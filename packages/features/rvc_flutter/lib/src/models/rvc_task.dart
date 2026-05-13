import 'package:rvc_sdk/rvc_sdk.dart';

/// RVC 任务状态
enum RvcTaskStatus {
  /// 空闲，无任务
  idle,

  /// 正在转换中
  running,

  /// 转换成功
  succeeded,

  /// 转换失败
  failed,
}

/// RVC 任务快照（不可变）
///
/// 记录一次转换任务的完整状态，由 [RvcTaskController] 持有。
/// 页面退出后 controller 仍存活，下次进入页面可恢复上次任务。
class RvcTaskSnapshot {
  final String id;
  final RvcTaskStatus status;

  /// 'convert' 或 'cover'
  final String mode;

  /// 音频文件名
  final String? sourceName;

  /// 使用的模型名
  final String? modelName;

  /// 转换结果（ConvertResult 或 CoverResult）
  final dynamic result;

  /// 错误信息
  final String? errorMessage;

  /// 任务创建时间
  final DateTime createdAt;

  /// 任务完成时间
  final DateTime? completedAt;

  const RvcTaskSnapshot({
    required this.id,
    required this.status,
    required this.mode,
    this.sourceName,
    this.modelName,
    this.result,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  /// 播放地址（从 result 提取）
  String? get playUrl {
    final r = result;
    if (r is ConvertResult) return r.playUrl;
    if (r is CoverResult) return r.playUrl;
    return null;
  }

  /// 下载地址（从 result 提取）
  String? get downloadUrl {
    final r = result;
    if (r is ConvertResult) return r.downloadUrl;
    if (r is CoverResult) return r.downloadUrl;
    return null;
  }

  /// 便捷 copyWith
  RvcTaskSnapshot copyWith({
    RvcTaskStatus? status,
    String? mode,
    String? sourceName,
    String? modelName,
    dynamic result,
    String? errorMessage,
    DateTime? completedAt,
  }) {
    return RvcTaskSnapshot(
      id: id,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      sourceName: sourceName ?? this.sourceName,
      modelName: modelName ?? this.modelName,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
