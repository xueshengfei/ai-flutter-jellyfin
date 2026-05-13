import 'package:flutter/foundation.dart';

import '../contracts/personal_repository.dart';
import '../models/personal_media_query.dart';
import '../models/personal_module_config.dart';
import 'personal_section_state.dart';

/// 个人模块控制器
final class PersonalController extends ChangeNotifier {
  final PersonalRepository repository;
  final PersonalModuleConfig config;

  PersonalMediaTypeFilter _typeFilter = PersonalMediaTypeFilter.all;
  final Map<PersonalSection, PersonalSectionState> _sectionStates = {
    for (final section in PersonalSection.values)
      section: const PersonalSectionState(),
  };

  PersonalController({
    required this.repository,
    required this.config,
  });

  /// 当前过滤类型
  PersonalMediaTypeFilter get typeFilter => _typeFilter;

  /// 当前过滤后的媒体类型
  List<PersonalMediaKind> get filteredKinds =>
      _typeFilter.filterKinds(config.mediaKinds);

  PersonalSectionState sectionState(PersonalSection section) {
    return _sectionStates[section] ?? const PersonalSectionState();
  }

  /// 切换过滤类型并刷新数据
  Future<void> setTypeFilter(PersonalMediaTypeFilter filter) async {
    if (_typeFilter == filter) return;
    _typeFilter = filter;
    notifyListeners();
    await loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait(config.sections.map(refreshSection));
  }

  Future<void> refreshSection(PersonalSection section) async {
    _setSectionState(section, const PersonalSectionState.loading());

    final kinds = filteredKinds;
    // 过滤后可能为空（比如音乐 App 切到视频 Tab）
    if (kinds.isEmpty) {
      _setSectionState(section, PersonalSectionState.loaded([]));
      return;
    }

    final query = PersonalMediaQuery(mediaKinds: kinds);
    try {
      final result = switch (section) {
        PersonalSection.continueWatching =>
          await repository.getContinueWatching(query),
        PersonalSection.favorites => await repository.getFavorites(query),
        PersonalSection.history => await repository.getHistory(query),
      };
      _setSectionState(
        section,
        PersonalSectionState.loaded(result.items),
      );
    } catch (error) {
      _setSectionState(
        section,
        PersonalSectionState.failure('$error'),
      );
    }
  }

  Future<void> toggleFavorite(String itemId, bool isFavorite) async {
    await repository.setFavorite(
      itemId: itemId,
      isFavorite: isFavorite,
    );
    if (config.sections.contains(PersonalSection.favorites)) {
      await refreshSection(PersonalSection.favorites);
    }
  }

  Future<void> setPlayed(String itemId, bool isPlayed) async {
    await repository.setPlayed(
      itemId: itemId,
      isPlayed: isPlayed,
    );
    if (config.sections.contains(PersonalSection.history)) {
      await refreshSection(PersonalSection.history);
    }
    if (config.sections.contains(PersonalSection.continueWatching)) {
      await refreshSection(PersonalSection.continueWatching);
    }
  }

  void _setSectionState(
    PersonalSection section,
    PersonalSectionState state,
  ) {
    _sectionStates[section] = state;
    notifyListeners();
  }
}
