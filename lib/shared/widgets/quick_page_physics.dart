import 'package:flutter/widgets.dart';

/// The page a swipe started on, for [QuickPageScrollPhysics]. Update it
/// from a `ScrollStartNotification` whose `dragDetails` is non-null.
class PageSwipeTracker {
  int originPage = 0;
}

/// Page snapping for a `PageView` (use with `pageSnapping: false`) that
/// turns the page after a short drag (8% of the page) or a light flick,
/// instead of the default half-page drag — a quicker, more responsive swipe.
class QuickPageScrollPhysics extends ScrollPhysics {
  const QuickPageScrollPhysics({required this.tracker, super.parent});

  static const dragThreshold = 0.08;
  static const flingVelocity = 30.0;
  final PageSwipeTracker tracker;

  @override
  QuickPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      QuickPageScrollPhysics(tracker: tracker, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final visiblePage = position.pixels / position.viewportDimension;
    final displacement = visiblePage - tracker.originPage;
    var targetPage = tracker.originPage;
    if (displacement.abs() >= dragThreshold) {
      targetPage += displacement.isNegative ? -1 : 1;
    } else if (velocity.abs() >= flingVelocity) {
      targetPage += velocity.isNegative ? -1 : 1;
    }

    final lastPage = (position.maxScrollExtent / position.viewportDimension)
        .round();
    targetPage = targetPage.clamp(0, lastPage);
    final targetPixels = targetPage * position.viewportDimension;
    final tolerance = toleranceFor(position);
    if ((targetPixels - position.pixels).abs() <= tolerance.distance) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels,
      velocity,
      tolerance: tolerance,
    );
  }
}
