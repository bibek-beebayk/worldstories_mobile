import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/config.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../engagement/presentation/completion_signals.dart';
import '../../story/presentation/story_detail_screen.dart';
import '../data/audio_progress_repository.dart';
import '../../../core/api_error_view.dart';

class AudiobookPlayerScreen extends ConsumerStatefulWidget {
  const AudiobookPlayerScreen({
    super.key,
    required this.storySlug,
    required this.audioSlug,
  });
  final String storySlug;
  final String audioSlug;
  @override
  ConsumerState<AudiobookPlayerScreen> createState() =>
      _AudiobookPlayerScreenState();
}

class _AudiobookPlayerScreenState
    extends ConsumerState<AudiobookPlayerScreen> {
  final player = AudioPlayer();
  Timer? saveTimer;
  bool initStarted = false;
  bool loading = true;
  Object? loadError;

  bool get signedIn => ref.read(authControllerProvider).value != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant AudiobookPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioSlug != widget.audioSlug) {
      initStarted = false;
      loading = true;
      loadError = null;
      _init();
    }
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (initStarted) return;
    initStarted = true;
    try {
      final token = await ref
          .read(tokenStoreProvider)
          .readAccessToken();
      final url = AppConfig.apiBaseUri.resolve(
        'stories/${Uri.encodeComponent(widget.storySlug)}/audios/${Uri.encodeComponent(widget.audioSlug)}/stream/',
      );
      double? initialPositionSeconds;
      if (signedIn) {
        try {
          final saved = await ref
              .read(audioProgressRepositoryProvider)
              .fetch(widget.storySlug);
          if (saved?.audioSlug == widget.audioSlug) {
            initialPositionSeconds = saved!.positionSeconds;
          }
        } catch (_) {
          // Best-effort restore; fall back to the start of the track.
        }
      }
      await player.setAudioSource(
        AudioSource.uri(
          url,
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
        ),
      );
      if (initialPositionSeconds != null && initialPositionSeconds > 0) {
        await player.seek(
          Duration(milliseconds: (initialPositionSeconds * 1000).round()),
        );
      }
      player.positionStream.listen(_onPositionChanged);
      if (!mounted) return;
      setState(() => loading = false);
      await player.play();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = error;
      });
    }
  }

  void _onPositionChanged(Duration position) {
    if (!signedIn || !player.playing) return;
    saveTimer?.cancel();
    saveTimer = Timer(
      const Duration(seconds: 5),
      () => _saveProgress(position),
    );
  }

  Future<void> _saveProgress(Duration position) async {
    if (!mounted) return;
    final duration = player.duration;
    if (duration == null || duration.inMilliseconds <= 0) return;
    final progress = (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0);
    try {
      final result = await ref
          .read(audioProgressRepositoryProvider)
          .save(
            storySlug: widget.storySlug,
            audioSlug: widget.audioSlug,
            progress: progress,
            positionSeconds: position.inMilliseconds / 1000,
            durationSeconds: duration.inMilliseconds / 1000,
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

  void _goToTrack(String audioSlug) {
    context.pushReplacement('/listen/${widget.storySlug}/$audioSlug');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Audiobook')),
    body: ref
        .watch(storyDetailProvider(widget.storySlug))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (story) {
            final tracks = story.audios;
            final index = tracks.indexWhere(
              (item) => item.slug == widget.audioSlug,
            );
            final previousSlug = index > 0 ? tracks[index - 1].slug : null;
            final nextSlug = index >= 0 && index < tracks.length - 1
                ? tracks[index + 1].slug
                : null;
            final title = index >= 0 ? tracks[index].title : story.title;
            if (loadError != null) {
              return ApiErrorView(error: loadError!);
            }
            if (loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    story.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = player.duration ?? Duration.zero;
                      return Column(
                        children: [
                          Slider(
                            min: 0,
                            max: duration.inMilliseconds.toDouble().clamp(
                              1,
                              double.infinity,
                            ),
                            value: position.inMilliseconds
                                .toDouble()
                                .clamp(0, duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                            onChanged: (value) => player.seek(
                              Duration(milliseconds: value.round()),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position)),
                              Text(_formatDuration(duration)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.skip_previous),
                        tooltip: 'Previous track',
                        onPressed: previousSlug == null
                            ? null
                            : () => _goToTrack(previousSlug),
                      ),
                      const SizedBox(width: 16),
                      StreamBuilder<PlayerState>(
                        stream: player.playerStateStream,
                        builder: (context, snapshot) {
                          final playing = snapshot.data?.playing ?? false;
                          return IconButton(
                            iconSize: 56,
                            icon: Icon(
                              playing
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                            ),
                            tooltip: playing ? 'Pause' : 'Play',
                            onPressed: () =>
                                playing ? player.pause() : player.play(),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.skip_next),
                        tooltip: 'Next track',
                        onPressed: nextSlug == null
                            ? null
                            : () => _goToTrack(nextSlug),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
  );
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
}
