import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_theme.dart';
import '../../../shared/widgets/cached_app_image.dart';
import '../data/watch_repository.dart';

/// A tappable video tile. [horizontal] is the compact thumbnail-left variant
/// used for "Up next".
class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video, this.horizontal = false});
  final WatchVideo video;
  final bool horizontal;

  Widget _thumbnail() {
    final duration = formatVideoDuration(video.durationSeconds);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video.thumbnail.isEmpty)
              const ColoredBox(color: AppTheme.muted)
            else
              CachedAppImage(imageUrl: video.thumbnail, fit: BoxFit.cover),
            if (video.videoType != null)
              Positioned(
                left: 6,
                top: 6,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: _Badge(video.videoType!.name),
                ),
              ),
            if (duration.isNotEmpty)
              Positioned(right: 6, bottom: 6, child: _Badge(duration)),
          ],
        ),
      ),
    );
  }

  Widget _texts(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        video.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      if (video.story != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            video.story!.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.mutedForeground,
              fontSize: 12,
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => context.push('/watch/${video.id}'),
    child: horizontal
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 144, child: _thumbnail()),
              const SizedBox(width: 10),
              Expanded(child: _texts(context)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumbnail(),
              const SizedBox(height: 8),
              _texts(context),
            ],
          ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
