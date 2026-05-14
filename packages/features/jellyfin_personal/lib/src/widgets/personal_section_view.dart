import 'package:flutter/material.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../contracts/personal_actions.dart';
import '../controllers/personal_section_state.dart';
import '../models/personal_module_config.dart';
import 'personal_media_card.dart';

/// Personal-center section rendered as a stable horizontal media rail.
final class PersonalSectionView extends StatelessWidget {
  final PersonalSection section;
  final String title;
  final PersonalSectionState state;
  final JellyfinImageProvider imageProvider;
  final PersonalActions actions;
  final void Function(String itemId, bool isFavorite) onFavoriteToggle;

  const PersonalSectionView({
    super.key,
    required this.section,
    required this.title,
    required this.state,
    required this.imageProvider,
    required this.actions,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final layout = _layoutForSection(section);
    final extent = _extentForLayout(layout);

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          switch (state.status) {
            PersonalSectionStatus.initial ||
            PersonalSectionStatus.loading => SizedBox(
              height: extent.height,
              child: const Center(child: CircularProgressIndicator()),
            ),
            PersonalSectionStatus.failure => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(state.errorMessage ?? '加载失败'),
            ),
            PersonalSectionStatus.empty => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                '暂无内容',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            PersonalSectionStatus.loaded => SizedBox(
              height: extent.height,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return SizedBox(
                    width: extent.width,
                    height: extent.height,
                    child: PersonalMediaCard(
                      layout: layout,
                      imageProvider: imageProvider,
                      item: item,
                      actions: actions,
                      onFavoriteToggle: (value) {
                        onFavoriteToggle(item.id, value);
                      },
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemCount: state.items.length,
              ),
            ),
          },
        ],
      ),
    );
  }

  PersonalMediaCardLayout _layoutForSection(PersonalSection section) {
    return switch (section) {
      PersonalSection.continueWatching => PersonalMediaCardLayout.landscape,
      PersonalSection.favorites ||
      PersonalSection.history => PersonalMediaCardLayout.poster,
    };
  }

  Size _extentForLayout(PersonalMediaCardLayout layout) {
    return switch (layout) {
      PersonalMediaCardLayout.landscape => const Size(220, 184),
      PersonalMediaCardLayout.square => const Size(176, 212),
      PersonalMediaCardLayout.poster => const Size(176, 224),
    };
  }
}
