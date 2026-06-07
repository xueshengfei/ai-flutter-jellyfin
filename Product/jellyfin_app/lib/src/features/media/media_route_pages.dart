/// ??????
///
/// ???????? Widget???? path parameter ??? ?
/// FutureBuilder ???? ? ?? feature ?? ? navigate ??????
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

// ???????????????????????????? ????? ????????????????????????????

class SeriesListRoutePage extends StatefulWidget {
  final JellyfinGateway gateway;
  final models.MediaLibrary library;
  final JellyfinAppImageProvider imageProvider;

  const SeriesListRoutePage({
    super.key,
    required this.gateway,
    required this.library,
    required this.imageProvider,
  });

  @override
  State<SeriesListRoutePage> createState() => _SeriesListRoutePageState();
}

class _SeriesListRoutePageState extends State<SeriesListRoutePage> {
  ViewModeConfig _viewModeConfig = const ViewModeConfig();

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final config = await ViewModeManager().getViewModeConfig(widget.library.id);
    if (mounted) {
      setState(() => _viewModeConfig = config);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaItemsPage(
      library: widget.library,
      fetchMediaItems: widget.gateway.fetchMediaItems,
      onNavigateToMediaItem: (context, item) {
        context.push('/media/items/${item.id}');
      },
      appBarActions: [
        ViewModeSelector(
          libraryId: widget.library.id,
          onViewModeChanged: (config) {
            setState(() => _viewModeConfig = config);
          },
        ),
      ],
      listBuilder: (items, onTap) {
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

// ???????????????????????????? ????? ????????????????????????????

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

// ???????????????????????????? ????? ????????????????????????????

class MovieDetailRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String itemId;
  final JellyfinAppImageProvider? imageProvider;
  final void Function(BuildContext context, models.MediaItem movie)?
      onStartDownload;

  const MovieDetailRoutePage({
    super.key,
    required this.gateway,
    required this.itemId,
    this.imageProvider,
    this.onStartDownload,
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
            appBar: AppBar(title: const Text('??')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('??'),
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
          imageProvider: imageProvider,
          onStartPlayback: (context, item) {
            context.push('/playback/video/${item.id}');
          },
          onStartDownload: onStartDownload,
        );
      },
    );
  }
}

// ???????????????????????????? ??????? ????????????????????????????

class MediaDetailRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String itemId;
  final JellyfinAppImageProvider? imageProvider;
  final void Function(BuildContext context, models.MediaItem item)?
      onStartDownload;

  const MediaDetailRoutePage({
    super.key,
    required this.gateway,
    required this.itemId,
    this.imageProvider,
    this.onStartDownload,
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
            appBar: AppBar(title: const Text('??')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('??'),
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
          imageProvider: imageProvider,
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
          onStartDownload: onStartDownload,
        );
      },
    );
  }
}

// ???????????????????????????? ?????? ????????????????????????????

class SeriesSeasonsRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String seriesId;
  final JellyfinAppImageProvider? imageProvider;

  const SeriesSeasonsRoutePage({
    super.key,
    required this.gateway,
    required this.seriesId,
    this.imageProvider,
    this.onStartDownload,
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
            appBar: AppBar(title: const Text('??')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('??'),
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
          imageProvider: imageProvider,
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

// ???????????????????????????? ?????? ????????????????????????????

class SeriesEpisodesRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String seriesId;
  final String seasonId;
  final JellyfinAppImageProvider? imageProvider;

  const SeriesEpisodesRoutePage({
    super.key,
    required this.gateway,
    required this.seriesId,
    required this.seasonId,
    this.imageProvider,
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
            appBar: AppBar(title: const Text('??')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${seasonsSnapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('??'),
                  ),
                ],
              ),
            ),
          );
        }

        // ?? series ??
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

            // ???? season
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
              imageProvider: imageProvider,
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
