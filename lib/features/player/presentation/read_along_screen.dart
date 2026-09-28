import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/api_error_view.dart';
import '../../../core/providers.dart';
import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../data/read_along_repository.dart';

class ReadAlongScreen extends ConsumerStatefulWidget {
  const ReadAlongScreen({
    super.key,
    required this.storySlug,
    required this.audioSlug,
  });
  final String storySlug;
  final String audioSlug;
  @override
  ConsumerState<ReadAlongScreen> createState() => _ReadAlongScreenState();
}

class _ReadAlongScreenState extends ConsumerState<ReadAlongScreen> {
  final player = AudioPlayer();
  final itemScrollController = ItemScrollController();
  bool initStarted = false;
  bool loading = true;
  Object? loadError;
  ReadAlongPayload? payload;
  int activeIndex = -1;
  StreamSubscription<Duration>? positionSubscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant ReadAlongScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioSlug != widget.audioSlug) {
      initStarted = false;
      loading = true;
      loadError = null;
      payload = null;
      activeIndex = -1;
      _init();
    }
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    player.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (initStarted) return;
    initStarted = true;
    try {
      final result = await ref
          .read(readAlongRepositoryProvider)
          .fetch(storySlug: widget.storySlug, audioSlug: widget.audioSlug);
      final streamUrl = result.streamUrl;
      if (streamUrl == null) {
        throw StateError('This track has no audio to play.');
      }
      final token = await ref.read(tokenStoreProvider).readAccessToken();
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamUrl),
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
        ),
      );
      positionSubscription = player.positionStream.listen(_onPositionChanged);
      if (!mounted) return;
      setState(() {
        payload = result;
        loading = false;
      });
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
    final current = payload;
    if (current == null) return;
    final adjusted =
        position.inMilliseconds / 1000 - current.defaultOffsetSeconds;
    final index = findActiveCueIndex(current.cues, adjusted);
    if (index == activeIndex) return;
    setState(() => activeIndex = index);
    if (index >= 0 && itemScrollController.isAttached) {
      itemScrollController.scrollTo(
        index: index,
        alignment: 0.35,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _seekToCue(ReadAlongCue cue) {
    final current = payload;
    if (current == null) return;
    final target = cue.startSeconds + current.defaultOffsetSeconds;
    player.seek(
      Duration(milliseconds: (target.clamp(0, double.infinity) * 1000).round()),
    );
    ref
        .read(analyticsServiceProvider)
        .track(
          AnalyticsEventType.readAlongCueSeek,
          storySlug: widget.storySlug,
          value: cue.startSeconds,
        );
  }

  void _goToTrack(String audioSlug) {
    context.pushReplacement('/read-along/${widget.storySlug}/$audioSlug');
  }

  @override
  Widget build(BuildContext context) {
    final current = payload;
    return Scaffold(
      appBar: AppBar(title: Text(current?.audioTitle ?? 'Read Along')),
      body: loadError != null
          ? ApiErrorView(error: loadError!)
          : loading || current == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: current.cues.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'This track has no synchronized transcript yet.',
                            ),
                          ),
                        )
                      : ScrollablePositionedList.builder(
                          itemScrollController: itemScrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          itemCount: current.cues.length,
                          itemBuilder: (context, index) {
                            final cue = current.cues[index];
                            final active = index == activeIndex;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                              ),
                              child: GestureDetector(
                                onTap: () => _seekToCue(cue),
                                child: Text(
                                  cue.text,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: active
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : null,
                                      ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          tooltip: 'Previous track',
                          onPressed: current.previousAudioSlug == null
                              ? null
                              : () => _goToTrack(current.previousAudioSlug!),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: player.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            return IconButton(
                              iconSize: 44,
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
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          tooltip: 'Next track',
                          onPressed: current.nextAudioSlug == null
                              ? null
                              : () => _goToTrack(current.nextAudioSlug!),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
