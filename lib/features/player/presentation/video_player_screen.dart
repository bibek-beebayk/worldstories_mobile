import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  double videoAspectRatio = 16 / 9;
  Future<double?>? aspectRatioDetection;

  bool get signedIn => ref.read(authControllerProvider).value != null;

  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoSlug != widget.videoSlug) {
      initStarted = false;
      aspectRatioDetection = null;
      controller?.close();
      controller = null;
      unawaited(_restoreScreen());
      setState(() {});
    }
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    controller?.close();
    unawaited(_restoreScreen());
    super.dispose();
  }

  Future<void> _init(String youtubeId, double aspectRatio) async {
    if (initStarted) return;
    initStarted = true;
    videoAspectRatio = aspectRatio;
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
    newController.setFullScreenListener(_onFullScreenChanged);
    setState(() => controller = newController);
  }

  Future<void> _onFullScreenChanged(bool isFullScreen) async {
    if (isFullScreen) {
      final detectedAspectRatio = await _detectAndApplyAspectRatio();
      if (controller?.value.fullScreenOption.enabled != true) return;
      final aspectRatio = detectedAspectRatio ?? videoAspectRatio;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(
        aspectRatio >= 1
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ],
      );
      return;
    }
    await _restoreScreen();
  }

  Future<void> _restoreScreen() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<double?> _detectAndApplyAspectRatio() async {
    final detection = aspectRatioDetection ??= _detectAspectRatio();
    final detected = await detection;
    if (detected == null && identical(aspectRatioDetection, detection)) {
      aspectRatioDetection = null;
    }
    if (detected == null || !mounted) return detected;
    if ((videoAspectRatio - detected).abs() > 0.01) {
      setState(() => videoAspectRatio = detected);
    }
    return detected;
  }

  Future<double?> _detectAspectRatio() async {
    final activeController = controller;
    if (activeController == null) return null;

    // The IFrame Player API omits source dimensions. On Android/iOS, however,
    // the decoded HTML video element inside the same-origin YouTube frame has
    // populated videoWidth/videoHeight once playback metadata is available.
    const script = '''
      (() => {
        try {
          const frame = document.querySelector('iframe');
          const frameDocument = frame?.contentDocument || frame?.contentWindow?.document;
          const videos = frameDocument?.querySelectorAll('video') || [];
          for (const video of videos) {
            if (video.videoWidth > 0 && video.videoHeight > 0) {
              return video.videoWidth / video.videoHeight;
            }
          }
        } catch (_) {}
        return 0;
      })();
    ''';

    for (var attempt = 0; attempt < 12; attempt++) {
      if (!identical(controller, activeController)) return null;
      try {
        final result = await activeController.webViewController
            .runJavaScriptReturningResult(script);
        final ratio = double.tryParse(
          result.toString().replaceAll('"', '').trim(),
        );
        if (ratio != null && ratio >= 0.2 && ratio <= 5) return ratio;
      } catch (_) {
        // The iframe may still be initializing; retry briefly below.
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return null;
  }

  void _onStateChanged(YoutubeVideoState state) {
    unawaited(_detectAndApplyAspectRatio());
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
            _init(youtubeId, video.aspectRatio);
            final previousSlug = index > 0 ? videos[index - 1].slug : null;
            final nextSlug = index < videos.length - 1
                ? videos[index + 1].slug
                : null;
            final activeController = controller;
            final effectiveAspectRatio = initStarted
                ? videoAspectRatio
                : video.aspectRatio;
            return LayoutBuilder(
              builder: (context, constraints) {
                // Leave room for the title and navigation controls. This is
                // especially important while a portrait video rotates into
                // fullscreen: using the landscape width alone would make a
                // 9:16 player much taller than the available body.
                final maxPlayerHeight = math.max(
                  160.0,
                  constraints.maxHeight - 120,
                );
                final playerWidth = math.min(
                  constraints.maxWidth,
                  maxPlayerHeight * effectiveAspectRatio,
                );

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Center(
                        child: SizedBox(
                          width: playerWidth,
                          child: activeController == null
                              ? AspectRatio(
                                  aspectRatio: effectiveAspectRatio,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : YoutubePlayer(
                                  controller: activeController,
                                  aspectRatio: effectiveAspectRatio,
                                  backgroundColor: Colors.black,
                                ),
                        ),
                      ),
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
                  ),
                );
              },
            );
          },
        ),
  );
}
