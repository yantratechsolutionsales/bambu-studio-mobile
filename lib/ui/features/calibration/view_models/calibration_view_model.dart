import 'package:material_ui/material_ui.dart';
import '../../../../domain/models/calibration_models.dart';

class CalibrationViewModel extends ChangeNotifier {
  CalibrationSuiteType _activeSuite = CalibrationSuiteType.flowDynamics;
  CalibrationSuiteType get activeSuite => _activeSuite;

  // 1. Flow Dynamics (Pressure Advance K-Factor)
  String _paMode = 'Pattern'; // Auto (LiDAR) / Pattern / Line
  String get paMode => _paMode;
  double _paStartK = 0.0;
  double get paStartK => _paStartK;
  double _paEndK = 0.10;
  double get paEndK => _paEndK;
  double _paStepK = 0.005;
  double get paStepK => _paStepK;
  double _paSelectedK = 0.020;
  double get paSelectedK => _paSelectedK;

  final List<PressureAdvanceRecord> _paHistory = [
    const PressureAdvanceRecord(
      id: 'pa_1',
      filamentName: 'Bambu PLA Basic',
      nozzleDiameter: '0.4 mm',
      kValue: 0.020,
      mode: 'Auto (LiDAR)',
      savedAt: 'Today 14:22',
    ),
    const PressureAdvanceRecord(
      id: 'pa_2',
      filamentName: 'Bambu PETG HF',
      nozzleDiameter: '0.4 mm',
      kValue: 0.032,
      mode: 'Pattern',
      savedAt: 'Yesterday',
    ),
    const PressureAdvanceRecord(
      id: 'pa_3',
      filamentName: 'Bambu ABS',
      nozzleDiameter: '0.4 mm',
      kValue: 0.025,
      mode: 'Line',
      savedAt: '3 days ago',
    ),
  ];
  List<PressureAdvanceRecord> get paHistory => List.unmodifiable(_paHistory);

  // 2. Flow Rate (Pass 1 & Pass 2)
  double _currentFlowRatio = 0.98;
  double get currentFlowRatio => _currentFlowRatio;
  int _flowPass1Offset = 0; // -20 to +20 step 5
  int get flowPass1Offset => _flowPass1Offset;
  int _flowPass2Offset = -2; // -9 to 0 step 1
  int get flowPass2Offset => _flowPass2Offset;

  double get calculatedFlowPass1 =>
      _currentFlowRatio * (100 + _flowPass1Offset) / 100.0;
  double get calculatedFlowPass2 =>
      calculatedFlowPass1 * (100 + _flowPass2Offset) / 100.0;

  // 3. Temperature Tower
  int _tempStart = 230;
  int get tempStart => _tempStart;
  int _tempEnd = 190;
  int get tempEnd => _tempEnd;
  int _tempStep = 5;
  int get tempStep => _tempStep;

  // 4. Retraction Test
  double _retractStart = 0.0;
  double get retractStart => _retractStart;
  double _retractEnd = 2.0;
  double get retractEnd => _retractEnd;
  double _retractStep = 0.1;
  double get retractStep => _retractStep;

  // 5. Max Volumetric Speed
  double _volStart = 5.0;
  double get volStart => _volStart;
  double _volEnd = 25.0;
  double get volEnd => _volEnd;
  double _volStep = 0.5;
  double get volStep => _volStep;
  double _volMeasuredHeightMm = 28.0;
  double get volMeasuredHeightMm => _volMeasuredHeightMm;
  double get calculatedMaxVolSpeed =>
      _volStart + (_volMeasuredHeightMm * _volStep);

  // 5b. VFA (Vertical Fine Artifacts) Speed Sweep
  int _vfaStartSpeed = 40;
  int get vfaStartSpeed => _vfaStartSpeed;
  int _vfaEndSpeed = 240;
  int get vfaEndSpeed => _vfaEndSpeed;
  int _vfaStepSpeed = 10;
  int get vfaStepSpeed => _vfaStepSpeed;

  void setVfaParams({int? start, int? end, int? step}) {
    if (start != null) _vfaStartSpeed = start;
    if (end != null) _vfaEndSpeed = end;
    if (step != null) _vfaStepSpeed = step;
    notifyListeners();
  }

  // 6. Machine Self-Test Calibration
  bool _calibVibration = true;
  bool get calibVibration => _calibVibration;
  bool _calibAutoBedLevel = true;
  bool get calibAutoBedLevel => _calibAutoBedLevel;
  bool _calibMotorNoise = true;
  bool get calibMotorNoise => _calibMotorNoise;
  bool _calibLidarFlow = true;
  bool get calibLidarFlow => _calibLidarFlow;
  bool _isRunningSelfTest = false;
  bool get isRunningSelfTest => _isRunningSelfTest;
  double _selfTestProgress = 0.0;
  double get selfTestProgress => _selfTestProgress;

  void selectSuite(CalibrationSuiteType suite) {
    _activeSuite = suite;
    notifyListeners();
  }

  void setPaMode(String mode) {
    _paMode = mode;
    notifyListeners();
  }

  void setPaParams({double? start, double? end, double? step, double? selected}) {
    if (start != null) _paStartK = start;
    if (end != null) _paEndK = end;
    if (step != null) _paStepK = step;
    if (selected != null) _paSelectedK = selected;
    notifyListeners();
  }

  void savePaRecord(String filamentName, String nozzle) {
    _paHistory.insert(
      0,
      PressureAdvanceRecord(
        id: 'pa_${DateTime.now().millisecondsSinceEpoch}',
        filamentName: filamentName,
        nozzleDiameter: '$nozzle mm',
        kValue: _paSelectedK,
        mode: _paMode,
        savedAt: 'Just now',
      ),
    );
    notifyListeners();
  }

  void setFlowParams({double? baseFlow, int? pass1, int? pass2}) {
    if (baseFlow != null) _currentFlowRatio = baseFlow;
    if (pass1 != null) _flowPass1Offset = pass1;
    if (pass2 != null) _flowPass2Offset = pass2;
    notifyListeners();
  }

  void setTempTowerParams({int? start, int? end, int? step}) {
    if (start != null) _tempStart = start;
    if (end != null) _tempEnd = end;
    if (step != null) _tempStep = step;
    notifyListeners();
  }

  void setRetractionParams({double? start, double? end, double? step}) {
    if (start != null) _retractStart = start;
    if (end != null) _retractEnd = end;
    if (step != null) _retractStep = step;
    notifyListeners();
  }

  void setVolumetricParams({double? start, double? end, double? step, double? height}) {
    if (start != null) _volStart = start;
    if (end != null) _volEnd = end;
    if (step != null) _volStep = step;
    if (height != null) _volMeasuredHeightMm = height;
    notifyListeners();
  }

  void setSelfTestToggle({bool? vib, bool? bed, bool? noise, bool? lidar}) {
    if (vib != null) _calibVibration = vib;
    if (bed != null) _calibAutoBedLevel = bed;
    if (noise != null) _calibMotorNoise = noise;
    if (lidar != null) _calibLidarFlow = lidar;
    notifyListeners();
  }

  Future<void> runMachineSelfTest() async {
    if (_isRunningSelfTest) return;
    _isRunningSelfTest = true;
    _selfTestProgress = 0.05;
    notifyListeners();
    for (var i = 1; i <= 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      _selfTestProgress = i / 10.0;
      notifyListeners();
    }
    _isRunningSelfTest = false;
    notifyListeners();
  }
}
