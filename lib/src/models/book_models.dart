import 'package:equatable/equatable.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;

/// 电子书（业务模型）
class Book extends Equatable {
  final String id;
  final String name;
  final String? sortName;
  final List<String>? authors;
  final List<String>? publishers;
  final List<String>? genres;
  final int? productionYear;
  final String? overview;
  final double? communityRating;
  final String? primaryImageTag;
  final String serverUrl;
  final String? accessToken;
  final String? parentId;
  final String? seriesName;
  final String? seriesId;
  final int? pageCount;
  final String? mediaType;
  final bool? played;
  final double? playedPercentage;
  final bool? isFavorite;

  const Book({
    required this.id,
    required this.name,
    required this.serverUrl,
    this.sortName,
    this.authors,
    this.publishers,
    this.genres,
    this.productionYear,
    this.overview,
    this.communityRating,
    this.primaryImageTag,
    this.accessToken,
    this.parentId,
    this.seriesName,
    this.seriesId,
    this.pageCount,
    this.mediaType,
    this.played,
    this.playedPercentage,
    this.isFavorite,
  });

  factory Book.fromDto(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final imageTags = dto.imageTags;
    final primaryTag = imageTags?['Primary'];
    final hasImageTag = primaryTag != null && primaryTag.isNotEmpty;
    final hasBlurHash = dto.imageBlurHashes != null;
    final hasImage = hasImageTag || hasBlurHash;

    // 提取作者（writer 角色人员）
    final authors = <String>[];
    for (final person in (dto.people ?? [])) {
      if (person.type == jellyfin_dart.PersonKind.writer && person.name != null) {
        authors.add(person.name!);
      }
    }

    // 提取出版社（studios）
    final publishers = dto.studios?.map((s) => s.name ?? '').where((n) => n.isNotEmpty).toList();

    final userData = dto.userData;

    return Book(
      id: dto.id ?? '',
      name: dto.name ?? '未知书籍',
      sortName: dto.sortName,
      serverUrl: serverUrl,
      authors: authors.isNotEmpty ? authors : null,
      publishers: publishers != null && publishers.isNotEmpty ? publishers : null,
      genres: dto.genres,
      productionYear: dto.productionYear,
      overview: dto.overview,
      communityRating: dto.communityRating,
      primaryImageTag: hasImageTag ? primaryTag : (hasImage ? 'has_image' : null),
      accessToken: accessToken,
      parentId: dto.parentId,
      seriesName: dto.seriesName,
      seriesId: dto.seriesId,
      pageCount: dto.childCount,
      mediaType: dto.mediaType?.value,
      played: userData?.played,
      playedPercentage: userData?.playedPercentage,
      isFavorite: userData?.isFavorite,
    );
  }

  /// 获取封面图URL
  String? getCoverImageUrl({int? fillWidth, int? fillHeight}) {
    if (primaryImageTag == null) return null;
    var url = '$serverUrl/Items/$id/Images/Primary?tag=$primaryImageTag';
    if (fillWidth != null) url += '&fillWidth=$fillWidth';
    if (fillHeight != null) url += '&fillHeight=$fillHeight';
    return url;
  }

  bool get hasCoverImage => primaryImageTag != null;

  /// 获取电子书下载URL
  String getDownloadUrl() {
    var url = '$serverUrl/Items/$id/Download';
    if (accessToken != null) url += '?api_key=$accessToken';
    return url;
  }

  /// 作者显示文本
  String get authorText => authors?.join(' / ') ?? '未知作者';

  /// 出版社显示文本
  String get publisherText => publishers?.join(' / ') ?? '';

  @override
  List<Object?> get props => [id, name, serverUrl, productionYear, authors];

  @override
  String toString() => 'Book(id: $id, name: $name, year: $productionYear)';
}

/// 书籍系列/丛书（业务模型）
class BookSeries extends Equatable {
  final String id;
  final String name;
  final String? sortName;
  final int? bookCount;
  final String? primaryImageTag;
  final String serverUrl;
  final String? accessToken;

  const BookSeries({
    required this.id,
    required this.name,
    required this.serverUrl,
    this.sortName,
    this.bookCount,
    this.primaryImageTag,
    this.accessToken,
  });

  factory BookSeries.fromDto(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final imageTags = dto.imageTags;
    final primaryTag = imageTags?['Primary'];
    final hasImageTag = primaryTag != null && primaryTag.isNotEmpty;
    final hasBlurHash = dto.imageBlurHashes != null;
    final hasImage = hasImageTag || hasBlurHash;

    return BookSeries(
      id: dto.id ?? '',
      name: dto.name ?? '未知系列',
      sortName: dto.sortName,
      serverUrl: serverUrl,
      bookCount: dto.childCount,
      primaryImageTag: hasImageTag ? primaryTag : (hasImage ? 'has_image' : null),
      accessToken: accessToken,
    );
  }

  String? getCoverImageUrl({int? fillWidth, int? fillHeight}) {
    if (primaryImageTag == null) return null;
    var url = '$serverUrl/Items/$id/Images/Primary?tag=$primaryImageTag';
    if (fillWidth != null) url += '&fillWidth=$fillWidth';
    if (fillHeight != null) url += '&fillHeight=$fillHeight';
    return url;
  }

  bool get hasCoverImage => primaryImageTag != null;

  @override
  List<Object?> get props => [id, name, serverUrl, bookCount];

  @override
  String toString() => 'BookSeries(id: $id, name: $name, count: $bookCount)';
}

/// 有声书（业务模型）
class AudioBook extends Equatable {
  final String id;
  final String name;
  final String? sortName;
  final List<String>? authors;
  final List<String>? publishers;
  final List<String>? genres;
  final int? productionYear;
  final String? overview;
  final double? communityRating;
  final String? primaryImageTag;
  final String serverUrl;
  final String? accessToken;
  final String? parentId;
  final String? seriesName;
  final String? seriesId;
  final int? runTimeTicks;
  final int? runTimeSeconds;
  final bool? played;
  final double? playedPercentage;
  final bool? isFavorite;

  const AudioBook({
    required this.id,
    required this.name,
    required this.serverUrl,
    this.sortName,
    this.authors,
    this.publishers,
    this.genres,
    this.productionYear,
    this.overview,
    this.communityRating,
    this.primaryImageTag,
    this.accessToken,
    this.parentId,
    this.seriesName,
    this.seriesId,
    this.runTimeTicks,
    this.runTimeSeconds,
    this.played,
    this.playedPercentage,
    this.isFavorite,
  });

  factory AudioBook.fromDto(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final imageTags = dto.imageTags;
    final primaryTag = imageTags?['Primary'];
    final hasImageTag = primaryTag != null && primaryTag.isNotEmpty;
    final hasBlurHash = dto.imageBlurHashes != null;
    final hasImage = hasImageTag || hasBlurHash;

    // 提取作者（writer 角色人员）
    final authors = <String>[];
    for (final person in (dto.people ?? [])) {
      if (person.type == jellyfin_dart.PersonKind.writer && person.name != null) {
        authors.add(person.name!);
      }
    }

    // 提取出版社（studios）
    final publishers = dto.studios?.map((s) => s.name ?? '').where((n) => n.isNotEmpty).toList();

    final runTimeSeconds = dto.runTimeTicks != null
        ? (dto.runTimeTicks! / 10000000).round()
        : null;

    final userData = dto.userData;

    return AudioBook(
      id: dto.id ?? '',
      name: dto.name ?? '未知有声书',
      sortName: dto.sortName,
      serverUrl: serverUrl,
      authors: authors.isNotEmpty ? authors : null,
      publishers: publishers != null && publishers.isNotEmpty ? publishers : null,
      genres: dto.genres,
      productionYear: dto.productionYear,
      overview: dto.overview,
      communityRating: dto.communityRating,
      primaryImageTag: hasImageTag ? primaryTag : (hasImage ? 'has_image' : null),
      accessToken: accessToken,
      parentId: dto.parentId,
      seriesName: dto.seriesName,
      seriesId: dto.seriesId,
      runTimeTicks: dto.runTimeTicks,
      runTimeSeconds: runTimeSeconds,
      played: userData?.played,
      playedPercentage: userData?.playedPercentage,
      isFavorite: userData?.isFavorite,
    );
  }

  /// 获取封面图URL
  String? getCoverImageUrl({int? fillWidth, int? fillHeight}) {
    if (primaryImageTag == null) return null;
    var url = '$serverUrl/Items/$id/Images/Primary?tag=$primaryImageTag';
    if (fillWidth != null) url += '&fillWidth=$fillWidth';
    if (fillHeight != null) url += '&fillHeight=$fillHeight';
    return url;
  }

  bool get hasCoverImage => primaryImageTag != null;

  /// 获取音频流URL（复用音乐播放的 Audio API）
  String getStreamUrl({int? startTimeTicks}) {
    var url = '$serverUrl/Audio/$id/stream';
    if (accessToken != null) url += '?api_key=$accessToken';
    if (startTimeTicks != null) url += '&startTimeTicks=$startTimeTicks';
    return url;
  }

  /// 获取播放时长文本
  String get durationText {
    if (runTimeSeconds == null) return '';
    final hours = runTimeSeconds! ~/ 3600;
    final minutes = (runTimeSeconds! % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}小时${minutes}分钟';
    }
    return '$minutes分钟';
  }

  /// 作者显示文本
  String get authorText => authors?.join(' / ') ?? '未知作者';

  @override
  List<Object?> get props => [id, name, serverUrl, runTimeTicks];

  @override
  String toString() => 'AudioBook(id: $id, name: $name, duration: $durationText)';
}

// ==================== 列表结果 ====================

/// 书籍列表结果
class BookListResult extends Equatable {
  final List<Book> books;
  final int? totalCount;
  final int? startIndex;

  const BookListResult({
    required this.books,
    this.totalCount,
    this.startIndex,
  });

  factory BookListResult.fromDto(
    jellyfin_dart.BaseItemDtoQueryResult dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final books = dto.items
            ?.map((item) => Book.fromDto(item, serverUrl, accessToken: accessToken))
            .toList() ??
        [];
    return BookListResult(
      books: books,
      totalCount: dto.totalRecordCount,
      startIndex: dto.startIndex,
    );
  }

  bool get isEmpty => books.isEmpty;
  bool get isNotEmpty => books.isNotEmpty;
  int get length => books.length;

  @override
  List<Object?> get props => [books, totalCount, startIndex];
}

/// 书籍系列列表结果
class BookSeriesListResult extends Equatable {
  final List<BookSeries> series;
  final int? totalCount;
  final int? startIndex;

  const BookSeriesListResult({
    required this.series,
    this.totalCount,
    this.startIndex,
  });

  factory BookSeriesListResult.fromDto(
    jellyfin_dart.BaseItemDtoQueryResult dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final series = dto.items
            ?.map((item) => BookSeries.fromDto(item, serverUrl, accessToken: accessToken))
            .toList() ??
        [];
    return BookSeriesListResult(
      series: series,
      totalCount: dto.totalRecordCount,
      startIndex: dto.startIndex,
    );
  }

  bool get isEmpty => series.isEmpty;
  bool get isNotEmpty => series.isNotEmpty;
  int get length => series.length;

  @override
  List<Object?> get props => [series, totalCount, startIndex];
}

/// 有声书列表结果
class AudioBookListResult extends Equatable {
  final List<AudioBook> audioBooks;
  final int? totalCount;
  final int? startIndex;

  const AudioBookListResult({
    required this.audioBooks,
    this.totalCount,
    this.startIndex,
  });

  factory AudioBookListResult.fromDto(
    jellyfin_dart.BaseItemDtoQueryResult dto,
    String serverUrl, {
    String? accessToken,
  }) {
    final audioBooks = dto.items
            ?.map((item) => AudioBook.fromDto(item, serverUrl, accessToken: accessToken))
            .toList() ??
        [];
    return AudioBookListResult(
      audioBooks: audioBooks,
      totalCount: dto.totalRecordCount,
      startIndex: dto.startIndex,
    );
  }

  bool get isEmpty => audioBooks.isEmpty;
  bool get isNotEmpty => audioBooks.isNotEmpty;
  int get length => audioBooks.length;

  @override
  List<Object?> get props => [audioBooks, totalCount, startIndex];
}
