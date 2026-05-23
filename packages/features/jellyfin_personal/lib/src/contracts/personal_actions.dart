import 'package:flutter/widgets.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;

/// 媒体动作回调
typedef PersonalMediaAction = void Function(
  BuildContext context,
  models.MediaItem item,
);

/// 个人模块跳转协议
///
/// Feature 包通过此协议通知外部导航，不直接使用 go_router。
final class PersonalActions {
  /// 点击卡片主体 — 跳转详情
  final PersonalMediaAction onOpenMedia;

  /// 播放按钮 — 跳转播放页
  final PersonalMediaAction? onPlayMedia;

  /// 退出登录
  final VoidCallback? onLogout;

  /// 打开设置
  final VoidCallback? onOpenSettings;

  /// 打开统计
  final VoidCallback? onOpenStats;

  const PersonalActions({
    required this.onOpenMedia,
    this.onPlayMedia,
    this.onLogout,
    this.onOpenSettings,
    this.onOpenStats,
  });
}
