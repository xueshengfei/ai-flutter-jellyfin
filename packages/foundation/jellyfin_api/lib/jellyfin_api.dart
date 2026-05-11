/// Jellyfin API - HTTP 客户端与 API 适配层
///
/// 提供 Dio HTTP 客户端、jellyfin_dart 接入、鉴权头管理和异常转换
library;

export 'src/api_client.dart';
export 'src/exceptions/api_exception.dart';
export 'src/exceptions/authentication_exception.dart';

// re-export core 层的配置和基类异常
export 'package:jellyfin_core/jellyfin_core.dart';
