import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/models/device_models.dart';
import '../../domain/models/printer_profile.dart';
import '../../domain/models/scene_models.dart';
import '../services/stl_parser_service.dart';

class BambuAssetCatalog {
  const BambuAssetCatalog({
    required this.printers,
    required this.filaments,
    required this.processes,
    required this.hmsCodes,
    required this.flushPairs,
  });

  final List<PrinterProfile> printers;
  final List<FilamentProfile> filaments;
  final List<ProcessSettings> processes;
  final List<HmsCodeEntry> hmsCodes;
  final Map<String, int> flushPairs; // "FROM->TO" -> purge mm³
}

/// Loads real Bambu Studio printer profiles, filament profiles, process presets,
/// HMS error dictionaries, flush matrices, and STL models extracted from BambuStudio/resources.
class BambuAssetRepository {
  BambuAssetRepository({StlParserService? stlParser})
      : _stlParser = stlParser ?? const StlParserService();

  final StlParserService _stlParser;
  BambuAssetCatalog? _cachedCatalog;
  final Map<String, Mesh3D> _cachedMeshes = {};

  Future<BambuAssetCatalog> loadCatalog() async {
    if (_cachedCatalog != null) return _cachedCatalog!;

    // Load all JSON assets concurrently instead of serially
    final strings = await Future.wait([
      rootBundle.loadString('assets/bambu_data/printers.json'),
      rootBundle.loadString('assets/bambu_data/filaments.json'),
      rootBundle.loadString('assets/bambu_data/processes.json'),
      rootBundle.loadString('assets/bambu_data/hms_en.json'),
      rootBundle.loadString('assets/bambu_data/flush_matrix.json'),
    ]);

    final printersRaw = jsonDecode(strings[0]) as List<dynamic>;
    final filamentsRaw = jsonDecode(strings[1]) as List<dynamic>;
    final processesRaw = jsonDecode(strings[2]) as List<dynamic>;
    final hmsRaw = jsonDecode(strings[3]) as List<dynamic>;
    final flushRaw = jsonDecode(strings[4]) as Map<String, dynamic>;

    final flushPairs = <String, int>{};
    for (final item in (flushRaw['pairs'] as List<dynamic>? ?? const [])) {
      final m = item as Map<String, dynamic>;
      final key = '${m['from']}->${m['to']}';
      flushPairs[key] = (m['purge'] as num?)?.toInt() ?? 280;
    }

    _cachedCatalog = BambuAssetCatalog(
      printers: printersRaw
          .map((e) => PrinterProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
      filaments: filamentsRaw
          .map((e) => FilamentProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
      processes: processesRaw
          .map((e) => ProcessSettings.fromJson(e as Map<String, dynamic>))
          .toList(),
      hmsCodes: hmsRaw
          .map((e) => HmsCodeEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      flushPairs: flushPairs,
    );
    return _cachedCatalog!;
  }

  Future<Mesh3D> loadBuiltInStl(String assetPath, String displayName) async {
    final cached = _cachedMeshes[assetPath];
    if (cached != null) return cached;
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final mesh = _stlParser.parseStlBytes(bytes, name: displayName);
      _cachedMeshes[assetPath] = mesh;
      return mesh;
    } catch (_) {
      return _stlParser.createCube(name: displayName);
    }
  }
}
