import 'dart:io';

/// 文件保存工具 — 原生平台
///
/// 将字节数据写入本地文件。
String saveFile(String localPath, List<int> bytes) {
  final file = File(localPath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  return file.absolute.path;
}
