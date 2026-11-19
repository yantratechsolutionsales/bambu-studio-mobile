import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../domain/models/scene_models.dart';
import '../../../core/bambu_theme.dart';
import '../view_models/studio_workspace_view_model.dart';

/// Reusable flat typed-array render buffers to achieve zero per-triangle heap
/// allocations and single-call GPU `canvas.drawVertices` rendering at 60 FPS.
class _SceneRenderBuffers {
  static const int _buckets = 1024;

  int _cap = 0;
  Float32List sx0 = Float32List(0);
  Float32List sy0 = Float32List(0);
  Float32List sx1 = Float32List(0);
  Float32List sy1 = Float32List(0);
  Float32List sx2 = Float32List(0);
  Float32List sy2 = Float32List(0);
  Float32List depth = Float32List(0);
  Int32List color = Int32List(0);
  Int32List bucketIdx = Int32List(0);

  Float32List sortedPos = Float32List(0);
  Int32List sortedCol = Int32List(0);
  Float32List wireLines = Float32List(0);

  final Int32List bucketCounts = Int32List(_buckets);
  final Int32List bucketOffsets = Int32List(_buckets);

  /// Screen-space bounding boxes of rendered objects for tap-to-select hit testing.
  final Map<String, Rect> objectHitRects = {};

  void ensureCapacity(int neededTris) {
    if (neededTris <= _cap) return;
    var next = math.max(2048, _cap);
    while (next < neededTris) {
      next *= 2;
    }
    _cap = next;
    sx0 = Float32List(next);
    sy0 = Float32List(next);
    sx1 = Float32List(next);
    sy1 = Float32List(next);
    sx2 = Float32List(next);
    sy2 = Float32List(next);
    depth = Float32List(next);
    color = Int32List(next);
    bucketIdx = Int32List(next);
    sortedPos = Float32List(next * 6);
    sortedCol = Int32List(next * 3);
    wireLines = Float32List(next * 12);
  }
}

class Viewport3DWidget extends StatefulWidget {
  const Viewport3DWidget({
    super.key,
    required this.viewModel,
  });

  final StudioWorkspaceViewModel viewModel;

  @override
  State<Viewport3DWidget> createState() => _Viewport3DWidgetState();
}

class _Viewport3DWidgetState extends State<Viewport3DWidget> {
  double _yaw = -0.62;
  double _pitch = 0.58;
  double _zoom = 1.10;
  double _baseZoom = 1.10;
  Offset _pan = Offset.zero;
  bool _isInteracting = false;
  bool _showBuildVolume = true;
  bool _rightButtonDown = false;
  int _lastFramedRevision = -1;

  final _SceneRenderBuffers _buffers = _SceneRenderBuffers();

  @override
  void initState() {
    super.initState();
    _lastFramedRevision = widget.viewModel.importRevision;
  }

  @override
  void didUpdateWidget(covariant Viewport3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewModel.importRevision != _lastFramedRevision) {
      _lastFramedRevision = widget.viewModel.importRevision;
      _autoFramePlate();
    }
  }

  void _autoFramePlate() {
    _yaw = -0.62;
    _pitch = 0.58;
    _pan = Offset.zero;
    final objs = widget.viewModel.activePlate.objects;
    final printer = widget.viewModel.selectedPrinter;
    final bedMax = math.max(printer?.bedX ?? 256, printer?.bedY ?? 256).toDouble();
    if (objs.isEmpty) {
      _zoom = 1.08;
      return;
    }
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    var maxZ = 20.0;
    for (final o in objs) {
      if (!o.isVisible) continue;
      final sz = o.scaledSize;
      minX = math.min(minX, o.position.x - sz.x * 0.5);
      maxX = math.max(maxX, o.position.x + sz.x * 0.5);
      minY = math.min(minY, o.position.y - sz.y * 0.5);
      maxY = math.max(maxY, o.position.y + sz.y * 0.5);
      maxZ = math.max(maxZ, o.position.z + sz.z);
    }
    final span = math.max(maxX - minX, math.max(maxY - minY, maxZ));
    if (span.isFinite && span > 5) {
      // Frame neatly so small clips zoom in closer while full-plate projects show the whole bed
      final ratio = (bedMax * 0.85) / math.max(span, bedMax * 0.35);
      _zoom = ratio.clamp(1.02, 2.25);
    } else {
      _zoom = 1.10;
    }
  }

  void _setCameraPreset(double yaw, double pitch) {
    setState(() {
      _yaw = yaw;
      _pitch = pitch;
      _pan = Offset.zero;
    });
  }

  void _handleTapSelect(Offset localPos) {
    String? hitId;
    double bestArea = double.infinity;
    for (final entry in _buffers.objectHitRects.entries) {
      if (entry.value.inflate(6).contains(localPos)) {
        final area = entry.value.width * entry.value.height;
        if (area < bestArea) {
          bestArea = area;
          hitId = entry.key;
        }
      }
    }
    if (hitId != null && hitId != widget.viewModel.selectedObjectId) {
      widget.viewModel.selectObject(hitId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final printer = vm.selectedPrinter;
    final bedX = printer?.bedX ?? 256;
    final bedY = printer?.bedY ?? 256;
    final bedZ = printer?.bedZ ?? 256;
    final plate = vm.activePlate;

    // Count total rendered triangles on active plate for HUD & LOD heuristic
    var totalTris = 0;
    for (final o in plate.objects) {
      if (o.isVisible) totalTris += o.mesh.triangleCount;
    }
    final useLod = _isInteracting && totalTris > 9000;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF20242B), Color(0xFF14171C)],
          ),
          border: Border.all(color: BambuColors.borderDark),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Listener(
              onPointerDown: (e) {
                _rightButtonDown = (e.buttons & kSecondaryMouseButton) != 0 ||
                    (e.buttons & kMiddleMouseButton) != 0;
              },
              onPointerUp: (_) => _rightButtonDown = false,
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  setState(() {
                    final delta = event.scrollDelta.dy > 0 ? -0.12 : 0.12;
                    _zoom = (_zoom + delta).clamp(0.45, 3.8);
                  });
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _handleTapSelect(d.localPosition),
                onScaleStart: (_) {
                  _baseZoom = _zoom;
                  if (totalTris > 9000) {
                    setState(() => _isInteracting = true);
                  }
                },
                onScaleUpdate: (details) {
                  setState(() {
                    if (_rightButtonDown) {
                      _pan += details.focalPointDelta;
                    } else if (details.pointerCount >= 2 &&
                        (details.scale - 1.0).abs() > 0.01) {
                      _zoom = (_baseZoom * details.scale).clamp(0.45, 3.8);
                      _pan += details.focalPointDelta * 0.6;
                    } else {
                      _yaw += details.focalPointDelta.dx * 0.011;
                      _pitch = (_pitch + details.focalPointDelta.dy * 0.011)
                          .clamp(-1.35, 1.50);
                    }
                  });
                },
                onScaleEnd: (_) {
                  if (_isInteracting) {
                    setState(() => _isInteracting = false);
                  }
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    isComplex: true,
                    willChange: _isInteracting,
                    painter: _BambuScenePainter(
                      buffers: _buffers,
                      plate: plate,
                      sceneVersion: vm.sceneVersion,
                      selectedObjectId: vm.selectedObjectId,
                      filaments: vm.projectFilaments,
                      printerName: printer?.name ?? 'Bambu Lab X1 Carbon',
                      bedX: bedX,
                      bedY: bedY,
                      bedZ: bedZ,
                      yaw: _yaw,
                      pitch: _pitch,
                      zoom: _zoom,
                      pan: _pan,
                      wireframe: vm.wireframeMode,
                      showBuildVolume: _showBuildVolume,
                      useLod: useLod,
                      activeGizmo: vm.activeGizmo,
                      cutPlaneZ: vm.cutPlaneHeight,
                      explodeFactor: vm.assemblyExplodeFactor,
                    ),
                  ),
                ),
              ),
            ),

            // Top-left plate & printer HUD (Desktop Bambu Studio style)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BambuColors.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${plate.name} • ${plate.bedType}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: BambuColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${printer?.name ?? "Bambu Lab"} ($bedX×$bedY×$bedZ mm) • ${plate.objects.length} obj',
                      style: const TextStyle(
                        fontSize: 10,
                        color: BambuColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top-right camera presets + wireframe + build cage toggles
            Positioned(
              top: 10,
              right: 10,
              child: Wrap(
                spacing: 4,
                children: [
                  _CameraPill('ISO', () => _setCameraPreset(-0.62, 0.58)),
                  _CameraPill('TOP', () => _setCameraPreset(0, 1.49)),
                  _CameraPill('FRONT', () => _setCameraPreset(0, 0.04)),
                  _CameraPill('SIDE', () => _setCameraPreset(math.pi / 2, 0.04)),
                  _IconPill(
                    icon: Icons.crop_free,
                    active: _showBuildVolume,
                    tooltip: 'Toggle Build Volume Cage',
                    onTap: () => setState(() => _showBuildVolume = !_showBuildVolume),
                  ),
                  _IconPill(
                    icon: vm.wireframeMode ? Icons.grid_on : Icons.view_in_ar,
                    active: vm.wireframeMode,
                    tooltip: 'Toggle Wireframe',
                    onTap: vm.toggleWireframe,
                  ),
                ],
              ),
            ),

            // Bottom-right Zoom & Auto-Frame controls
            Positioned(
              bottom: 10,
              right: 10,
              child: Column(
                children: [
                  _IconPill(
                    icon: Icons.add,
                    tooltip: 'Zoom In',
                    onTap: () => setState(() => _zoom = (_zoom + 0.22).clamp(0.45, 3.8)),
                  ),
                  const SizedBox(height: 4),
                  _IconPill(
                    icon: Icons.remove,
                    tooltip: 'Zoom Out',
                    onTap: () => setState(() => _zoom = (_zoom - 0.22).clamp(0.45, 3.8)),
                  ),
                  const SizedBox(height: 4),
                  _IconPill(
                    icon: Icons.center_focus_strong,
                    tooltip: 'Fit Plate to View',
                    onTap: () => setState(_autoFramePlate),
                  ),
                ],
              ),
            ),

            // Bottom-left selected object badge
            if (vm.selectedObject != null)
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: BambuColors.green.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.view_in_ar, size: 13, color: BambuColors.green),
                      const SizedBox(width: 5),
                      Text(
                        '${vm.selectedObject!.name}  '
                        '${vm.selectedObject!.scaledSize.x.toStringAsFixed(1)}×'
                        '${vm.selectedObject!.scaledSize.y.toStringAsFixed(1)}×'
                        '${vm.selectedObject!.scaledSize.z.toStringAsFixed(1)} mm',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: BambuColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Import loading overlay
            if (vm.isImporting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: BambuColors.green),
                        SizedBox(height: 12),
                        Text(
                          'Importing 3MF / 3D Model...',
                          style: TextStyle(
                            color: BambuColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraPill extends StatelessWidget {
  const _CameraPill(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: BambuColors.borderDark),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: BambuColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active
              ? BambuColors.green.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? BambuColors.green : BambuColors.borderDark,
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: active ? BambuColors.green : BambuColors.textPrimary,
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: child) : child;
  }
}

class _BambuScenePainter extends CustomPainter {
  _BambuScenePainter({
    required this.buffers,
    required this.plate,
    required this.sceneVersion,
    required this.selectedObjectId,
    required this.filaments,
    required this.printerName,
    required this.bedX,
    required this.bedY,
    required this.bedZ,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
    required this.wireframe,
    required this.showBuildVolume,
    required this.useLod,
    required this.activeGizmo,
    required this.cutPlaneZ,
    required this.explodeFactor,
  });

  final _SceneRenderBuffers buffers;
  final BuildPlate plate;
  final int sceneVersion;
  final String? selectedObjectId;
  final List<AmsProjectFilament> filaments;
  final String printerName;
  final int bedX;
  final int bedY;
  final int bedZ;
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset pan;
  final bool wireframe;
  final bool showBuildVolume;
  final bool useLod;
  final GizmoTool activeGizmo;
  final double cutPlaneZ;
  final double explodeFactor;

  // Precomputed per-paint camera constants
  late double _cy, _sy, _cp, _sp;
  late double _baseScale, _cxScreen, _cyScreen;
  static const double _fov = 900.0;
  static const double _targetZ = 18.0;

  @pragma('vm:prefer-inline')
  Offset _projectOffset(double x, double y, double z) {
    final x1 = x * _cy - y * _sy;
    final y1 = x * _sy + y * _cy;
    final z1 = z - _targetZ;
    final y2 = y1 * _cp - z1 * _sp;
    final z2 = y1 * _sp + z1 * _cp;
    final persp = _fov / (y2 + _fov < 140.0 ? 140.0 : y2 + _fov);
    final s = _baseScale * persp;
    return Offset(_cxScreen + x1 * s, _cyScreen - z2 * s);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _cy = math.cos(yaw);
    _sy = math.sin(yaw);
    _cp = math.cos(pitch);
    _sp = math.sin(pitch);

    final maxBed = math.max(bedX, bedY).toDouble();
    _baseScale = (math.min(size.width, size.height) / (maxBed * 1.42)) * zoom;
    _cxScreen = size.width * 0.5 + pan.dx;
    _cyScreen = size.height * 0.56 + pan.dy;

    final halfX = bedX * 0.5;
    final halfY = bedY * 0.5;

    // 1. Desktop Bambu Studio Build Plate Surface & Grid
    _paintBuildPlate(canvas, halfX, halfY);

    // 2. Ground Contact Shadows under each object (drawn on bed before 3D meshes)
    _paintGroundShadows(canvas);

    // 3. Transform, Cull, Shade, Bucket-Sort & Single-Call GPU Render all 3D meshes
    _paintSceneMeshes(canvas);

    // 4. Crisp Selection Bounding Box around Selected Object (Desktop Bambu Style)
    _paintSelectedBounds(canvas);

    // 5. Optional Subtle 3D Print Volume Cage
    if (showBuildVolume) {
      _paintBuildVolumeCage(canvas, halfX, halfY, bedZ.toDouble());
    }

    // 6. Active Gizmo Overlays (Planar Cut / Measure)
    _paintGizmoOverlays(canvas, halfX);
  }

  void _paintBuildPlate(Canvas canvas, double halfX, double halfY) {
    final c0 = _projectOffset(-halfX, -halfY, 0);
    final c1 = _projectOffset(halfX, -halfY, 0);
    final c2 = _projectOffset(halfX, halfY, 0);
    final c3 = _projectOffset(-halfX, halfY, 0);

    // Outer subtle plate thickness bevel (plate rim)
    final r0 = _projectOffset(-halfX, -halfY, -2.5);
    final r1 = _projectOffset(halfX, -halfY, -2.5);
    final r2 = _projectOffset(halfX, halfY, -2.5);
    final r3 = _projectOffset(-halfX, halfY, -2.5);

    final rimPaint = Paint()..color = const Color(0xFF101318);
    final frontRim = Path()
      ..moveTo(c0.dx, c0.dy)
      ..lineTo(c1.dx, c1.dy)
      ..lineTo(r1.dx, r1.dy)
      ..lineTo(r0.dx, r0.dy)
      ..close();
    canvas.drawPath(frontRim, rimPaint);
    final sideRim = Path()
      ..moveTo(c1.dx, c1.dy)
      ..lineTo(c2.dx, c2.dy)
      ..lineTo(r2.dx, r2.dy)
      ..lineTo(r1.dx, r1.dy)
      ..close();
    canvas.drawPath(sideRim, rimPaint);
    final leftRim = Path()
      ..moveTo(c3.dx, c3.dy)
      ..lineTo(c0.dx, c0.dy)
      ..lineTo(r0.dx, r0.dy)
      ..lineTo(r3.dx, r3.dy)
      ..close();
    canvas.drawPath(leftRim, rimPaint);

    // Front PEI handle tab (characteristic Bambu Studio plate lip)
    final tabW = math.min(34.0, halfX * 0.35);
    final t0 = _projectOffset(-tabW, -halfY, 0);
    final t1 = _projectOffset(tabW, -halfY, 0);
    final t2 = _projectOffset(tabW * 0.82, -halfY - 11.0, 0);
    final t3 = _projectOffset(-tabW * 0.82, -halfY - 11.0, 0);
    final tabPath = Path()
      ..moveTo(t0.dx, t0.dy)
      ..lineTo(t1.dx, t1.dy)
      ..lineTo(t2.dx, t2.dy)
      ..lineTo(t3.dx, t3.dy)
      ..close();

    final bedLower = plate.bedType.toLowerCase();
    final isTexturedPei = bedLower.contains('textured');
    final isCool = bedLower.contains('cool');
    final bedFill = isTexturedPei
        ? const Color(0xFF2D271E)
        : isCool
            ? const Color(0xFF1E2832)
            : const Color(0xFF252A31);
    final borderCol = isTexturedPei
        ? const Color(0xFFD4A74A).withValues(alpha: 0.72)
        : BambuColors.green.withValues(alpha: 0.65);

    canvas.drawPath(tabPath, Paint()..color = bedFill);
    canvas.drawPath(
      tabPath,
      Paint()
        ..color = borderCol
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final bedPath = Path()
      ..moveTo(c0.dx, c0.dy)
      ..lineTo(c1.dx, c1.dy)
      ..lineTo(c2.dx, c2.dy)
      ..lineTo(c3.dx, c3.dy)
      ..close();

    canvas.drawPath(bedPath, Paint()..color = bedFill);

    // 10mm minor grid & 50mm major grid (matching Desktop Bambu Studio)
    final minorLines = <double>[];
    final majorLines = <double>[];

    for (var x = -halfX + 10.0; x < halfX - 0.1; x += 10.0) {
      final a = _projectOffset(x, -halfY, 0);
      final b = _projectOffset(x, halfY, 0);
      final fromEdge = (x + halfX).round();
      final target = (fromEdge % 50 == 0) ? majorLines : minorLines;
      target..add(a.dx)..add(a.dy)..add(b.dx)..add(b.dy);
    }
    for (var y = -halfY + 10.0; y < halfY - 0.1; y += 10.0) {
      final a = _projectOffset(-halfX, y, 0);
      final b = _projectOffset(halfX, y, 0);
      final fromEdge = (y + halfY).round();
      final target = (fromEdge % 50 == 0) ? majorLines : minorLines;
      target..add(a.dx)..add(a.dy)..add(b.dx)..add(b.dy);
    }

    if (minorLines.isNotEmpty) {
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(minorLines),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.055)
          ..strokeWidth = 0.75,
      );
    }
    if (majorLines.isNotEmpty) {
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(majorLines),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.14)
          ..strokeWidth = 1.0,
      );
    }

    // Crisp plate border
    canvas.drawPath(
      bedPath,
      Paint()
        ..color = borderCol
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Bambu Calibration Purge Strip along front edge
    final pStart = _projectOffset(-halfX + 14, -halfY + 5, 0.15);
    final pEnd = _projectOffset(halfX - 28, -halfY + 5, 0.15);
    canvas.drawLine(
      pStart,
      pEnd,
      Paint()
        ..color = BambuColors.green.withValues(alpha: 0.62)
        ..strokeWidth = 1.8,
    );

    // Printer Bed Watermark Label near front lip
    final labelPt = _projectOffset(0, -halfY + 11, 0.2);
    final tp = TextPainter(
      text: TextSpan(
        text: '$printerName  $bedX×$bedY',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.28),
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(labelPt.dx - tp.width * 0.5, labelPt.dy - tp.height * 0.5));

    // RGB Axis Triad at Front-Left Origin (X=Red, Y=Green, Z=Blue)
    final origin = _projectOffset(-halfX, -halfY, 0);
    final axX = _projectOffset(-halfX + 34, -halfY, 0);
    final axY = _projectOffset(-halfX, -halfY + 34, 0);
    final axZ = _projectOffset(-halfX, -halfY, 34);
    canvas.drawLine(origin, axX, Paint()..color = const Color(0xFFEF5350)..strokeWidth = 2.0);
    canvas.drawLine(origin, axY, Paint()..color = const Color(0xFF00AE42)..strokeWidth = 2.0);
    canvas.drawLine(origin, axZ, Paint()..color = const Color(0xFF42A5F5)..strokeWidth = 2.0);
  }

  void _paintGroundShadows(Canvas canvas) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;
    for (var oi = 0; oi < plate.objects.length; oi++) {
      final obj = plate.objects[oi];
      if (!obj.isVisible) continue;
      final sz = obj.scaledSize;
      final ox = obj.position.x * (1.0 + explodeFactor * 0.9);
      final oy = obj.position.y * (1.0 + explodeFactor * 0.9);
      final hx = sz.x * 0.48;
      final hy = sz.y * 0.48;
      final s0 = _projectOffset(ox - hx, oy - hy, 0.08);
      final s1 = _projectOffset(ox + hx, oy - hy, 0.08);
      final s2 = _projectOffset(ox + hx, oy + hy, 0.08);
      final s3 = _projectOffset(ox - hx, oy + hy, 0.08);
      final sp = Path()
        ..moveTo(s0.dx, s0.dy)
        ..lineTo(s1.dx, s1.dy)
        ..lineTo(s2.dx, s2.dy)
        ..lineTo(s3.dx, s3.dy)
        ..close();
      canvas.drawPath(sp, shadowPaint);
    }
  }

  void _paintSceneMeshes(Canvas canvas) {
    // 1. Estimate max visible triangles and ensure flat typed-array capacity
    var maxTris = 0;
    for (final obj in plate.objects) {
      if (!obj.isVisible) continue;
      final verts = useLod ? obj.mesh.lodVertexCoords : obj.mesh.vertexCoords;
      maxTris += verts.length ~/ 9;
    }
    buffers.objectHitRects.clear();
    if (maxTris == 0) return;
    buffers.ensureCapacity(maxTris);

    // 3-point Desktop Bambu Studio lighting rig (world space, unit vectors)
    // Key light: front-right-above
    const kLx = 0.42, kLy = -0.56, kLz = 0.714;
    // Fill light: front-left-above
    const fLx = -0.68, fLy = -0.35, fLz = 0.644;
    // Rim light: back-top
    const rLx = -0.25, rLy = 0.78, rLz = 0.573;

    // Camera view direction (pointing FROM origin TOWARD viewer) in world space
    // Inverse of yaw+pitch rotation applied to camera forward (0, -1, 0):
    final camX = -_sy * _cp;
    final camY = -_cy * _cp;
    final camZ = _sp;
    // Half-vector for Blinn-Phong specular with key light
    final hxRaw = kLx + camX;
    final hyRaw = kLy + camY;
    final hzRaw = kLz + camZ;
    final hLen = math.sqrt(hxRaw * hxRaw + hyRaw * hyRaw + hzRaw * hzRaw);
    final invH = hLen > 1e-6 ? 1.0 / hLen : 1.0;
    final hLx = hxRaw * invH, hLy = hyRaw * invH, hLz = hzRaw * invH;

    final sx0Buf = buffers.sx0;
    final sy0Buf = buffers.sy0;
    final sx1Buf = buffers.sx1;
    final sy1Buf = buffers.sy1;
    final sx2Buf = buffers.sx2;
    final sy2Buf = buffers.sy2;
    final depthBuf = buffers.depth;
    final colBuf = buffers.color;

    var visCount = 0;
    double minD = double.infinity;
    double maxD = double.negativeInfinity;

    final cy = _cy, sy = _sy, cp = _cp, sp = _sp;
    final baseScale = _baseScale, cxScr = _cxScreen, cyScr = _cyScreen;

    for (var oi = 0; oi < plate.objects.length; oi++) {
      final obj = plate.objects[oi];
      if (!obj.isVisible) continue;

      final isSel = obj.id == selectedObjectId;
      final slotIdx = filaments.isEmpty
          ? 0
          : obj.filamentIndex.clamp(0, filaments.length - 1);
      final rawColor = filaments.isNotEmpty
          ? filaments[slotIdx].color
          : BambuColors.green;

      // Smart albedo lift for pure-black filament (#000000 -> dark satin charcoal)
      // just like Desktop Bambu Studio so bevels, gear teeth, and threads remain readable!
      var baseR = rawColor.r;
      var baseG = rawColor.g;
      var baseB = rawColor.b;
      final lum = 0.2126 * baseR + 0.7152 * baseG + 0.0722 * baseB;
      if (lum < 0.14) {
        baseR = math.max(baseR, 0.20);
        baseG = math.max(baseG, 0.22);
        baseB = math.max(baseB, 0.25);
      }

      // Subtle warm highlight tint when selected
      final selLift = isSel ? 0.07 : 0.0;

      // Precompute 3x3 rotation+scale+mirror matrix ONCE per object
      final rx = obj.rotationDeg.x * (math.pi / 180.0);
      final ry = obj.rotationDeg.y * (math.pi / 180.0);
      final rz = obj.rotationDeg.z * (math.pi / 180.0);
      final crx = math.cos(rx), srx = math.sin(rx);
      final cry = math.cos(ry), sry = math.sin(ry);
      final crz = math.cos(rz), srz = math.sin(rz);

      final sx = obj.scale.x * (obj.mirroredX ? -1.0 : 1.0);
      final syS = obj.scale.y * (obj.mirroredY ? -1.0 : 1.0);
      final sz = obj.scale.z * (obj.mirroredZ ? -1.0 : 1.0);

      // R = Rz * Ry * Rx applied to diag(sx, syS, sz)
      final r00 = (crz * cry) * sx;
      final r01 = (crz * sry * srx - srz * crx) * syS;
      final r02 = (crz * sry * crx + srz * srx) * sz;

      final r10 = (srz * cry) * sx;
      final r11 = (srz * sry * srx + crz * crx) * syS;
      final r12 = (srz * sry * crx - crz * srx) * sz;

      final r20 = (-sry) * sx;
      final r21 = (cry * srx) * syS;
      final r22 = (cry * crx) * sz;

      // Normal rotation matrix (pure rotation without non-uniform scale)
      final n00 = crz * cry;
      final n01 = crz * sry * srx - srz * crx;
      final n02 = crz * sry * crx + srz * srx;
      final n10 = srz * cry;
      final n11 = srz * sry * srx + crz * crx;
      final n12 = srz * sry * crx - crz * srx;
      final n20 = -sry;
      final n21 = cry * srx;
      final n22 = cry * crx;

      final flipMirror = (sx * syS * sz) < 0;

      final tx = obj.position.x * (1.0 + explodeFactor * 0.9);
      final ty = obj.position.y * (1.0 + explodeFactor * 0.9);
      final tz = obj.position.z + explodeFactor * oi * 24.0;

      final verts = useLod ? obj.mesh.lodVertexCoords : obj.mesh.vertexCoords;
      final normals = useLod ? obj.mesh.lodFaceNormals : obj.mesh.faceNormals;
      final triCount = verts.length ~/ 9;

      final hasBands = obj.paintedBandColors.isNotEmpty;
      final maxLocalZ = math.max(1.0, obj.mesh.size.z);
      final supportPreview = activeGizmo == GizmoTool.supportPainting;
      final fuzzyPreview = activeGizmo == GizmoTool.fuzzySkin && obj.hasFuzzyZone;

      double hitMinX = double.infinity, hitMinY = double.infinity;
      double hitMaxX = double.negativeInfinity, hitMaxY = double.negativeInfinity;

      for (var t = 0; t < triCount; t++) {
        final vi = t * 9;
        // Vertex 0 -> world -> screen
        final lx0 = verts[vi], ly0 = verts[vi + 1], lz0 = verts[vi + 2];
        final wx0 = r00 * lx0 + r01 * ly0 + r02 * lz0 + tx;
        final wy0 = r10 * lx0 + r11 * ly0 + r12 * lz0 + ty;
        final wz0 = r20 * lx0 + r21 * ly0 + r22 * lz0 + tz;
        final cx0 = wx0 * cy - wy0 * sy;
        final cy0 = wx0 * sy + wy0 * cy;
        final cz0 = wz0 - _targetZ;
        final d0 = cy0 * cp - cz0 * sp;
        final p0 = _fov / (d0 + _fov < 140.0 ? 140.0 : d0 + _fov);
        final s0 = baseScale * p0;
        final px0 = cxScr + cx0 * s0;
        final py0 = cyScr - (cy0 * sp + cz0 * cp) * s0;

        // Vertex 1 -> world -> screen
        final lx1 = verts[vi + 3], ly1 = verts[vi + 4], lz1 = verts[vi + 5];
        final wx1 = r00 * lx1 + r01 * ly1 + r02 * lz1 + tx;
        final wy1 = r10 * lx1 + r11 * ly1 + r12 * lz1 + ty;
        final wz1 = r20 * lx1 + r21 * ly1 + r22 * lz1 + tz;
        final cx1 = wx1 * cy - wy1 * sy;
        final cy1 = wx1 * sy + wy1 * cy;
        final cz1 = wz1 - _targetZ;
        final d1 = cy1 * cp - cz1 * sp;
        final p1 = _fov / (d1 + _fov < 140.0 ? 140.0 : d1 + _fov);
        final s1 = baseScale * p1;
        final px1 = cxScr + cx1 * s1;
        final py1 = cyScr - (cy1 * sp + cz1 * cp) * s1;

        // Vertex 2 -> world -> screen
        final lx2 = verts[vi + 6], ly2 = verts[vi + 7], lz2 = verts[vi + 8];
        final wx2 = r00 * lx2 + r01 * ly2 + r02 * lz2 + tx;
        final wy2 = r10 * lx2 + r11 * ly2 + r12 * lz2 + ty;
        final wz2 = r20 * lx2 + r21 * ly2 + r22 * lz2 + tz;
        final cx2 = wx2 * cy - wy2 * sy;
        final cy2 = wx2 * sy + wy2 * cy;
        final cz2 = wz2 - _targetZ;
        final d2 = cy2 * cp - cz2 * sp;
        final p2 = _fov / (d2 + _fov < 140.0 ? 140.0 : d2 + _fov);
        final s2 = baseScale * p2;
        final px2 = cxScr + cx2 * s2;
        final py2 = cyScr - (cy2 * sp + cz2 * cp) * s2;

        // 2D Screen-space backface culling (front faces have cross2d < 0)
        if (!wireframe) {
          final cross2d = (px1 - px0) * (py2 - py0) - (py1 - py0) * (px2 - px0);
          if (flipMirror ? (cross2d <= 0.0) : (cross2d >= 0.0)) {
            continue;
          }
        }

        // Update screen-space hit-test AABB for tap selection
        if (px0 < hitMinX) hitMinX = px0;
        if (px0 > hitMaxX) hitMaxX = px0;
        if (py0 < hitMinY) hitMinY = py0;
        if (py0 > hitMaxY) hitMaxY = py0;

        // Rotate precomputed unit normal into world space
        final ni = t * 3;
        final lnx = normals[ni], lny = normals[ni + 1], lnz = normals[ni + 2];
        final wnx = n00 * lnx + n01 * lny + n02 * lnz;
        final wny = n10 * lnx + n11 * lny + n12 * lnz;
        final wnz = n20 * lnx + n21 * lny + n22 * lnz;

        var tr = baseR, tg = baseG, tb = baseB;

        if (hasBands) {
          final avgZ = (lz0 + lz1 + lz2) * (1.0 / 3.0);
          final band = ((avgZ / maxLocalZ) * 5.0).floor().clamp(0, 4);
          final paintSlot = obj.paintedBandColors[band];
          if (paintSlot != null && paintSlot < filaments.length) {
            final bc = filaments[paintSlot].color;
            tr = bc.r;
            tg = bc.g;
            tb = bc.b;
          }
        }

        if (supportPreview && wnz < -0.45) {
          tr = 0.0;
          tg = 0.90;
          tb = 0.46;
        } else if (fuzzyPreview && wnz.abs() < 0.4) {
          tr = 0.67;
          tg = 0.28;
          tb = 0.74;
        }

        // 3-Point Studio Shading + Hemisphere Ambient + Blinn-Phong Specular
        final keyDot = math.max(0.0, wnx * kLx + wny * kLy + wnz * kLz);
        final fillDot = math.max(0.0, wnx * fLx + wny * fLy + wnz * fLz);
        final rimDot = math.max(0.0, wnx * rLx + wny * rLy + wnz * rLz);
        final hemi = 0.24 + 0.08 * wnz; // brighter top, darker underside
        final diffuse = hemi + 0.58 * keyDot + 0.22 * fillDot + 0.14 * rimDot + selLift;

        // Subtle satin PLA/PETG specular highlight
        final specDot = math.max(0.0, wnx * hLx + wny * hLy + wnz * hLz);
        final spec2 = specDot * specDot;
        final spec4 = spec2 * spec2;
        final spec = spec4 * spec4 * spec4 * 0.16; // spec^12 * 0.16

        final ri = ((tr * diffuse + spec) * 255.0).round().clamp(0, 255);
        final gi = ((tg * diffuse + spec) * 255.0).round().clamp(0, 255);
        final bi = ((tb * diffuse + spec) * 255.0).round().clamp(0, 255);

        final avgD = (d0 + d1 + d2) * (1.0 / 3.0);
        sx0Buf[visCount] = px0;
        sy0Buf[visCount] = py0;
        sx1Buf[visCount] = px1;
        sy1Buf[visCount] = py1;
        sx2Buf[visCount] = px2;
        sy2Buf[visCount] = py2;
        depthBuf[visCount] = avgD;
        colBuf[visCount] = 0xFF000000 | (ri << 16) | (gi << 8) | bi;
        if (avgD < minD) minD = avgD;
        if (avgD > maxD) maxD = avgD;
        visCount++;
      }

      if (hitMinX < hitMaxX && hitMinY < hitMaxY) {
        buffers.objectHitRects[obj.id] = Rect.fromLTRB(hitMinX, hitMinY, hitMaxX, hitMaxY);
      }

      // Draw Brim Ears indicator discs if configured
      if (obj.brimEarCount > 0) {
        final szVec = obj.scaledSize;
        final corners = [
          (obj.position.x - szVec.x * 0.5, obj.position.y - szVec.y * 0.5),
          (obj.position.x + szVec.x * 0.5, obj.position.y - szVec.y * 0.5),
          (obj.position.x + szVec.x * 0.5, obj.position.y + szVec.y * 0.5),
          (obj.position.x - szVec.x * 0.5, obj.position.y + szVec.y * 0.5),
        ];
        final brimPaint = Paint()..color = BambuColors.info.withValues(alpha: 0.45);
        for (var i = 0; i < math.min(obj.brimEarCount, corners.length); i++) {
          final pt = _projectOffset(corners[i].$1, corners[i].$2, 0.3);
          canvas.drawCircle(pt, 6, brimPaint);
        }
      }
    }

    if (visCount == 0) return;

    if (wireframe) {
      // Single-call GPU wireframe rendering
      final wl = buffers.wireLines;
      var wi = 0;
      for (var i = 0; i < visCount; i++) {
        final x0 = sx0Buf[i], y0 = sy0Buf[i];
        final x1 = sx1Buf[i], y1 = sy1Buf[i];
        final x2 = sx2Buf[i], y2 = sy2Buf[i];
        wl[wi++] = x0;
        wl[wi++] = y0;
        wl[wi++] = x1;
        wl[wi++] = y1;
        wl[wi++] = x1;
        wl[wi++] = y1;
        wl[wi++] = x2;
        wl[wi++] = y2;
        wl[wi++] = x2;
        wl[wi++] = y2;
        wl[wi++] = x0;
        wl[wi++] = y0;
      }
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.sublistView(wl, 0, wi),
        Paint()
          ..color = BambuColors.green.withValues(alpha: 0.78)
          ..strokeWidth = 0.7,
      );
      return;
    }

    // 2. O(N) 1024-Bucket Counting Sort (back-to-front: largest depth first!)
    const buckets = _SceneRenderBuffers._buckets;
    final counts = buffers.bucketCounts;
    final offsets = buffers.bucketOffsets;
    final bIdx = buffers.bucketIdx;
    counts.fillRange(0, buckets, 0);

    final range = maxD - minD;
    final invRange = range > 1e-5 ? (buckets - 1) / range : 0.0;

    for (var i = 0; i < visCount; i++) {
      final b = ((maxD - depthBuf[i]) * invRange).toInt().clamp(0, buckets - 1);
      bIdx[i] = b;
      counts[b]++;
    }

    var sum = 0;
    for (var b = 0; b < buckets; b++) {
      offsets[b] = sum;
      sum += counts[b];
    }

    final sortedPos = buffers.sortedPos;
    final sortedCol = buffers.sortedCol;

    for (var i = 0; i < visCount; i++) {
      final dst = offsets[bIdx[i]]++;
      final pOff = dst * 6;
      sortedPos[pOff] = sx0Buf[i];
      sortedPos[pOff + 1] = sy0Buf[i];
      sortedPos[pOff + 2] = sx1Buf[i];
      sortedPos[pOff + 3] = sy1Buf[i];
      sortedPos[pOff + 4] = sx2Buf[i];
      sortedPos[pOff + 5] = sy2Buf[i];

      final c = colBuf[i];
      final cOff = dst * 3;
      sortedCol[cOff] = c;
      sortedCol[cOff + 1] = c;
      sortedCol[cOff + 2] = c;
    }

    // 3. SINGLE GPU DRAW CALL for all sorted triangles!
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(sortedPos, 0, visCount * 6),
      colors: Int32List.sublistView(sortedCol, 0, visCount * 3),
    );
    canvas.drawVertices(vertices, BlendMode.srcOver, Paint());
  }

  void _paintSelectedBounds(Canvas canvas) {
    if (selectedObjectId == null) return;
    SceneObject? sel;
    var selIdx = 0;
    for (var i = 0; i < plate.objects.length; i++) {
      if (plate.objects[i].id == selectedObjectId && plate.objects[i].isVisible) {
        sel = plate.objects[i];
        selIdx = i;
        break;
      }
    }
    if (sel == null) return;

    final sz = sel.scaledSize;
    final ox = sel.position.x * (1.0 + explodeFactor * 0.9);
    final oy = sel.position.y * (1.0 + explodeFactor * 0.9);
    final oz = sel.position.z + explodeFactor * selIdx * 24.0;
    final hx = sz.x * 0.5 + 0.8;
    final hy = sz.y * 0.5 + 0.8;
    final hz = sz.z + 0.8;

    final pts = [
      _projectOffset(ox - hx, oy - hy, oz),
      _projectOffset(ox + hx, oy - hy, oz),
      _projectOffset(ox + hx, oy + hy, oz),
      _projectOffset(ox - hx, oy + hy, oz),
      _projectOffset(ox - hx, oy - hy, oz + hz),
      _projectOffset(ox + hx, oy - hy, oz + hz),
      _projectOffset(ox + hx, oy + hy, oz + hz),
      _projectOffset(ox - hx, oy + hy, oz + hz),
    ];

    const edges = [
      0, 1, 1, 2, 2, 3, 3, 0,
      4, 5, 5, 6, 6, 7, 7, 4,
      0, 4, 1, 5, 2, 6, 3, 7,
    ];
    final linePts = Float32List(edges.length * 2);
    for (var i = 0; i < edges.length; i++) {
      final pt = pts[edges[i]];
      linePts[i * 2] = pt.dx;
      linePts[i * 2 + 1] = pt.dy;
    }

    canvas.drawRawPoints(
      ui.PointMode.lines,
      linePts,
      Paint()
        ..color = BambuColors.green.withValues(alpha: 0.65)
        ..strokeWidth = 1.15,
    );
  }

  void _paintBuildVolumeCage(Canvas canvas, double halfX, double halfY, double heightZ) {
    final pts = [
      _projectOffset(-halfX, -halfY, 0),
      _projectOffset(halfX, -halfY, 0),
      _projectOffset(halfX, halfY, 0),
      _projectOffset(-halfX, halfY, 0),
      _projectOffset(-halfX, -halfY, heightZ),
      _projectOffset(halfX, -halfY, heightZ),
      _projectOffset(halfX, halfY, heightZ),
      _projectOffset(-halfX, halfY, heightZ),
    ];
    const edges = [
      4, 5, 5, 6, 6, 7, 7, 4,
      0, 4, 1, 5, 2, 6, 3, 7,
    ];
    final linePts = Float32List(edges.length * 2);
    for (var i = 0; i < edges.length; i++) {
      final pt = pts[edges[i]];
      linePts[i * 2] = pt.dx;
      linePts[i * 2 + 1] = pt.dy;
    }
    canvas.drawRawPoints(
      ui.PointMode.lines,
      linePts,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 0.85,
    );
  }

  void _paintGizmoOverlays(Canvas canvas, double halfX) {
    // Active Planar Cut Gizmo Overlay
    if (activeGizmo == GizmoTool.cut) {
      final cutHalf = halfX * 0.65;
      final k0 = _projectOffset(-cutHalf, -cutHalf, cutPlaneZ);
      final k1 = _projectOffset(cutHalf, -cutHalf, cutPlaneZ);
      final k2 = _projectOffset(cutHalf, cutHalf, cutPlaneZ);
      final k3 = _projectOffset(-cutHalf, cutHalf, cutPlaneZ);
      final cutPath = Path()
        ..moveTo(k0.dx, k0.dy)
        ..lineTo(k1.dx, k1.dy)
        ..lineTo(k2.dx, k2.dy)
        ..lineTo(k3.dx, k3.dy)
        ..close();
      canvas.drawPath(
        cutPath,
        Paint()..color = const Color(0xFFFF5252).withValues(alpha: 0.22),
      );
      canvas.drawPath(
        cutPath,
        Paint()
          ..color = const Color(0xFFFF5252)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // Measure Gizmo Dimension Overlay
    if (activeGizmo == GizmoTool.measure && plate.objects.isNotEmpty) {
      final obj = plate.objects.firstWhere(
        (o) => o.id == selectedObjectId,
        orElse: () => plate.objects.first,
      );
      final sz = obj.scaledSize;
      final a = _projectOffset(obj.position.x - sz.x / 2, obj.position.y, obj.position.z + sz.z);
      final b = _projectOffset(obj.position.x + sz.x / 2, obj.position.y, obj.position.z + sz.z);
      canvas.drawLine(a, b, Paint()..color = BambuColors.warning..strokeWidth = 2.2);
      canvas.drawCircle(a, 4, Paint()..color = BambuColors.warning);
      canvas.drawCircle(b, 4, Paint()..color = BambuColors.warning);
    }
  }

  @override
  bool shouldRepaint(covariant _BambuScenePainter old) {
    return old.sceneVersion != sceneVersion ||
        old.plate != plate ||
        old.selectedObjectId != selectedObjectId ||
        old.bedX != bedX ||
        old.bedY != bedY ||
        old.bedZ != bedZ ||
        old.yaw != yaw ||
        old.pitch != pitch ||
        old.zoom != zoom ||
        old.pan != pan ||
        old.wireframe != wireframe ||
        old.showBuildVolume != showBuildVolume ||
        old.useLod != useLod ||
        old.activeGizmo != activeGizmo ||
        old.cutPlaneZ != cutPlaneZ ||
        old.explodeFactor != explodeFactor ||
        old.filaments != filaments;
  }
}
