import 'package:equatable/equatable.dart';

/// 个人模块支持的媒体类型
enum PersonalMediaKind {
  movie('Movie'),
  series('Series'),
  episode('Episode'),
  audio('Audio'),
  musicAlbum('MusicAlbum'),
  musicArtist('MusicArtist');

  const PersonalMediaKind(this.jellyfinTypeName);

  final String jellyfinTypeName;
}

/// 媒体类型预设集合
final class PersonalMediaKindSets {
  static const all = <PersonalMediaKind>[
    PersonalMediaKind.movie,
    PersonalMediaKind.series,
    PersonalMediaKind.episode,
    PersonalMediaKind.audio,
    PersonalMediaKind.musicAlbum,
    PersonalMediaKind.musicArtist,
  ];

  static const video = <PersonalMediaKind>[
    PersonalMediaKind.movie,
    PersonalMediaKind.series,
    PersonalMediaKind.episode,
  ];

  static const moviesOnly = <PersonalMediaKind>[
    PersonalMediaKind.movie,
  ];

  static const music = <PersonalMediaKind>[
    PersonalMediaKind.audio,
    PersonalMediaKind.musicAlbum,
    PersonalMediaKind.musicArtist,
  ];

  const PersonalMediaKindSets._();
}

/// 媒体类型过滤
enum PersonalMediaTypeFilter {
  all('全部'),
  video('视频'),
  music('音乐');

  const PersonalMediaTypeFilter(this.label);

  final String label;

  /// 将过滤转换为媒体类型列表
  List<PersonalMediaKind> filterKinds(List<PersonalMediaKind> base) {
    return switch (this) {
      PersonalMediaTypeFilter.all => base,
      PersonalMediaTypeFilter.video => base
          .where((k) => PersonalMediaKindSets.video.contains(k))
          .toList(),
      PersonalMediaTypeFilter.music => base
          .where((k) => PersonalMediaKindSets.music.contains(k))
          .toList(),
    };
  }
}

/// 个人模块媒体查询参数
final class PersonalMediaQuery extends Equatable {
  final int startIndex;
  final int limit;
  final List<PersonalMediaKind> mediaKinds;

  const PersonalMediaQuery({
    this.startIndex = 0,
    this.limit = 30,
    this.mediaKinds = PersonalMediaKindSets.all,
  });

  PersonalMediaQuery copyWith({
    int? startIndex,
    int? limit,
    List<PersonalMediaKind>? mediaKinds,
  }) {
    return PersonalMediaQuery(
      startIndex: startIndex ?? this.startIndex,
      limit: limit ?? this.limit,
      mediaKinds: mediaKinds ?? this.mediaKinds,
    );
  }

  @override
  List<Object?> get props => [startIndex, limit, mediaKinds];
}
