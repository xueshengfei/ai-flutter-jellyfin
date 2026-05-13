import 'package:equatable/equatable.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;

/// 区块加载状态
enum PersonalSectionStatus {
  initial,
  loading,
  loaded,
  empty,
  failure,
}

/// 个人区块状态
final class PersonalSectionState extends Equatable {
  final PersonalSectionStatus status;
  final List<models.MediaItem> items;
  final String? errorMessage;

  const PersonalSectionState({
    this.status = PersonalSectionStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  const PersonalSectionState.loading()
      : status = PersonalSectionStatus.loading,
        items = const [],
        errorMessage = null;

  const PersonalSectionState.failure(String message)
      : status = PersonalSectionStatus.failure,
        items = const [],
        errorMessage = message;

  factory PersonalSectionState.loaded(List<models.MediaItem> items) {
    return PersonalSectionState(
      status: items.isEmpty
          ? PersonalSectionStatus.empty
          : PersonalSectionStatus.loaded,
      items: items,
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
