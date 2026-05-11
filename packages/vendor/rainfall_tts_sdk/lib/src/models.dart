// ---------------------------------------------------------------------------
// 数据模型
// ---------------------------------------------------------------------------

/// TTS 合成结果（不可变）
final class TTSResult {
  /// 服务端生成的音频文件相对路径
  final String audioPath;

  /// 可下载的完整 URL
  final String audioUrl;

  /// 下载后的本地路径（下载前为空字符串）
  final String localPath;

  const TTSResult({
    required this.audioPath,
    this.audioUrl = '',
    this.localPath = '',
  });

  /// 返回标记了本地路径的副本（不修改原对象）
  TTSResult withLocalPath(String path) => TTSResult(
        audioPath: audioPath,
        audioUrl: audioUrl,
        localPath: path,
      );

  @override
  String toString() =>
      'TTSResult(audioPath: $audioPath, audioUrl: $audioUrl, localPath: $localPath)';
}

/// 可用音色信息
final class VoiceInfo {
  final String name;

  const VoiceInfo({required this.name});

  @override
  String toString() => 'VoiceInfo($name)';
}

/// 多角色对话中的角色分配
final class RoleAssignment {
  final String roleName;
  final String voice;

  const RoleAssignment({
    required this.roleName,
    this.voice = '',
  });

  @override
  String toString() => 'RoleAssignment($roleName -> $voice)';
}
