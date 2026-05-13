import '../models/lyrics_models.dart';

/// 获取歌词回调
typedef LyricsFetcher = Future<LyricsData?> Function(String itemId);

/// 搜索远程歌词回调
typedef RemoteLyricsSearcher = Future<List<RemoteLyricsInfo>> Function(String itemId);

/// 下载远程歌词回调
typedef RemoteLyricsDownloader = Future<LyricsData> Function({
  required String itemId,
  required String lyricId,
});
