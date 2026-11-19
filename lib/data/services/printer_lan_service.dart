import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import '../../domain/models/device_models.dart';

/// Bambu Lab LAN Protocol (MQTTS port 8883 + FTPS port 990) & Live Device Fleet Service.
/// Generates genuine Bambu Lab MQTT JSON payloads and tests real TLS LAN reachability,
/// while also powering a rich multi-printer simulator when no physical printer is reachable.
class PrinterLanService {
  const PrinterLanService();

  /// Tests TLS connectivity to a Bambu Lab printer in LAN-Only mode (port 8883).
  Future<(bool, String)> testLanMqttConnection({
    required String ipAddress,
    required String accessCode,
    required String serialNumber,
  }) async {
    if (kIsWeb) {
      return (
        false,
        'Direct raw TLS sockets are restricted in Web browsers; connect via Bambu CLI Bridge or Android/iOS build.'
      );
    }
    try {
      final socket = await SecureSocket.connect(
        ipAddress,
        8883,
        timeout: const Duration(seconds: 3),
        onBadCertificate: (_) => true, // Bambu printers use self-signed LAN certs
      );
      await socket.close();
      return (true, 'TLS MQTTS handshake succeeded on $ipAddress:8883 (SN: $serialNumber)');
    } catch (e) {
      return (
        false,
        'Could not reach $ipAddress:8883 ($e). Switched to live interactive simulator mode.'
      );
    }
  }

  /// Authentic Bambu Lab MQTT JSON payloads sent to `device/<serial>/request`
  Map<String, dynamic> buildPausePayload() => {
        'print': {'sequence_id': '${DateTime.now().millisecondsSinceEpoch}', 'command': 'pause'}
      };

  Map<String, dynamic> buildResumePayload() => {
        'print': {'sequence_id': '${DateTime.now().millisecondsSinceEpoch}', 'command': 'resume'}
      };

  Map<String, dynamic> buildStopPayload() => {
        'print': {'sequence_id': '${DateTime.now().millisecondsSinceEpoch}', 'command': 'stop'}
      };

  Map<String, dynamic> buildSpeedProfilePayload(PrinterSpeedProfile profile) => {
        'print': {
          'sequence_id': '${DateTime.now().millisecondsSinceEpoch}',
          'command': 'print_speed',
          'param': '${profile.bambuCode}',
        }
      };

  Map<String, dynamic> buildGcodePayload(String gcodeLine) => {
        'print': {
          'sequence_id': '${DateTime.now().millisecondsSinceEpoch}',
          'command': 'gcode_line',
          'param': '$gcodeLine\n',
        }
      };

  Map<String, dynamic> buildChamberLightPayload(bool on) => {
        'system': {
          'sequence_id': '${DateTime.now().millisecondsSinceEpoch}',
          'command': 'ledctrl',
          'led_node': 'chamber_light',
          'led_mode': on ? 'on' : 'off',
        }
      };

  Map<String, dynamic> buildProjectPrintPayload({
    required String fileName,
    required int plateId,
    required List<int> amsMapping,
    required bool bedLeveling,
    required bool flowCali,
    required bool timelapse,
    required bool useAms,
  }) =>
      {
        'print': {
          'sequence_id': '${DateTime.now().millisecondsSinceEpoch}',
          'command': 'project_file',
          'param': 'Metadata/plate_$plateId.gcode',
          'url': 'ftp://$fileName',
          'bed_leveling': bedLeveling,
          'flow_cali': flowCali,
          'timelapse': timelapse,
          'use_ams': useAms,
          'ams_mapping': amsMapping,
        }
      };

  String formatPayloadPretty(Map<String, dynamic> payload) =>
      const JsonEncoder.withIndent('  ').convert(payload);

  /// Initial multi-printer Bambu Lab fleet (X1 Carbon, A1 Combo, P1S, H2D Pro)
  List<BambuDevice> createDefaultFleet(List<HmsCodeEntry> hmsCatalog) {
    final sampleWarning = hmsCatalog.isNotEmpty
        ? hmsCatalog.firstWhere(
            (e) => e.message.toLowerCase().contains('filament') || e.message.toLowerCase().contains('ams'),
            orElse: () => hmsCatalog.first,
          )
        : const HmsCodeEntry(
            code: '0700-2000-0002-0001',
            rawCode: '0700200000020001',
            module: 'AMS / Filament',
            severity: 'Warning',
            message: 'AMS Slot 3 filament humidity is elevated. Consider drying filament.',
          );

    return [
      BambuDevice(
        id: 'dev_x1c_01',
        name: 'Studio X1 Carbon',
        modelName: 'Bambu Lab X1 Carbon',
        serialNumber: '00M09A341800142',
        ipAddress: '192.168.1.104',
        accessCode: '48291045',
        firmwareVersion: '01.08.02.00',
        isLanConnected: true,
        stage: PrinterJobStage.printing,
        currentJobName: 'Bambu_Cube_MultiColor.3mf',
        progressPercent: 64,
        currentLayer: 128,
        totalLayers: 200,
        remainingMinutes: 42,
        nozzleTemp: 220.2,
        nozzleTargetTemp: 220,
        bedTemp: 55.0,
        bedTargetTemp: 55,
        chamberTemp: 36.5,
        partFanPercent: 80,
        auxFanPercent: 40,
        chamberFanPercent: 50,
        chamberLightOn: true,
        timelapseEnabled: true,
        cameraResolution: '1080p',
        speedProfile: PrinterSpeedProfile.standard,
        nozzleDiameter: '0.4 mm',
        nozzleMaterial: 'Hardened Steel',
        wifiRssi: -48,
        printHours: 618,
        coverAsset: 'assets/bambu_data/printers/bambu_lab_x1_carbon_cover.png',
        amsUnits: const [
          AmsUnitState(
            id: 'ams_a',
            name: 'AMS A (4-Slot)',
            humidityLevel: 1,
            tempC: 27.4,
            slots: [
              AmsSlotState(
                slotIndex: 0,
                trayLabel: 'A1',
                materialType: 'PLA',
                filamentName: 'Bambu PLA Basic Green',
                color: Color(0xFF00AE42),
                remainingPercent: 84,
                nozzleMinTemp: 190,
                nozzleMaxTemp: 230,
                pressureAdvanceK: 0.020,
                isLoaded: true,
              ),
              AmsSlotState(
                slotIndex: 1,
                trayLabel: 'A2',
                materialType: 'PLA',
                filamentName: 'Bambu PLA Matte Charcoal',
                color: Color(0xFF2B2D42),
                remainingPercent: 62,
                nozzleMinTemp: 190,
                nozzleMaxTemp: 230,
                pressureAdvanceK: 0.022,
              ),
              AmsSlotState(
                slotIndex: 2,
                trayLabel: 'A3',
                materialType: 'PETG',
                filamentName: 'Bambu PETG HF Orange',
                color: Color(0xFFFF6D00),
                remainingPercent: 45,
                nozzleMinTemp: 230,
                nozzleMaxTemp: 260,
                pressureAdvanceK: 0.032,
              ),
              AmsSlotState(
                slotIndex: 3,
                trayLabel: 'A4',
                materialType: 'PLA',
                filamentName: 'Support for PLA White',
                color: Color(0xFFECEFF1),
                remainingPercent: 91,
                nozzleMinTemp: 190,
                nozzleMaxTemp: 230,
                pressureAdvanceK: 0.020,
              ),
            ],
          ),
        ],
        activeHmsAlerts: const [],
        aiOptions: const PrinterAiOptions(),
        sdCardFiles: const [
          SdCardFile(
            name: 'Bambu_Cube_MultiColor.3mf',
            sizeMb: 4.8,
            modifiedAt: 'Today 17:40',
            isTimelapse: false,
            estimatedTime: '1h 54m',
          ),
          SdCardFile(
            name: '3DBenchy_020_Standard.3mf',
            sizeMb: 3.1,
            modifiedAt: 'Yesterday',
            isTimelapse: false,
            estimatedTime: '41m',
          ),
          SdCardFile(
            name: 'timelapse_20261118_1602.mp4',
            sizeMb: 18.4,
            modifiedAt: 'Today 16:02',
            isTimelapse: true,
            estimatedTime: '00:24',
          ),
        ],
      ),
      BambuDevice(
        id: 'dev_a1_02',
        name: 'Workshop A1 Combo',
        modelName: 'Bambu Lab A1',
        serialNumber: '03919C410200881',
        ipAddress: '192.168.1.109',
        accessCode: '19384721',
        firmwareVersion: '01.04.00.00',
        isLanConnected: true,
        stage: PrinterJobStage.idle,
        currentJobName: 'No active print',
        progressPercent: 0,
        currentLayer: 0,
        totalLayers: 0,
        remainingMinutes: 0,
        nozzleTemp: 28.0,
        nozzleTargetTemp: 0,
        bedTemp: 26.5,
        bedTargetTemp: 0,
        chamberTemp: 25.0,
        partFanPercent: 0,
        auxFanPercent: 0,
        chamberFanPercent: 0,
        chamberLightOn: false,
        timelapseEnabled: false,
        cameraResolution: '720p',
        speedProfile: PrinterSpeedProfile.standard,
        nozzleDiameter: '0.4 mm',
        nozzleMaterial: 'Stainless Steel',
        wifiRssi: -55,
        printHours: 245,
        coverAsset: 'assets/bambu_data/printers/bambu_lab_a1_cover.png',
        amsUnits: const [
          AmsUnitState(
            id: 'ams_lite_1',
            name: 'AMS Lite',
            humidityLevel: 3,
            tempC: 25.1,
            slots: [
              AmsSlotState(
                slotIndex: 0,
                trayLabel: '1',
                materialType: 'PLA',
                filamentName: 'Bambu PLA Basic Jade White',
                color: Color(0xFFF5F5F5),
                remainingPercent: 78,
                nozzleMinTemp: 190,
                nozzleMaxTemp: 230,
                pressureAdvanceK: 0.020,
              ),
              AmsSlotState(
                slotIndex: 1,
                trayLabel: '2',
                materialType: 'PLA',
                filamentName: 'Bambu PLA Silk Gold',
                color: Color(0xFFFFCA28),
                remainingPercent: 52,
                nozzleMinTemp: 210,
                nozzleMaxTemp: 230,
                pressureAdvanceK: 0.024,
              ),
              AmsSlotState(
                slotIndex: 2,
                trayLabel: '3',
                materialType: 'PLA',
                filamentName: 'Bambu PLA Basic Cyan',
                color: Color(0xFF00B8D4),
                remainingPercent: 95,
                nozzleMinTemp: 190,
                nozzleMaxTemp: 230,
                pressureAdvanceK: 0.020,
              ),
              AmsSlotState(
                slotIndex: 3,
                trayLabel: '4',
                materialType: 'PLA',
                filamentName: 'Bambu PLA Basic Red',
                color: Color(0xFFD50000),
                remainingPercent: 30,
                nozzleMinTemp: 190,
                nozzleMaxTemp: 230,
                pressureAdvanceK: 0.020,
              ),
            ],
          ),
        ],
        activeHmsAlerts: [sampleWarning],
        aiOptions: const PrinterAiOptions(firstLayerInspection: false),
        sdCardFiles: const [
          SdCardFile(
            name: 'Cable_Organizer_Plate1.3mf',
            sizeMb: 2.3,
            modifiedAt: '2 days ago',
            isTimelapse: false,
            estimatedTime: '58m',
          ),
        ],
      ),
      BambuDevice(
        id: 'dev_h2d_03',
        name: 'Lab H2D Pro (Dual)',
        modelName: 'Bambu Lab H2D Pro',
        serialNumber: '09482H2DP000319',
        ipAddress: '192.168.1.115',
        accessCode: '90418273',
        firmwareVersion: '01.02.04.00',
        isLanConnected: true,
        stage: PrinterJobStage.paused,
        currentJobName: 'PAHT-CF_Bracket_DualNozzle.3mf',
        progressPercent: 81,
        currentLayer: 243,
        totalLayers: 300,
        remainingMinutes: 27,
        nozzleTemp: 270.0,
        nozzleTargetTemp: 270,
        bedTemp: 100.0,
        bedTargetTemp: 100,
        chamberTemp: 60.0,
        partFanPercent: 30,
        auxFanPercent: 20,
        chamberFanPercent: 65,
        chamberLightOn: true,
        timelapseEnabled: true,
        cameraResolution: '1080p',
        speedProfile: PrinterSpeedProfile.sport,
        nozzleDiameter: '0.4 mm (Dual)',
        nozzleMaterial: 'Hardened Steel HF',
        wifiRssi: -42,
        printHours: 112,
        coverAsset: 'assets/bambu_data/printers/bambu_lab_h2d_pro_cover.png',
        amsUnits: const [
          AmsUnitState(
            id: 'ams_ht_1',
            name: 'AMS 2 Pro (Active Dry)',
            humidityLevel: 1,
            tempC: 54.0,
            isDrying: true,
            dryTargetTempC: 65,
            dryRemainingMinutes: 210,
            slots: [
              AmsSlotState(
                slotIndex: 0,
                trayLabel: 'A1',
                materialType: 'PAHT-CF',
                filamentName: 'Bambu PAHT-CF Black',
                color: Color(0xFF1E2226),
                remainingPercent: 68,
                nozzleMinTemp: 260,
                nozzleMaxTemp: 290,
                pressureAdvanceK: 0.018,
                isLoaded: true,
              ),
              AmsSlotState(
                slotIndex: 1,
                trayLabel: 'A2',
                materialType: 'ABS',
                filamentName: 'Bambu ABS Blue',
                color: Color(0xFF1976D2),
                remainingPercent: 88,
                nozzleMinTemp: 240,
                nozzleMaxTemp: 270,
                pressureAdvanceK: 0.025,
              ),
              AmsSlotState(
                slotIndex: 2,
                trayLabel: 'A3',
                materialType: 'ASA',
                filamentName: 'Bambu ASA Gray',
                color: Color(0xFF78909C),
                remainingPercent: 74,
                nozzleMinTemp: 240,
                nozzleMaxTemp: 270,
                pressureAdvanceK: 0.025,
              ),
              AmsSlotState(
                slotIndex: 3,
                trayLabel: 'A4',
                materialType: 'Support',
                filamentName: 'Support for PA/PET',
                color: Color(0xFFFFD54F),
                remainingPercent: 90,
                nozzleMinTemp: 250,
                nozzleMaxTemp: 270,
                pressureAdvanceK: 0.022,
              ),
            ],
          ),
        ],
        activeHmsAlerts: const [],
        aiOptions: const PrinterAiOptions(),
        sdCardFiles: const [
          SdCardFile(
            name: 'PAHT-CF_Bracket_DualNozzle.3mf',
            sizeMb: 9.2,
            modifiedAt: 'Today 15:15',
            isTimelapse: false,
            estimatedTime: '2h 20m',
          ),
        ],
      ),
    ];
  }
}
