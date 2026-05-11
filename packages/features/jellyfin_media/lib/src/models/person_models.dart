import 'package:equatable/equatable.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

/// 个人详细信息（业务模型）
///
/// 封装人员（演员、导演、编剧等）的详细信息
class Person extends Equatable {
  /// 人员ID
  final String id;

  /// 人员姓名
  final String name;

  /// 人员类型（actor/director/writer/producer/composer）
  final String type;

  /// 个人简介
  final String? bio;

  /// 头像图片URL
  final String? imageUrl;

  /// 首映日期
  final String? premiereDate;

  /// 出生日期
  final String? birthDate;

  /// 死亡日期
  final String? deathDate;

  /// 类型标签
  final List<String>? genres;

  const Person({
    required this.id,
    required this.name,
    required this.type,
    this.bio,
    this.imageUrl,
    this.premiereDate,
    this.birthDate,
    this.deathDate,
    this.genres,
  });

  /// 获取类型显示名称
  String get typeDisplayName {
    switch (type.toLowerCase()) {
      case 'actor':
        return '演员';
      case 'director':
        return '导演';
      case 'writer':
        return '编剧';
      case 'producer':
        return '制片人';
      case 'composer':
        return '作曲家';
      default:
        return type;
    }
  }

  @override
  List<Object?> get props => [
        id, name, type, bio, imageUrl,
        premiereDate, birthDate, deathDate, genres,
      ];

  @override
  String toString() => 'Person(id: $id, name: $name, type: $type)';
}

/// 个人作品列表结果（业务模型）
///
/// 封装人员参与的作品列表查询结果
class PersonCreditsResult extends Equatable {
  /// 作品列表
  final List<MediaItem> items;

  /// 总数
  final int? totalCount;

  const PersonCreditsResult({
    required this.items,
    this.totalCount,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get length => items.length;

  @override
  List<Object?> get props => [items, totalCount];
}
