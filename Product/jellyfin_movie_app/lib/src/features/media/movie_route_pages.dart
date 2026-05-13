import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_movies/jellyfin_movies_pages.dart';

import '../../data/jellyfin_gateway.dart';

// ──────────────────────────── 电影筛选页 ────────────────────────────

class MoviesRoutePage extends StatelessWidget {
  final JellyfinGateway gateway;
  final String libraryId;
  final String libraryName;

  const MoviesRoutePage({
    super.key,
    required this.gateway,
    required this.libraryId,
    required this.libraryName,
  });

  @override
  Widget build(BuildContext context) {
    return MovieFilterPage(
      libraryId: libraryId,
      libraryName: libraryName,
      fetchMovies: gateway.fetchMovies,
      onNavigateToMovie: (context, item) {
        context.push('/movies/${item.id}');
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
