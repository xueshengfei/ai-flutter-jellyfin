// ---------------------------------------------------------------------------
// 数据模型
// ---------------------------------------------------------------------------

/// 音色信息
final class VoiceInfo {
  /// 音色文件名（如 demo_boy.wav）
  final String name;

  const VoiceInfo({required this.name});

  @override
  String toString() => 'VoiceInfo($name)';
}

/// TTS 单条合成结果
final class TTSResult {
  /// 服务端生成的音频文件路径
  final String audioPath;

  /// 可下载的完整 URL
  final String audioUrl;

  /// 下载后的本地路径（下载前为空字符串）
  final String localPath;

  /// SRT 字幕文件路径（未生成时为空）
  final String srtPath;

  /// SRT 字幕文件 URL
  final String srtUrl;

  const TTSResult({
    required this.audioPath,
    this.audioUrl = '',
    this.localPath = '',
    this.srtPath = '',
    this.srtUrl = '',
  });

  TTSResult withLocalPath(String path) => TTSResult(
        audioPath: audioPath,
        audioUrl: audioUrl,
        localPath: path,
        srtPath: srtPath,
        srtUrl: srtUrl,
      );

  @override
  String toString() =>
      'TTSResult(audioPath: $audioPath, audioUrl: $audioUrl, srtPath: $srtPath)';
}

/// 音频格式转换结果
final class ConvertResult {
  final String audioPath;
  final String audioUrl;
  final String localPath;

  const ConvertResult({
    required this.audioPath,
    this.audioUrl = '',
    this.localPath = '',
  });

  ConvertResult withLocalPath(String path) => ConvertResult(
        audioPath: audioPath,
        audioUrl: audioUrl,
        localPath: path,
      );

  @override
  String toString() =>
      'ConvertResult(audioPath: $audioPath, audioUrl: $audioUrl)';
}

/// 多角色对话中的角色分配
final class RoleAssignment {
  /// 角色名称（对应剧本中的角色标识）
  final String roleName;

  /// 角色参考音色音频的本地文件路径（调用前需上传到服务端）
  final String audioFilePath;

  const RoleAssignment({
    required this.roleName,
    required this.audioFilePath,
  });

  @override
  String toString() => 'RoleAssignment($roleName)';
}

/// 视频提取参数（extract_from_video 的 subtitles 可选）
final class VideoExtractInput {
  final String videoFilePath;
  final String? subtitlesFilePath;

  const VideoExtractInput({
    required this.videoFilePath,
    this.subtitlesFilePath,
  });
}
