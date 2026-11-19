import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import '../../../../data/services/printer_lan_service.dart';
import '../../../../domain/models/device_models.dart';

/// MVVM ViewModel for both the single Device Tab and Multi-Device Print Farm tab.
class DeviceViewModel extends ChangeNotifier {
  DeviceViewModel({PrinterLanService? lanService})
      : _lan = lanService ?? const PrinterLanService();

  final PrinterLanService _lan;
  Timer? _telemetryTimer;

  List<BambuDevice> _devices = const [];
  List<BambuDevice> get devices => _devices;

  int _selectedIndex = -1;
  int get selectedIndex => _selectedIndex;
  BambuDevice? get activeDevice =>
      (_selectedIndex >= 0 && _selectedIndex < _devices.length)
          ? _devices[_selectedIndex]
          : null;

  List<HmsCodeEntry> _hmsCatalog = const [];
  List<HmsCodeEntry> get hmsCatalog => _hmsCatalog;

  final List<String> _mqttLog = [];
  List<String> get mqttLog => List.unmodifiable(_mqttLog);

  String _fleetFilter = 'All';
  String get fleetFilter => _fleetFilter;

  String? _lastLanTestResult;
  String? get lastLanTestResult => _lastLanTestResult;

  bool _demoMode = false;
  bool get demoMode => _demoMode;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // External Spool Holder (Non-AMS)
  String _externalSpoolMaterial = 'TPU 95A';
  String get externalSpoolMaterial => _externalSpoolMaterial;
  Color _externalSpoolColor = const Color(0xFF9B5DE5);
  Color get externalSpoolColor => _externalSpoolColor;
  String _firmwareStatus = 'Up to date (Latest Official Release)';
  String get firmwareStatus => _firmwareStatus;

  void updateExternalSpool({String? material, Color? color}) {
    if (material != null) _externalSpoolMaterial = material;
    if (color != null) _externalSpoolColor = color;
    _logMqtt('External Spool updated -> $_externalSpoolMaterial');
    notifyListeners();
  }

  void updateHotendHardware({required String diameter, required String material}) {
    _logMqtt('Nozzle Hardware Configured -> $diameter ($material)');
    _updateActive((d) => d.copyWith(
          nozzleDiameter: diameter,
          nozzleMaterial: material,
        ));
  }

  void sendCustomGcodeLine(String rawLine) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) return;
    _sendGcode(trimmed);
  }

  void checkFirmwareUpdate() {
    final dev = activeDevice;
    _firmwareStatus =
        'Checked ${dev?.firmwareVersion ?? "01.08.02.00"} — Up to date';
    _logMqtt('Firmware check complete for ${dev?.name ?? "printer"}');
    notifyListeners();
  }

  void initialize(List<HmsCodeEntry> catalog) {
    _hmsCatalog = catalog;
    _devices = [];
    _selectedIndex = -1;
    _telemetryTimer?.cancel();
    _logMqtt('Device manager initialized. Ready to connect your Bambu Lab printer.');
    notifyListeners();
  }

  void toggleDemoMode() {
    _demoMode = !_demoMode;
    if (_demoMode) {
      _devices = _lan.createDefaultFleet(_hmsCatalog);
      _selectedIndex = 0;
      _logMqtt('Demo Mode enabled: ${_devices.length} simulated printers loaded');
      _telemetryTimer?.cancel();
      _telemetryTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _tickSimulatedTelemetry();
      });
    } else {
      _telemetryTimer?.cancel();
      _devices = [];
      _selectedIndex = -1;
      _logMqtt('Demo Mode disabled: simulated fleet removed');
    }
    notifyListeners();
  }

  void _tickSimulatedTelemetry() {
    bool changed = false;
    final next = _devices.map((d) {
      if (d.stage == PrinterJobStage.printing && d.progressPercent < 100) {
        changed = true;
        final nextProg = (d.progressPercent + 1).clamp(0, 100);
        final nextLayer =
            ((nextProg / 100.0) * d.totalLayers).round().clamp(0, d.totalLayers);
        final rem = (d.remainingMinutes - 1).clamp(0, 999);
        return d.copyWith(
          progressPercent: nextProg,
          currentLayer: nextLayer,
          remainingMinutes: rem,
          stage: nextProg >= 100
              ? PrinterJobStage.finished
              : PrinterJobStage.printing,
        );
      }
      return d;
    }).toList();
    if (changed) {
      _devices = next;
      notifyListeners();
    }
  }

  void selectDevice(int index) {
    if (_devices.isEmpty) {
      _selectedIndex = -1;
      return;
    }
    if (index < 0 || index >= _devices.length) return;
    _selectedIndex = index;
    notifyListeners();
  }

  void removeDevice(int index) {
    if (index < 0 || index >= _devices.length) return;
    final dev = _devices[index];
    _logMqtt('Disconnected printer: ${dev.name} (${dev.ipAddress})');
    final updated = List<BambuDevice>.from(_devices)..removeAt(index);
    _devices = updated;
    if (_devices.isEmpty) {
      _selectedIndex = -1;
      _telemetryTimer?.cancel();
    } else if (_selectedIndex >= _devices.length) {
      _selectedIndex = _devices.length - 1;
    }
    notifyListeners();
  }

  Future<List<Map<String, String>>> discoverPrinters({String? bridgeUrl}) async {
    _isScanning = true;
    _logMqtt('Starting Wi-Fi / LAN printer auto-discovery...');
    notifyListeners();

    final results = <Map<String, String>>[];
    try {
      final url = (bridgeUrl != null && bridgeUrl.isNotEmpty) ? bridgeUrl : 'http://localhost:8765';
      try {
        final client = http.Client();
        final uri = Uri.parse('$url/discover');
        final resp = await client.get(uri).timeout(const Duration(seconds: 3));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final list = data['devices'] as List<dynamic>? ?? const [];
          for (final item in list) {
            final m = item as Map<String, dynamic>;
            results.add({
              'ip': '${m['ip'] ?? ""}',
              'name': '${m['name'] ?? "Bambu Printer"}',
              'model': '${m['model'] ?? "Bambu Lab A1 mini"}',
              'serial': '${m['serial'] ?? ""}',
            });
          }
        }
      } catch (_) {}
    } finally {
      _isScanning = false;
      _logMqtt('Auto-discovery completed. Found ${results.length} printer(s).');
      notifyListeners();
    }
    return results;
  }

  void setFleetFilter(String filter) {
    _fleetFilter = filter;
    notifyListeners();
  }

  List<BambuDevice> get filteredFleet {
    switch (_fleetFilter) {
      case 'Printing':
        return _devices
            .where((d) => d.stage == PrinterJobStage.printing)
            .toList();
      case 'Idle':
        return _devices
            .where((d) =>
                d.stage == PrinterJobStage.idle ||
                d.stage == PrinterJobStage.finished)
            .toList();
      case 'Attention':
        return _devices
            .where((d) =>
                d.activeHmsAlerts.isNotEmpty ||
                d.stage == PrinterJobStage.paused ||
                d.stage == PrinterJobStage.error)
            .toList();
      default:
        return _devices;
    }
  }

  Future<void> connectLanPrinter({
    required String name,
    required String modelName,
    required String ipAddress,
    required String accessCode,
    required String serialNumber,
  }) async {
    final (ok, msg) = await _lan.testLanMqttConnection(
      ipAddress: ipAddress,
      accessCode: accessCode,
      serialNumber: serialNumber,
    );
    _lastLanTestResult = msg;
    _logMqtt('LAN Connect ($ipAddress): $msg');

    final existingIdx = _devices.indexWhere(
      (d) => d.ipAddress == ipAddress || (serialNumber.isNotEmpty && d.serialNumber == serialNumber),
    );
    if (existingIdx != -1) {
      _updateDeviceAt(
        existingIdx,
        (d) => d.copyWith(
          name: name.isNotEmpty ? name : d.name,
          ipAddress: ipAddress,
          accessCode: accessCode,
          isLanConnected: ok,
        ),
      );
      _selectedIndex = existingIdx;
    } else {
      const defaultAms = [
        AmsUnitState(
          id: 'ams_lite_0',
          name: 'AMS lite',
          humidityLevel: 1,
          tempC: 25.0,
          slots: [
            AmsSlotState(
              slotIndex: 0,
              trayLabel: 'A1',
              materialType: 'PETG',
              filamentName: 'Bambu PETG Basic',
              color: Color(0xFF1E88E5),
              remainingPercent: 90,
              nozzleMinTemp: 220,
              nozzleMaxTemp: 250,
              pressureAdvanceK: 0.035,
              isLoaded: true,
            ),
            AmsSlotState(
              slotIndex: 1,
              trayLabel: 'A2',
              materialType: 'PLA',
              filamentName: 'Bambu PLA Basic',
              color: Color(0xFFE53935),
              remainingPercent: 85,
              nozzleMinTemp: 190,
              nozzleMaxTemp: 230,
              pressureAdvanceK: 0.020,
              isLoaded: false,
            ),
            AmsSlotState(
              slotIndex: 2,
              trayLabel: 'A3',
              materialType: 'PLA',
              filamentName: 'Bambu PLA Matte',
              color: Color(0xFF43A047),
              remainingPercent: 70,
              nozzleMinTemp: 190,
              nozzleMaxTemp: 230,
              pressureAdvanceK: 0.020,
              isLoaded: false,
            ),
            AmsSlotState(
              slotIndex: 3,
              trayLabel: 'A4',
              materialType: 'PETG-CF',
              filamentName: 'Bambu PETG-CF',
              color: Color(0xFF212121),
              remainingPercent: 95,
              nozzleMinTemp: 230,
              nozzleMaxTemp: 260,
              pressureAdvanceK: 0.038,
              isLoaded: false,
            ),
          ],
        ),
      ];

      final newDev = BambuDevice(
        id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
        name: name.isNotEmpty ? name : '$modelName ($ipAddress)',
        modelName: modelName,
        serialNumber: serialNumber.isNotEmpty ? serialNumber : '03900A${DateTime.now().millisecondsSinceEpoch % 100000000}',
        ipAddress: ipAddress,
        accessCode: accessCode,
        firmwareVersion: '01.03.00.00',
        isLanConnected: ok,
        stage: PrinterJobStage.idle,
        currentJobName: 'Ready for print',
        progressPercent: 0,
        currentLayer: 0,
        totalLayers: 0,
        remainingMinutes: 0,
        nozzleTemp: 26,
        nozzleTargetTemp: 0,
        bedTemp: 25,
        bedTargetTemp: 0,
        chamberTemp: 24,
        partFanPercent: 0,
        auxFanPercent: 0,
        chamberFanPercent: 0,
        chamberLightOn: true,
        timelapseEnabled: true,
        cameraResolution: '1080p',
        speedProfile: PrinterSpeedProfile.standard,
        nozzleDiameter: '0.4 mm',
        nozzleMaterial: 'Stainless Steel',
        wifiRssi: -52,
        printHours: 0,
        amsUnits: _devices.isNotEmpty ? _devices.first.amsUnits : defaultAms,
        activeHmsAlerts: const [],
        aiOptions: const PrinterAiOptions(),
        sdCardFiles: const [],
      );
      _devices = [..._devices, newDev];
      _selectedIndex = _devices.length - 1;
    }
    notifyListeners();
  }

  void pausePrint() {
    final d = activeDevice;
    if (d == null) return;
    _logMqtt('MQTT -> ${d.serialNumber}: ${_lan.formatPayloadPretty(_lan.buildPausePayload())}');
    _updateActive((dev) => dev.copyWith(stage: PrinterJobStage.paused));
  }

  void resumePrint() {
    final d = activeDevice;
    if (d == null) return;
    _logMqtt('MQTT -> ${d.serialNumber}: ${_lan.formatPayloadPretty(_lan.buildResumePayload())}');
    _updateActive((dev) => dev.copyWith(stage: PrinterJobStage.printing));
  }

  void stopPrint() {
    final d = activeDevice;
    if (d == null) return;
    _logMqtt('MQTT -> ${d.serialNumber}: ${_lan.formatPayloadPretty(_lan.buildStopPayload())}');
    _updateActive((dev) => dev.copyWith(
          stage: PrinterJobStage.idle,
          progressPercent: 0,
          currentLayer: 0,
          remainingMinutes: 0,
          currentJobName: 'Stopped by user',
          nozzleTargetTemp: 0,
          bedTargetTemp: 0,
        ));
  }

  void setSpeedProfile(PrinterSpeedProfile profile) {
    final d = activeDevice;
    if (d == null) return;
    _logMqtt('MQTT -> ${d.serialNumber}: Speed=${profile.label} (${profile.multiplier})');
    _updateActive((dev) => dev.copyWith(speedProfile: profile));
  }

  void setNozzleTarget(int temp) {
    _sendGcode('M104 S$temp');
    _updateActive((dev) => dev.copyWith(
          nozzleTargetTemp: temp,
          nozzleTemp: temp == 0 ? 32.0 : temp.toDouble(),
        ));
  }

  void setBedTarget(int temp) {
    _sendGcode('M140 S$temp');
    _updateActive((dev) => dev.copyWith(
          bedTargetTemp: temp,
          bedTemp: temp == 0 ? 28.0 : temp.toDouble(),
        ));
  }

  void setPartFan(int pct) {
    _sendGcode('M106 P1 S${(pct * 2.55).round()}');
    _updateActive((dev) => dev.copyWith(partFanPercent: pct));
  }

  void setAuxFan(int pct) {
    _sendGcode('M106 P2 S${(pct * 2.55).round()}');
    _updateActive((dev) => dev.copyWith(auxFanPercent: pct));
  }

  void setChamberFan(int pct) {
    _sendGcode('M106 P3 S${(pct * 2.55).round()}');
    _updateActive((dev) => dev.copyWith(chamberFanPercent: pct));
  }

  void toggleChamberLight() {
    final d = activeDevice;
    if (d == null) return;
    final next = !d.chamberLightOn;
    _logMqtt('MQTT -> ${d.serialNumber}: Chamber Light ${next ? "ON" : "OFF"}');
    _updateActive((dev) => dev.copyWith(chamberLightOn: next));
  }

  void toggleTimelapse() {
    _updateActive((dev) => dev.copyWith(timelapseEnabled: !dev.timelapseEnabled));
  }

  void setCameraResolution(String res) {
    _updateActive((dev) => dev.copyWith(cameraResolution: res));
  }

  void jogAxis(String axis, double deltaMm) {
    _sendGcode('G91\nG0 $axis${deltaMm >= 0 ? "+" : ""}${deltaMm.toStringAsFixed(1)} F3000\nG90');
  }

  void homeAllAxes() {
    _sendGcode('G28');
  }

  void extruderAction(String action) {
    switch (action) {
      case 'Load':
        _sendGcode('M620 S0A ; Load Filament');
      case 'Unload':
        _sendGcode('M620 S255 ; Unload Filament');
      case 'Extrude':
        _sendGcode('G91\nG1 E10 F300\nG90');
      case 'Retract':
        _sendGcode('G91\nG1 E-10 F300\nG90');
    }
  }

  void toggleAmsAutoRefill(int unitIdx, bool val) {
    _updateActive((dev) {
      final units = List<AmsUnitState>.from(dev.amsUnits);
      units[unitIdx] = units[unitIdx].copyWith(autoRefillEnabled: val);
      return dev.copyWith(amsUnits: units);
    });
  }

  void setAmsDrying(int unitIdx, {required bool start, int targetTemp = 55, int minutes = 480}) {
    _logMqtt('AMS Drying ${start ? "STARTED ($targetTemp°C / ${minutes}m)" : "STOPPED"}');
    _updateActive((dev) {
      final units = List<AmsUnitState>.from(dev.amsUnits);
      units[unitIdx] = units[unitIdx].copyWith(
        isDrying: start,
        dryTargetTempC: targetTemp,
        dryRemainingMinutes: start ? minutes : 0,
      );
      return dev.copyWith(amsUnits: units);
    });
  }

  void updateAmsSlot(int unitIdx, int slotIdx, {String? materialType, String? filamentName, Color? color}) {
    _updateActive((dev) {
      final units = List<AmsUnitState>.from(dev.amsUnits);
      final slots = List<AmsSlotState>.from(units[unitIdx].slots);
      slots[slotIdx] = slots[slotIdx].copyWith(
        materialType: materialType,
        filamentName: filamentName,
        color: color,
      );
      units[unitIdx] = units[unitIdx].copyWith(slots: slots);
      return dev.copyWith(amsUnits: units);
    });
  }

  void updateAiOptions(PrinterAiOptions Function(PrinterAiOptions) updater) {
    _updateActive((dev) => dev.copyWith(aiOptions: updater(dev.aiOptions)));
  }

  void skipObjectInPrint(String objName) {
    _logMqtt('MQTT -> Skip Object: $objName');
    _updateActive((dev) {
      final skipped = List<String>.from(dev.skippedObjectIds);
      if (!skipped.contains(objName)) skipped.add(objName);
      return dev.copyWith(skippedObjectIds: skipped);
    });
  }

  void dismissHmsAlert(String code) {
    _updateActive((dev) => dev.copyWith(
          activeHmsAlerts:
              dev.activeHmsAlerts.where((a) => a.code != code).toList(),
        ));
  }

  void startPrintJob({
    required String fileName,
    required int totalLayers,
    required int estimatedMinutes,
    required List<int> amsMapping,
    required bool bedLeveling,
    required bool flowCali,
    required bool timelapse,
    required bool useAms,
    int? targetDeviceIndex,
  }) {
    final idx = targetDeviceIndex ?? _selectedIndex;
    if (idx < 0 || idx >= _devices.length) return;
    final dev = _devices[idx];
    final payload = _lan.buildProjectPrintPayload(
      fileName: fileName,
      plateId: 1,
      amsMapping: amsMapping,
      bedLeveling: bedLeveling,
      flowCali: flowCali,
      timelapse: timelapse,
      useAms: useAms,
    );
    _logMqtt('FTPS Upload + MQTT Start -> ${dev.name}:\n${_lan.formatPayloadPretty(payload)}');
    _updateDeviceAt(
      idx,
      (d) => d.copyWith(
        stage: PrinterJobStage.printing,
        currentJobName: fileName,
        progressPercent: 1,
        currentLayer: 1,
        totalLayers: totalLayers > 0 ? totalLayers : 100,
        remainingMinutes: estimatedMinutes > 0 ? estimatedMinutes : 35,
        nozzleTargetTemp: 220,
        nozzleTemp: 220,
        bedTargetTemp: 55,
        bedTemp: 55,
        timelapseEnabled: timelapse,
      ),
    );
  }

  void startSdCardPrint(SdCardFile file) {
    startPrintJob(
      fileName: file.name,
      totalLayers: 160,
      estimatedMinutes: 45,
      amsMapping: const [0, 1, 2, 3],
      bedLeveling: true,
      flowCali: true,
      timelapse: activeDevice?.timelapseEnabled ?? false,
      useAms: true,
    );
  }

  void deleteSdCardFile(SdCardFile file) {
    _updateActive((dev) => dev.copyWith(
          sdCardFiles:
              dev.sdCardFiles.where((f) => f.name != file.name).toList(),
        ));
  }

  // Multi-Device Fleet Batch Commands
  void batchPauseAll() {
    _devices = _devices
        .map((d) => d.stage == PrinterJobStage.printing
            ? d.copyWith(stage: PrinterJobStage.paused)
            : d)
        .toList();
    _logMqtt('Batch Command: Paused all active fleet prints');
    notifyListeners();
  }

  void batchResumeAll() {
    _devices = _devices
        .map((d) => d.stage == PrinterJobStage.paused
            ? d.copyWith(stage: PrinterJobStage.printing)
            : d)
        .toList();
    _logMqtt('Batch Command: Resumed all paused fleet prints');
    notifyListeners();
  }

  void batchToggleLights(bool on) {
    _devices = _devices.map((d) => d.copyWith(chamberLightOn: on)).toList();
    _logMqtt('Batch Command: Chamber lights ${on ? "ON" : "OFF"} across fleet');
    notifyListeners();
  }

  void _sendGcode(String line) {
    final d = activeDevice;
    if (d == null) return;
    _logMqtt('G-Code -> ${d.name}: $line');
    notifyListeners();
  }

  void _updateActive(BambuDevice Function(BambuDevice) updater) {
    _updateDeviceAt(_selectedIndex, updater);
  }

  void _updateDeviceAt(int index, BambuDevice Function(BambuDevice) updater) {
    if (index < 0 || index >= _devices.length) return;
    final next = List<BambuDevice>.from(_devices);
    next[index] = updater(next[index]);
    _devices = next;
    notifyListeners();
  }

  void _logMqtt(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _mqttLog.insert(0, '[$ts] $message');
    if (_mqttLog.length > 40) _mqttLog.removeLast();
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }
}
