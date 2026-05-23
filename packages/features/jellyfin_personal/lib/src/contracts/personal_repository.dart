import 'package:jellyfin_models/jellyfin_models.dart' as models;

import '../models/personal_media_query.dart';
import '../models/personal_stats.dart';

/// 个人模块数据仓库协议
///
/// Product App 在 adapter 中实现此接口，调用 jellyfin_dart API。
abstract interface class PersonalRepository {
  /// 获取用户信息
  Future<models.UserProfile> getProfile();

  /// 继续观看
  Future<models.MediaItemListResult> getContinueWatching(
    PersonalMediaQuery query,
  );

  /// 收藏列表
  Future<models.MediaItemListResult> getFavorites(
    PersonalMediaQuery query,
  );

  /// 观看历史
  Future<models.MediaItemListResult> getHistory(
    PersonalMediaQuery query,
  );

  /// 切换收藏
  Future<void> setFavorite({
    required String itemId,
    required bool isFavorite,
  });

  /// 标记已看/未看
  Future<void> setPlayed({
    required String itemId,
    required bool isPlayed,
  });

  /// 获取统计数据
  Future<PersonalStats> getStats(PersonalMediaQuery query);
}
