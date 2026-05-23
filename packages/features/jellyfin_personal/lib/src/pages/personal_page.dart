import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../contracts/personal_actions.dart';
import '../contracts/personal_repository.dart';
import '../controllers/personal_controller.dart';
import '../models/personal_media_query.dart';
import '../models/personal_module_config.dart';
import '../widgets/personal_header.dart';
import '../widgets/personal_section_view.dart';

/// 个人中心页面
///
/// 接收 Repository、配置、图片 provider 和动作协议，
/// 不依赖 go_router / jellyfin_dart / Session。
final class PersonalPage extends StatefulWidget {
  final PersonalRepository repository;
  final PersonalModuleConfig config;
  final JellyfinImageProvider imageProvider;
  final PersonalActions actions;

  const PersonalPage({
    super.key,
    required this.repository,
    required this.config,
    required this.imageProvider,
    required this.actions,
  });

  @override
  State<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage> {
  late final PersonalController _controller;
  late final Future<models.UserProfile> _profileFuture;

  /// 是否需要显示过滤 Tab（config 同时包含视频和音乐类型时才显示）
  bool get _showFilterTabs {
    final kinds = widget.config.mediaKinds;
    final hasVideo = kinds.any((k) => PersonalMediaKindSets.video.contains(k));
    final hasMusic = kinds.any((k) => PersonalMediaKindSets.music.contains(k));
    return hasVideo && hasMusic;
  }

  /// 可用的过滤选项（只包含过滤后有内容的选项）
  List<PersonalMediaTypeFilter> get _availableFilters {
    final filters = <PersonalMediaTypeFilter>[PersonalMediaTypeFilter.all];
    final kinds = widget.config.mediaKinds;
    if (kinds.any((k) => PersonalMediaKindSets.video.contains(k))) {
      filters.add(PersonalMediaTypeFilter.video);
    }
    if (kinds.any((k) => PersonalMediaKindSets.music.contains(k))) {
      filters.add(PersonalMediaTypeFilter.music);
    }
    return filters;
  }

  @override
  void initState() {
    super.initState();
    _controller = PersonalController(
      repository: widget.repository,
      config: widget.config,
    );
    _profileFuture = widget.repository.getProfile();
    _controller.loadAll();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.config.title)),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _controller.loadAll,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                if (widget.config.showProfileHeader)
                  FutureBuilder<models.UserProfile>(
                    future: _profileFuture,
                    builder: (context, snapshot) {
                      final profile = snapshot.data;
                      if (profile == null) {
                        return const LinearProgressIndicator();
                      }
                      return PersonalHeader(
                        profile: profile,
                        onLogout: widget.config.showLogoutAction
                            ? widget.actions.onLogout
                            : null,
                        onOpenSettings: widget.actions.onOpenSettings,
                        onOpenStats: widget.actions.onOpenStats,
                      );
                    },
                  ),
                if (_showFilterTabs) _buildFilterTabs(),
                for (final section in widget.config.sections)
                  PersonalSectionView(
                    section: section,
                    title: section.labelFor(_controller.typeFilter),
                    state: _controller.sectionState(section),
                    imageProvider: widget.imageProvider,
                    actions: widget.actions,
                    onFavoriteToggle: _controller.toggleFavorite,
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = _availableFilters;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _controller.typeFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter.label),
                selected: isSelected,
                onSelected: (_) => _controller.setTypeFilter(filter),
                showCheckmark: true,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
