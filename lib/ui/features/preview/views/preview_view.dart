import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../../domain/models/slice_result.dart';
import '../../../core/bambu_theme.dart';
import '../../../core/shared_widgets.dart';
import '../../device/view_models/device_view_model.dart';
import '../../prepare/view_models/studio_workspace_view_model.dart';
import 'gcode_3d_canvas.dart';

class PreviewView extends StatefulWidget {
  const PreviewView({
    super.key,
    required this.workspaceVm,
    required this.deviceVm,
    required this.onNavigateToDevice,
  });

  final StudioWorkspaceViewModel workspaceVm;
  final DeviceViewModel deviceVm;
  final VoidCallback onNavigateToDevice;

  @override
  State<PreviewView> createState() => _PreviewViewState();
}

class _PreviewViewState extends State<PreviewView> {
  int _currentLayer = 9999;
  double _stepRatio = 1.0;
  bool _isPlaying = false;
  Timer? _playTimer;

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  void _togglePlayback(int maxLayer) {
    if (_isPlaying) {
      _playTimer?.cancel();
      setState(() => _isPlaying = false);
      return;
    }
    setState(() {
      _isPlaying = true;
      _stepRatio = 0.05;
    });
    _playTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      setState(() {
        _stepRatio += 0.06;
        if (_stepRatio > 1.0) {
          _stepRatio = 0.08;
          if (_currentLayer < maxLayer) {
            _currentLayer++;
          } else {
            _currentLayer = 0;
          }
        }
      });
    });
  }

  void _showSendToPrinterDialog(BuildContext context, SliceResult res) {
    if (widget.deviceVm.devices.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: BambuColors.surfaceDark,
          title: const Row(
            children: [
              Icon(Icons.print_disabled_outlined, color: BambuColors.warning),
              SizedBox(width: 8),
              Text('No Printer Connected'),
            ],
          ),
          content: const Text(
            'No Bambu Lab printer is connected yet.\n\n'
            'Please go to the Device tab to connect your Bambu Lab A1 mini via LAN-Only mode (Wi-Fi IP & Access Code) before sending print jobs.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: BambuColors.green),
              icon: const Icon(Icons.print),
              label: const Text('Go to Device Tab'),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onNavigateToDevice();
              },
            ),
          ],
        ),
      );
      return;
    }

    int selectedDevIdx = widget.deviceVm.selectedIndex >= 0 &&
            widget.deviceVm.selectedIndex < widget.deviceVm.devices.length
        ? widget.deviceVm.selectedIndex
        : 0;
    bool bedLeveling = true;
    bool flowCali = true;
    bool timelapse = true;
    bool useAms = true;
    final amsMap = List<int>.generate(
      widget.workspaceVm.projectFilaments.length,
      (i) => i % 4,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BambuColors.surfaceDark,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final devices = widget.deviceVm.devices;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.send_rounded, color: BambuColors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Send Print Job (${widget.workspaceVm.activePlate.name})',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedDevIdx.clamp(0, devices.length - 1),
                    decoration: const InputDecoration(labelText: 'Target Bambu Lab Printer'),
                    items: [
                      for (var i = 0; i < devices.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('${devices[i].name} (${devices[i].ipAddress})'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => selectedDevIdx = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'AMS Filament Mapping (Project Slot → Printer Tray)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < amsMap.length; i++)
                        Chip(
                          avatar: CircleAvatar(
                            backgroundColor: widget.workspaceVm.projectFilaments[i].color,
                            radius: 7,
                          ),
                          label: Text('P${i + 1} → A${amsMap[i] + 1}'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SettingSwitchRow(
                    label: 'Bed Leveling (ABL)',
                    value: bedLeveling,
                    onChanged: (v) => setSheetState(() => bedLeveling = v),
                  ),
                  SettingSwitchRow(
                    label: 'Flow Dynamics Calibration',
                    value: flowCali,
                    onChanged: (v) => setSheetState(() => flowCali = v),
                  ),
                  SettingSwitchRow(
                    label: 'Timelapse Recording',
                    value: timelapse,
                    onChanged: (v) => setSheetState(() => timelapse = v),
                  ),
                  SettingSwitchRow(
                    label: 'Enable AMS',
                    value: useAms,
                    onChanged: (v) => setSheetState(() => useAms = v),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: BambuColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.print),
                      label: Text('Send & Print (${res.formattedTime} • ${res.totalGrams.toStringAsFixed(1)} g)'),
                      onPressed: () {
                        widget.deviceVm.selectDevice(selectedDevIdx);
                        widget.deviceVm.startPrintJob(
                          fileName: '${widget.workspaceVm.projectMetadata.title.replaceAll(" ", "_")}.3mf',
                          totalLayers: res.layers.length,
                          estimatedMinutes: (res.totalSeconds / 60).round(),
                          amsMapping: amsMap,
                          bedLeveling: bedLeveling,
                          flowCali: flowCali,
                          timelapse: timelapse,
                          useAms: useAms,
                          targetDeviceIndex: selectedDevIdx,
                        );
                        Navigator.pop(ctx);
                        widget.onNavigateToDevice();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.workspaceVm,
      builder: (context, _) {
        final vm = widget.workspaceVm;
        final res = vm.lastSliceResult;

        if (res == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers_outlined, size: 56, color: BambuColors.green),
                  const SizedBox(height: 12),
                  Text(
                    'Plate Not Sliced Yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Slice the active plate to generate G-code toolpaths, layer inspection, filament usage, and print time breakdown.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BambuColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: BambuColors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    icon: vm.isSlicing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(vm.isSlicing ? 'Slicing...' : 'Slice Active Plate Now'),
                    onPressed: vm.isSlicing ? null : () => vm.sliceActivePlate(),
                  ),
                ],
              ),
            ),
          );
        }

        final maxLayer = (res.layers.length - 1).clamp(0, 9999);
        final activeLayerIdx = _currentLayer.clamp(0, maxLayer);
        final currentZ = res.layers.isNotEmpty ? res.layers[activeLayerIdx].zHeight : 0.0;

        return ListView(
          padding: const EdgeInsets.all(10),
          children: [
            // Top Slicing Summary & Action Bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              res.engineName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: BambuColors.green,
                              ),
                            ),
                            Text(
                              '${res.layers.length} Layers • ${res.filamentChanges} AMS Changes',
                              style: const TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Re-Slice'),
                              onPressed: vm.isSlicing ? null : () => vm.sliceActivePlate(),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: BambuColors.green),
                              icon: const Icon(Icons.print, size: 16),
                              label: const Text('Print Plate'),
                              onPressed: () => _showSendToPrinterDialog(context, res),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        BambuMetricChip(
                          label: 'Total Time',
                          value: res.formattedTime,
                          icon: Icons.schedule,
                        ),
                        BambuMetricChip(
                          label: 'Filament',
                          value: '${res.totalGrams.toStringAsFixed(1)} g',
                          color: BambuColors.info,
                          icon: Icons.scale_outlined,
                        ),
                        BambuMetricChip(
                          label: 'Length',
                          value: '${res.totalMeters.toStringAsFixed(2)} m',
                          color: BambuColors.warning,
                          icon: Icons.straighten,
                        ),
                        BambuMetricChip(
                          label: 'Est. Cost',
                          value: '\$${res.totalCostUsd.toStringAsFixed(2)}',
                          color: const Color(0xFFAB47BC),
                          icon: Icons.payments_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Color Scheme Selector (ALL 10 Bambu Studio Preview Schemes!)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final scheme in PreviewColorScheme.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(scheme.label, style: const TextStyle(fontSize: 11.5)),
                        selected: vm.previewColorScheme == scheme,
                        onSelected: (_) => vm.setPreviewColorScheme(scheme),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 3D G-Code Preview Canvas
            SizedBox(
              height: 310,
              child: Stack(
                children: [
                  GCode3DCanvas(
                    sliceResult: res,
                    filaments: vm.projectFilaments,
                    maxLayerIndex: activeLayerIdx,
                    stepRatio: _stepRatio,
                    colorScheme: vm.previewColorScheme,
                    showTravel: vm.showTravelMoves,
                    showSeams: vm.showSeams,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: BambuColors.borderDark),
                      ),
                      child: Text(
                        'Layer ${activeLayerIdx + 1}/${res.layers.length} • Z ${currentZ.toStringAsFixed(2)} mm',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Layer & Step Toolpath Scrubber Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: () => _togglePlayback(maxLayer),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SettingSliderRow(
                            label: 'Layer Height Slider',
                            value: activeLayerIdx.toDouble(),
                            min: 0,
                            max: maxLayer > 0 ? maxLayer.toDouble() : 1,
                            unit: ' / $maxLayer',
                            onChanged: (v) => setState(() => _currentLayer = v.round()),
                          ),
                        ),
                      ],
                    ),
                    SettingSliderRow(
                      label: 'Nozzle Toolpath Step',
                      value: _stepRatio * 100,
                      min: 5,
                      max: 100,
                      unit: '%',
                      onChanged: (v) => setState(() => _stepRatio = v / 100.0),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChip(
                          label: const Text('Show Travel'),
                          selected: vm.showTravelMoves,
                          onSelected: (_) => vm.toggleShowTravelMoves(),
                        ),
                        FilterChip(
                          label: const Text('Show Seams'),
                          selected: vm.showSeams,
                          onSelected: (_) => vm.toggleShowSeams(),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.add_circle_outline, size: 15, color: BambuColors.warning),
                          label: Text('+ Layer ${activeLayerIdx + 1} Pause/Swap'),
                          onPressed: () => _showAddLayerEventSheet(context, vm, activeLayerIdx),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.code, size: 16),
                          label: const Text('Inspect G-Code'),
                          onPressed: () => _showGcodeModal(context, res),
                        ),
                      ],
                    ),
                    if (vm.layerEvents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: vm.layerEvents
                            .map((ev) => InputChip(
                                  avatar: Icon(ev.type.icon, size: 14, color: ev.type.color),
                                  label: Text(
                                    'L${ev.layerIndex + 1}: ${ev.detail}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onDeleted: () => vm.removeLayerEvent(ev),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Filament Usage Breakdown per AMS Slot
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BambuSectionHeader(
                      title: 'Filament Usage Breakdown',
                      icon: Icons.pie_chart_outline,
                    ),
                    ...res.filamentUsages.map((u) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(radius: 8, backgroundColor: u.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Slot ${u.slotIndex + 1} • ${u.filamentName}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                '${u.totalGrams.toStringAsFixed(1)} g  (Model ${u.modelGrams.toStringAsFixed(1)}g • Flush ${u.flushGrams.toStringAsFixed(1)}g)',
                                style: const TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Line Type Time Breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BambuSectionHeader(
                      title: 'Feature Time Breakdown',
                      icon: Icons.bar_chart,
                    ),
                    ...res.featureBreakdown.map((f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: f.type.color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(f.type.label, style: const TextStyle(fontSize: 12)),
                                  ),
                                  Text(
                                    '${f.percentage.toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: (f.percentage / 100.0).clamp(0.0, 1.0),
                                color: f.type.color,
                                backgroundColor: BambuColors.surfaceElevated,
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddLayerEventSheet(
    BuildContext context,
    StudioWorkspaceViewModel vm,
    int layerIdx,
  ) {
    final gcodeCtrl = TextEditingController(text: 'M400 U1 ; Pause for magnet insert');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BambuColors.surfaceDark,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Event at Layer ${layerIdx + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.pause_circle_outline, color: BambuColors.warning),
                title: const Text('Add Pause (M400 U1)'),
                subtitle: const Text('Pause print head to embed magnets or nuts'),
                onTap: () {
                  vm.addLayerEvent(LayerGCodeEvent(
                    layerIndex: layerIdx,
                    type: LayerEventType.pause,
                    detail: 'Pause (M400 U1)',
                  ));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: BambuColors.green),
                title: const Text('Change Filament (AMS Slot 2)'),
                subtitle: const Text('Insert AMS M620 filament swap at this layer'),
                onTap: () {
                  vm.addLayerEvent(LayerGCodeEvent(
                    layerIndex: layerIdx,
                    type: LayerEventType.filamentChange,
                    detail: 'Swap → Slot 2',
                    filamentSlotIndex: 1,
                  ));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: gcodeCtrl,
                      decoration: const InputDecoration(labelText: 'Custom Layer G-Code'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      vm.addLayerEvent(LayerGCodeEvent(
                        layerIndex: layerIdx,
                        type: LayerEventType.customGcode,
                        detail: gcodeCtrl.text.trim(),
                      ));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Inject'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGcodeModal(BuildContext context, SliceResult res) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BambuColors.surfaceDark,
        title: const Text('Generated G-Code Preview'),
        content: SizedBox(
          width: 420,
          height: 360,
          child: SingleChildScrollView(
            child: SelectableText(
              res.gcodeText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy G-Code'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: res.gcodeText));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied G-code to clipboard')),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
