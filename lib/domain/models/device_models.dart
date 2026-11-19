import 'package:material_ui/material_ui.dart';

enum PrinterSpeedProfile {
  silent(1, 'Silent', '50%'),
  standard(2, 'Standard', '100%'),
  sport(3, 'Sport', '124%'),
  ludicrous(4, 'Ludicrous', '166%');

  const PrinterSpeedProfile(this.bambuCode, this.label, this.multiplier);
  final int bambuCode;
  final String label;
  final String multiplier;
}

enum PrinterJobStage {
  idle('Idle', Color(0xFF78909C)),
  preparing('Preparing / Leveling', Color(0xFF42A5F5)),
  printing('Printing', Color(0xFF00AE42)),
  paused('Paused', Color(0xFFFFB300)),
  finished('Completed', Color(0xFF26A69A)),
  error('Attention Required', Color(0xFFEF5350)),
  offline('Offline', Color(0xFF546E7A));

  const PrinterJobStage(this.label, this.color);
  final String label;
  final Color color;
}

class HmsCodeEntry {
  const HmsCodeEntry({
    required this.code,
    required this.rawCode,
    required this.module,
    required this.severity,
    required this.message,
  });

  final String code;
  final String rawCode;
  final String module;
  final String severity;
  final String message;

  factory HmsCodeEntry.fromJson(Map<String, dynamic> json) {
    return HmsCodeEntry(
      code: json['code'] as String? ?? '',
      rawCode: json['rawCode'] as String? ?? '',
      module: json['module'] as String? ?? 'Printer Core',
      severity: json['severity'] as String? ?? 'Warning',
      message: json['message'] as String? ?? '',
    );
  }
}

class AmsSlotState {
  const AmsSlotState({
    required this.slotIndex,
    required this.trayLabel,
    required this.materialType,
    required this.filamentName,
    required this.color,
    required this.remainingPercent,
    required this.nozzleMinTemp,
    required this.nozzleMaxTemp,
    required this.pressureAdvanceK,
    this.isBambuRfid = true,
    this.isLoaded = false,
  });

  final int slotIndex;
  final String trayLabel;
  final String materialType;
  final String filamentName;
  final Color color;
  final int remainingPercent;
  final int nozzleMinTemp;
  final int nozzleMaxTemp;
  final double pressureAdvanceK;
  final bool isBambuRfid;
  final bool isLoaded;

  AmsSlotState copyWith({
    String? materialType,
    String? filamentName,
    Color? color,
    int? remainingPercent,
    double? pressureAdvanceK,
    bool? isLoaded,
  }) {
    return AmsSlotState(
      slotIndex: slotIndex,
      trayLabel: trayLabel,
      materialType: materialType ?? this.materialType,
      filamentName: filamentName ?? this.filamentName,
      color: color ?? this.color,
      remainingPercent: remainingPercent ?? this.remainingPercent,
      nozzleMinTemp: nozzleMinTemp,
      nozzleMaxTemp: nozzleMaxTemp,
      pressureAdvanceK: pressureAdvanceK ?? this.pressureAdvanceK,
      isBambuRfid: isBambuRfid,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class AmsUnitState {
  const AmsUnitState({
    required this.id,
    required this.name,
    required this.humidityLevel, // 1 = Driest, 5 = Wet
    required this.tempC,
    required this.slots,
    this.isDrying = false,
    this.dryTargetTempC = 55,
    this.dryRemainingMinutes = 0,
    this.autoRefillEnabled = true,
    this.insertionUpdateEnabled = true,
  });

  final String id;
  final String name;
  final int humidityLevel;
  final double tempC;
  final List<AmsSlotState> slots;
  final bool isDrying;
  final int dryTargetTempC;
  final int dryRemainingMinutes;
  final bool autoRefillEnabled;
  final bool insertionUpdateEnabled;

  AmsUnitState copyWith({
    int? humidityLevel,
    double? tempC,
    List<AmsSlotState>? slots,
    bool? isDrying,
    int? dryTargetTempC,
    int? dryRemainingMinutes,
    bool? autoRefillEnabled,
    bool? insertionUpdateEnabled,
  }) {
    return AmsUnitState(
      id: id,
      name: name,
      humidityLevel: humidityLevel ?? this.humidityLevel,
      tempC: tempC ?? this.tempC,
      slots: slots ?? this.slots,
      isDrying: isDrying ?? this.isDrying,
      dryTargetTempC: dryTargetTempC ?? this.dryTargetTempC,
      dryRemainingMinutes: dryRemainingMinutes ?? this.dryRemainingMinutes,
      autoRefillEnabled: autoRefillEnabled ?? this.autoRefillEnabled,
      insertionUpdateEnabled:
          insertionUpdateEnabled ?? this.insertionUpdateEnabled,
    );
  }
}

class SdCardFile {
  const SdCardFile({
    required this.name,
    required this.sizeMb,
    required this.modifiedAt,
    required this.isTimelapse,
    required this.estimatedTime,
  });

  final String name;
  final double sizeMb;
  final String modifiedAt;
  final bool isTimelapse;
  final String estimatedTime;
}

class PrinterAiOptions {
  const PrinterAiOptions({
    this.firstLayerInspection = true,
    this.spaghettiDetection = true,
    this.spaghettiSensitivity = 'Medium',
    this.nozzleClumpingDetection = true,
    this.buildPlateMarkerDetection = true,
    this.airPrintingDetection = true,
    this.autoRecoveryStepLoss = true,
    this.promptSound = true,
  });

  final bool firstLayerInspection;
  final bool spaghettiDetection;
  final String spaghettiSensitivity;
  final bool nozzleClumpingDetection;
  final bool buildPlateMarkerDetection;
  final bool airPrintingDetection;
  final bool autoRecoveryStepLoss;
  final bool promptSound;

  PrinterAiOptions copyWith({
    bool? firstLayerInspection,
    bool? spaghettiDetection,
    String? spaghettiSensitivity,
    bool? nozzleClumpingDetection,
    bool? buildPlateMarkerDetection,
    bool? airPrintingDetection,
    bool? autoRecoveryStepLoss,
    bool? promptSound,
  }) {
    return PrinterAiOptions(
      firstLayerInspection: firstLayerInspection ?? this.firstLayerInspection,
      spaghettiDetection: spaghettiDetection ?? this.spaghettiDetection,
      spaghettiSensitivity: spaghettiSensitivity ?? this.spaghettiSensitivity,
      nozzleClumpingDetection:
          nozzleClumpingDetection ?? this.nozzleClumpingDetection,
      buildPlateMarkerDetection:
          buildPlateMarkerDetection ?? this.buildPlateMarkerDetection,
      airPrintingDetection: airPrintingDetection ?? this.airPrintingDetection,
      autoRecoveryStepLoss: autoRecoveryStepLoss ?? this.autoRecoveryStepLoss,
      promptSound: promptSound ?? this.promptSound,
    );
  }
}

class BambuDevice {
  const BambuDevice({
    required this.id,
    required this.name,
    required this.modelName,
    required this.serialNumber,
    required this.ipAddress,
    required this.accessCode,
    required this.firmwareVersion,
    required this.isLanConnected,
    required this.stage,
    required this.currentJobName,
    required this.progressPercent,
    required this.currentLayer,
    required this.totalLayers,
    required this.remainingMinutes,
    required this.nozzleTemp,
    required this.nozzleTargetTemp,
    required this.bedTemp,
    required this.bedTargetTemp,
    required this.chamberTemp,
    required this.partFanPercent,
    required this.auxFanPercent,
    required this.chamberFanPercent,
    required this.chamberLightOn,
    required this.timelapseEnabled,
    required this.cameraResolution,
    required this.speedProfile,
    required this.nozzleDiameter,
    required this.nozzleMaterial,
    required this.wifiRssi,
    required this.printHours,
    required this.amsUnits,
    required this.activeHmsAlerts,
    required this.aiOptions,
    required this.sdCardFiles,
    this.skippedObjectIds = const [],
    this.coverAsset,
  });

  final String id;
  final String name;
  final String modelName;
  final String serialNumber;
  final String ipAddress;
  final String accessCode;
  final String firmwareVersion;
  final bool isLanConnected;
  final PrinterJobStage stage;
  final String currentJobName;
  final int progressPercent;
  final int currentLayer;
  final int totalLayers;
  final int remainingMinutes;
  final double nozzleTemp;
  final int nozzleTargetTemp;
  final double bedTemp;
  final int bedTargetTemp;
  final double chamberTemp;
  final int partFanPercent;
  final int auxFanPercent;
  final int chamberFanPercent;
  final bool chamberLightOn;
  final bool timelapseEnabled;
  final String cameraResolution;
  final PrinterSpeedProfile speedProfile;
  final String nozzleDiameter;
  final String nozzleMaterial;
  final int wifiRssi;
  final int printHours;
  final List<AmsUnitState> amsUnits;
  final List<HmsCodeEntry> activeHmsAlerts;
  final PrinterAiOptions aiOptions;
  final List<SdCardFile> sdCardFiles;
  final List<String> skippedObjectIds;
  final String? coverAsset;

  BambuDevice copyWith({
    String? name,
    String? ipAddress,
    String? accessCode,
    bool? isLanConnected,
    PrinterJobStage? stage,
    String? currentJobName,
    int? progressPercent,
    int? currentLayer,
    int? totalLayers,
    int? remainingMinutes,
    double? nozzleTemp,
    int? nozzleTargetTemp,
    double? bedTemp,
    int? bedTargetTemp,
    double? chamberTemp,
    int? partFanPercent,
    int? auxFanPercent,
    int? chamberFanPercent,
    bool? chamberLightOn,
    bool? timelapseEnabled,
    String? cameraResolution,
    PrinterSpeedProfile? speedProfile,
    String? nozzleDiameter,
    String? nozzleMaterial,
    List<AmsUnitState>? amsUnits,
    List<HmsCodeEntry>? activeHmsAlerts,
    PrinterAiOptions? aiOptions,
    List<SdCardFile>? sdCardFiles,
    List<String>? skippedObjectIds,
  }) {
    return BambuDevice(
      id: id,
      name: name ?? this.name,
      modelName: modelName,
      serialNumber: serialNumber,
      ipAddress: ipAddress ?? this.ipAddress,
      accessCode: accessCode ?? this.accessCode,
      firmwareVersion: firmwareVersion,
      isLanConnected: isLanConnected ?? this.isLanConnected,
      stage: stage ?? this.stage,
      currentJobName: currentJobName ?? this.currentJobName,
      progressPercent: progressPercent ?? this.progressPercent,
      currentLayer: currentLayer ?? this.currentLayer,
      totalLayers: totalLayers ?? this.totalLayers,
      remainingMinutes: remainingMinutes ?? this.remainingMinutes,
      nozzleTemp: nozzleTemp ?? this.nozzleTemp,
      nozzleTargetTemp: nozzleTargetTemp ?? this.nozzleTargetTemp,
      bedTemp: bedTemp ?? this.bedTemp,
      bedTargetTemp: bedTargetTemp ?? this.bedTargetTemp,
      chamberTemp: chamberTemp ?? this.chamberTemp,
      partFanPercent: partFanPercent ?? this.partFanPercent,
      auxFanPercent: auxFanPercent ?? this.auxFanPercent,
      chamberFanPercent: chamberFanPercent ?? this.chamberFanPercent,
      chamberLightOn: chamberLightOn ?? this.chamberLightOn,
      timelapseEnabled: timelapseEnabled ?? this.timelapseEnabled,
      cameraResolution: cameraResolution ?? this.cameraResolution,
      speedProfile: speedProfile ?? this.speedProfile,
      nozzleDiameter: nozzleDiameter ?? this.nozzleDiameter,
      nozzleMaterial: nozzleMaterial ?? this.nozzleMaterial,
      wifiRssi: wifiRssi,
      printHours: printHours,
      amsUnits: amsUnits ?? this.amsUnits,
      activeHmsAlerts: activeHmsAlerts ?? this.activeHmsAlerts,
      aiOptions: aiOptions ?? this.aiOptions,
      sdCardFiles: sdCardFiles ?? this.sdCardFiles,
      skippedObjectIds: skippedObjectIds ?? this.skippedObjectIds,
      coverAsset: coverAsset,
    );
  }
}
