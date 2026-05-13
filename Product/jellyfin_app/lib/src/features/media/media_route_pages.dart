/// 媒体路由页面
///
/// 每个路由对应一个 Widget，负责从 path parameter 取参数 →
/// FutureBuilder 加载数据 → 传给 feature 页面 → navigate 回调走路由。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_movies/jellyfin_movies_pages.dart';
import 'package:jellyfin_media/jellyfin_media_pages.dart';
import 'package:jellyfin_series/jellyfin_series_pages.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../../data/jellyfin_gateway.dart';
import '../../ui/jellyfin_app_image_provider.dart';

// ──────────────────────────── 剧集列表页 ────────────────────────────

class SeriesListRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final models.MediaLibrary library;

  const SeriesListRoutePage({
    super.key,
    required this.gateway,
    required this.library,
  });

  @override
  Widget build(BuildContext context) {
    return MediaItemsPage(
      library: library,
      fetchMediaItems: gateway.fetchMediaItems,
      onNavigateToMediaItem: (context, item) {
        context.push('/media/items/${item.id}');
      },
    );
  }
}

// ──────────────────────────── 电影筛选页 ────────────────────────────

class MoviesRoutePage extends StatefulWidget {
  final JellyfinGateway gateway;
  final String libraryId;
  final String libraryName;
  final JellyfinAppImageProvider imageProvider;

  const MoviesRoutePage({
    super.key,
    required this.gateway,
    required this.libraryId,
    required this.libraryName,
    required this.imageProvider,
  });

  @override
  State<MoviesRoutePage> createState() => _MoviesRoutePageState();
}

class _MoviesRoutePageState extends State<MoviesRoutePage> {
  ViewModeConfig _viewModeConfig = const ViewModeConfig();

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final config = await ViewModeManager().getViewModeConfig(widget.libraryId);
    if (mounted) {
      setState(() => _viewModeConfig = config);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MovieFilterPage(
      libraryId: widget.libraryId,
      libraryName: widget.libraryName,
      fetchMovies: widget.gateway.fetchMovies,
      onNavigateToMovie: (context, item) {
        context.push('/movies/${item.id}');
      },
      appBarActions: [
        ViewModeSelector(
          libraryId: widget.libraryId,
          onViewModeChanged: (config) {
            setState(() => _viewModeConfig = config);
          },
        ),
      ],
      listBuilder: ({required items, required onTap}) {
        return MediaListBuilder(
          imageProvider: widget.imageProvider,
          items: items,
          config: _viewModeConfig,
          onTap: onTap,
        );
      },
    );
  }
}

// ──────────────────────────── 电影详情页 ────────────────────────────

class MovieDetailRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String itemId;

  const MovieDetailRoutePage({
    super.key,
    required this.gateway,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.MediaItem>(
      future: gateway.getMediaItemDetail(itemId),
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

        final movie = snapshot.data!;
        return MovieDetailPage(
          movie: movie,
          fetchDetail: gateway.getMediaItemDetail,
          onStartPlayback: (context, item) {
            context.push('/playback/video/${item.id}');
          },
        );
      },
    );
  }
}

// ──────────────────────────── 通用媒体详情页 ────────────────────────────

class MediaDetailRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String itemId;

  const MediaDetailRoutePage({
    super.key,
    required this.gateway,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.MediaItem>(
      future: gateway.getMediaItemDetail(itemId),
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

        final item = snapshot.data!;
        return MediaItemDetailPage(
          item: item,
          fetchDetail: gateway.getMediaItemDetail,
          fetchSeasons: item.type.toLowerCase() == 'series'
              ? gateway.getSeasons
              : null,
          onNavigateToEpisodes: (context, series, season) {
            context.push(
              '/series/${series.id}/seasons/${season.id}/episodes',
            );
          },
          onStartPlayback: (context, item) {
            context.push('/playback/video/${item.id}');
          },
        );
      },
    );
  }
}

// ──────────────────────────── 剧集季列表页 ────────────────────────────

class SeriesSeasonsRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String seriesId;

  const SeriesSeasonsRoutePage({
    super.key,
    required this.gateway,
    required this.seriesId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.MediaItem>(
      future: gateway.getMediaItemDetail(seriesId),
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

        final series = snapshot.data!;
        return SeasonsPage(
          series: series,
          fetchSeasons: gateway.getSeasons,
          onNavigateToEpisodes: (context, series, season) {
            context.push(
              '/series/${series.id}/seasons/${season.id}/episodes',
            );
          },
        );
      },
    );
  }
}

// ──────────────────────────── 剧集集列表页 ────────────────────────────

class SeriesEpisodesRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String seriesId;
  final String seasonId;

  const SeriesEpisodesRoutePage({
    super.key,
    required this.gateway,
    required this.seriesId,
    required this.seasonId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.SeasonListResult>(
      future: gateway.getSeasons(seriesId),
      builder: (context, seasonsSnapshot) {
        if (seasonsSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (seasonsSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('错误')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${seasonsSnapshot.error}', textAlign: TextAlign.center),
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

        // 先取 series 信息
        return FutureBuilder<models.MediaItem>(
          future: gateway.getMediaItemDetail(seriesId),
          builder: (context, seriesSnapshot) {
            if (seriesSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final series = seriesSnapshot.data ?? models.MediaItem(
              id: seriesId,
              name: '',
              type: 'Series',
              serverUrl: '',
            );

            // 找到当前 season
            final seasons = seasonsSnapshot.data?.seasons ?? [];
            final season = seasons.firstWhere(
              (s) => s.id == seasonId,
              orElse: () => models.Season(
                id: seasonId,
                seriesId: seriesId,
                name: '',
                indexNumber: 0,
                serverUrl: '',
              ),
            );

            return EpisodesPage(
              series: series,
              season: season,
              fetchEpisodes: gateway.getEpisodes,
              onStartPlayback: (context, episode) {
                context.push('/playback/video/${episode.id}');
              },
            );
          },
        );
      },
    );
  }
}
