import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

// MediaItemDetailFetcher ? SeasonsFetcher ???? jellyfin_models/media_contracts.dart
// ?? re-export ?????? jellyfin_media_pages.dart ????

/// ?????????
///
/// ?????????Movie, Series, Episode ?
/// ????????????????
class MediaItemDetailPage extends StatefulWidget {
  /// ???????
  final MediaItem item;

  /// ??????
  final MediaItemDetailFetcher fetchDetail;

  /// ???????
  final SeasonsFetcher? fetchSeasons;

  /// ????????
  final void Function(BuildContext context, String personId, String personName,
      String personType)? onNavigateToPerson;

  /// ????????
  final void Function(BuildContext context, MediaItem series, Season season)?
      onNavigateToEpisodes;

  /// ????
  final void Function(BuildContext context, MediaItem item)? onStartPlayback;

  /// ?????
  ///
  /// ???????????????????? App ???????????
  final void Function(BuildContext context, MediaItem item)? onStartDownload;

  /// ???????????? JellyfinImage?? null ???? Image.network
  final JellyfinImageProvider? imageProvider;

  const MediaItemDetailPage({
    super.key,
    required this.item,
    required this.fetchDetail,
    this.fetchSeasons,
    this.onNavigateToPerson,
    this.onNavigateToEpisodes,
    this.onStartPlayback,
    this.onStartDownload,
    this.imageProvider,
  });

  @override
  State<MediaItemDetailPage> createState() => _MediaItemDetailPageState();
}

class _MediaItemDetailPageState extends State<MediaItemDetailPage> {
  late Future<MediaItem> _detailFuture;
  Future<SeasonListResult>? _seasonsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _detailFuture = widget.fetchDetail(widget.item.id);

      if (widget.item.type.toLowerCase() == 'series' &&
          widget.fetchSeasons != null) {
        _seasonsFuture = widget.fetchSeasons!(widget.item.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.item.name,
                style: TextStyle(
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 8,
                      color: Colors.black.withOpacity(0.8),
                    ),
                  ],
                ),
              ),
              background: _buildBackdrop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: _startPlayback,
                tooltip: '??',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
              ),
              if (widget.onStartDownload != null)
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => widget.onStartDownload?.call(
                    context,
                    widget.item,
                  ),
                  tooltip: '??',
                ),
            ],
          ),
          FutureBuilder<MediaItem>(
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('??????...'),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('????: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadData,
                          child: const Text('??'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final item = snapshot.data!;
              return SliverToBoxAdapter(
                child: _buildContent(item),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    if (widget.item.hasBackdropImage) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.imageProvider != null)
            JellyfinImage(
              imageProvider: widget.imageProvider!,
              itemId: widget.item.id,
              imageType: JellyfinImageType.backdrop,
              imageTag: widget.item.backdropImageTag,
              fillWidth: 800,
              fillHeight: 450,
              fit: BoxFit.cover,
              errorWidget: Container(
                color: Theme.of(context).colorScheme.surface,
              ),
            )
          else
            Image.network(
              widget.item.getBackdropImageUrl()!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context).colorScheme.surface,
                );
              },
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      return Container(
        color: Theme.of(context).colorScheme.surface,
        child: Icon(
          Icons.movie_outlined,
          size: 100,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
  }

  Widget _buildContent(MediaItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildHeaderInfo(item),
        ),
        const SizedBox(height: 16),

        // ????
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _startPlayback,
              icon: const Icon(Icons.play_arrow),
              label: const Text('??'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ????
        if (item.overview != null && item.overview!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('????'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    item.overview!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: Colors.grey.shade700,
                        ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

        // ???
        if (item.type.toLowerCase() == 'series') _buildSeasonsList(),
        const SizedBox(height: 24),

        // ????
        if (item.actorInfos != null && item.actorInfos!.isNotEmpty)
          PersonListRow(
            persons: item.actorInfos!,
            title: '??',
            itemBuilder: (person) => PersonAvatarCard(
              person: person,
              onTap: () {
                if (person.id != null) {
                  widget.onNavigateToPerson
                      ?.call(context, person.id!, person.name, 'actor');
                }
              },
            ),
          ),
        const SizedBox(height: 24),

        // ????
        if (item.directorInfos != null && item.directorInfos!.isNotEmpty)
          PersonListRow(
            persons: item.directorInfos!,
            title: '??',
            itemBuilder: (person) => PersonAvatarCard(
              person: person,
              onTap: () {
                if (person.id != null) {
                  widget.onNavigateToPerson
                      ?.call(context, person.id!, person.name, 'director');
                }
              },
            ),
          ),
        const SizedBox(height: 24),

        // ????
        if (item.writerInfos != null && item.writerInfos!.isNotEmpty)
          PersonListRow(
            persons: item.writerInfos!,
            title: '??',
            itemBuilder: (person) => PersonAvatarCard(
              person: person,
              onTap: () {
                if (person.id != null) {
                  widget.onNavigateToPerson
                      ?.call(context, person.id!, person.name, 'writer');
                }
              },
            ),
          ),
        const SizedBox(height: 24),

        // ????
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildAdditionalInfo(item),
        ),
      ],
    );
  }

  Widget _buildHeaderInfo(MediaItem item) {
    return Row(
      children: [
        if (item.hasCoverImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.imageProvider != null
                ? JellyfinImage(
                    imageProvider: widget.imageProvider!,
                    itemId: item.id,
                    imageTag: item.primaryImageTag,
                    fillWidth: 200,
                    fillHeight: 300,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      width: 100,
                      height: 150,
                      color: Colors.grey.shade300,
                      child: Icon(Icons.movie, color: Colors.grey),
                    ),
                  )
                : Image.network(
                    item.getCoverImageUrl()!,
                    width: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 150,
                        color: Colors.grey.shade300,
                        child: Icon(Icons.movie, color: Colors.grey),
                      );
                    },
                  ),
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (item.productionYear != null)
                    Chip(
                      label: Text('${item.productionYear}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (item.officialRating != null)
                    Chip(
                      label: Text(item.officialRating!),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.orange.shade100,
                    ),
                  if (item.runTimeMinutes != null)
                    Chip(
                      label: Text(item.durationText),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (widget.onStartDownload != null)
                    ActionChip(
                      avatar: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('??'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        widget.onStartDownload?.call(context, item);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (item.communityRating != null)
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      item.ratingText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonsList() {
    if (_seasonsFuture == null) return const SizedBox.shrink();

    return FutureBuilder<SeasonListResult>(
      future: _seasonsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.seasons.isEmpty) {
          return const SizedBox.shrink();
        }

        final seasons = snapshot.data!.seasons;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: seasons.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildSeasonCard(seasons[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSeasonCard(Season season) {
    return InkWell(
      onTap: () {
        widget.onNavigateToEpisodes?.call(context, widget.item, season);
      },
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: season.hasCoverImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: widget.imageProvider != null
                            ? JellyfinImage(
                                imageProvider: widget.imageProvider!,
                                itemId: season.id,
                                imageTag: season.primaryImageTag,
                                fillWidth: 240,
                                fillHeight: 360,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: Center(
                                    child: Text(
                                      season.seasonNumberText,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                  ),
                                ),
                              )
                            : Image.network(
                                season.getCoverImageUrl()!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: Center(
                                      child: Text(
                                        season.seasonNumberText,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      )
                    : Center(
                        child: Text(
                          season.seasonNumberText,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              season.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (season.episodeCount != null)
              Text(
                '${season.episodeCount} ?',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfo(MediaItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.genres != null && item.genres!.isNotEmpty) ...[
          _buildSectionTitle('??'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.genres!
                  .map((genre) => Chip(
                        label: Text(genre),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (item.studios != null && item.studios!.isNotEmpty) ...[
          _buildSectionTitle('???'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.studios!
                  .map((studio) => Chip(
                        avatar: const Icon(Icons.business, size: 16),
                        label: Text(studio),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _startPlayback() {
    widget.onStartPlayback?.call(context, widget.item);
  }
}
