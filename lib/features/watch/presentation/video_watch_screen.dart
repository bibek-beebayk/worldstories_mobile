import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/api_error_view.dart';
import '../../../core/app_theme.dart';
import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../data/watch_repository.dart';
import 'video_card.dart';

/// The `/watch/:videoId` page: a standalone video with resume + "Up next".
class VideoWatchScreen extends ConsumerStatefulWidget {
  const VideoWatchScreen({super.key, required this.videoId});
  final int videoId;

  @override
  ConsumerState<VideoWatchScreen> createState() => _VideoWatchScreenState();
}

class _VideoWatchScreenState extends ConsumerState<VideoWatchScreen>
    with WidgetsBindingObserver {
  // Captured up front: `ref` must not be used once the element is disposing.
  late final WatchRepository _repository = ref.read(watchRepositoryProvider);
  late final AnalyticsService _analytics = ref.read(analyticsServiceProvider);

  WatchVideoDetail? _detail;
  Object? _error;
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _valueSub;
  StreamSubscription<YoutubeVideoState>? _stateSub;
  int _loadToken = 0;

  bool _signedIn = false;
  PlayerState _lastPlayerState = PlayerState.unknown;
  double _positionSeconds = 0;
  double _lastSavedSeconds = 0;
  double _durationSeconds = 0;
  bool _endedHandled = false;

  // Time actually spent playing, reported as a `watching_session`.
  final Stopwatch _playing = Stopwatch();
  double _unreportedSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant VideoWatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _teardownPlayer(save: true);
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _teardownPlayer(save: true);
    unawaited(_restoreScreen());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopPlaying();
      _flushAnalytics();
      _saveProgress();
    }
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _detail = null;
      _error = null;
    });
    try {
      final detail = await _repository.fetchVideo(widget.videoId);
      if (!mounted || token != _loadToken) return;

      // Resolve the saved position BEFORE creating the controller so the
      // player starts at the right time.
      _signedIn = ref.read(authControllerProvider).value != null;
      var start = 0.0;
      if (_signedIn) {
        try {
          final saved = await _repository.fetchProgress(widget.videoId);
          if (saved != null) start = saved.startSeconds;
        } catch (_) {
          // Best-effort restore; start from the beginning.
        }
      }
      if (!mounted || token != _loadToken) return;

      _durationSeconds = detail.video.durationSeconds?.toDouble() ?? 0;
      _positionSeconds = start;
      _lastSavedSeconds = start;
      _endedHandled = false;
      _lastPlayerState = PlayerState.unknown;

      final controller = YoutubePlayerController.fromVideoId(
        videoId: detail.video.youtubeId,
        autoPlay: true,
        startSeconds: start > 2 ? start : null,
        params: const YoutubePlayerParams(showFullscreenButton: true),
      );
      _valueSub = controller.stream.listen(_onValue);
      _stateSub = controller.videoStateStream.listen(_onVideoState);
      controller.setFullScreenListener(_onFullScreenChanged);
      setState(() {
        _detail = detail;
        _controller = controller;
      });
    } catch (error) {
      if (!mounted || token != _loadToken) return;
      setState(() => _error = error);
    }
  }

  void _teardownPlayer({required bool save}) {
    final controller = _controller;
    if (controller == null) return;
    _stopPlaying();
    _flushAnalytics();
    if (save && !_endedHandled) _saveProgress();
    _valueSub?.cancel();
    _stateSub?.cancel();
    _valueSub = null;
    _stateSub = null;
    _controller = null;
    controller.close();
  }

  void _onValue(YoutubePlayerValue value) {
    final state = value.playerState;
    if (state == _lastPlayerState) return;
    final previous = _lastPlayerState;
    _lastPlayerState = state;

    if (state == PlayerState.playing) {
      _playing.start();
      unawaited(_refreshDuration());
    } else {
      _stopPlaying();
    }

    if (state == PlayerState.paused && previous == PlayerState.playing) {
      _saveProgress();
    } else if (state == PlayerState.ended) {
      _onEnded();
    }
  }

  void _onVideoState(YoutubeVideoState state) {
    _positionSeconds = state.position.inMilliseconds / 1000;
    if (_lastPlayerState == PlayerState.playing &&
        (_positionSeconds - _lastSavedSeconds).abs() >= 5) {
      _saveProgress();
    }
  }

  Future<void> _refreshDuration() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final duration = await controller.duration;
      if (duration > 0) _durationSeconds = duration;
    } catch (_) {
      // Keep the duration from the API.
    }
  }

  void _stopPlaying() {
    if (!_playing.isRunning) return;
    _playing.stop();
    _unreportedSeconds += _playing.elapsedMilliseconds / 1000;
    _playing.reset();
  }

  void _flushAnalytics() {
    final seconds = _unreportedSeconds.round();
    final video = _detail?.video;
    if (video == null || seconds < 2) return;
    _unreportedSeconds = 0;
    _analytics.track(
      AnalyticsEventType.watchingSession,
      videoId: video.id,
      durationSeconds: seconds.toDouble(),
      metadata: {'format': 'video', 'item_slug': video.slug},
    );
  }

  /// Best-effort, signed-in only; never throws.
  void _saveProgress({bool completed = false}) {
    if (!_signedIn) return;
    final video = _detail?.video;
    if (video == null) return;
    final duration = _durationSeconds;
    if (duration <= 0) return;
    final position = completed ? duration : _positionSeconds;
    _lastSavedSeconds = position;
    unawaited(
      _repository
          .saveProgress(
            video.id,
            progress: position / duration,
            positionSeconds: position,
            durationSeconds: duration,
          )
          .catchError((Object _) {}),
    );
  }

  void _onEnded() {
    if (_endedHandled) return;
    _endedHandled = true;
    _flushAnalytics();
    _saveProgress(completed: true);
    final next = _detail?.suggested.firstOrNull;
    if (next != null && mounted) {
      context.pushReplacement('/watch/${next.id}');
    }
  }

  Future<void> _onFullScreenChanged(bool isFullScreen) async {
    if (!isFullScreen) return _restoreScreen();
    final portrait = _detail?.video.isPortrait ?? false;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(
      portrait
          ? const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
          : const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
    );
  }

  Future<void> _restoreScreen() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Watch')),
      body: _error != null
          ? ApiErrorView(error: _error!, onRetry: _load)
          : detail == null || controller == null
          ? const Center(child: CircularProgressIndicator())
          : _content(context, detail, controller),
    );
  }

  Widget _content(
    BuildContext context,
    WatchVideoDetail detail,
    YoutubePlayerController controller,
  ) {
    final video = detail.video;
    final screenHeight = MediaQuery.sizeOf(context).height;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = video.isPortrait ? 9 / 16 : 16 / 9;
                  final width = video.isPortrait
                      ? math.min(constraints.maxWidth, screenHeight * 0.7 * ratio)
                      : constraints.maxWidth;
                  return SizedBox(
                    width: width,
                    child: YoutubePlayer(
                      key: ValueKey('player-${video.id}'),
                      controller: controller,
                      aspectRatio: ratio,
                      backgroundColor: Colors.black,
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (video.story != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      children: [
                        const Text(
                          'From the story ',
                          style: TextStyle(color: AppTheme.mutedForeground),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/story/${video.story!.slug}'),
                          child: Text(
                            video.story!.title,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_signedIn)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Log in to track your watch progress across devices.',
                      style: TextStyle(
                        color: AppTheme.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Up next',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (detail.suggested.isEmpty)
                  const Text(
                    'No other videos yet.',
                    style: TextStyle(color: AppTheme.mutedForeground),
                  )
                else
                  for (final item in detail.suggested)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: VideoCard(video: item, horizontal: true),
                    ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
