import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// A persistently cached network image with bounded decoding and consistent
/// loading/error behavior. Screen-specific fallbacks can be supplied without
/// duplicating the networking and cache configuration.
class CachedAppImage extends StatelessWidget {
  const CachedAppImage({
    required this.imageUrl,
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.decodeWidth = 480,
    this.diskCacheWidth = 900,
    this.placeholder,
    this.error,
    this.loadTimeout = const Duration(seconds: 8),
  });

  /// How long the loading placeholder may stay up before the [error] fallback
  /// is shown instead. Third-party hosts (e.g. a cover hotlinked from another
  /// site) can hang or throttle; without this the card would spin forever.
  /// If the image does arrive later it still replaces the fallback.
  final Duration loadTimeout;

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? decodeWidth;
  final int? diskCacheWidth;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? error;

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    imageUrl: imageUrl,
    fit: fit,
    width: width,
    height: height,
    memCacheWidth: decodeWidth,
    maxWidthDiskCache: diskCacheWidth,
    fadeInDuration: const Duration(milliseconds: 160),
    placeholder: (context, url) => _TimedPlaceholder(
      timeout: loadTimeout,
      loading: placeholder ?? (_) => const BookPageOpeningLoader(),
      fallback: error ?? (_) => const _ImageErrorPlaceholder(),
    ),
    errorWidget: (context, url, failure) =>
        error?.call(context) ?? const _ImageErrorPlaceholder(),
  );
}

class _TimedPlaceholder extends StatefulWidget {
  const _TimedPlaceholder({
    required this.timeout,
    required this.loading,
    required this.fallback,
  });
  final Duration timeout;
  final WidgetBuilder loading;
  final WidgetBuilder fallback;

  @override
  State<_TimedPlaceholder> createState() => _TimedPlaceholderState();
}

class _TimedPlaceholderState extends State<_TimedPlaceholder> {
  late final Timer _timer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.timeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _timedOut ? widget.fallback(context) : widget.loading(context);
}

class BookPageOpeningLoader extends StatefulWidget {
  const BookPageOpeningLoader({super.key});

  @override
  State<BookPageOpeningLoader> createState() => _BookPageOpeningLoaderState();
}

class _BookPageOpeningLoaderState extends State<BookPageOpeningLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.muted,
    child: Center(
      child: Semantics(
        label: 'Loading cover image',
        child: SizedBox(
          width: 52,
          height: 42,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final pageTurn = Curves.easeInOutCubic.transform(
                controller.value,
              );
              return Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned(
                    left: 4,
                    top: 7,
                    child: _BookPage(isLeft: true),
                  ),
                  const Positioned(
                    right: 4,
                    top: 7,
                    child: _BookPage(isLeft: false),
                  ),
                  Positioned(
                    right: 4,
                    top: 7,
                    child: Transform(
                      alignment: Alignment.centerLeft,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002)
                        ..rotateY(-math.pi * pageTurn),
                      child: const _TurningPage(),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 44,
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _BookPage extends StatelessWidget {
  const _BookPage({required this.isLeft});

  final bool isLeft;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 31,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.horizontal(
        left: Radius.circular(isLeft ? 5 : 1),
        right: Radius.circular(isLeft ? 1 : 5),
      ),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 3,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: List.generate(
          4,
          (_) => Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 1.2,
                color: AppTheme.primary.withValues(alpha: 0.18),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TurningPage extends StatelessWidget {
  const _TurningPage();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 31,
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBF7),
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.55)),
      gradient: LinearGradient(
        colors: [AppTheme.primary.withValues(alpha: 0.1), Colors.white],
      ),
    ),
  );
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppTheme.muted,
    child: Center(child: Icon(Icons.broken_image_outlined)),
  );
}
