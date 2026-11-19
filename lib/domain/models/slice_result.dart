import 'package:material_ui/material_ui.dart';

enum GCodeLineType {
  outerWall('Outer Wall', Color(0xFFFF9800)),
  innerWall('Inner Wall', Color(0xFFFFEB3B)),
  sparseInfill('Sparse Infill', Color(0xFFE53935)),
  solidInfill('Internal Solid Infill', Color(0xFF9C27B0)),
  topSurface('Top Surface', Color(0xFFF44336)),
  support('Support', Color(0xFF4CAF50)),
  supportInterface('Support Interface', Color(0xFF1B5E20)),
  primeTower('Prime Tower', Color(0xFF00BCD4)),
  brim('Brim / Skirt', Color(0xFF26A69A)),
  travel('Travel', Color(0xFF42A5F5)),
  seam('Seam', Color(0xFFFFFFFF));

  const GCodeLineType(this.label, this.color);
  final String label;
  final Color color;
}

/// All Bambu Studio Preview Color Schemes (including Per-Object from latest commit 8e524a3!)
enum PreviewColorScheme {
  lineType('Line Type'),
  filament('Filament'),
  speed('Speed (mm/s)'),
  flow('Flow (mm³/s)'),
  layerHeight('Layer Height (mm)'),
  fanSpeed('Fan Speed (%)'),
  layerTime('Layer Time (s)'),
  temperature('Temperature (°C)'),
  tool('Tool / Extruder'),
  perObject('Per-Object');

  const PreviewColorScheme(this.label);
  final String label;
}

class GCodeSegment {
  const GCodeSegment({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.z,
    required this.lineType,
    required this.filamentIndex,
    required this.speedMmS,
    required this.flowMm3S,
    required this.layerHeight,
    required this.fanPercent,
    required this.tempC,
    required this.objectIndex,
    this.isRetract = false,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double z;
  final GCodeLineType lineType;
  final int filamentIndex;
  final double speedMmS;
  final double flowMm3S;
  final double layerHeight;
  final int fanPercent;
  final int tempC;
  final int objectIndex;
  final bool isRetract;
}

class GCodeLayer {
  const GCodeLayer({
    required this.index,
    required this.zHeight,
    required this.layerHeight,
    required this.estimatedSeconds,
    required this.segments,
  });

  final int index;
  final double zHeight;
  final double layerHeight;
  final double estimatedSeconds;
  final List<GCodeSegment> segments;
}

class FilamentUsageBreakdown {
  const FilamentUsageBreakdown({
    required this.slotIndex,
    required this.filamentName,
    required this.color,
    required this.modelGrams,
    required this.flushGrams,
    required this.towerGrams,
    required this.meters,
    required this.costUsd,
  });

  final int slotIndex;
  final String filamentName;
  final Color color;
  final double modelGrams;
  final double flushGrams;
  final double towerGrams;
  final double meters;
  final double costUsd;

  double get totalGrams => modelGrams + flushGrams + towerGrams;
}

enum LayerEventType {
  pause('Pause Print (M400 U1)', Icons.pause_circle_outline, Color(0xFFFFB300)),
  filamentChange('Change Filament (M620)', Icons.swap_horiz, Color(0xFF00AE42)),
  customGcode('Custom G-Code', Icons.code, Color(0xFF29B6F6));

  const LayerEventType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class LayerGCodeEvent {
  const LayerGCodeEvent({
    required this.layerIndex,
    required this.type,
    required this.detail,
    this.filamentSlotIndex,
  });

  final int layerIndex;
  final LayerEventType type;
  final String detail;
  final int? filamentSlotIndex;
}

class FeatureTimeBreakdown {
  const FeatureTimeBreakdown({
    required this.type,
    required this.seconds,
    required this.percentage,
  });

  final GCodeLineType type;
  final double seconds;
  final double percentage;
}

class SliceResult {
  const SliceResult({
    required this.plateIndex,
    required this.engineName,
    required this.slicedAt,
    required this.layers,
    required this.totalSeconds,
    required this.totalGrams,
    required this.totalMeters,
    required this.totalCostUsd,
    required this.filamentChanges,
    required this.filamentUsages,
    required this.featureBreakdown,
    required this.gcodeText,
    required this.bedX,
    required this.bedY,
    this.usedCliBridge = false,
  });

  final int plateIndex;
  final String engineName;
  final DateTime slicedAt;
  final List<GCodeLayer> layers;
  final double totalSeconds;
  final double totalGrams;
  final double totalMeters;
  final double totalCostUsd;
  final int filamentChanges;
  final List<FilamentUsageBreakdown> filamentUsages;
  final List<FeatureTimeBreakdown> featureBreakdown;
  final String gcodeText;
  final int bedX;
  final int bedY;
  final bool usedCliBridge;

  String get formattedTime {
    final totalMin = (totalSeconds / 60).round();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }
}
