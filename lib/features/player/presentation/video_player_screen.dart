import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../auth/application/auth_controller.dart';
import '../../engagement/presentation/completion_signals.dart';
import '../../story/presentation/story_detail_screen.dart';
import '../data/video_progress_repository.dart';
import '../../../core/api_error_view.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.storySlug,
    required this.videoSlug,
  });
  final String storySlug;
  final String videoSlug;
  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  YoutubePlayerController? controller;
  Timer? saveTimer;
  bool initStarted = false;

  bool get signedIn => ref.read(authControllerProvider).value != null;

  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoSlug != widget.videoSlug) {
      initStarted = false;
      controller?.close();
      controller = null;
      setState(() {});
    }
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    controller?.close();
    super.dispose();
  }

  Future<void> _init(String youtubeId) async {
    if (initStarted) return;
    initStarted = true;
    // `await`ing before `setState` keeps this out of the synchronous
    // build/didUpdateWidget call stack (see the EPUB reader's equivalent fix
    // in Milestone 3 for why calling setState synchronously there is unsafe).
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    double? initialPositionSeconds;
    if (signedIn) {
      try {
        final saved = await ref
            .read(videoProgressRepositoryProvider)
            .fetch(widget.storySlug);
        if (saved?.videoSlug == widget.videoSlug) {
          initialPositionSeconds = saved!.positionSeconds;
        }
      } catch (_) {
        // Best-effort restore; fall back to the start of the video.
      }
    }
    if (!mounted) return;
    final newController = YoutubePlayerController.fromVideoId(
      videoId: youtubeId,
      autoPlay: true,
      startSeconds: initialPositionSeconds,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
    newController.videoStateStream.listen(_onStateChanged);
    setState(() => controller = newController);
  }

  void _onStateChanged(YoutubeVideoState state) {
    if (!signedIn) return;
    saveTimer?.cancel();
    saveTimer = Timer(
      const Duration(seconds: 5),
      () => _saveProgress(state.position),
    );
  }

  Future<void> _saveProgress(Duration position) async {
    if (!mounted || controller == null) return;
    final durationSeconds = await controller!.duration;
    if (durationSeconds <= 0) return;
    final progress = (position.inMilliseconds / 1000 / durationSeconds).clamp(
      0.0,
      1.0,
    );
    try {
      final result = await ref
          .read(videoProgressRepositoryProvider)
          .save(
            storySlug: widget.storySlug,
            videoSlug: widget.videoSlug,
            progress: progress,
            positionSeconds: position.inMilliseconds / 1000,
            durationSeconds: durationSeconds,
          );
      if (!mounted) return;
      handleCompletionSignals(
        context,
        ref,
        widget.storySlug,
        storyCompleted: result.storyCompleted,
        unlockedCountry: result.unlockedCountry,
        unlockedAchievements: result.unlockedAchievements,
      );
    } catch (_) {
      // Progress is best-effort during playback; the next tick retries.
    }
  }

  void _goToVideo(String videoSlug) {
    context.pushReplacement('/watch/${widget.storySlug}/$videoSlug');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Video')),
    body: ref
        .watch(storyDetailProvider(widget.storySlug))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (story) {
            final videos = story.videos;
            final index = videos.indexWhere(
              (item) => item.slug == widget.videoSlug,
            );
            if (index == -1) {
              return const Center(child: Text('Video not found.'));
            }
            final video = videos[index];
            final youtubeId = video.youtubeId;
            if (youtubeId == null) {
              return const Center(child: Text('This video is unavailable.'));
            }
            _init(youtubeId);
            final previousSlug = index > 0 ? videos[index - 1].slug : null;
            final nextSlug = index < videos.length - 1
                ? videos[index + 1].slug
                : null;
            final activeController = controller;
            return Column(
              children: [
                if (activeController == null)
                  const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  YoutubePlayer(controller: activeController),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    video.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      tooltip: 'Previous video',
                      onPressed: previousSlug == null
                          ? null
                          : () => _goToVideo(previousSlug),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      tooltip: 'Next video',
                      onPressed: nextSlug == null
                          ? null
                          : () => _goToVideo(nextSlug),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
  );
}
