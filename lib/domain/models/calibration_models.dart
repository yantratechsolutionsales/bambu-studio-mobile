class PressureAdvanceRecord {
  const PressureAdvanceRecord({
    required this.id,
    required this.filamentName,
    required this.nozzleDiameter,
    required this.kValue,
    required this.mode,
    required this.savedAt,
  });

  final String id;
  final String filamentName;
  final String nozzleDiameter;
  final double kValue;
  final String mode; // Auto (LiDAR) / Pattern / Line
  final String savedAt;
}

enum CalibrationSuiteType {
  flowDynamics('Flow Dynamics (PA)', 'Calibrate K-factor for crisp corners & seams'),
  flowRate('Flow Rate', 'Two-pass surface extrusion ratio calibration'),
  temperatureTower('Temp Tower', 'Find optimal nozzle temperature for overhangs'),
  retraction('Retraction Test', 'Eliminate stringing and oozing'),
  maxVolumetricSpeed('Max Volumetric', 'Determine peak filament flow rate (mm³/s)'),
  vfaSpeed('VFA Speed Test', 'Identify Vertical Fine Artifacts resonance speeds'),
  machineCalibration('Machine Self-Test', 'Input shaping, motor noise & auto bed leveling');

  const CalibrationSuiteType(this.title, this.subtitle);
  final String title;
  final String subtitle;
}
