import 'package:flutter/widgets.dart';
import 'package:jellyfin_core/jellyfin_core.dart';
import 'package:jellyfin_music/src/models/music_models.dart';
import 'package:jellyfin_music/src/pages/album_detail_page.dart';
import 'package:jellyfin_music/src/pages/artist_detail_page.dart';
import 'package:jellyfin_music/src/pages/lyrics_page.dart';
import 'package:jellyfin_music/src/pages/music_library_page.dart';
import 'package:jellyfin_music/src/pages/music_player_page.dart';
import 'package:jellyfin_music/src/pages/music_search_page.dart';
import 'package:jellyfin_music/src/services/audio_playback_port.dart';
import 'package:jellyfin_music/src/services/lyrics_port.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

/// 音乐业务 Feature 模块
///
/// 自注册路由：音乐库、专辑详情、艺术家详情、搜索、播放、歌词。
/// 导航通过 ServiceRegistry 获取 AppNavigator，不需要 Product App 注入回调。
final class MusicFeatureModule extends JellyfinFeatureModule {
  MusicFeatureModule();

  @override
  String get name => 'music';

  @override
  String get version => '0.1.0';

  @override
  List<RouteDescriptor> buildRoutes(ModuleContext context) => [
    const RouteDescriptor(
      path: '/libraries/:libraryId/music',
      name: JellyfinRouteNames.musicLibrary,
    ),
    const RouteDescriptor(
      path: '/music/albums/:albumId',
      name: JellyfinRouteNames.musicAlbum,
    ),
    const RouteDescriptor(
      path: '/music/artists/:artistId',
      name: JellyfinRouteNames.musicArtist,
    ),
    const RouteDescriptor(
      path: '/libraries/:libraryId/music/search',
      name: JellyfinRouteNames.musicSearch,
    ),
    const RouteDescriptor(
      path: '/playback/music',
      name: JellyfinRouteNames.playbackMusic,
    ),
    const RouteDescriptor(
      path: '/music/lyrics',
      name: JellyfinRouteNames.musicLyrics,
    ),
  ];

  @override
  List<NavigationEntry> buildNavigationEntries(ModuleContext context) => [];

  @override
  Widget buildPage(
    BuildContext context,
    String routeName, {
    Map<String, String> pathParameters = const {},
    Object? extra,
  }) {
    switch (routeName) {
      case JellyfinRouteNames.musicLibrary:
        return _buildMusicLibraryPage(context, pathParameters, extra);

      case JellyfinRouteNames.musicAlbum:
        return _buildAlbumDetailPage(context, pathParameters, extra);

      case JellyfinRouteNames.musicArtist:
        return _buildArtistDetailPage(context, pathParameters, extra);

      case JellyfinRouteNames.musicSearch:
        return _buildMusicSearchPage(context, pathParameters, extra);

      case JellyfinRouteNames.playbackMusic:
        return _buildMusicPlayerPage(context, extra);

      case JellyfinRouteNames.musicLyrics:
        return _buildLyricsPage(context, extra);

      default:
        throw ArgumentError(
          'MusicFeatureModule: unknown route $routeName',
        );
    }
  }

  // ─── 音乐库页面 ───

  Widget _buildMusicLibraryPage(
    BuildContext context,
    Map<String, String> pathParameters,
    Object? extra,
  ) {
    final libraryId = pathParameters['libraryId'] ?? '';
    final libraryName = _extractString(extra, 'libraryName') ?? '音乐库';
    final fetchAlbums = ServiceRegistry.get<AlbumsFetcher>(context);
    final fetchArtists = ServiceRegistry.get<ArtistsFetcher>(context);
    final fetchSongs = ServiceRegistry.get<SongsFetcher>(context);
    final imageProvider = ServiceRegistry.tryGet<JellyfinImageProvider>(context);
    final onPlayTracks = ServiceRegistry.tryGet<OnPlayTracks>(context);
    final onSearch = _extractBool(extra, 'hasSearch') == true;
    final onOpenPersonal = _extractBool(extra, 'hasPersonal') == true;

    return MusicLibraryPage(
      libraryName: libraryName,
      libraryId: libraryId,
      fetchAlbums: fetchAlbums,
      fetchArtists: fetchArtists,
      fetchSongs: fetchSongs,
      onPlayTracks: onPlayTracks,
      imageProvider: imageProvider,
      enableSearch: onSearch,
      enablePersonal: onOpenPersonal,
    );
  }

  // ─── 专辑详情页面 ───

  Widget _buildAlbumDetailPage(
    BuildContext context,
    Map<String, String> pathParameters,
    Object? extra,
  ) {
    final albumId = pathParameters['albumId'] ?? '';
    final fetchAlbumDetail =
        ServiceRegistry.get<AlbumDetailFetcher>(context);
    final fetchAlbumSongs =
        ServiceRegistry.get<AlbumSongsFetcher>(context);
    final onPlaySong = ServiceRegistry.tryGet<OnPlaySong>(context);

    // extra 可能包含完整的 MusicAlbum
    final album = extra is MusicAlbum
        ? extra
        : MusicAlbum(
            id: albumId,
            name: '',
            serverUrl: '',
          );

    return AlbumDetailPage(
      album: album,
      fetchAlbumDetail: fetchAlbumDetail,
      fetchAlbumSongs: fetchAlbumSongs,
      onPlaySong: onPlaySong,
    );
  }

  // ─── 艺术家详情页面 ───

  Widget _buildArtistDetailPage(
    BuildContext context,
    Map<String, String> pathParameters,
    Object? extra,
  ) {
    final artistId = pathParameters['artistId'] ?? '';
    final fetchArtistDetail =
        ServiceRegistry.get<ArtistDetailFetcher>(context);
    final fetchArtistAlbums =
        ServiceRegistry.get<ArtistAlbumsFetcher>(context);

    // extra 可能包含完整的 MusicArtist
    final artist = extra is MusicArtist
        ? extra
        : MusicArtist(
            id: artistId,
            name: '',
            serverUrl: '',
          );

    return ArtistDetailPage(
      artist: artist,
      fetchArtistDetail: fetchArtistDetail,
      fetchArtistAlbums: fetchArtistAlbums,
    );
  }

  // ─── 音乐搜索页面 ───

  Widget _buildMusicSearchPage(
    BuildContext context,
    Map<String, String> pathParameters,
    Object? extra,
  ) {
    final libraryId = pathParameters['libraryId'];
    final search = ServiceRegistry.get<MusicSearchFetcher>(context);
    final onPlayTracks = ServiceRegistry.tryGet<OnPlayTracks>(context);

    return MusicSearchPage(
      libraryId: libraryId,
      search: search,
      onPlayTracks: onPlayTracks,
    );
  }

  // ─── 音乐播放页面 ───

  Widget _buildMusicPlayerPage(
    BuildContext context,
    Object? extra,
  ) {
    final playbackPort = ServiceRegistry.get<AudioPlaybackPort>(context);
    final fetchLyrics = ServiceRegistry.tryGet<LyricsFetcher>(context);

    return MusicPlayerPage(
      playbackPort: playbackPort,
      fetchLyrics: fetchLyrics,
    );
  }

  // ─── 歌词页面 ───

  Widget _buildLyricsPage(
    BuildContext context,
    Object? extra,
  ) {
    final playbackPort = ServiceRegistry.get<AudioPlaybackPort>(context);
    final fetchLyrics = ServiceRegistry.get<LyricsFetcher>(context);
    final searchRemoteLyrics =
        ServiceRegistry.tryGet<RemoteLyricsSearcher>(context);
    final downloadRemoteLyrics =
        ServiceRegistry.tryGet<RemoteLyricsDownloader>(context);

    // extra 可包含 albumCoverUrl
    final albumCoverUrl = extra is Map<String, Object?>
        ? extra['albumCoverUrl'] as String?
        : null;

    return LyricsPage(
      playbackPort: playbackPort,
      fetchLyrics: fetchLyrics,
      searchRemoteLyrics: searchRemoteLyrics,
      downloadRemoteLyrics: downloadRemoteLyrics,
      albumCoverUrl: albumCoverUrl,
    );
  }

  // ─── 工具方法 ───

  String? _extractString(Object? extra, String key) {
    if (extra is Map<String, Object?>) return extra[key] as String?;
    return null;
  }

  bool? _extractBool(Object? extra, String key) {
    if (extra is Map<String, Object?>) return extra[key] as bool?;
    return null;
  }
}
