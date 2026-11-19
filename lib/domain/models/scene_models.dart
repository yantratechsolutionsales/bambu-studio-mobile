import 'dart:math' as math;
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'printer_profile.dart';

class Vec3 {
  const Vec3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) => Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 normalized() {
    final len = length;
    if (len < 1e-8) return const Vec3(0, 0, 1);
    return Vec3(x / len, y / len, z / len);
  }
}

class Triangle3D {
  const Triangle3D({
    required this.v0,
    required this.v1,
    required this.v2,
    required this.normal,
    this.filamentOverride,
    this.isSupportEnforcer = false,
    this.isSupportBlocker = false,
    this.isSeam = false,
    this.isFuzzy = false,
  });

  final Vec3 v0;
  final Vec3 v1;
  final Vec3 v2;
  final Vec3 normal;
  final int? filamentOverride;
  final bool isSupportEnforcer;
  final bool isSupportBlocker;
  final bool isSeam;
  final bool isFuzzy;

  Triangle3D copyWith({
    int? filamentOverride,
    bool? isSupportEnforcer,
    bool? isSupportBlocker,
    bool? isSeam,
    bool? isFuzzy,
  }) {
    return Triangle3D(
      v0: v0,
      v1: v1,
      v2: v2,
      normal: normal,
      filamentOverride: filamentOverride ?? this.filamentOverride,
      isSupportEnforcer: isSupportEnforcer ?? this.isSupportEnforcer,
      isSupportBlocker: isSupportBlocker ?? this.isSupportBlocker,
      isSeam: isSeam ?? this.isSeam,
      isFuzzy: isFuzzy ?? this.isFuzzy,
    );
  }
}

class Mesh3D {
  Mesh3D({
    required this.name,
    required List<Triangle3D> triangles,
    required this.minBounds,
    required this.maxBounds,
    int? sourceTriangleCount,
    this._lodVertexCoords,
    this._lodFaceNormals,
  })  : _triangles = triangles,
        _vertexCoords = _packTriangles(triangles),
        _faceNormals = _packNormals(triangles),
        sourceTriangleCount = sourceTriangleCount ?? triangles.length;

  /// Fast zero-object-overhead constructor backed directly by flat Float32Lists.
  /// [vertexCoords] has 9 floats per triangle: [x0,y0,z0, x1,y1,z1, x2,y2,z2, ...].
  /// [_faceNormals] has 3 floats per triangle: [nx,ny,nz, ...].
  Mesh3D.fromPacked({
    required this.name,
    required Float32List vertexCoords,
    required this._faceNormals,
    required this.minBounds,
    required this.maxBounds,
    int? sourceTriangleCount,
    this._lodVertexCoords,
    this._lodFaceNormals,
  })  : _triangles = null,
        _vertexCoords = vertexCoords,
        sourceTriangleCount = sourceTriangleCount ?? (vertexCoords.length ~/ 9);

  final String name;
  List<Triangle3D>? _triangles;
  final Float32List _vertexCoords;
  final Float32List _faceNormals;
  final Float32List? _lodVertexCoords;
  final Float32List? _lodFaceNormals;
  final Vec3 minBounds;
  final Vec3 maxBounds;
  final int sourceTriangleCount;

  /// Flat packed triangle vertices (9 floats per triangle) for GPU drawVertices.
  Float32List get vertexCoords => _vertexCoords;

  /// Flat packed triangle unit normals (3 floats per triangle).
  Float32List get faceNormals => _faceNormals;

  /// Optional lightweight LOD vertices used while actively orbiting heavy scenes.
  Float32List get lodVertexCoords => _lodVertexCoords ?? _vertexCoords;
  Float32List get lodFaceNormals => _lodFaceNormals ?? _faceNormals;

  /// Lazily materializes Triangle3D list only when requested (e.g. cut/boolean).
  List<Triangle3D> get triangles {
    final existing = _triangles;
    if (existing != null) return existing;
    final count = triangleCount;
    final list = List<Triangle3D>.generate(count, (i) {
      final vi = i * 9;
      final ni = i * 3;
      return Triangle3D(
        v0: Vec3(_vertexCoords[vi], _vertexCoords[vi + 1], _vertexCoords[vi + 2]),
        v1: Vec3(_vertexCoords[vi + 3], _vertexCoords[vi + 4], _vertexCoords[vi + 5]),
        v2: Vec3(_vertexCoords[vi + 6], _vertexCoords[vi + 7], _vertexCoords[vi + 8]),
        normal: Vec3(_faceNormals[ni], _faceNormals[ni + 1], _faceNormals[ni + 2]),
      );
    }, growable: false);
    _triangles = list;
    return list;
  }

  Vec3 get size => Vec3(
        (maxBounds.x - minBounds.x).abs(),
        (maxBounds.y - minBounds.y).abs(),
        (maxBounds.z - minBounds.z).abs(),
      );

  int get triangleCount => _vertexCoords.length ~/ 9;

  static Float32List _packTriangles(List<Triangle3D> tris) {
    final out = Float32List(tris.length * 9);
    for (var i = 0; i < tris.length; i++) {
      final t = tris[i];
      final o = i * 9;
      out[o] = t.v0.x;
      out[o + 1] = t.v0.y;
      out[o + 2] = t.v0.z;
      out[o + 3] = t.v1.x;
      out[o + 4] = t.v1.y;
      out[o + 5] = t.v1.z;
      out[o + 6] = t.v2.x;
      out[o + 7] = t.v2.y;
      out[o + 8] = t.v2.z;
    }
    return out;
  }

  static Float32List _packNormals(List<Triangle3D> tris) {
    final out = Float32List(tris.length * 3);
    for (var i = 0; i < tris.length; i++) {
      final n = tris[i].normal;
      final o = i * 3;
      out[o] = n.x;
      out[o + 1] = n.y;
      out[o + 2] = n.z;
    }
    return out;
  }

  /// Exports mesh to valid ASCII STL for Bambu Studio CLI bridge or export.
  String toAsciiStl({
    Vec3 offset = const Vec3(0, 0, 0),
    Vec3 scale = const Vec3(1, 1, 1),
  }) {
    final buf = StringBuffer()..writeln('solid $name');
    final count = triangleCount;
    for (var i = 0; i < count; i++) {
      final vi = i * 9;
      final ni = i * 3;
      buf.writeln(
        '  facet normal ${_faceNormals[ni].toStringAsFixed(4)} ${_faceNormals[ni + 1].toStringAsFixed(4)} ${_faceNormals[ni + 2].toStringAsFixed(4)}',
      );
      buf.writeln('    outer loop');
      for (var k = 0; k < 3; k++) {
        final vx = _vertexCoords[vi + k * 3] * scale.x + offset.x;
        final vy = _vertexCoords[vi + k * 3 + 1] * scale.y + offset.y;
        final vz = _vertexCoords[vi + k * 3 + 2] * scale.z + offset.z;
        buf.writeln(
          '      vertex ${vx.toStringAsFixed(3)} ${vy.toStringAsFixed(3)} ${vz.toStringAsFixed(3)}',
        );
      }
      buf.writeln('    endloop');
      buf.writeln('  endfacet');
    }
    buf.writeln('endsolid $name');
    return buf.toString();
  }
}

/// Every official Bambu Studio 3D Gizmo tool from src/slic3r/GUI/Gizmos/
enum GizmoTool {
  select('Select', Icons.near_me_outlined, 'Inspect & select objects'),
  move('Move', Icons.open_with, 'Translate X / Y / Z'),
  rotate('Rotate', Icons.rotate_90_degrees_cw, 'Rotate axes or lay on face'),
  scale('Scale', Icons.aspect_ratio, 'Scale uniform or non-uniform'),
  layOnFace('Lay on Face', Icons.layers_outlined, 'Snap flat face to build plate'),
  cut('Cut', Icons.content_cut, 'Planar & dovetail cut with connectors'),
  meshBoolean('Boolean', Icons.join_inner, 'Union, Difference, Intersection'),
  supportPainting('Support Paint', Icons.account_tree_outlined, 'Paint support enforcers & blockers'),
  seamPainting('Seam Paint', Icons.linear_scale, 'Paint Z-seam alignment & blockers'),
  colorPainting('Color Paint', Icons.brush, 'Multi-color AMS filament painting'),
  fuzzySkin('Fuzzy Skin', Icons.grain, 'Paint textured fuzzy skin zones'),
  variableLayerHeight('Variable Layer', Icons.tune, 'Adaptive Z layer height curve'),
  textEmboss('Text Shape', Icons.text_fields, '3D embossed/debossed surface text'),
  svgEmboss('SVG Shape', Icons.draw_outlined, 'Import & emboss vector SVG'),
  measure('Measure', Icons.straighten, 'Point-to-point distance & angle'),
  simplify('Simplify', Icons.auto_fix_high, 'Decimate triangle count'),
  assembly('Assemble', Icons.view_in_ar, 'Exploded view & face alignment'),
  brimEars('Brim Ears', Icons.radio_button_checked, 'Add anti-warp helper discs'),
  hollow('Hollow', Icons.invert_colors, 'Shell hollowing & drain holes');

  const GizmoTool(this.label, this.icon, this.tooltip);
  final String label;
  final IconData icon;
  final String tooltip;
}

class TextEmbossAnnotation {
  const TextEmbossAnnotation({
    required this.text,
    required this.sizeMm,
    required this.thicknessMm,
    required this.isDeboss,
    required this.filamentIndex,
  });

  final String text;
  final double sizeMm;
  final double thicknessMm;
  final bool isDeboss;
  final int filamentIndex;
}

enum PartModifierKind {
  modifier('Modifier Mesh', Icons.tune),
  negativePart('Negative Part (Cutout)', Icons.remove_circle_outline),
  heightRange('Height Range Modifier', Icons.height);

  const PartModifierKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

class ObjectPartModifier {
  const ObjectPartModifier({
    required this.id,
    required this.kind,
    required this.label,
    this.zMinMm = 0,
    this.zMaxMm = 10,
    this.infillOverridePercent,
    this.wallLoopsOverride,
  });

  final String id;
  final PartModifierKind kind;
  final String label;
  final double zMinMm;
  final double zMaxMm;
  final int? infillOverridePercent;
  final int? wallLoopsOverride;
}

class SceneObject {
  const SceneObject({
    required this.id,
    required this.name,
    required this.mesh,
    this.position = const Vec3(0, 0, 0),
    this.rotationDeg = const Vec3(0, 0, 0),
    this.scale = const Vec3(1, 1, 1),
    this.filamentIndex = 0,
    this.isVisible = true,
    this.isLocked = false,
    this.objectProcessOverrides,
    this.variableLayerQuality = 0.5,
    this.hasVariableLayerHeight = false,
    this.brimEarCount = 0,
    this.hollowWallThickness = 0.0,
    this.textAnnotations = const [],
    this.svgBadgeName,
    this.paintedBandColors = const {},
    this.hasSupportEnforcers = false,
    this.hasSeamOverride = false,
    this.hasFuzzyZone = false,
    this.mirroredX = false,
    this.mirroredY = false,
    this.mirroredZ = false,
    this.isMeshRepaired = true,
    this.modifiers = const [],
  });

  final String id;
  final String name;
  final Mesh3D mesh;
  final Vec3 position;
  final Vec3 rotationDeg;
  final Vec3 scale;
  final int filamentIndex;
  final bool isVisible;
  final bool isLocked;
  final ProcessSettings? objectProcessOverrides;
  final double variableLayerQuality;
  final bool hasVariableLayerHeight;
  final int brimEarCount;
  final double hollowWallThickness;
  final List<TextEmbossAnnotation> textAnnotations;
  final String? svgBadgeName;
  /// Map of normalized height band (0..4) -> filamentIndex for color painting
  final Map<int, int> paintedBandColors;
  final bool hasSupportEnforcers;
  final bool hasSeamOverride;
  final bool hasFuzzyZone;
  final bool mirroredX;
  final bool mirroredY;
  final bool mirroredZ;
  final bool isMeshRepaired;
  final List<ObjectPartModifier> modifiers;

  Vec3 get scaledSize => Vec3(
        mesh.size.x * scale.x,
        mesh.size.y * scale.y,
        mesh.size.z * scale.z,
      );

  SceneObject copyWith({
    String? id,
    String? name,
    Mesh3D? mesh,
    Vec3? position,
    Vec3? rotationDeg,
    Vec3? scale,
    int? filamentIndex,
    bool? isVisible,
    bool? isLocked,
    ProcessSettings? objectProcessOverrides,
    bool clearOverrides = false,
    double? variableLayerQuality,
    bool? hasVariableLayerHeight,
    int? brimEarCount,
    double? hollowWallThickness,
    List<TextEmbossAnnotation>? textAnnotations,
    String? svgBadgeName,
    Map<int, int>? paintedBandColors,
    bool? hasSupportEnforcers,
    bool? hasSeamOverride,
    bool? hasFuzzyZone,
    bool? mirroredX,
    bool? mirroredY,
    bool? mirroredZ,
    bool? isMeshRepaired,
    List<ObjectPartModifier>? modifiers,
  }) {
    return SceneObject(
      id: id ?? this.id,
      name: name ?? this.name,
      mesh: mesh ?? this.mesh,
      position: position ?? this.position,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      scale: scale ?? this.scale,
      filamentIndex: filamentIndex ?? this.filamentIndex,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      objectProcessOverrides: clearOverrides
          ? null
          : (objectProcessOverrides ?? this.objectProcessOverrides),
      variableLayerQuality: variableLayerQuality ?? this.variableLayerQuality,
      hasVariableLayerHeight:
          hasVariableLayerHeight ?? this.hasVariableLayerHeight,
      brimEarCount: brimEarCount ?? this.brimEarCount,
      hollowWallThickness: hollowWallThickness ?? this.hollowWallThickness,
      textAnnotations: textAnnotations ?? this.textAnnotations,
      svgBadgeName: svgBadgeName ?? this.svgBadgeName,
      paintedBandColors: paintedBandColors ?? this.paintedBandColors,
      hasSupportEnforcers: hasSupportEnforcers ?? this.hasSupportEnforcers,
      hasSeamOverride: hasSeamOverride ?? this.hasSeamOverride,
      hasFuzzyZone: hasFuzzyZone ?? this.hasFuzzyZone,
      mirroredX: mirroredX ?? this.mirroredX,
      mirroredY: mirroredY ?? this.mirroredY,
      mirroredZ: mirroredZ ?? this.mirroredZ,
      isMeshRepaired: isMeshRepaired ?? this.isMeshRepaired,
      modifiers: modifiers ?? this.modifiers,
    );
  }
}

class BuildPlate {
  const BuildPlate({
    required this.index,
    required this.name,
    this.bedType = 'Textured PEI Plate',
    this.printSequence = 'by_layer',
    this.isLocked = false,
    this.objects = const [],
  });

  final int index;
  final String name;
  final String bedType;
  final String printSequence;
  final bool isLocked;
  final List<SceneObject> objects;

  BuildPlate copyWith({
    String? name,
    String? bedType,
    String? printSequence,
    bool? isLocked,
    List<SceneObject>? objects,
  }) {
    return BuildPlate(
      index: index,
      name: name ?? this.name,
      bedType: bedType ?? this.bedType,
      printSequence: printSequence ?? this.printSequence,
      isLocked: isLocked ?? this.isLocked,
      objects: objects ?? this.objects,
    );
  }
}

class AmsProjectFilament {
  const AmsProjectFilament({
    required this.slotIndex,
    required this.profile,
    required this.customColorHex,
  });

  final int slotIndex;
  final FilamentProfile profile;
  final String customColorHex;

  Color get color {
    final cleaned = customColorHex.replaceFirst('#', '');
    final value = int.tryParse(
          cleaned.length == 6 ? 'FF$cleaned' : cleaned,
          radix: 16,
        ) ??
        0xFF00AE42;
    return Color(value);
  }

  AmsProjectFilament copyWith({
    FilamentProfile? profile,
    String? customColorHex,
  }) {
    return AmsProjectFilament(
      slotIndex: slotIndex,
      profile: profile ?? this.profile,
      customColorHex: customColorHex ?? this.customColorHex,
    );
  }
}
