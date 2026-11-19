import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../domain/models/scene_models.dart';

/// Represents a single parsed build plate from a 3MF project or standalone mesh file.
class ImportedPlateData {
  const ImportedPlateData({
    required this.plateIndex,
    required this.name,
    required this.bedType,
    required this.objects,
  });

  final int plateIndex;
  final String name;
  final String bedType;
  final List<SceneObject> objects;
}

/// Complete imported project payload parsed from Bambu Studio 3MF (Core & Production
/// Extension), Binary/ASCII STL, or Wavefront OBJ files.
class ImportedProjectData {
  const ImportedProjectData({
    required this.projectName,
    required this.plates,
    required this.isFullProject,
    this.printerModel,
    this.bedX,
    this.bedY,
    this.bedType,
    this.layerHeight,
    this.filamentColors = const [],
    this.filamentTypes = const [],
    this.totalSourceTriangles = 0,
    this.totalRenderedTriangles = 0,
    this.parseTimeMs = 0,
  });

  final String projectName;
  final List<ImportedPlateData> plates;
  final bool isFullProject;
  final String? printerModel;
  final int? bedX;
  final int? bedY;
  final String? bedType;
  final double? layerHeight;
  final List<String> filamentColors;
  final List<String> filamentTypes;
  final int totalSourceTriangles;
  final int totalRenderedTriangles;
  final int parseTimeMs;
}

/// Top-level isolate-safe entry point for `compute()`.
ImportedProjectData parseModelFileIsolate(Map<String, dynamic> args) {
  const parser = StlParserService();
  return parser.parseAnyModelFile(
    args['bytes'] as Uint8List,
    fileName: args['fileName'] as String,
    defaultBedX: args['defaultBedX'] as int? ?? 256,
    defaultBedY: args['defaultBedY'] as int? ?? 256,
    maxPlateTriangles: args['maxPlateTriangles'] as int? ?? 14000,
  );
}

/// Top-level isolate-safe entry point for parsing standalone STL bytes.
Mesh3D parseStlBytesIsolate(Map<String, dynamic> args) {
  const parser = StlParserService();
  return parser.parseStlBytes(
    args['bytes'] as Uint8List,
    name: args['name'] as String,
    maxTriangles: args['maxTriangles'] as int? ?? 6000,
  );
}

class _RawIndexedMesh {
  _RawIndexedMesh(this.verts, this.indices);
  final Float32List verts; // x,y,z per vertex
  final Int32List indices; // v1,v2,v3 per triangle
  int get triangleCount => indices.length ~/ 3;
}

class _ComponentRef {
  _ComponentRef({
    required this.path,
    required this.objectId,
    required this.matrix,
  });
  final String? path;
  final String objectId;
  final Float64List matrix; // 12-float 3MF affine matrix
}

class _ModelObjectMeta {
  _ModelObjectMeta({required this.id});
  final String id;
  String? name;
  int extruder = 1; // 1-based in Bambu Studio
  final Set<String> partSubtypes = {};
}

class _PlateConfig {
  _PlateConfig({required this.platerId, required this.name});
  final int platerId;
  final String name;
  final List<String> objectIds = [];
}

class _WorldObjectBuild {
  _WorldObjectBuild({
    required this.objectId,
    required this.name,
    required this.filamentIndex,
    required this.verts,
    required this.indices,
    required this.minX,
    required this.minY,
    required this.minZ,
    required this.maxX,
    required this.maxY,
    required this.maxZ,
  });
  final String objectId;
  final String name;
  final int filamentIndex;
  final Float32List verts;
  final Int32List indices;
  final double minX, minY, minZ, maxX, maxY, maxZ;
  int get triangleCount => indices.length ~/ 3;
}

/// High-performance 3D file parser supporting:
/// - Full Bambu Studio 3MF (Core Spec + Production Extension external object models,
///   multi-object transforms, multi-plate assignments, printer/filament/bed metadata)
/// - Binary & ASCII STL
/// - Wavefront OBJ
/// - Hole-free Spatial Vertex-Clustering Decimation (with optional interactive LOD)
/// - Built-in Bambu Studio primitive generators & mesh operations (cut, simplify)
class StlParserService {
  const StlParserService();

  static final Float64List _identityMatrix = Float64List.fromList([
    1, 0, 0,
    0, 1, 0,
    0, 0, 1,
    0, 0, 0,
  ]);

  /// Universal entry point for `.3mf`, `.stl`, and `.obj` files.
  ImportedProjectData parseAnyModelFile(
    Uint8List bytes, {
    required String fileName,
    int defaultBedX = 256,
    int defaultBedY = 256,
    int maxPlateTriangles = 14000,
  }) {
    final sw = Stopwatch()..start();
    final lower = fileName.toLowerCase();
    final isZipMagic = bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

    if (lower.endsWith('.3mf') || isZipMagic) {
      try {
        final parsed = _parse3mfBytes(
          bytes,
          fileName: fileName,
          defaultBedX: defaultBedX,
          defaultBedY: defaultBedY,
          maxPlateTriangles: maxPlateTriangles,
        );
        sw.stop();
        return ImportedProjectData(
          projectName: parsed.projectName,
          plates: parsed.plates,
          isFullProject: true,
          printerModel: parsed.printerModel,
          bedX: parsed.bedX,
          bedY: parsed.bedY,
          bedType: parsed.bedType,
          layerHeight: parsed.layerHeight,
          filamentColors: parsed.filamentColors,
          filamentTypes: parsed.filamentTypes,
          totalSourceTriangles: parsed.totalSourceTriangles,
          totalRenderedTriangles: parsed.totalRenderedTriangles,
          parseTimeMs: sw.elapsedMilliseconds,
        );
      } catch (_) {
        // Fall through to STL/OBJ if ZIP wasn't a valid 3MF
      }
    }

    if (lower.endsWith('.obj')) {
      final mesh = _parseObjBytes(bytes, name: fileName, maxTriangles: maxPlateTriangles);
      sw.stop();
      final obj = SceneObject(
        id: 'obj_${DateTime.now().microsecondsSinceEpoch}',
        name: fileName,
        mesh: mesh,
        filamentIndex: 0,
      );
      return ImportedProjectData(
        projectName: fileName,
        isFullProject: false,
        plates: [
          ImportedPlateData(
            plateIndex: 0,
            name: 'Plate 1',
            bedType: 'Textured PEI Plate',
            objects: [obj],
          ),
        ],
        totalSourceTriangles: mesh.sourceTriangleCount,
        totalRenderedTriangles: mesh.triangleCount,
        parseTimeMs: sw.elapsedMilliseconds,
      );
    }

    final mesh = parseStlBytes(bytes, name: fileName, maxTriangles: maxPlateTriangles);
    sw.stop();
    final obj = SceneObject(
      id: 'obj_${DateTime.now().microsecondsSinceEpoch}',
      name: fileName,
      mesh: mesh,
      filamentIndex: 0,
    );
    return ImportedProjectData(
      projectName: fileName,
      isFullProject: false,
      plates: [
        ImportedPlateData(
          plateIndex: 0,
          name: 'Plate 1',
          bedType: 'Textured PEI Plate',
          objects: [obj],
        ),
      ],
      totalSourceTriangles: mesh.sourceTriangleCount,
      totalRenderedTriangles: mesh.triangleCount,
      parseTimeMs: sw.elapsedMilliseconds,
    );
  }

  /// Parses binary or ASCII STL (or 3MF single-mesh fallback) into a packed Mesh3D.
  Mesh3D parseStlBytes(Uint8List bytes, {required String name, int maxTriangles = 6000}) {
    final isZipMagic = bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (name.toLowerCase().endsWith('.3mf') || isZipMagic) {
      final proj = _parse3mfBytes(
        bytes,
        fileName: name,
        defaultBedX: 256,
        defaultBedY: 256,
        maxPlateTriangles: maxTriangles,
      );
      if (proj.plates.isNotEmpty && proj.plates.first.objects.isNotEmpty) {
        return proj.plates.first.objects.first.mesh;
      }
    }
    if (name.toLowerCase().endsWith('.obj')) {
      return _parseObjBytes(bytes, name: name, maxTriangles: maxTriangles);
    }

    if (bytes.length >= 84) {
      final bd = ByteData.sublistView(bytes);
      final triCount = bd.getUint32(80, Endian.little);
      final expectedBytes = 84 + triCount * 50;
      if (triCount > 0 && expectedBytes <= bytes.length + 16 && expectedBytes >= bytes.length - 16) {
        return _parseBinaryStl(bytes, triCount, name, maxTriangles);
      }
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    if (text.contains('facet normal')) {
      return _parseAsciiStl(text, name, maxTriangles);
    }
    return createCube(name: name);
  }

  // ============================================================================
  // 1. Full Bambu Studio 3MF Parser (Core + Production Extension + Metadata)
  // ============================================================================
  ImportedProjectData _parse3mfBytes(
    Uint8List bytes, {
    required String fileName,
    required int defaultBedX,
    required int defaultBedY,
    required int maxPlateTriangles,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final fileMap = <String, ArchiveFile>{};
    for (final f in archive.files) {
      if (f.isFile) {
        fileMap[_normZipPath(f.name)] = f;
      }
    }

    // 1. Parse Metadata/project_settings.config (JSON)
    String? printerModel;
    String? bedType;
    double? layerHeight;
    int? bedX;
    int? bedY;
    final filamentColors = <String>[];
    final filamentTypes = <String>[];

    final projectCfgFile = fileMap['metadata/project_settings.config'];
    if (projectCfgFile != null) {
      try {
        final jsonStr = utf8.decode(_fileBytes(projectCfgFile), allowMalformed: true);
        final cfg = jsonDecode(jsonStr);
        if (cfg is Map<String, dynamic>) {
          final pm = cfg['printer_model'] ?? cfg['printer_settings_id'];
          if (pm is String && pm.trim().isNotEmpty) {
            printerModel = pm.trim();
          }
          final bt = cfg['curr_bed_type'];
          if (bt is String && bt.trim().isNotEmpty) {
            bedType = bt.trim();
          }
          final lh = cfg['layer_height'];
          if (lh is num) {
            layerHeight = lh.toDouble();
          } else if (lh is String) {
            layerHeight = double.tryParse(lh);
          }
          final pa = cfg['printable_area'];
          if (pa is List && pa.isNotEmpty) {
            double maxBx = 0, maxBy = 0;
            for (final pt in pa) {
              final parts = pt.toString().split('x');
              if (parts.length == 2) {
                final x = double.tryParse(parts[0]) ?? 0;
                final y = double.tryParse(parts[1]) ?? 0;
                if (x > maxBx) maxBx = x;
                if (y > maxBy) maxBy = y;
              }
            }
            if (maxBx >= 100 && maxBy >= 100) {
              bedX = maxBx.round();
              bedY = maxBy.round();
            }
          }
          final fc = cfg['filament_colour'];
          if (fc is List) {
            for (final c in fc) {
              final s = c.toString().trim();
              if (s.isNotEmpty) filamentColors.add(s);
            }
          }
          final ft = cfg['filament_type'];
          if (ft is List) {
            for (final t in ft) {
              final s = t.toString().trim();
              if (s.isNotEmpty) filamentTypes.add(s);
            }
          }
        }
      } catch (_) {}
    }

    // 2. Parse Metadata/model_settings.config (object names, extruders, plates)
    final objectMeta = <String, _ModelObjectMeta>{};
    final plateConfigs = <_PlateConfig>[];
    final modelSettingsFile = fileMap['metadata/model_settings.config'];
    if (modelSettingsFile != null) {
      final msXml = utf8.decode(_fileBytes(modelSettingsFile), allowMalformed: true);
      _parseModelSettingsXml(msXml, objectMeta, plateConfigs);
      // Detect A1 mini hint from plater_name if project_settings.config wasn't included
      if (printerModel == null) {
        for (final pc in plateConfigs) {
          if (pc.name.toLowerCase().contains('a1 mini')) {
            printerModel = 'Bambu Lab A1 mini';
            bedX ??= 180;
            bedY ??= 180;
            break;
          }
        }
      }
    }

    // Also infer bed dimensions from printerModel if printable_area was absent
    if (bedX == null || bedY == null) {
      final pmLower = (printerModel ?? fileName).toLowerCase();
      if (pmLower.contains('a1 mini') || pmLower.contains('a1mini')) {
        printerModel ??= 'Bambu Lab A1 mini';
        bedX = 180;
        bedY = 180;
      } else if (pmLower.contains('h2d')) {
        bedX = 350;
        bedY = 320;
      } else {
        bedX = defaultBedX;
        bedY = defaultBedY;
      }
    }

    // 3. Parse root 3D/3dmodel.model (unit, inline meshes, component refs, build items)
    final rootModelFile = fileMap['3d/3dmodel.model'] ??
        fileMap.entries
            .where((e) => e.key.endsWith('.model') && !e.key.contains('/objects/'))
            .map((e) => e.value)
            .firstOrNull;
    if (rootModelFile == null) {
      throw const FormatException('No 3D/3dmodel.model found in 3MF archive');
    }

    final rootBytes = _fileBytes(rootModelFile);
    final rootText = utf8.decode(rootBytes, allowMalformed: true);
    final unitScale = _parse3mfUnitScale(rootText);
    final rootTitle = _extract3mfTitle(rootText) ?? fileName;

    // Parse inline meshes from root model (e.g. standard single-file 3MF)
    final externalMeshCache = <String, Map<String, _RawIndexedMesh>>{};
    final rootInlineMeshes = _scanModelMeshesFast(rootBytes);
    externalMeshCache['3d/3dmodel.model'] = rootInlineMeshes;

    // Parse <object id="..."><components>...</components></object> & <build><item .../>
    final objectComponents = _parseObjectComponents(rootText);
    final buildItems = _parseBuildItems(rootText);

    // Helper to load meshes from external object_N.model on demand (cached)
    Map<String, _RawIndexedMesh> getModelMeshes(String? pPath) {
      final key = (pPath == null || pPath.isEmpty) ? '3d/3dmodel.model' : _normZipPath(pPath);
      final cached = externalMeshCache[key];
      if (cached != null) return cached;
      final f = fileMap[key];
      if (f == null) {
        externalMeshCache[key] = const {};
        return const {};
      }
      final parsed = _scanModelMeshesFast(_fileBytes(f));
      externalMeshCache[key] = parsed;
      return parsed;
    }

    // Recursive resolver: collect all (RawIndexedMesh, combinedMatrix) for a given objectId
    void collectMeshInstances(
      String? modelPath,
      String objectId,
      Float64List parentMatrix,
      List<(_RawIndexedMesh, Float64List)> out,
      int depth,
    ) {
      if (depth > 8) return;
      final meshes = getModelMeshes(modelPath);
      final direct = meshes[objectId];
      if (direct != null && direct.triangleCount > 0) {
        out.add((direct, parentMatrix));
        return;
      }
      // Check component references (in root model)
      final comps = objectComponents[objectId];
      if (comps != null && comps.isNotEmpty) {
        for (final comp in comps) {
          final combined = _mul3mfMatrices(comp.matrix, parentMatrix);
          collectMeshInstances(comp.path, comp.objectId, combined, out, depth + 1);
        }
      }
    }

    // Build world-transformed indexed geometry per build item
    final worldBuildsByObjId = <String, List<_WorldObjectBuild>>{};
    final orderedWorldBuilds = <_WorldObjectBuild>[];

    // If <build> is empty, fall back to all inline meshes
    final itemsToBuild = buildItems.isNotEmpty
        ? buildItems
        : [
            for (final id in rootInlineMeshes.keys)
              (objectId: id, matrix: _identityMatrix, printable: true),
          ];

    for (var idx = 0; idx < itemsToBuild.length; idx++) {
      final item = itemsToBuild[idx];
      if (!item.printable) continue;

      final meta = objectMeta[item.objectId];
      // Skip pure negative/modifier-only objects if flagged
      if (meta != null &&
          meta.partSubtypes.isNotEmpty &&
          meta.partSubtypes.every((s) => s == 'negative_part' || s == 'modifier_part')) {
        continue;
      }

      final instances = <(_RawIndexedMesh, Float64List)>[];
      collectMeshInstances(null, item.objectId, item.matrix, instances, 0);
      if (instances.isEmpty) continue;

      // Merge component sub-meshes of this single build object into one world-space mesh
      var totalVerts = 0;
      var totalIndices = 0;
      for (final inst in instances) {
        totalVerts += inst.$1.verts.length ~/ 3;
        totalIndices += inst.$1.indices.length;
      }
      if (totalIndices == 0) continue;

      final mergedVerts = Float32List(totalVerts * 3);
      final mergedIndices = Int32List(totalIndices);
      var vOffset = 0;
      var iOffset = 0;

      var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
      var maxX = double.negativeInfinity, maxY = double.negativeInfinity, maxZ = double.negativeInfinity;

      for (final inst in instances) {
        final raw = inst.$1;
        final m = inst.$2;
        final m00 = m[0], m01 = m[1], m02 = m[2];
        final m10 = m[3], m11 = m[4], m12 = m[5];
        final m20 = m[6], m21 = m[7], m22 = m[8];
        final m30 = m[9], m31 = m[10], m32 = m[11];

        // Check linear determinant for negative scale / mirror
        final det = m00 * (m11 * m22 - m12 * m21) -
            m01 * (m10 * m22 - m12 * m20) +
            m02 * (m10 * m21 - m11 * m20);
        final flipWinding = det < 0;

        final rv = raw.verts;
        final vc = rv.length ~/ 3;
        for (var vi = 0; vi < vc; vi++) {
          final sx = rv[vi * 3];
          final sy = rv[vi * 3 + 1];
          final sz = rv[vi * 3 + 2];
          final wx = (sx * m00 + sy * m10 + sz * m20 + m30) * unitScale;
          final wy = (sx * m01 + sy * m11 + sz * m21 + m31) * unitScale;
          final wz = (sx * m02 + sy * m12 + sz * m22 + m32) * unitScale;
          final dst = (vOffset + vi) * 3;
          mergedVerts[dst] = wx;
          mergedVerts[dst + 1] = wy;
          mergedVerts[dst + 2] = wz;
          if (wx < minX) minX = wx;
          if (wy < minY) minY = wy;
          if (wz < minZ) minZ = wz;
          if (wx > maxX) maxX = wx;
          if (wy > maxY) maxY = wy;
          if (wz > maxZ) maxZ = wz;
        }

        final ri = raw.indices;
        final tc = ri.length ~/ 3;
        for (var ti = 0; ti < tc; ti++) {
          final a = ri[ti * 3] + vOffset;
          final b = ri[ti * 3 + 1] + vOffset;
          final c = ri[ti * 3 + 2] + vOffset;
          if (flipWinding) {
            mergedIndices[iOffset++] = a;
            mergedIndices[iOffset++] = c;
            mergedIndices[iOffset++] = b;
          } else {
            mergedIndices[iOffset++] = a;
            mergedIndices[iOffset++] = b;
            mergedIndices[iOffset++] = c;
          }
        }
        vOffset += vc;
      }

      final objName = meta?.name ??
          (itemsToBuild.length == 1
              ? rootTitle
              : 'Object ${item.objectId}');
      final filIdx = math.max(0, (meta?.extruder ?? 1) - 1);

      final wb = _WorldObjectBuild(
        objectId: item.objectId,
        name: objName,
        filamentIndex: filIdx,
        verts: mergedVerts,
        indices: mergedIndices,
        minX: minX,
        minY: minY,
        minZ: minZ,
        maxX: maxX,
        maxY: maxY,
        maxZ: maxZ,
      );
      orderedWorldBuilds.add(wb);
      worldBuildsByObjId.putIfAbsent(item.objectId, () => []).add(wb);
    }

    if (orderedWorldBuilds.isEmpty) {
      throw const FormatException('No printable mesh geometry found in 3MF');
    }

    // 4. Group builds into plates (respecting Bambu model_settings.config <plate> assignments)
    final plateGroups = <(String name, List<_WorldObjectBuild> items)>[];
    final assigned = <_WorldObjectBuild>{};

    if (plateConfigs.isNotEmpty) {
      for (var pi = 0; pi < plateConfigs.length; pi++) {
        final pc = plateConfigs[pi];
        final list = <_WorldObjectBuild>[];
        for (final oid in pc.objectIds) {
          final candidates = worldBuildsByObjId[oid];
          if (candidates != null) {
            for (final c in candidates) {
              if (!assigned.contains(c)) {
                list.add(c);
                assigned.add(c);
                break;
              }
            }
          }
        }
        if (list.isNotEmpty) {
          final pName = pc.name.isNotEmpty ? pc.name : 'Plate ${pi + 1}';
          plateGroups.add((pName, list));
        }
      }
    }

    // Any remaining unassigned builds go onto Plate 1 (or a new plate if others existed)
    final unassigned = orderedWorldBuilds.where((b) => !assigned.contains(b)).toList();
    if (unassigned.isNotEmpty) {
      if (plateGroups.isEmpty) {
        final firstName = plateConfigs.isNotEmpty && plateConfigs.first.name.isNotEmpty
            ? plateConfigs.first.name
            : 'Plate 1';
        plateGroups.add((firstName, unassigned));
      } else {
        plateGroups.first.$2.addAll(unassigned);
      }
    }

    // 5. Convert each plate's builds to bed-aligned SceneObjects with smart decimation
    final platesOut = <ImportedPlateData>[];
    var totalSourceTris = 0;
    var totalRenderedTris = 0;
    final effectiveBedType = bedType ?? 'Textured PEI Plate';
    final bx = bedX.toDouble();
    final by = bedY.toDouble();

    for (var pi = 0; pi < plateGroups.length; pi++) {
      final pName = plateGroups[pi].$1;
      final group = plateGroups[pi].$2;

      var plateMinX = double.infinity, plateMinY = double.infinity, plateMinZ = double.infinity;
      var plateMaxX = double.negativeInfinity, plateMaxY = double.negativeInfinity;
      var plateTotalTris = 0;

      for (final wb in group) {
        if (wb.minX < plateMinX) plateMinX = wb.minX;
        if (wb.minY < plateMinY) plateMinY = wb.minY;
        if (wb.minZ < plateMinZ) plateMinZ = wb.minZ;
        if (wb.maxX > plateMaxX) plateMaxX = wb.maxX;
        if (wb.maxY > plateMaxY) plateMaxY = wb.maxY;
        plateTotalTris += wb.triangleCount;
      }

      // Determine whether coordinates are in Bambu [0..bedX, 0..bedY] plate coordinates
      // or already origin-centered around (0, 0).
      final plateCx = (plateMinX + plateMaxX) * 0.5;
      final plateCy = (plateMinY + plateMaxY) * 0.5;
      final inBambuBedCoords = plateMinX >= -15.0 &&
          plateMinY >= -15.0 &&
          plateMaxX <= bx + 15.0 &&
          plateMaxY <= by + 15.0 &&
          (plateCx > bx * 0.15 || plateCy > by * 0.15);

      final shiftX = inBambuBedCoords ? bx * 0.5 : plateCx;
      final shiftY = inBambuBedCoords ? by * 0.5 : plateCy;
      final shiftZ = (plateMinZ < -0.1 || plateMinZ > 0.5) ? plateMinZ : 0.0;

      final sceneObjects = <SceneObject>[];
      final nowMicros = DateTime.now().microsecondsSinceEpoch;

      for (var oi = 0; oi < group.length; oi++) {
        final wb = group[oi];
        totalSourceTris += wb.triangleCount;

        // Allocate triangle budget proportionally across objects on the plate
        int targetTris;
        if (plateTotalTris <= maxPlateTriangles) {
          targetTris = wb.triangleCount;
        } else {
          final share = (maxPlateTriangles * (wb.triangleCount / plateTotalTris)).round();
          targetTris = share.clamp(math.min(1200, wb.triangleCount), maxPlateTriangles);
        }

        final objCx = (wb.minX + wb.maxX) * 0.5;
        final objCy = (wb.minY + wb.maxY) * 0.5;
        final objMinZ = wb.minZ;

        // Shift mesh into local object space: centered at local XY (0,0), resting on Z=0
        final localVerts = Float32List(wb.verts.length);
        for (var k = 0; k < wb.verts.length; k += 3) {
          localVerts[k] = wb.verts[k] - objCx;
          localVerts[k + 1] = wb.verts[k + 1] - objCy;
          localVerts[k + 2] = wb.verts[k + 2] - objMinZ;
        }

        final mesh = _buildPackedMeshFromIndexed(
          name: wb.name,
          verts: localVerts,
          indices: wb.indices,
          maxTriangles: targetTris,
          sourceTriangleCount: wb.triangleCount,
          alreadyCentered: true,
        );
        totalRenderedTris += mesh.triangleCount;

        sceneObjects.add(SceneObject(
          id: '3mf_${nowMicros}_${pi}_$oi',
          name: wb.name,
          mesh: mesh,
          position: Vec3(
            objCx - shiftX,
            objCy - shiftY,
            math.max(0.0, objMinZ - shiftZ),
          ),
          filamentIndex: wb.filamentIndex,
        ));
      }

      platesOut.add(ImportedPlateData(
        plateIndex: pi,
        name: pName,
        bedType: effectiveBedType,
        objects: sceneObjects,
      ));
    }

    return ImportedProjectData(
      projectName: rootTitle,
      plates: platesOut,
      isFullProject: true,
      printerModel: printerModel,
      bedX: bedX,
      bedY: bedY,
      bedType: effectiveBedType,
      layerHeight: layerHeight,
      filamentColors: filamentColors,
      filamentTypes: filamentTypes,
      totalSourceTriangles: totalSourceTris,
      totalRenderedTriangles: totalRenderedTris,
    );
  }

  // ============================================================================
  // 2. Zero-DOM Fast Byte-Level 3MF XML Mesh Scanner
  // ============================================================================
  Map<String, _RawIndexedMesh> _scanModelMeshesFast(Uint8List data) {
    final result = <String, _RawIndexedMesh>{};
    final len = data.length;

    String? currentObjId;
    var verts = Float32List(1024 * 3);
    var vLen = 0;
    var indices = Int32List(1024 * 3);
    var iLen = 0;

    void ensureVertCap(int needed) {
      if (needed <= verts.length) return;
      var cap = verts.length;
      while (cap < needed) {
        cap *= 2;
      }
      final next = Float32List(cap);
      next.setRange(0, vLen, verts);
      verts = next;
    }

    void ensureIdxCap(int needed) {
      if (needed <= indices.length) return;
      var cap = indices.length;
      while (cap < needed) {
        cap *= 2;
      }
      final next = Int32List(cap);
      next.setRange(0, iLen, indices);
      indices = next;
    }

    var pos = 0;
    while (pos < len) {
      // Find next '<' (0x3C)
      while (pos < len && data[pos] != 0x3C) {
        pos++;
      }
      if (pos + 8 >= len) break;
      pos++; // skip '<'

      final b0 = data[pos];
      // Fast check: '<vertex ' -> 'v'(118) 'e'(101) 'r'(114) 't'(116) 'e'(101) 'x'(120)
      if (b0 == 118 &&
          data[pos + 1] == 101 &&
          data[pos + 2] == 114 &&
          data[pos + 3] == 116 &&
          data[pos + 4] == 101 &&
          data[pos + 5] == 120 &&
          (data[pos + 6] == 32 || data[pos + 6] == 9)) {
        pos += 7;
        final tagEnd = _findByte(data, pos, 0x3E); // '>'
        if (tagEnd < 0) break;
        double x = 0, y = 0, z = 0;
        var p = pos;
        while (p < tagEnd) {
          final c = data[p];
          if ((c == 120 || c == 121 || c == 122) && // x, y, z
              p + 2 < tagEnd &&
              data[p + 1] == 61 && // '='
              (data[p + 2] == 34 || data[p + 2] == 39) && // '"' or "'"
              (p == pos || data[p - 1] <= 32)) {
            final q = data[p + 2];
            final valStart = p + 3;
            var valEnd = valStart;
            while (valEnd < tagEnd && data[valEnd] != q) {
              valEnd++;
            }
            final val = _parseAsciiDouble(data, valStart, valEnd);
            if (c == 120) {
              x = val;
            } else if (c == 121) {
              y = val;
            } else {
              z = val;
            }
            p = valEnd + 1;
          } else {
            p++;
          }
        }
        ensureVertCap(vLen + 3);
        verts[vLen++] = x;
        verts[vLen++] = y;
        verts[vLen++] = z;
        pos = tagEnd + 1;
        continue;
      }

      // Fast check: '<triangle ' -> 't'(116) 'r'(114) 'i'(105) 'a'(97) 'n'(110) 'g'(103) 'l'(108) 'e'(101)
      if (b0 == 116 &&
          pos + 9 < len &&
          data[pos + 1] == 114 &&
          data[pos + 2] == 105 &&
          data[pos + 3] == 97 &&
          data[pos + 4] == 110 &&
          data[pos + 5] == 103 &&
          data[pos + 6] == 108 &&
          data[pos + 7] == 101 &&
          (data[pos + 8] == 32 || data[pos + 8] == 9)) {
        pos += 9;
        final tagEnd = _findByte(data, pos, 0x3E);
        if (tagEnd < 0) break;
        int v1 = 0, v2 = 0, v3 = 0;
        var p = pos;
        while (p < tagEnd) {
          if (data[p] == 118 && // 'v'
              p + 3 < tagEnd &&
              (data[p + 1] == 49 || data[p + 1] == 50 || data[p + 1] == 51) && // '1','2','3'
              data[p + 2] == 61 && // '='
              (data[p + 3] == 34 || data[p + 3] == 39) &&
              (p == pos || data[p - 1] <= 32)) {
            final idxChar = data[p + 1];
            final q = data[p + 3];
            final valStart = p + 4;
            var valEnd = valStart;
            while (valEnd < tagEnd && data[valEnd] != q) {
              valEnd++;
            }
            final val = _parseAsciiInt(data, valStart, valEnd);
            if (idxChar == 49) {
              v1 = val;
            } else if (idxChar == 50) {
              v2 = val;
            } else {
              v3 = val;
            }
            p = valEnd + 1;
          } else {
            p++;
          }
        }
        ensureIdxCap(iLen + 3);
        indices[iLen++] = v1;
        indices[iLen++] = v2;
        indices[iLen++] = v3;
        pos = tagEnd + 1;
        continue;
      }

      // Check '<object ' -> 'o'(111) 'b'(98) 'j'(106) 'e'(101) 'c'(99) 't'(116)
      if (b0 == 111 &&
          data[pos + 1] == 98 &&
          data[pos + 2] == 106 &&
          data[pos + 3] == 101 &&
          data[pos + 4] == 99 &&
          data[pos + 5] == 116 &&
          (data[pos + 6] == 32 || data[pos + 6] == 9)) {
        pos += 7;
        final tagEnd = _findByte(data, pos, 0x3E);
        if (tagEnd < 0) break;
        final tagStr = ascii.decode(data.sublist(pos, tagEnd), allowInvalid: true);
        final idMatch = RegExp(r'\bid\s*=\s*"([^"]+)"').firstMatch(tagStr);
        currentObjId = idMatch?.group(1) ?? '1';
        vLen = 0;
        iLen = 0;
        pos = tagEnd + 1;
        continue;
      }

      // Check '</object>' -> '/'(47) 'o'(111) 'b'(98) 'j'(106) 'e'(101) 'c'(99) 't'(116)
      if (b0 == 47 &&
          data[pos + 1] == 111 &&
          data[pos + 2] == 98 &&
          data[pos + 3] == 106 &&
          data[pos + 4] == 101 &&
          data[pos + 5] == 99 &&
          data[pos + 6] == 116) {
        if (currentObjId != null && vLen > 0 && iLen > 0) {
          result[currentObjId] = _RawIndexedMesh(
            Float32List.fromList(verts.sublist(0, vLen)),
            Int32List.fromList(indices.sublist(0, iLen)),
          );
        }
        currentObjId = null;
        vLen = 0;
        iLen = 0;
        final tagEnd = _findByte(data, pos, 0x3E);
        pos = tagEnd < 0 ? len : tagEnd + 1;
        continue;
      }
    }

    return result;
  }

  static int _findByte(Uint8List data, int start, int target) {
    final len = data.length;
    for (var i = start; i < len; i++) {
      if (data[i] == target) return i;
    }
    return -1;
  }

  static int _parseAsciiInt(Uint8List data, int start, int end) {
    var i = start;
    while (i < end && data[i] <= 32) {
      i++;
    }
    var neg = false;
    if (i < end && data[i] == 45) {
      neg = true;
      i++;
    }
    var val = 0;
    while (i < end) {
      final d = data[i] - 48;
      if (d < 0 || d > 9) break;
      val = val * 10 + d;
      i++;
    }
    return neg ? -val : val;
  }

  static double _parseAsciiDouble(Uint8List data, int start, int end) {
    var i = start;
    while (i < end && data[i] <= 32) {
      i++;
    }
    var neg = false;
    if (i < end) {
      if (data[i] == 45) {
        neg = true;
        i++;
      } else if (data[i] == 43) {
        i++;
      }
    }
    double val = 0.0;
    while (i < end) {
      final d = data[i] - 48;
      if (d < 0 || d > 9) break;
      val = val * 10.0 + d;
      i++;
    }
    if (i < end && data[i] == 46) {
      i++;
      double frac = 0.1;
      while (i < end) {
        final d = data[i] - 48;
        if (d < 0 || d > 9) break;
        val += d * frac;
        frac *= 0.1;
        i++;
      }
    }
    if (i < end && (data[i] == 101 || data[i] == 69)) {
      i++;
      var expNeg = false;
      if (i < end) {
        if (data[i] == 45) {
          expNeg = true;
          i++;
        } else if (data[i] == 43) {
          i++;
        }
      }
      var exp = 0;
      while (i < end) {
        final d = data[i] - 48;
        if (d < 0 || d > 9) break;
        exp = exp * 10 + d;
        i++;
      }
      if (exp != 0) {
        final mult = math.pow(10.0, expNeg ? -exp : exp).toDouble();
        val *= mult;
      }
    }
    return neg ? -val : val;
  }

  // ============================================================================
  // 3. 3MF XML Metadata & Transform Helpers
  // ============================================================================
  static Uint8List _fileBytes(ArchiveFile f) {
    final c = f.content;
    if (c is Uint8List) return c;
    return Uint8List.fromList(c as List<int>);
  }

  static String _normZipPath(String p) {
    var s = p.replaceAll('\\', '/').trim();
    while (s.startsWith('/')) {
      s = s.substring(1);
    }
    return s.toLowerCase();
  }

  static double _parse3mfUnitScale(String xml) {
    final m = RegExp(r'<model\b[^>]*\bunit\s*=\s*"([^"]+)"').firstMatch(xml);
    switch ((m?.group(1) ?? 'millimeter').toLowerCase()) {
      case 'inch':
        return 25.4;
      case 'centimeter':
        return 10.0;
      case 'meter':
        return 1000.0;
      case 'foot':
        return 304.8;
      case 'micron':
        return 0.001;
      default:
        return 1.0;
    }
  }

  static String? _extract3mfTitle(String xml) {
    final m = RegExp(r'<metadata\s+name\s*=\s*"Title"\s*>([^<]+)</metadata>')
        .firstMatch(xml);
    final t = m?.group(1)?.trim();
    return (t != null && t.isNotEmpty) ? t : null;
  }

  static Float64List _parse3mfTransform(String? raw) {
    if (raw == null || raw.trim().isEmpty) return _identityMatrix;
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.length < 12) return _identityMatrix;
    final out = Float64List(12);
    for (var i = 0; i < 12; i++) {
      out[i] = double.tryParse(parts[i]) ?? _identityMatrix[i];
    }
    return out;
  }

  /// Composes two 3MF row-vector 4x3 affine matrices: applies [first] then [second].
  static Float64List _mul3mfMatrices(Float64List a, Float64List b) {
    final out = Float64List(12);
    // Linear 3x3: A_3x3 * B_3x3
    for (var r = 0; r < 3; r++) {
      final a0 = a[r * 3], a1 = a[r * 3 + 1], a2 = a[r * 3 + 2];
      out[r * 3] = a0 * b[0] + a1 * b[3] + a2 * b[6];
      out[r * 3 + 1] = a0 * b[1] + a1 * b[4] + a2 * b[7];
      out[r * 3 + 2] = a0 * b[2] + a1 * b[5] + a2 * b[8];
    }
    // Translation: t_a * B_3x3 + t_b
    final tx = a[9], ty = a[10], tz = a[11];
    out[9] = tx * b[0] + ty * b[3] + tz * b[6] + b[9];
    out[10] = tx * b[1] + ty * b[4] + tz * b[7] + b[10];
    out[11] = tx * b[2] + ty * b[5] + tz * b[8] + b[11];
    return out;
  }

  static Map<String, List<_ComponentRef>> _parseObjectComponents(String xml) {
    final map = <String, List<_ComponentRef>>{};
    final objRe = RegExp(
      r'<object\b([^>]*)>([\s\S]*?)</object>',
      multiLine: true,
    );
    final idRe = RegExp(r'\bid\s*=\s*"([^"]+)"');
    final compRe = RegExp(r'<component\b([^>]*)/?>');
    final pathRe = RegExp(r'(?:p:)?path\s*=\s*"([^"]+)"');
    final objIdRe = RegExp(r'\bobjectid\s*=\s*"([^"]+)"');
    final transRe = RegExp(r'\btransform\s*=\s*"([^"]+)"');

    for (final m in objRe.allMatches(xml)) {
      final body = m.group(2) ?? '';
      if (!body.contains('<component')) continue;
      final id = idRe.firstMatch(m.group(1) ?? '')?.group(1);
      if (id == null) continue;
      final list = <_ComponentRef>[];
      for (final cm in compRe.allMatches(body)) {
        final attrs = cm.group(1) ?? '';
        final cid = objIdRe.firstMatch(attrs)?.group(1);
        if (cid == null) continue;
        list.add(_ComponentRef(
          path: pathRe.firstMatch(attrs)?.group(1),
          objectId: cid,
          matrix: _parse3mfTransform(transRe.firstMatch(attrs)?.group(1)),
        ));
      }
      if (list.isNotEmpty) map[id] = list;
    }
    return map;
  }

  static List<({String objectId, Float64List matrix, bool printable})> _parseBuildItems(
    String xml,
  ) {
    final buildStart = xml.indexOf('<build');
    if (buildStart < 0) return const [];
    final buildEnd = xml.indexOf('</build>', buildStart);
    final buildSection = buildEnd > buildStart
        ? xml.substring(buildStart, buildEnd)
        : xml.substring(buildStart);

    final out = <({String objectId, Float64List matrix, bool printable})>[];
    final itemRe = RegExp(r'<item\b([^>]*)/?>');
    final objIdRe = RegExp(r'\bobjectid\s*=\s*"([^"]+)"');
    final transRe = RegExp(r'\btransform\s*=\s*"([^"]+)"');
    final printRe = RegExp(r'\bprintable\s*=\s*"([^"]+)"');

    for (final m in itemRe.allMatches(buildSection)) {
      final attrs = m.group(1) ?? '';
      final oid = objIdRe.firstMatch(attrs)?.group(1);
      if (oid == null) continue;
      final printable = (printRe.firstMatch(attrs)?.group(1) ?? '1') != '0';
      out.add((
        objectId: oid,
        matrix: _parse3mfTransform(transRe.firstMatch(attrs)?.group(1)),
        printable: printable,
      ));
    }
    return out;
  }

  static void _parseModelSettingsXml(
    String xml,
    Map<String, _ModelObjectMeta> objectMeta,
    List<_PlateConfig> plates,
  ) {
    final objRe = RegExp(r'<object\s+id="([^"]+)">([\s\S]*?)</object>');
    final metaRe = RegExp(r'<metadata\s+key="([^"]+)"\s+value="([^"]*)"');
    final partRe = RegExp(r'<part\b[^>]*subtype="([^"]+)"');

    for (final m in objRe.allMatches(xml)) {
      final oid = m.group(1)!;
      final body = m.group(2)!;
      final om = _ModelObjectMeta(id: oid);
      // Only take top-level object metadata before first <part
      final firstPartIdx = body.indexOf('<part');
      final header = firstPartIdx >= 0 ? body.substring(0, firstPartIdx) : body;
      for (final mm in metaRe.allMatches(header)) {
        final k = mm.group(1);
        final v = mm.group(2) ?? '';
        if (k == 'name' && v.isNotEmpty) {
          om.name = v;
        } else if (k == 'extruder') {
          om.extruder = int.tryParse(v) ?? 1;
        }
      }
      for (final pm in partRe.allMatches(body)) {
        om.partSubtypes.add(pm.group(1)!);
      }
      objectMeta[oid] = om;
    }

    final plateRe = RegExp(r'<plate>([\s\S]*?)</plate>');
    final instRe = RegExp(r'<model_instance>([\s\S]*?)</model_instance>');
    for (final pm in plateRe.allMatches(xml)) {
      final body = pm.group(1)!;
      final firstInstIdx = body.indexOf('<model_instance');
      final header = firstInstIdx >= 0 ? body.substring(0, firstInstIdx) : body;
      var platerId = plates.length + 1;
      var platerName = '';
      for (final mm in metaRe.allMatches(header)) {
        final k = mm.group(1);
        final v = mm.group(2) ?? '';
        if (k == 'plater_id') platerId = int.tryParse(v) ?? platerId;
        if (k == 'plater_name') platerName = v;
      }
      final pc = _PlateConfig(platerId: platerId, name: platerName);
      for (final im in instRe.allMatches(body)) {
        for (final mm in metaRe.allMatches(im.group(1)!)) {
          if (mm.group(1) == 'object_id' && (mm.group(2)?.isNotEmpty ?? false)) {
            pc.objectIds.add(mm.group(2)!);
          }
        }
      }
      plates.add(pc);
    }
  }

  // ============================================================================
  // 4. Wavefront OBJ & Binary/ASCII STL Parsers
  // ============================================================================
  Mesh3D _parseObjBytes(Uint8List bytes, {required String name, int maxTriangles = 12000}) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = const LineSplitter().convert(text);
    final verts = <double>[];
    final indices = <int>[];

    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('v ')) {
        final parts = t.split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          verts.add(double.tryParse(parts[1]) ?? 0.0);
          verts.add(double.tryParse(parts[2]) ?? 0.0);
          verts.add(double.tryParse(parts[3]) ?? 0.0);
        }
      } else if (t.startsWith('f ')) {
        final parts = t.split(RegExp(r'\s+'));
        final vCount = verts.length ~/ 3;
        final poly = <int>[];
        for (var i = 1; i < parts.length; i++) {
          final slash = parts[i].indexOf('/');
          final rawIdx = int.tryParse(slash >= 0 ? parts[i].substring(0, slash) : parts[i]);
          if (rawIdx == null) continue;
          final idx = rawIdx > 0 ? rawIdx - 1 : vCount + rawIdx;
          if (idx >= 0 && idx < vCount) poly.add(idx);
        }
        for (var i = 1; i + 1 < poly.length; i++) {
          indices.add(poly[0]);
          indices.add(poly[i]);
          indices.add(poly[i + 1]);
        }
      }
    }

    if (indices.isEmpty || verts.isEmpty) return createCube(name: name);
    return _buildPackedMeshFromIndexed(
      name: name,
      verts: Float32List.fromList(verts),
      indices: Int32List.fromList(indices),
      maxTriangles: maxTriangles,
      sourceTriangleCount: indices.length ~/ 3,
    );
  }

  Mesh3D _parseBinaryStl(Uint8List bytes, int triCount, String name, int maxTriangles) {
    final bd = ByteData.sublistView(bytes);
    // Read all vertices into flat array; if <= maxTriangles pack directly, else vertex-cluster!
    final validTris = math.min(triCount, (bytes.length - 84) ~/ 50);
    if (validTris <= 0) return createCube(name: name);

    final rawVerts = Float32List(validTris * 9);
    for (var i = 0; i < validTris; i++) {
      final off = 84 + i * 50;
      final dst = i * 9;
      rawVerts[dst] = bd.getFloat32(off + 12, Endian.little);
      rawVerts[dst + 1] = bd.getFloat32(off + 16, Endian.little);
      rawVerts[dst + 2] = bd.getFloat32(off + 20, Endian.little);
      rawVerts[dst + 3] = bd.getFloat32(off + 24, Endian.little);
      rawVerts[dst + 4] = bd.getFloat32(off + 28, Endian.little);
      rawVerts[dst + 5] = bd.getFloat32(off + 32, Endian.little);
      rawVerts[dst + 6] = bd.getFloat32(off + 36, Endian.little);
      rawVerts[dst + 7] = bd.getFloat32(off + 40, Endian.little);
      rawVerts[dst + 8] = bd.getFloat32(off + 44, Endian.little);
    }

    return _buildPackedMeshFromSoup(
      name: name,
      rawTriVerts: rawVerts,
      maxTriangles: maxTriangles,
      sourceTriangleCount: validTris,
    );
  }

  Mesh3D _parseAsciiStl(String text, String name, int maxTriangles) {
    final lines = const LineSplitter().convert(text);
    final raw = <double>[];
    final triBuf = <double>[];

    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('vertex')) {
        final parts = t.split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          triBuf.add(double.tryParse(parts[1]) ?? 0);
          triBuf.add(double.tryParse(parts[2]) ?? 0);
          triBuf.add(double.tryParse(parts[3]) ?? 0);
        }
      } else if (t.startsWith('endfacet') && triBuf.length >= 9) {
        for (var k = 0; k < 9; k++) {
          raw.add(triBuf[k]);
        }
        triBuf.clear();
      } else if (t.startsWith('facet')) {
        triBuf.clear();
      }
    }

    if (raw.length < 9) return createCube(name: name);
    return _buildPackedMeshFromSoup(
      name: name,
      rawTriVerts: Float32List.fromList(raw),
      maxTriangles: maxTriangles,
      sourceTriangleCount: raw.length ~/ 9,
    );
  }

  // ============================================================================
  // 5. Hole-Free Spatial Vertex-Clustering Decimation & Packed Mesh Builder
  // ============================================================================
  Mesh3D _buildPackedMeshFromSoup({
    required String name,
    required Float32List rawTriVerts,
    required int maxTriangles,
    required int sourceTriangleCount,
  }) {
    final triCount = rawTriVerts.length ~/ 9;
    if (triCount == 0) return createCube(name: name);

    final indices = Int32List(triCount * 3);
    for (var i = 0; i < indices.length; i++) {
      indices[i] = i;
    }
    return _buildPackedMeshFromIndexed(
      name: name,
      verts: rawTriVerts,
      indices: indices,
      maxTriangles: maxTriangles,
      sourceTriangleCount: sourceTriangleCount,
    );
  }

  Mesh3D _buildPackedMeshFromIndexed({
    required String name,
    required Float32List verts,
    required Int32List indices,
    required int maxTriangles,
    required int sourceTriangleCount,
    bool alreadyCentered = false,
  }) {
    final vCount = verts.length ~/ 3;
    final triCount = indices.length ~/ 3;
    if (vCount == 0 || triCount == 0) return createCube(name: name);

    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity, maxZ = double.negativeInfinity;
    for (var i = 0; i < verts.length; i += 3) {
      final x = verts[i], y = verts[i + 1], z = verts[i + 2];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (z < minZ) minZ = z;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (z > maxZ) maxZ = z;
    }

    Float32List centeredVerts;
    if (alreadyCentered) {
      centeredVerts = verts;
    } else {
      final cx = (minX + maxX) * 0.5;
      final cy = (minY + maxY) * 0.5;
      centeredVerts = Float32List(verts.length);
      for (var i = 0; i < verts.length; i += 3) {
        centeredVerts[i] = verts[i] - cx;
        centeredVerts[i + 1] = verts[i + 1] - cy;
        centeredVerts[i + 2] = verts[i + 2] - minZ;
      }
      maxX -= cx;
      minX -= cx;
      maxY -= cy;
      minY -= cy;
      maxZ -= minZ;
      minZ = 0.0;
    }

    // Apply hole-free spatial vertex-clustering decimation if triCount exceeds target
    Float32List finalVerts = centeredVerts;
    Int32List finalIndices = indices;

    if (triCount > maxTriangles && maxTriangles >= 200) {
      var gridRes = math.sqrt(maxTriangles * 1.45).round().clamp(22, 140);
      var clustered = _vertexClusterDecimate(
        centeredVerts,
        indices,
        minX,
        minY,
        minZ,
        maxX,
        maxY,
        maxZ,
        gridRes,
      );
      // Refine grid once if triangle count is still noticeably over budget
      if (clustered.triangleCount > (maxTriangles * 1.35).round() && gridRes > 18) {
        final adjustedRes = (gridRes * math.sqrt(maxTriangles / clustered.triangleCount))
            .round()
            .clamp(16, gridRes - 2);
        clustered = _vertexClusterDecimate(
          centeredVerts,
          indices,
          minX,
          minY,
          minZ,
          maxX,
          maxY,
          maxZ,
          adjustedRes,
        );
      }
      if (clustered.triangleCount >= 12) {
        finalVerts = clustered.verts;
        finalIndices = clustered.indices;
      }
    }

    final (packedCoords, packedNormals) = _packIndexedWithOutwardNormals(
      finalVerts,
      finalIndices,
      (minX + maxX) * 0.5,
      (minY + maxY) * 0.5,
      (minZ + maxZ) * 0.5,
    );

    // Optional lightweight interactive LOD for smooth 60 FPS orbiting on heavy scenes
    Float32List? lodCoords;
    Float32List? lodNormals;
    final renderedCount = packedCoords.length ~/ 9;
    if (renderedCount > 3200) {
      final lodGrid = math.sqrt(2200 * 1.35).round().clamp(18, 64);
      final lodMesh = _vertexClusterDecimate(
        finalVerts,
        finalIndices,
        minX,
        minY,
        minZ,
        maxX,
        maxY,
        maxZ,
        lodGrid,
      );
      if (lodMesh.triangleCount >= 24 && lodMesh.triangleCount < renderedCount * 0.75) {
        final (lc, ln) = _packIndexedWithOutwardNormals(
          lodMesh.verts,
          lodMesh.indices,
          (minX + maxX) * 0.5,
          (minY + maxY) * 0.5,
          (minZ + maxZ) * 0.5,
        );
        lodCoords = lc;
        lodNormals = ln;
      }
    }

    return Mesh3D.fromPacked(
      name: name,
      vertexCoords: packedCoords,
      faceNormals: packedNormals,
      minBounds: Vec3(minX, minY, minZ),
      maxBounds: Vec3(maxX, maxY, maxZ),
      sourceTriangleCount: sourceTriangleCount,
      lodVertexCoords: lodCoords,
      lodFaceNormals: lodNormals,
    );
  }

  /// Hole-free Spatial Vertex-Clustering Decimation (Rossignac-Borrel).
  /// Collapses vertices inside each 3D voxel cell to their mean position,
  /// preserving a closed, solid surface with zero missing shards.
  _RawIndexedMesh _vertexClusterDecimate(
    Float32List verts,
    Int32List indices,
    double minX,
    double minY,
    double minZ,
    double maxX,
    double maxY,
    double maxZ,
    int gridRes,
  ) {
    final spanX = math.max(1e-4, maxX - minX);
    final spanY = math.max(1e-4, maxY - minY);
    final spanZ = math.max(1e-4, maxZ - minZ);
    final maxSpan = math.max(spanX, math.max(spanY, spanZ));
    final invCell = gridRes / maxSpan;

    final vCount = verts.length ~/ 3;
    final vertToCluster = Int32List(vCount);
    final cellMap = <int, int>{};

    var sumX = Float64List(math.min(vCount, 4096));
    var sumY = Float64List(sumX.length);
    var sumZ = Float64List(sumX.length);
    var counts = Int32List(sumX.length);
    var clusterCount = 0;

    void growClusters() {
      final oldCap = sumX.length;
      final newCap = oldCap * 2;
      final oldX = sumX, oldY = sumY, oldZ = sumZ, oldC = counts;
      sumX = Float64List(newCap)..setRange(0, oldCap, oldX);
      sumY = Float64List(newCap)..setRange(0, oldCap, oldY);
      sumZ = Float64List(newCap)..setRange(0, oldCap, oldZ);
      counts = Int32List(newCap)..setRange(0, oldCap, oldC);
    }

    // 53-bit JS-safe packing: 11 bits per axis (0..2047)
    for (var i = 0; i < vCount; i++) {
      final x = verts[i * 3];
      final y = verts[i * 3 + 1];
      final z = verts[i * 3 + 2];
      final ix = ((x - minX) * invCell).floor().clamp(0, 2047);
      final iy = ((y - minY) * invCell).floor().clamp(0, 2047);
      final iz = ((z - minZ) * invCell).floor().clamp(0, 2047);
      final key = ix + (iy << 11) + (iz << 22);

      var cid = cellMap[key];
      if (cid == null) {
        cid = clusterCount++;
        if (cid >= sumX.length) growClusters();
        cellMap[key] = cid;
      }
      vertToCluster[i] = cid;
      sumX[cid] += x;
      sumY[cid] += y;
      sumZ[cid] += z;
      counts[cid] += 1;
    }

    final outVerts = Float32List(clusterCount * 3);
    for (var c = 0; c < clusterCount; c++) {
      final inv = 1.0 / counts[c];
      outVerts[c * 3] = sumX[c] * inv;
      outVerts[c * 3 + 1] = sumY[c] * inv;
      outVerts[c * 3 + 2] = sumZ[c] * inv;
    }

    final triCount = indices.length ~/ 3;
    final outIdx = <int>[];
    for (var t = 0; t < triCount; t++) {
      final a = indices[t * 3];
      final b = indices[t * 3 + 1];
      final c = indices[t * 3 + 2];
      if (a < 0 || a >= vCount || b < 0 || b >= vCount || c < 0 || c >= vCount) {
        continue;
      }
      final ca = vertToCluster[a];
      final cb = vertToCluster[b];
      final cc = vertToCluster[c];
      if (ca == cb || cb == cc || ca == cc) continue;
      outIdx.add(ca);
      outIdx.add(cb);
      outIdx.add(cc);
    }

    return _RawIndexedMesh(outVerts, Int32List.fromList(outIdx));
  }

  /// Packs indexed triangles into flat Float32Lists and verifies positive signed volume
  /// so outward face normals & backface culling are always consistent.
  (Float32List, Float32List) _packIndexedWithOutwardNormals(
    Float32List verts,
    Int32List indices,
    double refX,
    double refY,
    double refZ,
  ) {
    final vCount = verts.length ~/ 3;
    final triCount = indices.length ~/ 3;
    final coords = Float32List(triCount * 9);
    final normals = Float32List(triCount * 3);
    var outT = 0;
    double signedVol6 = 0.0;

    for (var t = 0; t < triCount; t++) {
      final ia = indices[t * 3];
      final ib = indices[t * 3 + 1];
      final ic = indices[t * 3 + 2];
      if (ia < 0 || ia >= vCount || ib < 0 || ib >= vCount || ic < 0 || ic >= vCount) {
        continue;
      }
      final ax = verts[ia * 3], ay = verts[ia * 3 + 1], az = verts[ia * 3 + 2];
      final bx = verts[ib * 3], by = verts[ib * 3 + 1], bz = verts[ib * 3 + 2];
      final cx = verts[ic * 3], cy = verts[ic * 3 + 1], cz = verts[ic * 3 + 2];

      final e1x = bx - ax, e1y = by - ay, e1z = bz - az;
      final e2x = cx - ax, e2y = cy - ay, e2z = cz - az;
      final nx = e1y * e2z - e1z * e2y;
      final ny = e1z * e2x - e1x * e2z;
      final nz = e1x * e2y - e1y * e2x;
      final nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (nLen < 1e-9) continue;

      final invN = 1.0 / nLen;
      final vo = outT * 9;
      coords[vo] = ax;
      coords[vo + 1] = ay;
      coords[vo + 2] = az;
      coords[vo + 3] = bx;
      coords[vo + 4] = by;
      coords[vo + 5] = bz;
      coords[vo + 6] = cx;
      coords[vo + 7] = cy;
      coords[vo + 8] = cz;

      final no = outT * 3;
      normals[no] = nx * invN;
      normals[no + 1] = ny * invN;
      normals[no + 2] = nz * invN;

      // Signed volume contribution relative to centroid
      final rax = ax - refX, ray = ay - refY, raz = az - refZ;
      final rbx = bx - refX, rby = by - refY, rbz = bz - refZ;
      final rcx = cx - refX, rcy = cy - refY, rcz = cz - refZ;
      signedVol6 += rax * (rby * rcz - rbz * rcy) +
          ray * (rbz * rcx - rbx * rcz) +
          raz * (rbx * rcy - rby * rcx);
      outT++;
    }

    final finalCoords = outT == triCount ? coords : coords.sublist(0, outT * 9);
    final finalNormals = outT == triCount ? normals : normals.sublist(0, outT * 3);

    // If mesh had inward winding (negative volume), flip every triangle once
    if (signedVol6 < -1e-2) {
      for (var t = 0; t < outT; t++) {
        final vo = t * 9;
        final tx = finalCoords[vo + 3];
        final ty = finalCoords[vo + 4];
        final tz = finalCoords[vo + 5];
        finalCoords[vo + 3] = finalCoords[vo + 6];
        finalCoords[vo + 4] = finalCoords[vo + 7];
        finalCoords[vo + 5] = finalCoords[vo + 8];
        finalCoords[vo + 6] = tx;
        finalCoords[vo + 7] = ty;
        finalCoords[vo + 8] = tz;

        final no = t * 3;
        finalNormals[no] = -finalNormals[no];
        finalNormals[no + 1] = -finalNormals[no + 1];
        finalNormals[no + 2] = -finalNormals[no + 2];
      }
    }

    return (finalCoords, finalNormals);
  }

  // ============================================================================
  // 6. Built-In Primitives & Mesh Editing Operations
  // ============================================================================
  Mesh3D _normalizeToBuildPlate(String name, List<Triangle3D> tris) {
    if (tris.isEmpty) return createCube(name: name);
    var minX = double.infinity;
    var minY = double.infinity;
    var minZ = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    var maxZ = double.negativeInfinity;

    for (final t in tris) {
      for (final v in [t.v0, t.v1, t.v2]) {
        if (v.x < minX) minX = v.x;
        if (v.y < minY) minY = v.y;
        if (v.z < minZ) minZ = v.z;
        if (v.x > maxX) maxX = v.x;
        if (v.y > maxY) maxY = v.y;
        if (v.z > maxZ) maxZ = v.z;
      }
    }

    final cx = (minX + maxX) * 0.5;
    final cy = (minY + maxY) * 0.5;
    final shifted = tris
        .map((t) => Triangle3D(
              v0: Vec3(t.v0.x - cx, t.v0.y - cy, t.v0.z - minZ),
              v1: Vec3(t.v1.x - cx, t.v1.y - cy, t.v1.z - minZ),
              v2: Vec3(t.v2.x - cx, t.v2.y - cy, t.v2.z - minZ),
              normal: t.normal,
            ))
        .toList();

    return Mesh3D(
      name: name,
      triangles: shifted,
      minBounds: Vec3(minX - cx, minY - cy, 0),
      maxBounds: Vec3(maxX - cx, maxY - cy, maxZ - minZ),
    );
  }

  Mesh3D createCube({String name = 'Cube', double size = 40}) {
    final h = size / 2;
    final pts = [
      Vec3(-h, -h, 0),
      Vec3(h, -h, 0),
      Vec3(h, h, 0),
      Vec3(-h, h, 0),
      Vec3(-h, -h, size),
      Vec3(h, -h, size),
      Vec3(h, h, size),
      Vec3(-h, h, size),
    ];
    final faces = [
      [0, 2, 1], [0, 3, 2],
      [4, 5, 6], [4, 6, 7],
      [0, 1, 5], [0, 5, 4],
      [2, 3, 7], [2, 7, 6],
      [1, 2, 6], [1, 6, 5],
      [3, 0, 4], [3, 4, 7],
    ];
    return _fromIndexed(name, pts, faces);
  }

  Mesh3D createCylinder({
    String name = 'Cylinder',
    double radius = 20,
    double height = 45,
    int segments = 28,
  }) {
    final tris = <Triangle3D>[];
    const bottomCenter = Vec3(0, 0, 0);
    final topCenter = Vec3(0, 0, height);
    for (var i = 0; i < segments; i++) {
      final a0 = (i / segments) * math.pi * 2;
      final a1 = ((i + 1) / segments) * math.pi * 2;
      final b0 = Vec3(math.cos(a0) * radius, math.sin(a0) * radius, 0);
      final b1 = Vec3(math.cos(a1) * radius, math.sin(a1) * radius, 0);
      final t0 = Vec3(b0.x, b0.y, height);
      final t1 = Vec3(b1.x, b1.y, height);

      tris.add(_tri(bottomCenter, b1, b0));
      tris.add(_tri(topCenter, t0, t1));
      tris.add(_tri(b0, b1, t1));
      tris.add(_tri(b0, t1, t0));
    }
    return _normalizeToBuildPlate(name, tris);
  }

  Mesh3D createCone({
    String name = 'Cone',
    double radius = 22,
    double height = 48,
    int segments = 28,
  }) {
    final tris = <Triangle3D>[];
    const bottomCenter = Vec3(0, 0, 0);
    final apex = Vec3(0, 0, height);
    for (var i = 0; i < segments; i++) {
      final a0 = (i / segments) * math.pi * 2;
      final a1 = ((i + 1) / segments) * math.pi * 2;
      final b0 = Vec3(math.cos(a0) * radius, math.sin(a0) * radius, 0);
      final b1 = Vec3(math.cos(a1) * radius, math.sin(a1) * radius, 0);
      tris.add(_tri(bottomCenter, b1, b0));
      tris.add(_tri(b0, b1, apex));
    }
    return _normalizeToBuildPlate(name, tris);
  }

  Mesh3D createSphere({
    String name = 'Sphere',
    double radius = 22,
    int latSteps = 14,
    int lonSteps = 24,
  }) {
    final tris = <Triangle3D>[];
    for (var i = 0; i < latSteps; i++) {
      final phi0 = math.pi * i / latSteps;
      final phi1 = math.pi * (i + 1) / latSteps;
      for (var j = 0; j < lonSteps; j++) {
        final theta0 = 2 * math.pi * j / lonSteps;
        final theta1 = 2 * math.pi * (j + 1) / lonSteps;

        Vec3 pt(double p, double t) => Vec3(
              radius * math.sin(p) * math.cos(t),
              radius * math.sin(p) * math.sin(t),
              radius * math.cos(p) + radius,
            );

        final p00 = pt(phi0, theta0);
        final p10 = pt(phi1, theta0);
        final p11 = pt(phi1, theta1);
        final p01 = pt(phi0, theta1);
        if (i > 0) tris.add(_tri(p00, p10, p11));
        if (i < latSteps - 1) tris.add(_tri(p00, p11, p01));
      }
    }
    return _normalizeToBuildPlate(name, tris);
  }

  Mesh3D createTorus({
    String name = 'Torus',
    double majorR = 24,
    double minorR = 8,
    int majorSteps = 28,
    int minorSteps = 14,
  }) {
    final tris = <Triangle3D>[];
    for (var i = 0; i < majorSteps; i++) {
      final u0 = 2 * math.pi * i / majorSteps;
      final u1 = 2 * math.pi * (i + 1) / majorSteps;
      for (var j = 0; j < minorSteps; j++) {
        final v0 = 2 * math.pi * j / minorSteps;
        final v1 = 2 * math.pi * (j + 1) / minorSteps;

        Vec3 pt(double u, double v) => Vec3(
              (majorR + minorR * math.cos(v)) * math.cos(u),
              (majorR + minorR * math.cos(v)) * math.sin(u),
              minorR * math.sin(v) + minorR,
            );

        final a = pt(u0, v0);
        final b = pt(u1, v0);
        final c = pt(u1, v1);
        final d = pt(u0, v1);
        tris.add(_tri(a, b, c));
        tris.add(_tri(a, c, d));
      }
    }
    return _normalizeToBuildPlate(name, tris);
  }

  Mesh3D createTempTower({String name = 'Temp Tower', int levels = 6}) {
    final tris = <Triangle3D>[];
    const w = 36.0;
    const d = 14.0;
    const levelH = 10.0;
    for (var lvl = 0; lvl < levels; lvl++) {
      final z0 = lvl * levelH;
      final z1 = z0 + levelH - 0.5;
      _addBox(tris, -w / 2, -d / 2, z0, -w / 2 + 10, d / 2, z1);
      _addBox(tris, w / 2 - 10, -d / 2, z0, w / 2, d / 2, z1);
      _addBox(tris, -w / 2 + 10, -d / 2 + 2, z1 - 3, w / 2 - 10, d / 2 - 2, z1);
    }
    return _normalizeToBuildPlate(name, tris);
  }

  void _addBox(
    List<Triangle3D> out,
    double x0,
    double y0,
    double z0,
    double x1,
    double y1,
    double z1,
  ) {
    final p = [
      Vec3(x0, y0, z0),
      Vec3(x1, y0, z0),
      Vec3(x1, y1, z0),
      Vec3(x0, y1, z0),
      Vec3(x0, y0, z1),
      Vec3(x1, y0, z1),
      Vec3(x1, y1, z1),
      Vec3(x0, y1, z1),
    ];
    final f = [
      [0, 2, 1], [0, 3, 2],
      [4, 5, 6], [4, 6, 7],
      [0, 1, 5], [0, 5, 4],
      [2, 3, 7], [2, 7, 6],
      [1, 2, 6], [1, 6, 5],
      [3, 0, 4], [3, 4, 7],
    ];
    for (final idx in f) {
      out.add(_tri(p[idx[0]], p[idx[1]], p[idx[2]]));
    }
  }

  /// Hole-free simplification via spatial vertex clustering.
  Mesh3D simplifyMesh(Mesh3D mesh, double keepRatio) {
    final ratio = keepRatio.clamp(0.1, 1.0);
    if (ratio >= 0.99 || mesh.triangleCount <= 24) return mesh;
    final target = math.max(24, (mesh.triangleCount * ratio).round());
    return _buildPackedMeshFromSoup(
      name: '${mesh.name} (Simplified)',
      rawTriVerts: mesh.vertexCoords,
      maxTriangles: target,
      sourceTriangleCount: mesh.sourceTriangleCount,
    );
  }

  /// Planar cut at height Z, returning (lowerHalf, upperHalf).
  (Mesh3D, Mesh3D) cutMeshAtZ(Mesh3D mesh, double cutZ) {
    final lower = <Triangle3D>[];
    final upper = <Triangle3D>[];
    for (final t in mesh.triangles) {
      final avgZ = (t.v0.z + t.v1.z + t.v2.z) / 3.0;
      if (avgZ <= cutZ) {
        lower.add(t);
      } else {
        upper.add(t);
      }
    }
    return (
      lower.isNotEmpty
          ? _normalizeToBuildPlate('${mesh.name}_lower', lower)
          : createCube(name: '${mesh.name}_lower', size: 20),
      upper.isNotEmpty
          ? _normalizeToBuildPlate('${mesh.name}_upper', upper)
          : createCube(name: '${mesh.name}_upper', size: 20),
    );
  }

  Mesh3D _fromIndexed(String name, List<Vec3> pts, List<List<int>> faces) {
    final tris = faces.map((f) => _tri(pts[f[0]], pts[f[1]], pts[f[2]])).toList();
    return _normalizeToBuildPlate(name, tris);
  }

  Triangle3D _tri(Vec3 a, Vec3 b, Vec3 c) {
    final n = (b - a).cross(c - a).normalized();
    return Triangle3D(v0: a, v1: b, v2: c, normal: n);
  }
}
