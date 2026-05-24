/// 音乐路由页面
///
/// App 业务编排层 — 只负责：
/// - 从 route 参数拿 libraryId / albumId / artistId
/// - 注入 JellyfinGateway 回调
/// - 注入 AudioPlaybackPort
/// - 用 MusicAreaShell 包裹迷你播放器
/// - 处理 context.push(...)
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_music/jellyfin_music.dart' as music;
import 'package:jellyfin_music/jellyfin_music_pages.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../../data/jellyfin_gateway.dart';

// ──────────────────────────── MusicSong → AudioTrack 转换 ────────────────────────────

/// 将 [MusicSong] 转为 [AudioTrack]
music.AudioTrack _songToTrack(music.MusicSong song) {
  return music.AudioTrack(
    id: song.id,
    name: song.name,
    streamUrl: song.getStreamUrl(),
    coverUrl: song.getAlbumCoverUrl(fillWidth: 480, fillHeight: 480),
    artistText: song.artistText,
    duration: song.runTimeSeconds != null
        ? Duration(seconds: song.runTimeSeconds!)
        : null,
    albumName: song.albumName,
    trackNumber: song.trackNumber,
    isFavorite: song.isFavorite,
    path: song.path,
  );
}

/// 批量转换歌曲列表为音轨列表
List<music.AudioTrack> _songsToTracks(List<music.MusicSong> songs) {
  return songs.map(_songToTrack).toList();
}

// ──────────────────────────── 音乐库列表页 ────────────────────────────

class MusicLibraryRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final music.AudioPlaybackPort? audioPlaybackPort;
  final String libraryId;
  final String libraryName;
  final JellyfinImageProvider? imageProvider;
  final VoidCallback? onOpenPersonal;

  const MusicLibraryRoutePage({
    super.key,
    required this.gateway,
    this.audioPlaybackPort,
    required this.libraryId,
    required this.libraryName,
    this.imageProvider,
    this.onOpenPersonal,
  });

  @override
  Widget build(BuildContext context) {
    final port = audioPlaybackPort;
    final page = MusicLibraryPage(
      libraryName: libraryName,
      libraryId: libraryId,
      fetchAlbums: ({required parentId, startIndex, limit, sortBy}) =>
          gateway.fetchAlbums(
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
        sortBy: sortBy,
      ),
      fetchArtists: ({required parentId, startIndex, limit}) =>
          gateway.fetchArtists(
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
      ),
      fetchSongs: ({required parentId, startIndex, limit}) =>
          gateway.fetchSongs(
        parentId: parentId,
        startIndex: startIndex,
        limit: limit,
      ),
      onOpenAlbum: (ctx, album) =>
          ctx.push('/music/albums/${album.id}'),
      onOpenArtist: (ctx, artist) =>
          ctx.push('/music/artists/${artist.id}'),
      onPlayTracks: port != null
          ? (ctx, tracks, startIndex) {
              port.playSong(tracks[startIndex], tracks, startIndex);
              ctx.push('/playback/music');
            }
          : null,
      onSearch: () => context.push(
        '/libraries/$libraryId/music/search?name=${Uri.encodeComponent(libraryName)}',
      ),
      onOpenPersonal: onOpenPersonal,
      imageProvider: imageProvider,
    );

    if (port == null) return page;
    return MusicAreaShell(
      audioPlaybackPort: port,
      onOpenMusicPlayer: () => context.push('/playback/music'),
      child: page,
    );
  }
}

// ──────────────────────────── 专辑详情页 ────────────────────────────

class AlbumDetailRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final music.AudioPlaybackPort? audioPlaybackPort;
  final String albumId;

  const AlbumDetailRoutePage({
    super.key,
    required this.gateway,
    this.audioPlaybackPort,
    required this.albumId,
  });

  @override
  Widget build(BuildContext context) {
    final port = audioPlaybackPort;
    final futurePage = FutureBuilder<dynamic>(
      future: gateway.getAlbumDetail(albumId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('错误')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          );
        }

        final album = snapshot.data!;
        return AlbumDetailPage(
          album: album,
          fetchAlbumDetail: gateway.getAlbumDetail,
          fetchAlbumSongs: gateway.getAlbumSongs,
          onPlaySong: (context, song, playlist, initialIndex) {
            if (port == null) return;

            final tracks = _songsToTracks(playlist);
            port.playSong(tracks[initialIndex], tracks, initialIndex);
            context.push('/playback/music');
          },
        );
      },
    );

    if (port == null) return futurePage;
    return MusicAreaShell(
      audioPlaybackPort: port,
      onOpenMusicPlayer: () => context.push('/playback/music'),
      child: futurePage,
    );
  }
}

// ──────────────────────────── 艺术家详情页 ────────────────────────────

class ArtistDetailRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final music.AudioPlaybackPort? audioPlaybackPort;
  final String artistId;

  const ArtistDetailRoutePage({
    super.key,
    required this.gateway,
    this.audioPlaybackPort,
    required this.artistId,
  });

  @override
  Widget build(BuildContext context) {
    final port = audioPlaybackPort;
    final futurePage = FutureBuilder<dynamic>(
      future: gateway.getArtistDetail(artistId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('错误')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          );
        }

        final artist = snapshot.data!;
        return ArtistDetailPage(
          artist: artist,
          fetchArtistDetail: gateway.getArtistDetail,
          fetchArtistAlbums: gateway.getArtistAlbums,
          onNavigateToAlbum: (context, album) {
            context.push('/music/albums/${album.id}');
          },
        );
      },
    );

    if (port == null) return futurePage;
    return MusicAreaShell(
      audioPlaybackPort: port,
      onOpenMusicPlayer: () => context.push('/playback/music'),
      child: futurePage,
    );
  }
}

// ──────────────────────────── 音乐搜索页 ────────────────────────────

class MusicSearchRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final music.AudioPlaybackPort? audioPlaybackPort;
  final String libraryId;

  const MusicSearchRoutePage({
    super.key,
    required this.gateway,
    this.audioPlaybackPort,
    required this.libraryId,
  });

  @override
  Widget build(BuildContext context) {
    final port = audioPlaybackPort;
    final page = MusicSearchPage(
      libraryId: libraryId,
      search: ({required searchTerm, parentId, limit}) =>
          gateway.searchMusic(
        searchTerm: searchTerm,
        parentId: parentId,
        limit: limit,
      ),
      onOpenAlbum: (ctx, album) =>
          ctx.push('/music/albums/${album.id}'),
      onOpenArtist: (ctx, artist) =>
          ctx.push('/music/artists/${artist.id}'),
      onPlayTracks: port != null
          ? (ctx, tracks, startIndex) {
              port.playSong(tracks[startIndex], tracks, startIndex);
              ctx.push('/playback/music');
            }
          : null,
    );

    if (port == null) return page;
    return MusicAreaShell(
      audioPlaybackPort: port,
      onOpenMusicPlayer: () => context.push('/playback/music'),
      child: page,
    );
  }
}

// ──────────────────────────── 音乐播放页 ────────────────────────────

class MusicPlayerRoutePage extends StatelessWidget {
  final music.AudioPlaybackPort audioPlaybackPort;
  final JellyfinGateway gateway;

  const MusicPlayerRoutePage({
    super.key,
    required this.audioPlaybackPort,
    required this.gateway,
  });

  @override
  Widget build(BuildContext context) {
    return MusicPlayerPage(
      playbackPort: audioPlaybackPort,
      onOpenLyrics: () => context.push('/music/lyrics'),
    );
  }
}

// ──────────────────────────── 歌词页 ────────────────────────────

class LyricsRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final music.AudioPlaybackPort audioPlaybackPort;

  const LyricsRoutePage({
    super.key,
    required this.gateway,
    required this.audioPlaybackPort,
  });

  @override
  Widget build(BuildContext context) {
    final track = audioPlaybackPort.currentTrack;
    if (track == null) {
      return const Scaffold(
        body: Center(child: Text('当前没有播放歌曲')),
      );
    }

    return LyricsPage(
      playbackPort: audioPlaybackPort,
      fetchLyrics: (itemId) => gateway.getLyrics(itemId),
      searchRemoteLyrics: (itemId) => gateway.searchRemoteLyrics(itemId),
      downloadRemoteLyrics: ({required itemId, required lyricId}) =>
          gateway.downloadRemoteLyrics(itemId: itemId, lyricId: lyricId),
    );
  }
}
