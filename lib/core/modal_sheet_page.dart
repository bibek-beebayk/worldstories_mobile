import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A go_router page that presents its [child] as a modal bottom sheet, so a
/// route can open over the current screen instead of replacing it.
class ModalSheetPage<T> extends Page<T> {
  const ModalSheetPage({
    required this.child,
    this.heightFactor = 0.92,
    this.showDragHandle = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;
  final double heightFactor;

  /// Pass false when the child draws its own handle, e.g. over a full-bleed
  /// header. Dragging any non-scrolling part of the sheet still dismisses it.
  final bool showDragHandle;

  @override
  Route<T> createRoute(BuildContext context) => _ModalSheetRoute<T>(
    settings: this,
    showDragHandle: showDragHandle,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    heightFactor: heightFactor,
    child: child,
  );
}

class _ModalSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _ModalSheetRoute({
    super.settings,
    required bool showDragHandle,
    required Color backgroundColor,
    required double heightFactor,
    required Widget child,
  }) : super(
         isScrollControlled: true,
         useSafeArea: true,
         showDragHandle: showDragHandle,
         clipBehavior: Clip.antiAlias,
         backgroundColor: backgroundColor,
         sheetAnimationStyle: _animationStyle,
         builder: (context) => FractionallySizedBox(
           heightFactor: heightFactor,
           child: _SheetContentReveal(child: child),
         ),
       );

  static const _animationStyle = AnimationStyle(
    duration: Duration(milliseconds: 450),
    reverseDuration: Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  final sheetKey = GlobalKey();

  AnimationController get sheetController => controller!;
}

/// Lets a downward drag that starts on [child] pull the enclosing
/// [ModalSheetPage] closed, like dragging its handle. It only claims the drag
/// while the surrounding scroll view is at the top and the finger moves down;
/// upward drags, and any drag once the content is scrolled, still scroll.
class SheetDismissDragArea extends StatefulWidget {
  const SheetDismissDragArea({super.key, required this.child});

  final Widget child;

  @override
  State<SheetDismissDragArea> createState() => _SheetDismissDragAreaState();
}

class _SheetDismissDragAreaState extends State<SheetDismissDragArea> {
  // Mirror BottomSheet's own drag-to-dismiss thresholds.
  static const _minFlingVelocity = 700.0;
  static const _closeProgressThreshold = 0.5;

  /// Linear sheet position during a drag: 1 is fully open, 0 is closed.
  var _progress = 1.0;

  _ModalSheetRoute<dynamic>? get _route {
    final route = ModalRoute.of(context);
    return route is _ModalSheetRoute ? route : null;
  }

  double get _sheetHeight => _route?.sheetKey.currentContext?.size?.height ?? 1;

  bool _canStart() {
    final position = Scrollable.maybeOf(context)?.position;
    return _route != null &&
        (position == null || position.pixels <= position.minScrollExtent);
  }

  void _onStart(DragStartDetails _) =>
      _progress = _visibleFraction(_route!.sheetController.value);

  void _onUpdate(DragUpdateDetails details) {
    _progress = (_progress - details.primaryDelta! / _sheetHeight).clamp(0, 1);
    _route!.sheetController.value = _controllerValueFor(_progress);
  }

  void _onEnd(DragEndDetails details) {
    final controller = _route!.sheetController;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final closing =
        velocity > _minFlingVelocity ||
        (velocity >= -_minFlingVelocity && _progress < _closeProgressThreshold);
    if (closing) {
      Navigator.of(context).pop();
    } else {
      controller.forward();
    }
  }

  // The sheet's position is the controller value run through the open curve,
  // so invert that curve to keep the sheet tracking the finger exactly.
  double _visibleFraction(double value) =>
      _ModalSheetRoute._animationStyle.curve!.transform(value);

  double _controllerValueFor(double fraction) {
    var low = 0.0, high = 1.0;
    for (var i = 0; i < 24; i++) {
      final mid = (low + high) / 2;
      if (_visibleFraction(mid) < fraction) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      _DownwardDragRecognizer:
          GestureRecognizerFactoryWithHandlers<_DownwardDragRecognizer>(
            () => _DownwardDragRecognizer(canStart: _canStart),
            (recognizer) => recognizer
              ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
              ..onStart = _onStart
              ..onUpdate = _onUpdate
              ..onEnd = _onEnd,
          ),
    },
    child: widget.child,
  );
}

/// A vertical drag recognizer that only wins the gesture arena for downward
/// movement, leaving upward drags to the enclosing scroll view.
///
/// It accepts at half the touch slop so it always claims a downward drag
/// before the scroll view does; otherwise the scroll view can win and turn
/// the pull into an overscroll (and a pull-to-refresh).
class _DownwardDragRecognizer extends VerticalDragGestureRecognizer {
  _DownwardDragRecognizer({required this.canStart});

  final bool Function() canStart;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved >
          computeHitSlop(pointerDeviceKind, gestureSettings) / 2 &&
      canStart();
}

/// Fades and lifts the sheet's content in during the second half of the
/// sheet's slide-up, so the content settles in after the sheet itself.
class _SheetContentReveal extends StatelessWidget {
  const _SheetContentReveal({required this.child});

  final Widget child;

  static final _curve = CurveTween(
    curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
  );

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation == null) return child;
    final reveal = animation.drive(_curve);
    return FadeTransition(
      opacity: reveal,
      child: SlideTransition(
        position: reveal.drive(
          Tween(begin: const Offset(0, 0.04), end: Offset.zero),
        ),
        child: KeyedSubtree(
          key: route is _ModalSheetRoute ? route.sheetKey : null,
          child: child,
        ),
      ),
    );
  }
}
