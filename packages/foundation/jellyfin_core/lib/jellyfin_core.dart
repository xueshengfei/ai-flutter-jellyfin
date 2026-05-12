/// Jellyfin Core - 核心基础包
///
/// 提供配置、异常基类和模块注册协议
library;

// 配置
export 'src/configuration/jellyfin_configuration.dart';

// 异常基类
export 'src/exceptions/jellyfin_exception.dart';

// 模块协议
export 'src/module/jellyfin_feature_module.dart';
export 'src/module/navigation_intent.dart';
export 'src/module/app_navigator.dart';
export 'src/module/jellyfin_route_names.dart';
export 'src/module/jellyfin_route_intents.dart';
