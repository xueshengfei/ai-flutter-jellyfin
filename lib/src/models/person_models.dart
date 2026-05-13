import 'package:equatable/equatable.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'media_item_models.dart' show MediaItem;

/// 个人详细信息（业务模型）
///
/// 封装人员（演员、导演、编剧等）的详细信息
class Person extends Equatable {
  /// 人员ID
  final String id;

  /// 人员姓名
  final String name;

  /// 人员类型
  final jellyfin_dart.PersonKind type;

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

  /// 从jellyfin_dart的BaseItemDto创建人员信息
  factory Person.fromDto(
    jellyfin_dart.BaseItemDto dto,
    jellyfin_dart.PersonKind personType,
    String serverUrl, {
    String? accessToken,
  }) {
    // 检查是否有图片标签
    final imageTags = dto.imageTags;
    final primaryImageTag = imageTags?['Primary'];

    // 生成头像URL
    String? imageUrl;
    if (primaryImageTag != null && primaryImageTag.isNotEmpty) {
      imageUrl = '$serverUrl/Items/${dto.id}/Images/Primary?tag=$primaryImageTag';
      if (accessToken != null && accessToken.isNotEmpty) {
        imageUrl += '&api_key=$accessToken';
      }
    }

    // 格式化日期为字符串
    String? formatDate(DateTime? date) {
      if (date == null) return null;
      return date.toIso8601String();
    }

    return Person(
      id: dto.id ?? '',
      name: dto.name ?? '未知人员',
      type: personType,
      bio: dto.overview,
      imageUrl: imageUrl,
      premiereDate: formatDate(dto.premiereDate),
      birthDate: formatDate(dto.premiereDate),
      deathDate: formatDate(dto.endDate),
      genres: dto.genres,
    );
  }

  /// 获取类型显示名称
  String get typeDisplayName {
    switch (type.name.toLowerCase()) {
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
        return type.name;
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        bio,
        imageUrl,
        premiereDate,
        birthDate,
        deathDate,
        genres,
      ];

  @override
  String toString() {
    return 'Person(id: $id, name: $name, type: $type)';
  }
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

  /// 是否为空
  bool get isEmpty => items.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => items.isNotEmpty;

  /// 数量
  int get length => items.length;

  @override
  List<Object?> get props => [items, totalCount];
}
