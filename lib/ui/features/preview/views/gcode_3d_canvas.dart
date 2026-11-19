import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../domain/models/scene_models.dart';
import '../../../../domain/models/slice_result.dart';
import '../../../core/bambu_theme.dart';

class GCode3DCanvas extends StatefulWidget {
  const GCode3DCanvas({
    super.key,
    required this.sliceResult,
    required this.filaments,
    required this.maxLayerIndex,
    required this.stepRatio,
    required this.colorScheme,
    required this.showTravel,
    required this.showSeams,
  });

  final SliceResult sliceResult;
  final List<AmsProjectFilament> filaments;
  final int maxLayerIndex;
  final double stepRatio;
  final PreviewColorScheme colorScheme;
  final bool showTravel;
  final bool showSeams;

  @override
  State<GCode3DCanvas> createState() => _GCode3DCanvasState();
}

class _GCode3DCanvasState extends State<GCode3DCanvas> {
  double _yaw = -0.62;
  double _pitch = 0.60;
  double _zoom = 1.15;
  double _baseZoom = 1.15;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1E24), Color(0xFF101317)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BambuColors.borderDark),
        ),
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              setState(() {
                final delta = event.scrollDelta.dy > 0 ? -0.12 : 0.12;
                _zoom = (_zoom + delta).clamp(0.5, 3.8);
              });
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => _baseZoom = _zoom,
            onScaleUpdate: (d) {
              setState(() {
                if (d.pointerCount >= 2 || (d.scale - 1.0).abs() > 0.01) {
                  _zoom = (_baseZoom * d.scale).clamp(0.5, 3.8);
                } else {
                  _yaw += d.focalPointDelta.dx * 0.011;
                  _pitch = (_pitch + d.focalPointDelta.dy * 0.011).clamp(-1.3, 1.48);
                }
              });
            },
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                isComplex: true,
                painter: _GCodePainter(
                  result: widget.sliceResult,
                  filaments: widget.filaments,
                  maxLayerIndex: widget.maxLayerIndex,
                  stepRatio: widget.stepRatio,
                  scheme: widget.colorScheme,
                  showTravel: widget.showTravel,
                  showSeams: widget.showSeams,
                  yaw: _yaw,
                  pitch: _pitch,
                  zoom: _zoom,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GCodePainter extends CustomPainter {
  _GCodePainter({
    required this.result,
    required this.filaments,
    required this.maxLayerIndex,
    required this.stepRatio,
    required this.scheme,
    required this.showTravel,
    required this.showSeams,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });

  final SliceResult result;
  final List<AmsProjectFilament> filaments;
  final int maxLayerIndex;
  final double stepRatio;
  final PreviewColorScheme scheme;
  final bool showTravel;
  final bool showSeams;
  final double yaw;
  final double pitch;
  final double zoom;

  static const _objectPalette = [
    Color(0xFF00AE42),
    Color(0xFF29B6F6),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
    Color(0xFFEF5350),
    Color(0xFF26A69A),
  ];

  late double _cy, _sy, _cp, _sp;
  late double _baseScale, _cxScr, _cyScr, _halfX, _halfY;
  static const double _fov = 900.0;

  @pragma('vm:prefer-inline')
  Offset _project(double x, double y, double z) {
    final cx = x - _halfX;
    final cy = y - _halfY;
    final cz = z - 18.0;
    final x1 = cx * _cy - cy * _sy;
    final y1 = cx * _sy + cy * _cy;
    final y2 = y1 * _cp - cz * _sp;
    final z2 = y1 * _sp + cz * _cp;
    final persp = _fov / (y2 + _fov < 140.0 ? 140.0 : y2 + _fov);
    final s = _baseScale * persp;
    return Offset(_cxScr + x1 * s, _cyScr - z2 * s);
  }

  Color _colorForSegment(GCodeSegment s, GCodeLayer layer) {
    switch (scheme) {
      case PreviewColorScheme.lineType:
        return s.lineType.color;
      case PreviewColorScheme.filament:
      case PreviewColorScheme.tool:
        if (filaments.isEmpty) return BambuColors.green;
        return filaments[s.filamentIndex.clamp(0, filaments.length - 1)].color;
      case PreviewColorScheme.speed:
        return _heatColor((s.speedMmS / 350.0).clamp(0.0, 1.0));
      case PreviewColorScheme.flow:
        return _heatColor((s.flowMm3S / 24.0).clamp(0.0, 1.0));
      case PreviewColorScheme.layerHeight:
        return _heatColor(((s.layerHeight - 0.08) / 0.24).clamp(0.0, 1.0));
      case PreviewColorScheme.fanSpeed:
        return Color.lerp(const Color(0xFFEF5350), const Color(0xFF29B6F6), s.fanPercent / 100.0)!;
      case PreviewColorScheme.layerTime:
        return _heatColor((layer.estimatedSeconds / 45.0).clamp(0.0, 1.0));
      case PreviewColorScheme.temperature:
        return Color.lerp(
          const Color(0xFFFFB300),
          const Color(0xFFD50000),
          ((s.tempC - 190) / 100.0).clamp(0.0, 1.0),
        )!;
      case PreviewColorScheme.perObject:
        if (s.objectIndex < 0) return const Color(0xFF00BCD4);
        return _objectPalette[s.objectIndex % _objectPalette.length];
    }
  }

  Color _heatColor(double t) {
    if (t < 0.5) {
      return Color.lerp(const Color(0xFF1E88E5), const Color(0xFF00E676), t * 2)!;
    }
    return Color.lerp(const Color(0xFF00E676), const Color(0xFFFF3D00), (t - 0.5) * 2)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _cy = math.cos(yaw);
    _sy = math.sin(yaw);
    _cp = math.cos(pitch);
    _sp = math.sin(pitch);
    _halfX = result.bedX * 0.5;
    _halfY = result.bedY * 0.5;
    _baseScale =
        (math.min(size.width, size.height) / (math.max(result.bedX, result.bedY) * 1.42)) * zoom;
    _cxScr = size.width * 0.5;
    _cyScr = size.height * 0.58;

    // 1. Draw bed boundary
    final p0 = _project(0, 0, 0);
    final p1 = _project(result.bedX.toDouble(), 0, 0);
    final p2 = _project(result.bedX.toDouble(), result.bedY.toDouble(), 0);
    final p3 = _project(0, result.bedY.toDouble(), 0);
    final bed = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    canvas.drawPath(bed, Paint()..color = const Color(0xFF23272E));
    canvas.drawPath(
      bed,
      Paint()
        ..color = BambuColors.green.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    if (result.layers.isEmpty) return;

    final topLayer = maxLayerIndex.clamp(0, result.layers.length - 1);

    // 2. Batch line segments by (ARGB color + strokeWidth bucket) for GPU drawRawPoints!
    final bodyBatches = <int, List<double>>{};
    final topBatches = <int, List<double>>{};
    final travelLines = <double>[];
    final seamPts = <double>[];
    Offset? nozzlePos;

    for (var li = 0; li <= topLayer; li++) {
      final layer = result.layers[li];
      final isCurrentTop = li == topLayer;
      final segLimit = isCurrentTop
          ? (layer.segments.length * stepRatio).ceil().clamp(0, layer.segments.length)
          : layer.segments.length;

      for (var si = 0; si < segLimit; si++) {
        final s = layer.segments[si];
        if (s.lineType == GCodeLineType.travel) {
          if (!showTravel) continue;
          final a = _project(s.x1, s.y1, s.z);
          final b = _project(s.x2, s.y2, s.z);
          travelLines..add(a.dx)..add(a.dy)..add(b.dx)..add(b.dy);
          if (isCurrentTop) nozzlePos = b;
          continue;
        }

        final a = _project(s.x1, s.y1, s.z);
        final b = _project(s.x2, s.y2, s.z);
        final argb = _colorForSegment(s, layer).toARGB32();
        final bucketMap = isCurrentTop ? topBatches : bodyBatches;
        final list = bucketMap.putIfAbsent(argb, () => <double>[]);
        list..add(a.dx)..add(a.dy)..add(b.dx)..add(b.dy);

        if (showSeams && si == 0 && s.lineType == GCodeLineType.outerWall) {
          seamPts..add(a.dx)..add(a.dy);
        }
        if (isCurrentTop) nozzlePos = b;
      }
    }

    // Draw lower body layers in batched GPU calls
    final paint = Paint()..strokeCap = StrokeCap.round;
    paint.strokeWidth = 1.45;
    for (final entry in bodyBatches.entries) {
      paint.color = Color(entry.key).withValues(alpha: 0.72);
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(entry.value),
        paint,
      );
    }

    // Draw travel lines in one GPU call
    if (travelLines.isNotEmpty) {
      paint
        ..color = GCodeLineType.travel.color.withValues(alpha: 0.55)
        ..strokeWidth = 0.8;
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(travelLines),
        paint,
      );
    }

    // Draw active top layer brightly
    paint.strokeWidth = 2.2;
    for (final entry in topBatches.entries) {
      paint.color = Color(entry.key);
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(entry.value),
        paint,
      );
    }

    // Draw Z-seams in one GPU call
    if (seamPts.isNotEmpty) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(seamPts),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // Draw animated nozzle head indicator
    if (nozzlePos != null) {
      canvas.drawCircle(
        nozzlePos,
        6,
        Paint()..color = BambuColors.green.withValues(alpha: 0.35),
      );
      canvas.drawCircle(
        nozzlePos,
        3.2,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GCodePainter old) {
    return old.result != result ||
        old.maxLayerIndex != maxLayerIndex ||
        old.stepRatio != stepRatio ||
        old.scheme != scheme ||
        old.showTravel != showTravel ||
        old.showSeams != showSeams ||
        old.yaw != yaw ||
        old.pitch != pitch ||
        old.zoom != zoom ||
        old.filaments != filaments;
  }
}
