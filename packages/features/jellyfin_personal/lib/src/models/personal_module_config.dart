import 'package:equatable/equatable.dart';

import 'personal_media_query.dart';

/// 个人页区块
enum PersonalSection {
  continueWatching,
  favorites,
  history,
}

extension PersonalSectionLabel on PersonalSection {
  /// 默认标签
  String get label => labelFor(PersonalMediaTypeFilter.all);

  /// 根据过滤类型返回语义化标签
  String labelFor(PersonalMediaTypeFilter filter) {
    return switch (this) {
      PersonalSection.continueWatching => switch (filter) {
        PersonalMediaTypeFilter.music => '继续收听',
        _ => '继续观看',
      },
      PersonalSection.favorites => '我的收藏',
      PersonalSection.history => switch (filter) {
        PersonalMediaTypeFilter.music => '收听历史',
        _ => '观看历史',
      },
    };
  }
}

/// 个人模块配置
final class PersonalModuleConfig extends Equatable {
  final String title;
  final List<PersonalSection> sections;
  final List<PersonalMediaKind> mediaKinds;
  final bool showProfileHeader;
  final bool showLogoutAction;

  const PersonalModuleConfig({
    required this.title,
    required this.sections,
    required this.mediaKinds,
    this.showProfileHeader = true,
    this.showLogoutAction = true,
  });

  const PersonalModuleConfig.full()
      : title = '个人中心',
        sections = const [
          PersonalSection.continueWatching,
          PersonalSection.favorites,
          PersonalSection.history,
        ],
        mediaKinds = PersonalMediaKindSets.all,
        showProfileHeader = true,
        showLogoutAction = true;

  const PersonalModuleConfig.moviesOnly()
      : title = '我的电影',
        sections = const [
          PersonalSection.continueWatching,
          PersonalSection.favorites,
          PersonalSection.history,
        ],
        mediaKinds = PersonalMediaKindSets.moviesOnly,
        showProfileHeader = true,
        showLogoutAction = true;

  const PersonalModuleConfig.musicOnly()
      : title = '我的音乐',
        sections = const [
          PersonalSection.favorites,
          PersonalSection.history,
        ],
        mediaKinds = PersonalMediaKindSets.music,
        showProfileHeader = true,
        showLogoutAction = true;

  @override
  List<Object?> get props => [
        title,
        sections,
        mediaKinds,
        showProfileHeader,
        showLogoutAction,
      ];
}
