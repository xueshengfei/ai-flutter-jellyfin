/// 文件保存工具 — Web 空壳
///
/// Web 平台不支持文件系统写入。
String saveFile(String localPath, List<int> bytes) {
  throw UnsupportedError('Web 平台不支持文件保存');
}
