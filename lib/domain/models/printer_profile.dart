import 'package:material_ui/material_ui.dart';

class PrinterProfile {
  const PrinterProfile({
    required this.id,
    required this.name,
    required this.family,
    required this.nozzles,
    required this.defaultBedType,
    required this.defaultPrintProfile,
    required this.bedX,
    required this.bedY,
    required this.bedZ,
    required this.maxSpeed,
    required this.maxAccel,
    required this.hasEnclosedChamber,
    required this.hasLidar,
    required this.isDualExtruder,
    this.coverAsset,
  });

  final String id;
  final String name;
  final String family;
  final List<String> nozzles;
  final String defaultBedType;
  final String defaultPrintProfile;
  final int bedX;
  final int bedY;
  final int bedZ;
  final int maxSpeed;
  final int maxAccel;
  final bool hasEnclosedChamber;
  final bool hasLidar;
  final bool isDualExtruder;
  final String? coverAsset;

  factory PrinterProfile.fromJson(Map<String, dynamic> json) {
    return PrinterProfile(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Bambu Lab X1 Carbon',
      family: json['family'] as String? ?? 'BBL-3DP',
      nozzles: (json['nozzles'] as List<dynamic>? ?? const ['0.4'])
          .map((e) => e.toString())
          .toList(),
      defaultBedType:
          json['defaultBedType'] as String? ?? 'Textured PEI Plate',
      defaultPrintProfile:
          json['defaultPrintProfile'] as String? ?? '0.20mm Standard @BBL X1C',
      bedX: (json['bedX'] as num?)?.toInt() ?? 256,
      bedY: (json['bedY'] as num?)?.toInt() ?? 256,
      bedZ: (json['bedZ'] as num?)?.toInt() ?? 256,
      maxSpeed: (json['maxSpeed'] as num?)?.toInt() ?? 500,
      maxAccel: (json['maxAccel'] as num?)?.toInt() ?? 20000,
      hasEnclosedChamber: json['hasEnclosedChamber'] as bool? ?? true,
      hasLidar: json['hasLidar'] as bool? ?? false,
      isDualExtruder: json['isDualExtruder'] as bool? ?? false,
      coverAsset: json['coverAsset'] as String?,
    );
  }
}

class FilamentProfile {
  const FilamentProfile({
    required this.id,
    required this.name,
    required this.vendor,
    required this.type,
    required this.nozzleTemp,
    required this.nozzleTempInitial,
    required this.bedTemp,
    required this.flowRatio,
    required this.maxVolumetricSpeed,
    required this.density,
    required this.costPerKg,
    required this.pressureAdvanceK,
    required this.fanMin,
    required this.fanMax,
    required this.colorHex,
  });

  final String id;
  final String name;
  final String vendor;
  final String type;
  final int nozzleTemp;
  final int nozzleTempInitial;
  final int bedTemp;
  final double flowRatio;
  final double maxVolumetricSpeed;
  final double density;
  final double costPerKg;
  final double pressureAdvanceK;
  final int fanMin;
  final int fanMax;
  final String colorHex;

  Color get color {
    final cleaned = colorHex.replaceFirst('#', '');
    final value = int.tryParse(
          cleaned.length == 6 ? 'FF$cleaned' : cleaned,
          radix: 16,
        ) ??
        0xFF00AE42;
    return Color(value);
  }

  FilamentProfile copyWith({
    String? name,
    String? type,
    int? nozzleTemp,
    int? nozzleTempInitial,
    int? bedTemp,
    double? flowRatio,
    double? maxVolumetricSpeed,
    double? density,
    double? costPerKg,
    double? pressureAdvanceK,
    int? fanMin,
    int? fanMax,
    String? colorHex,
  }) {
    return FilamentProfile(
      id: id,
      name: name ?? this.name,
      vendor: vendor,
      type: type ?? this.type,
      nozzleTemp: nozzleTemp ?? this.nozzleTemp,
      nozzleTempInitial: nozzleTempInitial ?? this.nozzleTempInitial,
      bedTemp: bedTemp ?? this.bedTemp,
      flowRatio: flowRatio ?? this.flowRatio,
      maxVolumetricSpeed: maxVolumetricSpeed ?? this.maxVolumetricSpeed,
      density: density ?? this.density,
      costPerKg: costPerKg ?? this.costPerKg,
      pressureAdvanceK: pressureAdvanceK ?? this.pressureAdvanceK,
      fanMin: fanMin ?? this.fanMin,
      fanMax: fanMax ?? this.fanMax,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  factory FilamentProfile.fromJson(Map<String, dynamic> json) {
    return FilamentProfile(
      id: json['id'] as String? ?? 'GFA00',
      name: json['name'] as String? ?? 'Bambu PLA Basic',
      vendor: json['vendor'] as String? ?? 'Bambu',
      type: json['type'] as String? ?? 'PLA',
      nozzleTemp: (json['nozzleTemp'] as num?)?.toInt() ?? 220,
      nozzleTempInitial: (json['nozzleTempInitial'] as num?)?.toInt() ?? 220,
      bedTemp: (json['bedTemp'] as num?)?.toInt() ?? 55,
      flowRatio: (json['flowRatio'] as num?)?.toDouble() ?? 0.98,
      maxVolumetricSpeed:
          (json['maxVolumetricSpeed'] as num?)?.toDouble() ?? 21.0,
      density: (json['density'] as num?)?.toDouble() ?? 1.24,
      costPerKg: (json['costPerKg'] as num?)?.toDouble() ?? 24.99,
      pressureAdvanceK:
          (json['pressureAdvanceK'] as num?)?.toDouble() ?? 0.02,
      fanMin: (json['fanMin'] as num?)?.toInt() ?? 60,
      fanMax: (json['fanMax'] as num?)?.toInt() ?? 100,
      colorHex: json['defaultColor'] as String? ?? '#00AE42',
    );
  }
}

/// Complete Bambu Studio Process Settings covering ALL 6 official tabs:
/// 1. Quality, 2. Strength, 3. Speed, 4. Support, 5. Others, 6. Machine G-Code
class ProcessSettings {
  const ProcessSettings({
    required this.name,
    this.description = '',
    // 1. Quality
    this.layerHeight = 0.20,
    this.initialLayerHeight = 0.20,
    this.lineWidth = 0.42,
    this.initialLayerLineWidth = 0.50,
    this.outerWallLineWidth = 0.42,
    this.innerWallLineWidth = 0.45,
    this.topSurfaceLineWidth = 0.42,
    this.sparseInfillLineWidth = 0.45,
    this.seamPosition = 'aligned',
    this.scarfSeam = false,
    this.sliceGapClosingRadius = 0.049,
    this.resolution = 0.012,
    this.enableArcFitting = true,
    this.xyHoleCompensation = 0.0,
    this.xyContourCompensation = 0.0,
    this.ironingType = 'no_ironing',
    this.ironingSpeed = 30,
    this.ironingFlow = 10,
    this.wallGenerator = 'classic',
    this.wallOrder = 'inner/outer',
    this.thickBridges = false,
    // 2. Strength
    this.wallLoops = 2,
    this.alternateExtraWall = false,
    this.topShellLayers = 4,
    this.topShellThickness = 0.8,
    this.bottomShellLayers = 3,
    this.bottomShellThickness = 0.6,
    this.topSurfacePattern = 'monotonicline',
    this.bottomSurfacePattern = 'monotonic',
    this.sparseInfillDensity = 15,
    this.sparseInfillPattern = 'gyroid',
    this.infillWallOverlap = 15,
    this.infillCombination = false,
    // 3. Speed
    this.initialLayerSpeed = 50,
    this.initialLayerInfillSpeed = 105,
    this.outerWallSpeed = 200,
    this.innerWallSpeed = 300,
    this.sparseInfillSpeed = 270,
    this.internalSolidInfillSpeed = 250,
    this.topSurfaceSpeed = 200,
    this.gapInfillSpeed = 250,
    this.supportSpeed = 150,
    this.bridgeSpeed = 50,
    this.travelSpeed = 500,
    this.slowDownForOverhangs = true,
    this.defaultAcceleration = 10000,
    this.outerWallAcceleration = 5000,
    this.initialLayerAcceleration = 500,
    this.topSurfaceAcceleration = 2000,
    this.travelAcceleration = 10000,
    this.xyJerk = 9,
    // 4. Support
    this.enableSupport = false,
    this.supportType = 'tree(auto)',
    this.supportStyle = 'default',
    this.supportThresholdAngle = 30,
    this.supportOnBuildPlateOnly = false,
    this.supportRemoveSmallOverhangs = true,
    this.raftLayers = 0,
    this.supportTopZDistance = 0.20,
    this.supportBottomZDistance = 0.20,
    this.supportBasePattern = 'rectilinear',
    this.supportInterfaceTopLayers = 2,
    this.supportInterfaceSpacing = 0.5,
    this.supportObjectXyDistance = 0.35,
    this.supportFilamentSlot = 0, // 0 = Default
    this.supportInterfaceFilamentSlot = 0,
    // 5. Others
    this.skirtLoops = 0,
    this.brimType = 'auto_brim',
    this.brimWidth = 5.0,
    this.brimObjectGap = 0.1,
    this.enablePrimeTower = true,
    this.primeTowerWidth = 35,
    this.primeVolume = 45,
    this.flushIntoInfill = false,
    this.flushIntoSupport = true,
    this.printSequence = 'by_layer',
    this.spiralVase = false,
    this.timelapseType = 'traditional',
    this.fuzzySkin = 'none',
    this.fuzzySkinPointDistance = 0.8,
    this.fuzzySkinThickness = 0.3,
    this.reduceInfillRetraction = true,
    // 6. Machine G-Code
    this.startGcode = '; Bambu Studio Start G-Code\nG28 ; Home all axes\nG29 ; Auto Bed Leveling\nM109 S[nozzle_temperature_initial_layer]',
    this.endGcode = '; Bambu Studio End G-Code\nM400 ; Wait for moves\nG92 E0\nG1 E-0.8 F1800\nM104 S0\nM140 S0\nM84',
    this.layerChangeGcode = '; LAYER_CHANGE\n; Z:[layer_z]',
    this.filamentChangeGcode = '; AMS FILAMENT CHANGE T[next_extruder]\nM620 S[next_extruder]A\nM621 S[next_extruder]A',
  });

  final String name;
  final String description;
  // Quality
  final double layerHeight;
  final double initialLayerHeight;
  final double lineWidth;
  final double initialLayerLineWidth;
  final double outerWallLineWidth;
  final double innerWallLineWidth;
  final double topSurfaceLineWidth;
  final double sparseInfillLineWidth;
  final String seamPosition;
  final bool scarfSeam;
  final double sliceGapClosingRadius;
  final double resolution;
  final bool enableArcFitting;
  final double xyHoleCompensation;
  final double xyContourCompensation;
  final String ironingType;
  final int ironingSpeed;
  final int ironingFlow;
  final String wallGenerator;
  final String wallOrder;
  final bool thickBridges;
  // Strength
  final int wallLoops;
  final bool alternateExtraWall;
  final int topShellLayers;
  final double topShellThickness;
  final int bottomShellLayers;
  final double bottomShellThickness;
  final String topSurfacePattern;
  final String bottomSurfacePattern;
  final int sparseInfillDensity;
  final String sparseInfillPattern;
  final int infillWallOverlap;
  final bool infillCombination;
  // Speed
  final int initialLayerSpeed;
  final int initialLayerInfillSpeed;
  final int outerWallSpeed;
  final int innerWallSpeed;
  final int sparseInfillSpeed;
  final int internalSolidInfillSpeed;
  final int topSurfaceSpeed;
  final int gapInfillSpeed;
  final int supportSpeed;
  final int bridgeSpeed;
  final int travelSpeed;
  final bool slowDownForOverhangs;
  final int defaultAcceleration;
  final int outerWallAcceleration;
  final int initialLayerAcceleration;
  final int topSurfaceAcceleration;
  final int travelAcceleration;
  final int xyJerk;
  // Support
  final bool enableSupport;
  final String supportType;
  final String supportStyle;
  final int supportThresholdAngle;
  final bool supportOnBuildPlateOnly;
  final bool supportRemoveSmallOverhangs;
  final int raftLayers;
  final double supportTopZDistance;
  final double supportBottomZDistance;
  final String supportBasePattern;
  final int supportInterfaceTopLayers;
  final double supportInterfaceSpacing;
  final double supportObjectXyDistance;
  final int supportFilamentSlot;
  final int supportInterfaceFilamentSlot;
  // Others
  final int skirtLoops;
  final String brimType;
  final double brimWidth;
  final double brimObjectGap;
  final bool enablePrimeTower;
  final int primeTowerWidth;
  final int primeVolume;
  final bool flushIntoInfill;
  final bool flushIntoSupport;
  final String printSequence;
  final bool spiralVase;
  final String timelapseType;
  final String fuzzySkin;
  final double fuzzySkinPointDistance;
  final double fuzzySkinThickness;
  final bool reduceInfillRetraction;
  // Machine G-Code
  final String startGcode;
  final String endGcode;
  final String layerChangeGcode;
  final String filamentChangeGcode;

  ProcessSettings copyWith({
    String? name,
    String? description,
    double? layerHeight,
    double? initialLayerHeight,
    double? lineWidth,
    double? initialLayerLineWidth,
    double? outerWallLineWidth,
    double? innerWallLineWidth,
    double? topSurfaceLineWidth,
    double? sparseInfillLineWidth,
    String? seamPosition,
    bool? scarfSeam,
    double? sliceGapClosingRadius,
    double? resolution,
    bool? enableArcFitting,
    double? xyHoleCompensation,
    double? xyContourCompensation,
    String? ironingType,
    int? ironingSpeed,
    int? ironingFlow,
    String? wallGenerator,
    String? wallOrder,
    bool? thickBridges,
    int? wallLoops,
    bool? alternateExtraWall,
    int? topShellLayers,
    double? topShellThickness,
    int? bottomShellLayers,
    double? bottomShellThickness,
    String? topSurfacePattern,
    String? bottomSurfacePattern,
    int? sparseInfillDensity,
    String? sparseInfillPattern,
    int? infillWallOverlap,
    bool? infillCombination,
    int? initialLayerSpeed,
    int? initialLayerInfillSpeed,
    int? outerWallSpeed,
    int? innerWallSpeed,
    int? sparseInfillSpeed,
    int? internalSolidInfillSpeed,
    int? topSurfaceSpeed,
    int? gapInfillSpeed,
    int? supportSpeed,
    int? bridgeSpeed,
    int? travelSpeed,
    bool? slowDownForOverhangs,
    int? defaultAcceleration,
    int? outerWallAcceleration,
    int? initialLayerAcceleration,
    int? topSurfaceAcceleration,
    int? travelAcceleration,
    int? xyJerk,
    bool? enableSupport,
    String? supportType,
    String? supportStyle,
    int? supportThresholdAngle,
    bool? supportOnBuildPlateOnly,
    bool? supportRemoveSmallOverhangs,
    int? raftLayers,
    double? supportTopZDistance,
    double? supportBottomZDistance,
    String? supportBasePattern,
    int? supportInterfaceTopLayers,
    double? supportInterfaceSpacing,
    double? supportObjectXyDistance,
    int? supportFilamentSlot,
    int? supportInterfaceFilamentSlot,
    int? skirtLoops,
    String? brimType,
    double? brimWidth,
    double? brimObjectGap,
    bool? enablePrimeTower,
    int? primeTowerWidth,
    int? primeVolume,
    bool? flushIntoInfill,
    bool? flushIntoSupport,
    String? printSequence,
    bool? spiralVase,
    String? timelapseType,
    String? fuzzySkin,
    double? fuzzySkinPointDistance,
    double? fuzzySkinThickness,
    bool? reduceInfillRetraction,
    String? startGcode,
    String? endGcode,
    String? layerChangeGcode,
    String? filamentChangeGcode,
  }) {
    return ProcessSettings(
      name: name ?? this.name,
      description: description ?? this.description,
      layerHeight: layerHeight ?? this.layerHeight,
      initialLayerHeight: initialLayerHeight ?? this.initialLayerHeight,
      lineWidth: lineWidth ?? this.lineWidth,
      initialLayerLineWidth:
          initialLayerLineWidth ?? this.initialLayerLineWidth,
      outerWallLineWidth: outerWallLineWidth ?? this.outerWallLineWidth,
      innerWallLineWidth: innerWallLineWidth ?? this.innerWallLineWidth,
      topSurfaceLineWidth: topSurfaceLineWidth ?? this.topSurfaceLineWidth,
      sparseInfillLineWidth:
          sparseInfillLineWidth ?? this.sparseInfillLineWidth,
      seamPosition: seamPosition ?? this.seamPosition,
      scarfSeam: scarfSeam ?? this.scarfSeam,
      sliceGapClosingRadius:
          sliceGapClosingRadius ?? this.sliceGapClosingRadius,
      resolution: resolution ?? this.resolution,
      enableArcFitting: enableArcFitting ?? this.enableArcFitting,
      xyHoleCompensation: xyHoleCompensation ?? this.xyHoleCompensation,
      xyContourCompensation:
          xyContourCompensation ?? this.xyContourCompensation,
      ironingType: ironingType ?? this.ironingType,
      ironingSpeed: ironingSpeed ?? this.ironingSpeed,
      ironingFlow: ironingFlow ?? this.ironingFlow,
      wallGenerator: wallGenerator ?? this.wallGenerator,
      wallOrder: wallOrder ?? this.wallOrder,
      thickBridges: thickBridges ?? this.thickBridges,
      wallLoops: wallLoops ?? this.wallLoops,
      alternateExtraWall: alternateExtraWall ?? this.alternateExtraWall,
      topShellLayers: topShellLayers ?? this.topShellLayers,
      topShellThickness: topShellThickness ?? this.topShellThickness,
      bottomShellLayers: bottomShellLayers ?? this.bottomShellLayers,
      bottomShellThickness: bottomShellThickness ?? this.bottomShellThickness,
      topSurfacePattern: topSurfacePattern ?? this.topSurfacePattern,
      bottomSurfacePattern: bottomSurfacePattern ?? this.bottomSurfacePattern,
      sparseInfillDensity: sparseInfillDensity ?? this.sparseInfillDensity,
      sparseInfillPattern: sparseInfillPattern ?? this.sparseInfillPattern,
      infillWallOverlap: infillWallOverlap ?? this.infillWallOverlap,
      infillCombination: infillCombination ?? this.infillCombination,
      initialLayerSpeed: initialLayerSpeed ?? this.initialLayerSpeed,
      initialLayerInfillSpeed:
          initialLayerInfillSpeed ?? this.initialLayerInfillSpeed,
      outerWallSpeed: outerWallSpeed ?? this.outerWallSpeed,
      innerWallSpeed: innerWallSpeed ?? this.innerWallSpeed,
      sparseInfillSpeed: sparseInfillSpeed ?? this.sparseInfillSpeed,
      internalSolidInfillSpeed:
          internalSolidInfillSpeed ?? this.internalSolidInfillSpeed,
      topSurfaceSpeed: topSurfaceSpeed ?? this.topSurfaceSpeed,
      gapInfillSpeed: gapInfillSpeed ?? this.gapInfillSpeed,
      supportSpeed: supportSpeed ?? this.supportSpeed,
      bridgeSpeed: bridgeSpeed ?? this.bridgeSpeed,
      travelSpeed: travelSpeed ?? this.travelSpeed,
      slowDownForOverhangs: slowDownForOverhangs ?? this.slowDownForOverhangs,
      defaultAcceleration: defaultAcceleration ?? this.defaultAcceleration,
      outerWallAcceleration:
          outerWallAcceleration ?? this.outerWallAcceleration,
      initialLayerAcceleration:
          initialLayerAcceleration ?? this.initialLayerAcceleration,
      topSurfaceAcceleration:
          topSurfaceAcceleration ?? this.topSurfaceAcceleration,
      travelAcceleration: travelAcceleration ?? this.travelAcceleration,
      xyJerk: xyJerk ?? this.xyJerk,
      enableSupport: enableSupport ?? this.enableSupport,
      supportType: supportType ?? this.supportType,
      supportStyle: supportStyle ?? this.supportStyle,
      supportThresholdAngle:
          supportThresholdAngle ?? this.supportThresholdAngle,
      supportOnBuildPlateOnly:
          supportOnBuildPlateOnly ?? this.supportOnBuildPlateOnly,
      supportRemoveSmallOverhangs:
          supportRemoveSmallOverhangs ?? this.supportRemoveSmallOverhangs,
      raftLayers: raftLayers ?? this.raftLayers,
      supportTopZDistance: supportTopZDistance ?? this.supportTopZDistance,
      supportBottomZDistance:
          supportBottomZDistance ?? this.supportBottomZDistance,
      supportBasePattern: supportBasePattern ?? this.supportBasePattern,
      supportInterfaceTopLayers:
          supportInterfaceTopLayers ?? this.supportInterfaceTopLayers,
      supportInterfaceSpacing:
          supportInterfaceSpacing ?? this.supportInterfaceSpacing,
      supportObjectXyDistance:
          supportObjectXyDistance ?? this.supportObjectXyDistance,
      supportFilamentSlot: supportFilamentSlot ?? this.supportFilamentSlot,
      supportInterfaceFilamentSlot:
          supportInterfaceFilamentSlot ?? this.supportInterfaceFilamentSlot,
      skirtLoops: skirtLoops ?? this.skirtLoops,
      brimType: brimType ?? this.brimType,
      brimWidth: brimWidth ?? this.brimWidth,
      brimObjectGap: brimObjectGap ?? this.brimObjectGap,
      enablePrimeTower: enablePrimeTower ?? this.enablePrimeTower,
      primeTowerWidth: primeTowerWidth ?? this.primeTowerWidth,
      primeVolume: primeVolume ?? this.primeVolume,
      flushIntoInfill: flushIntoInfill ?? this.flushIntoInfill,
      flushIntoSupport: flushIntoSupport ?? this.flushIntoSupport,
      printSequence: printSequence ?? this.printSequence,
      spiralVase: spiralVase ?? this.spiralVase,
      timelapseType: timelapseType ?? this.timelapseType,
      fuzzySkin: fuzzySkin ?? this.fuzzySkin,
      fuzzySkinPointDistance:
          fuzzySkinPointDistance ?? this.fuzzySkinPointDistance,
      fuzzySkinThickness: fuzzySkinThickness ?? this.fuzzySkinThickness,
      reduceInfillRetraction:
          reduceInfillRetraction ?? this.reduceInfillRetraction,
      startGcode: startGcode ?? this.startGcode,
      endGcode: endGcode ?? this.endGcode,
      layerChangeGcode: layerChangeGcode ?? this.layerChangeGcode,
      filamentChangeGcode: filamentChangeGcode ?? this.filamentChangeGcode,
    );
  }

  Map<String, dynamic> toCliOverrideJson() => {
        'layer_height': layerHeight.toStringAsFixed(2),
        'initial_layer_print_height': initialLayerHeight.toStringAsFixed(2),
        'wall_loops': wallLoops.toString(),
        'top_shell_layers': topShellLayers.toString(),
        'bottom_shell_layers': bottomShellLayers.toString(),
        'sparse_infill_density': '$sparseInfillDensity%',
        'sparse_infill_pattern': sparseInfillPattern,
        'outer_wall_speed': outerWallSpeed.toString(),
        'inner_wall_speed': innerWallSpeed.toString(),
        'sparse_infill_speed': sparseInfillSpeed.toString(),
        'enable_support': enableSupport ? '1' : '0',
        'support_type': supportType,
        'brim_type': brimType,
        'seam_position': seamPosition,
        'wall_generator': wallGenerator,
        'enable_arc_fitting': enableArcFitting ? '1' : '0',
        'print_sequence': printSequence,
        'spiral_mode': spiralVase ? '1' : '0',
      };

  factory ProcessSettings.fromJson(Map<String, dynamic> json) {
    return ProcessSettings(
      name: json['name'] as String? ?? '0.20mm Standard',
      description: json['description'] as String? ?? '',
      layerHeight: (json['layerHeight'] as num?)?.toDouble() ?? 0.20,
      initialLayerHeight:
          (json['initialLayerHeight'] as num?)?.toDouble() ?? 0.20,
      lineWidth: (json['lineWidth'] as num?)?.toDouble() ?? 0.42,
      outerWallLineWidth:
          (json['outerWallLineWidth'] as num?)?.toDouble() ?? 0.42,
      innerWallLineWidth:
          (json['innerWallLineWidth'] as num?)?.toDouble() ?? 0.45,
      wallLoops: (json['wallLoops'] as num?)?.toInt() ?? 2,
      topShellLayers: (json['topShellLayers'] as num?)?.toInt() ?? 4,
      bottomShellLayers: (json['bottomShellLayers'] as num?)?.toInt() ?? 3,
      sparseInfillDensity:
          (json['sparseInfillDensity'] as num?)?.toInt() ?? 15,
      sparseInfillPattern:
          json['sparseInfillPattern'] as String? ?? 'gyroid',
      outerWallSpeed: (json['outerWallSpeed'] as num?)?.toInt() ?? 200,
      innerWallSpeed: (json['innerWallSpeed'] as num?)?.toInt() ?? 300,
      sparseInfillSpeed: (json['sparseInfillSpeed'] as num?)?.toInt() ?? 270,
      topSurfaceSpeed: (json['topSurfaceSpeed'] as num?)?.toInt() ?? 200,
      initialLayerSpeed: (json['initialLayerSpeed'] as num?)?.toInt() ?? 50,
      travelSpeed: (json['travelSpeed'] as num?)?.toInt() ?? 500,
      defaultAcceleration:
          (json['defaultAcceleration'] as num?)?.toInt() ?? 10000,
      outerWallAcceleration:
          (json['outerWallAcceleration'] as num?)?.toInt() ?? 5000,
      enableSupport: json['enableSupport'] as bool? ?? false,
      supportType: json['supportType'] as String? ?? 'tree(auto)',
      brimType: json['brimType'] as String? ?? 'auto_brim',
      enableArcFitting: json['enableArcFitting'] as bool? ?? true,
      seamPosition: json['seamPosition'] as String? ?? 'aligned',
      wallGenerator: json['wallGenerator'] as String? ?? 'classic',
    );
  }
}
