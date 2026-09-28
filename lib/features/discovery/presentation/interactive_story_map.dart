import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';

class InteractiveStoryMap extends StatefulWidget {
  const InteractiveStoryMap({
    super.key,
    required this.storyCounts,
    required this.totalStories,
    required this.onCountryTap,
  });

  final Map<String, int> storyCounts;
  final int totalStories;
  final ValueChanged<String> onCountryTap;

  @override
  State<InteractiveStoryMap> createState() => _InteractiveStoryMapState();
}

class _InteractiveStoryMapState extends State<InteractiveStoryMap> {
  static const _maxZoom = 18.0;
  static final Future<_WorldGeometry> _geometry = _WorldGeometry.load();
  final _transformationController = TransformationController();
  String? _selectedCode;
  Size? _viewportSize;
  bool _initialTransformApplied = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _setZoom(double zoom) {
    final bounded = zoom.clamp(1.0, _maxZoom);
    final viewportSize = _viewportSize;
    _transformationController.value = viewportSize == null
        ? Matrix4.diagonal3Values(bounded, bounded, 1)
        : _centeredTransform(viewportSize, bounded);
  }

  double _fitHeightScale(Size size) =>
      (size.height * _MapCountry.mapAspectRatio / size.width).clamp(
        1.0,
        _maxZoom,
      );

  Matrix4 _centeredTransform(Size size, double scale) =>
      Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(
        (size.width - size.width * scale) / 2,
        (size.height - size.height * scale) / 2,
        0,
      );

  void _applyInitialTransform(Size size) {
    if (_initialTransformApplied && _viewportSize == size) return;
    _viewportSize = size;
    _initialTransformApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewportSize != size) return;
      final scale = _fitHeightScale(size);
      _transformationController.value = _centeredTransform(size, scale);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_WorldGeometry>(
    future: _geometry,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text('The world map could not be displayed.'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final geometry = snapshot.data!;
      final maxCount = widget.storyCounts.values.fold<int>(0, math.max);
      return ColoredBox(
        color: const Color(0xFFF5FAFC),
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _applyInitialTransform(constraints.biggest);
                  return InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1,
                    maxScale: _maxZoom,
                    boundaryMargin: const EdgeInsets.all(100),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final code = geometry.countryAt(
                          details.localPosition,
                          constraints.biggest,
                          widget.storyCounts.keys.toSet(),
                        );
                        if (code == null) return;
                        setState(() => _selectedCode = code);
                        widget.onCountryTap(code);
                      },
                      child: CustomPaint(
                        size: constraints.biggest,
                        painter: _WorldMapPainter(
                          geometry: geometry,
                          storyCounts: widget.storyCounts,
                          maxCount: maxCount,
                          selectedCode: _selectedCode,
                          transformationController: _transformationController,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Material(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.92),
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.totalStories} stories around the world',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Fewer',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(width: 6),
                          ...List.generate(
                            _heatColors.length,
                            (index) => Container(
                              width: 18,
                              height: 9,
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                color: _heatColors[index],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'More',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.92),
                elevation: 3,
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Zoom in',
                      onPressed: () => _setZoom(
                        _transformationController.value.getMaxScaleOnAxis() *
                            1.5,
                      ),
                      icon: const Icon(Icons.add, size: 19),
                    ),
                    const SizedBox(width: 32, child: Divider(height: 1)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Zoom out',
                      onPressed: () => _setZoom(
                        _transformationController.value.getMaxScaleOnAxis() /
                            1.5,
                      ),
                      icon: const Icon(Icons.remove, size: 19),
                    ),
                    const SizedBox(width: 32, child: Divider(height: 1)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Reset map',
                      onPressed: () {
                        final viewportSize = _viewportSize;
                        _transformationController.value = viewportSize == null
                            ? Matrix4.identity()
                            : _centeredTransform(
                                viewportSize,
                                _fitHeightScale(viewportSize),
                              );
                        setState(() {
                          _selectedCode = null;
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 10,
              bottom: 10,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xDFFFFFFF),
                    borderRadius: BorderRadius.all(Radius.circular(7)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Text(
                      'Pinch to zoom • Drag to move • Tap to explore',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

const _heatColors = [
  Color(0xFFFADDE2),
  Color(0xFFF5AEBB),
  Color(0xFFEE7C90),
  Color(0xFFE84E68),
  AppTheme.primary,
];

final class _WorldGeometry {
  const _WorldGeometry(this.countries);

  final List<_MapCountry> countries;

  static Future<_WorldGeometry> load() async {
    final source = await rootBundle.loadString(
      'assets/maps/world_countries.geo.json',
    );
    final json = jsonDecode(source) as Map<String, dynamic>;
    final features = json['features'] as List<dynamic>;
    return _WorldGeometry(
      features
          .map(
            (feature) =>
                _MapCountry.fromJson(Map<String, dynamic>.from(feature as Map)),
          )
          .where((country) => country.code.isNotEmpty)
          .toList(growable: false),
    );
  }

  String? countryAt(Offset point, Size size, Set<String> selectableCodes) {
    for (final country in countries.reversed) {
      if (!selectableCodes.contains(country.code)) continue;
      if (country.path(size).contains(point)) return country.code;
    }
    return null;
  }
}

final class _MapCountry {
  _MapCountry({required this.code, required this.polygons});

  static const mapAspectRatio = 1.9;

  final String code;
  final List<List<List<Offset>>> polygons;
  late final Offset _labelAnchor = _findInteriorLabelAnchor();

  factory _MapCountry.fromJson(Map<String, dynamic> json) {
    final properties = Map<String, dynamic>.from(json['properties'] as Map);
    final geometry = Map<String, dynamic>.from(json['geometry'] as Map);
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final polygons = geometry['type'] == 'Polygon'
        ? [_parsePolygon(coordinates)]
        : coordinates
              .map((polygon) => _parsePolygon(polygon as List<dynamic>))
              .toList(growable: false);
    return _MapCountry(
      code: properties['code'] as String? ?? '',
      polygons: polygons,
    );
  }

  static List<List<Offset>> _parsePolygon(List<dynamic> raw) => raw
      .map(
        (ring) => (ring as List<dynamic>)
            .map((point) {
              final coordinate = point as List<dynamic>;
              final longitude = (coordinate[0] as num).toDouble();
              final latitude = (coordinate[1] as num).toDouble();
              return Offset((longitude + 180) / 360, (90 - latitude) / 180);
            })
            .toList(growable: false),
      )
      .toList(growable: false);

  Path path(Size size) {
    final mapRect = _mapRect(size);
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final polygon in polygons) {
      for (final ring in polygon) {
        if (ring.isEmpty) continue;
        final unwrapped = _unwrapRing(ring);
        for (final shift in const [-1.0, 0.0, 1.0]) {
          path.moveTo(
            mapRect.left + (unwrapped.first.dx + shift) * mapRect.width,
            mapRect.top + unwrapped.first.dy * mapRect.height,
          );
          for (final point in unwrapped.skip(1)) {
            path.lineTo(
              mapRect.left + (point.dx + shift) * mapRect.width,
              mapRect.top + point.dy * mapRect.height,
            );
          }
          path.close();
        }
      }
    }
    return path;
  }

  Offset labelPosition(Size size) {
    final mapRect = _mapRect(size);
    return Offset(
      mapRect.left + _labelAnchor.dx * mapRect.width,
      mapRect.top + _labelAnchor.dy * mapRect.height,
    );
  }

  Offset _findInteriorLabelAnchor() {
    final unwrappedPolygons = polygons
        .map((polygon) => polygon.map(_unwrapRing).toList(growable: false))
        .toList(growable: false);
    List<List<Offset>>? mainPolygon;
    var largestArea = 0.0;
    for (final polygon in unwrappedPolygons) {
      if (polygon.isEmpty) continue;
      final area = _signedArea(polygon.first).abs();
      if (area > largestArea) {
        largestArea = area;
        mainPolygon = polygon;
      }
    }
    if (mainPolygon == null || mainPolygon.first.isEmpty) {
      return const Offset(0.5, 0.5);
    }

    final polygonPath = Path()..fillType = PathFillType.evenOdd;
    for (final ring in mainPolygon) {
      if (ring.isEmpty) continue;
      polygonPath.moveTo(ring.first.dx, ring.first.dy);
      for (final point in ring.skip(1)) {
        polygonPath.lineTo(point.dx, point.dy);
      }
      polygonPath.close();
    }

    final bounds = polygonPath.getBounds();
    final candidates = <Offset>[_centroid(mainPolygon.first), bounds.center];
    const divisions = 20;
    for (var row = 0; row < divisions; row++) {
      for (var column = 0; column < divisions; column++) {
        candidates.add(
          Offset(
            bounds.left + bounds.width * (column + 0.5) / divisions,
            bounds.top + bounds.height * (row + 0.5) / divisions,
          ),
        );
      }
    }

    Offset? best;
    var bestDistanceSquared = -1.0;
    for (final candidate in candidates) {
      if (!polygonPath.contains(candidate)) continue;
      final distanceSquared = _distanceFromEdgesSquared(candidate, mainPolygon);
      if (distanceSquared > bestDistanceSquared) {
        best = candidate;
        bestDistanceSquared = distanceSquared;
      }
    }
    final anchor = best ?? mainPolygon.first.first;
    return Offset(anchor.dx % 1, anchor.dy);
  }

  static List<Offset> _unwrapRing(List<Offset> ring) {
    if (ring.isEmpty) return ring;
    final result = <Offset>[ring.first];
    var previousX = ring.first.dx;
    for (final point in ring.skip(1)) {
      var x = point.dx;
      while (x - previousX > 0.5) {
        x -= 1;
      }
      while (x - previousX < -0.5) {
        x += 1;
      }
      result.add(Offset(x, point.dy));
      previousX = x;
    }
    return result;
  }

  static double _distanceFromEdgesSquared(
    Offset point,
    List<List<Offset>> polygon,
  ) {
    var closest = double.infinity;
    for (final ring in polygon) {
      for (var index = 0; index < ring.length; index++) {
        final distance = _distanceToSegmentSquared(
          point,
          ring[index],
          ring[(index + 1) % ring.length],
        );
        if (distance < closest) closest = distance;
      }
    }
    return closest;
  }

  static double _distanceToSegmentSquared(Offset point, Offset a, Offset b) {
    final segment = b - a;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared == 0) return (point - a).distanceSquared;
    final projection =
        ((point - a).dx * segment.dx + (point - a).dy * segment.dy) /
        lengthSquared;
    final bounded = projection.clamp(0.0, 1.0);
    final nearest = a + segment * bounded;
    return (point - nearest).distanceSquared;
  }

  static double _signedArea(List<Offset> ring) {
    var sum = 0.0;
    for (var index = 0; index < ring.length; index++) {
      final current = ring[index];
      final next = ring[(index + 1) % ring.length];
      sum += current.dx * next.dy - next.dx * current.dy;
    }
    return sum / 2;
  }

  static Offset _centroid(List<Offset> ring) {
    var x = 0.0;
    var y = 0.0;
    var crossSum = 0.0;
    for (var index = 0; index < ring.length; index++) {
      final current = ring[index];
      final next = ring[(index + 1) % ring.length];
      final cross = current.dx * next.dy - next.dx * current.dy;
      crossSum += cross;
      x += (current.dx + next.dx) * cross;
      y += (current.dy + next.dy) * cross;
    }
    if (crossSum.abs() < 0.0000001) {
      return ring.reduce((left, right) => left + right) /
          ring.length.toDouble();
    }
    return Offset(x / (3 * crossSum), y / (3 * crossSum));
  }

  static Rect _mapRect(Size size) {
    if (size.aspectRatio > mapAspectRatio) {
      final width = size.height * mapAspectRatio;
      return Rect.fromLTWH((size.width - width) / 2, 0, width, size.height);
    }
    final height = size.width / mapAspectRatio;
    return Rect.fromLTWH(0, (size.height - height) / 2, size.width, height);
  }
}

final class _WorldMapPainter extends CustomPainter {
  const _WorldMapPainter({
    required this.geometry,
    required this.storyCounts,
    required this.maxCount,
    required this.selectedCode,
    required this.transformationController,
  }) : super(repaint: transformationController);

  final _WorldGeometry geometry;
  final Map<String, int> storyCounts;
  final int maxCount;
  final String? selectedCode;
  final TransformationController transformationController;

  Color _fillFor(int count) {
    if (count <= 0 || maxCount <= 0) return const Color(0xFFDDE6E9);
    final index = ((count / maxCount) * _heatColors.length).ceil() - 1;
    return _heatColors[index.clamp(0, _heatColors.length - 1)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65
      ..color = Colors.white;
    canvas
      ..save()
      ..clipRect(_MapCountry._mapRect(size));
    for (final country in geometry.countries) {
      final path = country.path(size);
      final isSelected = country.code == selectedCode;
      fill.color = isSelected
          ? const Color(0xFF9F1239)
          : _fillFor(storyCounts[country.code] ?? 0);
      canvas
        ..drawPath(path, fill)
        ..drawPath(path, border);
    }
    canvas.restore();

    for (final country in geometry.countries) {
      final count = storyCounts[country.code] ?? 0;
      if (count <= 0) continue;
      _paintCountLabel(
        canvas,
        country.labelPosition(size),
        '$count',
        selected: country.code == selectedCode,
      );
    }
  }

  void _paintCountLabel(
    Canvas canvas,
    Offset center,
    String label, {
    required bool selected,
  }) {
    final inverseZoom = 1 / transformationController.value.getMaxScaleOnAxis();
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFF172033),
          fontSize: 9 * inverseZoom,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final horizontalPadding = 4 * inverseZoom;
    final verticalPadding = 2 * inverseZoom;
    final rect = Rect.fromCenter(
      center: center,
      width: textPainter.width + horizontalPadding * 2,
      height: textPainter.height + verticalPadding * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(5 * inverseZoom)),
      Paint()
        ..color = selected
            ? const Color(0xFF172033)
            : Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(5 * inverseZoom)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = inverseZoom
        ..color = selected ? Colors.white : AppTheme.primary,
    );
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter oldDelegate) =>
      oldDelegate.storyCounts != storyCounts ||
      oldDelegate.maxCount != maxCount ||
      oldDelegate.selectedCode != selectedCode ||
      oldDelegate.transformationController != transformationController;
}
