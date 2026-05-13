import 'package:flutter/material.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../contracts/personal_actions.dart';
import '../controllers/personal_section_state.dart';
import 'personal_media_card.dart';

/// 个人页区块视图 — 横向卡片列表
final class PersonalSectionView extends StatelessWidget {
  final String title;
  final PersonalSectionState state;
  final JellyfinImageProvider imageProvider;
  final PersonalActions actions;
  final void Function(String itemId, bool isFavorite) onFavoriteToggle;

  const PersonalSectionView({
    super.key,
    required this.title,
    required this.state,
    required this.imageProvider,
    required this.actions,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        switch (state.status) {
          PersonalSectionStatus.initial ||
          PersonalSectionStatus.loading =>
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
          PersonalSectionStatus.failure => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(state.errorMessage ?? '加载失败'),
            ),
          PersonalSectionStatus.empty => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('暂无内容'),
            ),
          PersonalSectionStatus.loaded => SizedBox(
              height: 240,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return SizedBox(
                    width: 150,
                    child: PersonalMediaCard(
                      imageProvider: imageProvider,
                      item: item,
                      actions: actions,
                      onFavoriteToggle: (value) {
                        onFavoriteToggle(item.id, value);
                      },
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: state.items.length,
              ),
            ),
        },
      ],
    );
  }
}
