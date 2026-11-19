import 'package:material_ui/material_ui.dart';
import '../../../../domain/models/calibration_models.dart';
import '../../../core/bambu_theme.dart';
import '../../../core/shared_widgets.dart';
import '../../prepare/view_models/studio_workspace_view_model.dart';
import '../view_models/calibration_view_model.dart';

class CalibrationView extends StatelessWidget {
  const CalibrationView({
    super.key,
    required this.calibVm,
    required this.workspaceVm,
    required this.onLoadModelToPrepare,
  });

  final CalibrationViewModel calibVm;
  final StudioWorkspaceViewModel workspaceVm;
  final VoidCallback onLoadModelToPrepare;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: calibVm,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // All 6 Official Bambu Studio Calibration Suites selector
            const BambuSectionHeader(
              title: 'Bambu Studio Calibration Center',
              icon: Icons.science_outlined,
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: CalibrationSuiteType.values.map((suite) {
                  final sel = calibVm.activeSuite == suite;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(suite.title),
                      selected: sel,
                      onSelected: (_) => calibVm.selectSuite(suite),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            _buildActiveSuiteCard(context),
          ],
        );
      },
    );
  }

  Widget _buildActiveSuiteCard(BuildContext context) {
    switch (calibVm.activeSuite) {
      case CalibrationSuiteType.flowDynamics:
        return Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BambuSectionHeader(
                      title: 'Flow Dynamics Calibration (Pressure Advance K)',
                      icon: Icons.speed,
                    ),
                    const Text(
                      'Calibrates the extrusion pressure advance factor K to eliminate bulging corners and under-extrusion after retractions.',
                      style: TextStyle(fontSize: 12, color: BambuColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Auto (LiDAR)', label: Text('Auto LiDAR')),
                        ButtonSegment(value: 'Pattern', label: Text('Pattern')),
                        ButtonSegment(value: 'Line', label: Text('Line')),
                      ],
                      selected: {calibVm.paMode},
                      onSelectionChanged: (s) => calibVm.setPaMode(s.first),
                    ),
                    const SizedBox(height: 10),
                    SettingSliderRow(
                      label: 'Start K',
                      value: calibVm.paStartK,
                      min: 0.0,
                      max: 0.05,
                      decimals: 3,
                      unit: '',
                      onChanged: (v) => calibVm.setPaParams(start: v),
                    ),
                    SettingSliderRow(
                      label: 'End K',
                      value: calibVm.paEndK,
                      min: 0.04,
                      max: 0.20,
                      decimals: 3,
                      unit: '',
                      onChanged: (v) => calibVm.setPaParams(end: v),
                    ),
                    SettingSliderRow(
                      label: 'Best Observed K-Factor',
                      value: calibVm.paSelectedK,
                      min: 0.0,
                      max: 0.15,
                      decimals: 3,
                      unit: '',
                      onChanged: (v) => calibVm.setPaParams(selected: v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: BambuColors.green),
                            icon: const Icon(Icons.save, size: 17),
                            label: const Text('Save K-Value to AMS Profile'),
                            onPressed: () {
                              final fil = workspaceVm.projectFilaments.first;
                              calibVm.savePaRecord(fil.profile.name, workspaceVm.selectedNozzle);
                              workspaceVm.updateProjectFilament(
                                0,
                                profile: fil.profile.copyWith(pressureAdvanceK: calibVm.paSelectedK),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Saved K=${calibVm.paSelectedK.toStringAsFixed(3)} to Slot 1')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BambuSectionHeader(
                      title: 'Manage PA Calibration History',
                      icon: Icons.history,
                    ),
                    ...calibVm.paHistory.map((r) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${r.filamentName} (${r.nozzleDiameter})', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${r.mode} • ${r.savedAt}', style: const TextStyle(fontSize: 11)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: BambuColors.greenSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'K = ${r.kValue.toStringAsFixed(3)}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: BambuColors.green),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
        );

      case CalibrationSuiteType.flowRate:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BambuSectionHeader(
                  title: 'Flow Rate Two-Pass Calibration',
                  icon: Icons.waves,
                ),
                SettingSliderRow(
                  label: 'Current Filament Flow Ratio',
                  value: calibVm.currentFlowRatio,
                  min: 0.85,
                  max: 1.10,
                  decimals: 2,
                  unit: '',
                  onChanged: (v) => calibVm.setFlowParams(baseFlow: v),
                ),
                const SizedBox(height: 6),
                const Text('Pass 1 — Select Smoothest Tile (-20% to +20%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [-20, -15, -10, -5, 0, 5, 10, 15, 20].map((v) {
                    return ChoiceChip(
                      label: Text('${v >= 0 ? "+" : ""}$v%'),
                      selected: calibVm.flowPass1Offset == v,
                      onSelected: (_) => calibVm.setFlowParams(pass1: v),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Pass 2 — Fine Tune (-9% to 0%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [-9, -8, -7, -6, -5, -4, -3, -2, -1, 0].map((v) {
                    return ChoiceChip(
                      label: Text('$v%'),
                      selected: calibVm.flowPass2Offset == v,
                      onSelected: (_) => calibVm.setFlowParams(pass2: v),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                BambuMetricChip(
                  label: 'New Calibrated Flow Ratio',
                  value: calibVm.calculatedFlowPass2.toStringAsFixed(4),
                  icon: Icons.check_circle_outline,
                ),
              ],
            ),
          ),
        );

      case CalibrationSuiteType.temperatureTower:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BambuSectionHeader(
                  title: 'Temperature Tower Generator',
                  icon: Icons.thermostat,
                ),
                SettingSliderRow(
                  label: 'Start Temperature (Bottom)',
                  value: calibVm.tempStart.toDouble(),
                  min: 190,
                  max: 300,
                  unit: '°C',
                  onChanged: (v) => calibVm.setTempTowerParams(start: v.round()),
                ),
                SettingSliderRow(
                  label: 'End Temperature (Top)',
                  value: calibVm.tempEnd.toDouble(),
                  min: 170,
                  max: 280,
                  unit: '°C',
                  onChanged: (v) => calibVm.setTempTowerParams(end: v.round()),
                ),
                SettingSliderRow(
                  label: 'Step Interval',
                  value: calibVm.tempStep.toDouble(),
                  min: 5,
                  max: 15,
                  divisions: 2,
                  unit: '°C',
                  onChanged: (v) => calibVm.setTempTowerParams(step: v.round()),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: BambuColors.green),
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('Generate Temp Tower on Plate 1'),
                  onPressed: () async {
                    await workspaceVm.addPrimitiveOrAsset('temp_tower');
                    onLoadModelToPrepare();
                  },
                ),
              ],
            ),
          ),
        );

      case CalibrationSuiteType.retraction:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BambuSectionHeader(
                  title: 'Retraction Length Calibration',
                  icon: Icons.compress,
                ),
                SettingSliderRow(
                  label: 'Start Retraction Length',
                  value: calibVm.retractStart,
                  min: 0.0,
                  max: 1.5,
                  decimals: 1,
                  unit: ' mm',
                  onChanged: (v) => calibVm.setRetractionParams(start: v),
                ),
                SettingSliderRow(
                  label: 'End Retraction Length',
                  value: calibVm.retractEnd,
                  min: 0.4,
                  max: 4.0,
                  decimals: 1,
                  unit: ' mm',
                  onChanged: (v) => calibVm.setRetractionParams(end: v),
                ),
                SettingSliderRow(
                  label: 'Step Size',
                  value: calibVm.retractStep,
                  min: 0.05,
                  max: 0.5,
                  decimals: 2,
                  unit: ' mm',
                  onChanged: (v) => calibVm.setRetractionParams(step: v),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Load Retraction Towers to Prepare'),
                  onPressed: () async {
                    await workspaceVm.addPrimitiveOrAsset('cone');
                    onLoadModelToPrepare();
                  },
                ),
              ],
            ),
          ),
        );

      case CalibrationSuiteType.maxVolumetricSpeed:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BambuSectionHeader(
                  title: 'Max Volumetric Flow Speed Calculator',
                  icon: Icons.bolt,
                ),
                SettingSliderRow(
                  label: 'Start Flow Rate',
                  value: calibVm.volStart,
                  min: 2,
                  max: 15,
                  decimals: 1,
                  unit: ' mm³/s',
                  onChanged: (v) => calibVm.setVolumetricParams(start: v),
                ),
                SettingSliderRow(
                  label: 'Step per mm Height',
                  value: calibVm.volStep,
                  min: 0.2,
                  max: 1.5,
                  decimals: 2,
                  unit: ' mm³/s/mm',
                  onChanged: (v) => calibVm.setVolumetricParams(step: v),
                ),
                SettingSliderRow(
                  label: 'Measured Defect Height (Z)',
                  value: calibVm.volMeasuredHeightMm,
                  min: 1,
                  max: 60,
                  decimals: 1,
                  unit: ' mm',
                  onChanged: (v) => calibVm.setVolumetricParams(height: v),
                ),
                const SizedBox(height: 8),
                BambuMetricChip(
                  label: 'Safe Max Volumetric Speed (90%)',
                  value: '${(calibVm.calculatedMaxVolSpeed * 0.9).toStringAsFixed(1)} mm³/s',
                  icon: Icons.speed,
                ),
              ],
            ),
          ),
        );

      case CalibrationSuiteType.vfaSpeed:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BambuSectionHeader(
                  title: 'VFA (Vertical Fine Artifacts) Speed Test',
                  icon: Icons.graphic_eq,
                ),
                const Text(
                  'Sweeps outer-wall print speeds across stepped bands to identify belt/motor resonance zones (matches BambuStudio/resources/calib/vfa).',
                  style: TextStyle(fontSize: 12, color: BambuColors.textSecondary),
                ),
                const SizedBox(height: 8),
                SettingSliderRow(
                  label: 'Start Speed',
                  value: calibVm.vfaStartSpeed.toDouble(),
                  min: 30,
                  max: 120,
                  unit: ' mm/s',
                  onChanged: (v) => calibVm.setVfaParams(start: v.round()),
                ),
                SettingSliderRow(
                  label: 'End Speed',
                  value: calibVm.vfaEndSpeed.toDouble(),
                  min: 140,
                  max: 350,
                  unit: ' mm/s',
                  onChanged: (v) => calibVm.setVfaParams(end: v.round()),
                ),
                SettingSliderRow(
                  label: 'Step Increment',
                  value: calibVm.vfaStepSpeed.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 5,
                  unit: ' mm/s',
                  onChanged: (v) => calibVm.setVfaParams(step: v.round()),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: BambuColors.green),
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('Generate VFA Speed Tower on Plate 1'),
                  onPressed: () async {
                    await workspaceVm.addPrimitiveOrAsset('temp_tower');
                    onLoadModelToPrepare();
                  },
                ),
              ],
            ),
          ),
        );

      case CalibrationSuiteType.machineCalibration:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BambuSectionHeader(
                  title: 'Machine Self-Test & Input Shaping',
                  icon: Icons.settings_suggest_outlined,
                ),
                SettingSwitchRow(
                  label: 'Vibration Compensation (Input Shaping)',
                  subtitle: 'Sweeps X/Y resonance frequencies to prevent ringing/VFA',
                  value: calibVm.calibVibration,
                  onChanged: (v) => calibVm.setSelfTestToggle(vib: v),
                ),
                SettingSwitchRow(
                  label: 'Auto Bed Leveling (36-Point Mesh)',
                  value: calibVm.calibAutoBedLevel,
                  onChanged: (v) => calibVm.setSelfTestToggle(bed: v),
                ),
                SettingSwitchRow(
                  label: 'Active Motor Noise Cancellation',
                  value: calibVm.calibMotorNoise,
                  onChanged: (v) => calibVm.setSelfTestToggle(noise: v),
                ),
                SettingSwitchRow(
                  label: 'Micro LiDAR Camera Calibration',
                  value: calibVm.calibLidarFlow,
                  onChanged: (v) => calibVm.setSelfTestToggle(lidar: v),
                ),
                const SizedBox(height: 10),
                if (calibVm.isRunningSelfTest || calibVm.selfTestProgress > 0) ...[
                  LinearProgressIndicator(
                    value: calibVm.selfTestProgress,
                    color: BambuColors.green,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    calibVm.isRunningSelfTest
                        ? 'Running printer calibration sweep... ${(calibVm.selfTestProgress * 100).round()}%'
                        : 'Calibration complete! Resonance & mesh saved to printer.',
                    style: const TextStyle(fontSize: 12, color: BambuColors.green),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: BambuColors.green),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(calibVm.isRunningSelfTest ? 'Calibrating...' : 'Start Full Calibration'),
                    onPressed: calibVm.isRunningSelfTest ? null : calibVm.runMachineSelfTest,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
