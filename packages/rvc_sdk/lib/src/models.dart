import 'dart:typed_data';

import 'package:meta/meta.dart';

// ---------------------------------------------------------------------------
// F0 提取算法
// ---------------------------------------------------------------------------
/// 基频提取算法
enum F0Method {
  rmvpe('rmvpe'),
  pm('pm'),
  harvest('harvest'),
  dio('dio'),
  crepe('crepe');

  final String value;
  const F0Method(this.value);
}

// ---------------------------------------------------------------------------
// 数据模型
// ---------------------------------------------------------------------------
/// 模型信息
final class ModelInfo {
  final String name;
  final double sizeMb;

  const ModelInfo({required this.name, required this.sizeMb});

  factory ModelInfo.fromJson(Map<String, dynamic> json) => ModelInfo(
        name: json['name'] as String,
        sizeMb: (json['size_mb'] as num).toDouble(),
      );

  @override
  String toString() => 'ModelInfo(name: $name, sizeMb: $sizeMb)';
}

/// 服务状态
final class ServiceStatus {
  final String service;
  final String version;
  final String status;

  const ServiceStatus({
    required this.service,
    required this.version,
    required this.status,
  });

  factory ServiceStatus.fromJson(Map<String, dynamic> json) => ServiceStatus(
        service: json['service'] as String,
        version: json['version'] as String,
        status: json['status'] as String,
      );
}

/// 转换结果（/convert 返回播放/下载地址）
final class ConvertResult {
  final bool success;
  final String playUrl;
  final String downloadUrl;
  final String filename;
  final int sampleRate;
  final double durationSec;
  final int fileSize;

  const ConvertResult({
    required this.success,
    required this.playUrl,
    required this.downloadUrl,
    required this.filename,
    required this.sampleRate,
    required this.durationSec,
    required this.fileSize,
  });

  factory ConvertResult.fromJson(Map<String, dynamic> json) => ConvertResult(
        success: json['success'] as bool,
        playUrl: json['play_url'] as String,
        downloadUrl: json['download_url'] as String,
        filename: json['filename'] as String,
        sampleRate: json['sample_rate'] as int,
        durationSec: (json['duration_sec'] as num).toDouble(),
        fileSize: json['file_size'] as int,
      );
}

/// 转换到文件结果（/convert/file 返回）
final class ConvertFileResult {
  final bool success;
  final String message;
  final double durationSec;

  const ConvertFileResult({
    required this.success,
    required this.message,
    required this.durationSec,
  });

  factory ConvertFileResult.fromJson(Map<String, dynamic> json) =>
      ConvertFileResult(
        success: json['success'] as bool,
        message: json['message'] as String,
        durationSec: (json['duration_sec'] as num).toDouble(),
      );
}

/// 一键翻唱结果（/cover 返回）
///
/// 完整流水线：人声分离 → 去混响 → RVC音色转换 → AI混音
final class CoverResult {
  final bool success;
  final String playUrl;
  final String downloadUrl;
  final String filename;
  final int sampleRate;
  final double durationSec;
  final int fileSize;
  final String? vocalPath;
  final String? instrPath;

  const CoverResult({
    required this.success,
    required this.playUrl,
    required this.downloadUrl,
    required this.filename,
    required this.sampleRate,
    required this.durationSec,
    required this.fileSize,
    this.vocalPath,
    this.instrPath,
  });

  factory CoverResult.fromJson(Map<String, dynamic> json) => CoverResult(
        success: json['success'] as bool,
        playUrl: json['play_url'] as String,
        downloadUrl: json['download_url'] as String,
        filename: json['filename'] as String,
        sampleRate: json['sample_rate'] as int,
        durationSec: (json['duration_sec'] as num).toDouble(),
        fileSize: json['file_size'] as int,
        vocalPath: json['vocal_path'] as String?,
        instrPath: json['instr_path'] as String?,
      );
}

// ---------------------------------------------------------------------------
// 转换参数
// ---------------------------------------------------------------------------
/// 转换请求参数（不可变）
@immutable
final class ConvertParams {
  final String modelName;
  final String? inputPath;
  final Uint8List? audioBytes;
  final String? audioFilename;
  final int f0UpKey;
  final F0Method f0Method;
  final double indexRate;
  final int filterRadius;
  final int resampleSr;
  final double rmsMixRate;
  final double protect;
  final String? indexFile;

  const ConvertParams({
    required this.modelName,
    this.inputPath,
    this.audioBytes,
    this.audioFilename,
    this.f0UpKey = 0,
    this.f0Method = F0Method.rmvpe,
    this.indexRate = 0.75,
    this.filterRadius = 3,
    this.resampleSr = 0,
    this.rmsMixRate = 1.0,
    this.protect = 0.33,
    this.indexFile,
  });

  /// 转为 query 参数 map（排除空值）
  Map<String, String> toQueryParams() => {
        'model_name': modelName,
        if (inputPath != null) 'input_path': inputPath!,
        'f0_up_key': f0UpKey.toString(),
        'f0_method': f0Method.value,
        'index_rate': indexRate.toString(),
        'filter_radius': filterRadius.toString(),
        'resample_sr': resampleSr.toString(),
        'rms_mix_rate': rmsMixRate.toString(),
        'protect': protect.toString(),
        if (indexFile != null) 'index_file': indexFile!,
      };
}
