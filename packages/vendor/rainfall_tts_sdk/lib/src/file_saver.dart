/// 文件保存条件导出
///
/// 原生平台使用 dart:io 写文件，Web 平台抛 UnsupportedError。
export 'file_saver_stub.dart'
    if (dart.library.io) 'file_saver_native.dart';
