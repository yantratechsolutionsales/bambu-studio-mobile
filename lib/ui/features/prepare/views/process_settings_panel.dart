import 'package:material_ui/material_ui.dart';
import '../../../../domain/models/printer_profile.dart';
import '../../../../domain/models/scene_models.dart';
import '../../../core/bambu_theme.dart';
import '../../../core/shared_widgets.dart';
import '../../device/view_models/device_view_model.dart';
import '../view_models/studio_workspace_view_model.dart';

/// Complete Bambu Studio Inspector Sidebar / Sheet:
/// - Printer & Nozzle Picker (15 real BBL printers with cover images!)
/// - Plate Bed Type & Sequence
/// - AMS Project Filaments (1..16 slots + Edit Filament + Sync from AMS + Flushing Volumes Matrix!)
/// - Global vs Per-Object Process Toggle + Advanced + Real-Time Settings Search
/// - ALL 6 Official Process Tabs: Quality, Strength, Speed, Support, Others, G-Code
class ProcessSettingsPanel extends StatefulWidget {
  const ProcessSettingsPanel({
    super.key,
    required this.workspaceVm,
    required this.deviceVm,
  });

  final StudioWorkspaceViewModel workspaceVm;
  final DeviceViewModel deviceVm;

  @override
  State<ProcessSettingsPanel> createState() => _ProcessSettingsPanelState();
}

class _ProcessSettingsPanelState extends State<ProcessSettingsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.workspaceVm;
    final catalog = vm.catalog;
    if (catalog == null || vm.selectedPrinter == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final proc = vm.activeProcessSettings;
    final query = vm.settingsSearchQuery.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Printer & Nozzle Selector Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BambuSectionHeader(
                  title: 'Printer & Plate',
                  icon: Icons.precision_manufacturing_outlined,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: BambuColors.greenSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${vm.selectedNozzle} mm',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: BambuColors.green,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (vm.selectedPrinter!.coverAsset != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          vm.selectedPrinter!.coverAsset!,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.print,
                            size: 36,
                            color: BambuColors.green,
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<PrinterProfile>(
                        initialValue: vm.selectedPrinter,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Printer Model'),
                        items: catalog.printers
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    '${p.name} (${p.bedX}×${p.bedY})',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ))
                            .toList(),
                        onChanged: (p) {
                          if (p != null) vm.selectPrinter(p);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: vm.selectedNozzle,
                        decoration: const InputDecoration(labelText: 'Nozzle'),
                        items: vm.selectedPrinter!.nozzles
                            .map((n) => DropdownMenuItem(
                                  value: n,
                                  child: Text('$n mm', style: const TextStyle(fontSize: 12.5)),
                                ))
                            .toList(),
                        onChanged: (n) {
                          if (n != null) vm.selectNozzle(n);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        initialValue: const [
                          'Textured PEI Plate',
                          'Cool Plate SuperTack',
                          'Smooth PEI / High Temp Plate',
                          'Engineering Plate',
                        ].contains(vm.activePlate.bedType)
                            ? vm.activePlate.bedType
                            : 'Textured PEI Plate',
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Bed Type'),
                        items: const [
                          DropdownMenuItem(value: 'Textured PEI Plate', child: Text('Textured PEI Plate', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Cool Plate SuperTack', child: Text('Cool Plate SuperTack', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Smooth PEI / High Temp Plate', child: Text('Smooth PEI / High Temp', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Engineering Plate', child: Text('Engineering Plate', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (v) {
                          if (v != null) vm.updatePlateBedType(v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 2. AMS Project Filaments & Flushing Volumes Matrix
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BambuSectionHeader(
                  title: 'Filament (AMS ${vm.projectFilaments.length}/16)',
                  icon: Icons.palette_outlined,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Sync from active printer AMS',
                        icon: const Icon(Icons.sync, size: 17),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final dev = widget.deviceVm.activeDevice;
                          if (dev != null) {
                            vm.syncFilamentsFromDevice(dev);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Synced AMS slots from ${dev.name}')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Flushing Volumes Matrix',
                        icon: const Icon(Icons.grid_4x4, size: 17, color: BambuColors.green),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showFlushingVolumesDialog(context, vm),
                      ),
                      IconButton(
                        tooltip: 'Add Filament Slot',
                        icon: const Icon(Icons.add_circle_outline, size: 17),
                        visualDensity: VisualDensity.compact,
                        onPressed: vm.addProjectFilamentSlot,
                      ),
                      IconButton(
                        tooltip: 'Remove Last Slot',
                        icon: const Icon(Icons.remove_circle_outline, size: 17),
                        visualDensity: VisualDensity.compact,
                        onPressed: vm.removeLastFilamentSlot,
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final slot in vm.projectFilaments)
                      InkWell(
                        onTap: () => _showEditFilamentSheet(context, vm, slot),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: BambuColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: vm.selectedObject?.filamentIndex == slot.slotIndex
                                  ? BambuColors.green
                                  : BambuColors.borderDark,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: slot.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white54),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${slot.slotIndex + 1} ${slot.profile.type}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (vm.selectedObject != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Assign selected object:',
                        style: TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < vm.projectFilaments.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: ChoiceChip(
                                    label: Text('Slot ${i + 1}', style: const TextStyle(fontSize: 10.5)),
                                    visualDensity: VisualDensity.compact,
                                    selected: vm.selectedObject!.filamentIndex == i,
                                    onSelected: (_) => vm.updateSelectedObject(
                                      (o) => o.copyWith(filamentIndex: i),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 3. Process Settings (ALL 6 Tabs + Global/Objects + Advanced + Search)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BambuSectionHeader(
                  title: 'Process Settings',
                  icon: Icons.tune,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Adv', style: TextStyle(fontSize: 11)),
                      Transform.scale(
                        scale: 0.78,
                        child: Switch(
                          value: vm.showAdvancedSettings,
                          activeThumbColor: BambuColors.green,
                          onChanged: vm.setShowAdvancedSettings,
                        ),
                      ),
                    ],
                  ),
                ),

                // Global vs Objects segmented toggle
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Global'), icon: Icon(Icons.public, size: 15)),
                    ButtonSegment(value: true, label: Text('Objects'), icon: Icon(Icons.category_outlined, size: 15)),
                  ],
                  selected: {vm.editObjectProcess},
                  onSelectionChanged: (s) => vm.setEditObjectProcess(s.first),
                ),
                const SizedBox(height: 8),

                // Real BBL Process Preset Picker + Save Custom User Preset
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: [
                          ...vm.userPresets,
                          ...catalog.processes,
                        ].any((p) => p.name == proc.name)
                            ? proc.name
                            : catalog.processes.first.name,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'System / User Preset'),
                        items: [
                          ...vm.userPresets,
                          ...catalog.processes,
                        ]
                            .map((p) => DropdownMenuItem(
                                  value: p.name,
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ))
                            .toList(),
                        onChanged: (name) {
                          if (name == null) return;
                          final all = [...vm.userPresets, ...catalog.processes];
                          final found = all.firstWhere((p) => p.name == name);
                          vm.selectProcessPreset(found);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: 'Save Custom Preset',
                      icon: const Icon(Icons.save_as_outlined, size: 18),
                      onPressed: () {
                        final ctrl = TextEditingController(text: '${proc.layerHeight.toStringAsFixed(2)}mm Custom');
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: BambuColors.surfaceDark,
                            title: const Text('Save Custom Process Preset'),
                            content: TextField(
                              controller: ctrl,
                              decoration: const InputDecoration(labelText: 'Preset Name'),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              FilledButton(
                                onPressed: () {
                                  vm.saveCustomProcessPreset(ctrl.text);
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Settings Search
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search settings (e.g., infill, scarf, tree, speed)...',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                  onChanged: vm.setSettingsSearchQuery,
                ),
                const SizedBox(height: 8),

                // 6 Official Bambu Studio Tabs
                TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: BambuColors.green,
                  labelColor: BambuColors.green,
                  unselectedLabelColor: BambuColors.textSecondary,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Quality'),
                    Tab(text: 'Strength'),
                    Tab(text: 'Speed'),
                    Tab(text: 'Support'),
                    Tab(text: 'Others'),
                    Tab(text: 'G-Code'),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 360,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildQualityTab(vm, proc, query),
                      _buildStrengthTab(vm, proc, query),
                      _buildSpeedTab(vm, proc, query),
                      _buildSupportTab(vm, proc, query),
                      _buildOthersTab(vm, proc, query),
                      _buildGcodeTab(vm, proc),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _matches(String label, String query) =>
      query.isEmpty || label.toLowerCase().contains(query);

  Widget _buildQualityTab(StudioWorkspaceViewModel vm, ProcessSettings p, String q) {
    return ListView(
      children: [
        if (_matches('Layer Height', q))
          SettingSliderRow(
            label: 'Layer Height',
            value: p.layerHeight,
            min: 0.06,
            max: 0.32,
            decimals: 2,
            unit: ' mm',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(layerHeight: v)),
          ),
        if (_matches('Initial Layer Height', q))
          SettingSliderRow(
            label: 'Initial Layer Height',
            value: p.initialLayerHeight,
            min: 0.12,
            max: 0.32,
            decimals: 2,
            unit: ' mm',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(initialLayerHeight: v)),
          ),
        if (_matches('Line Width', q))
          SettingSliderRow(
            label: 'Default Line Width',
            value: p.lineWidth,
            min: 0.22,
            max: 0.85,
            decimals: 2,
            unit: ' mm',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(lineWidth: v)),
          ),
        if (_matches('Seam Position', q))
          SettingDropdownRow<String>(
            label: 'Seam Position',
            value: p.seamPosition,
            items: const ['aligned', 'nearest', 'back', 'random'],
            labelBuilder: (e) => e.toUpperCase(),
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(seamPosition: v)),
          ),
        if (_matches('Scarf Joint Seam', q))
          SettingSwitchRow(
            label: 'Scarf Joint Seam (Contour)',
            subtitle: 'Smooths Z-seam visibility on curved walls',
            value: p.scarfSeam,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(scarfSeam: v)),
          ),
        if (_matches('Wall Generator Arachne Classic', q))
          SettingDropdownRow<String>(
            label: 'Wall Generator',
            value: p.wallGenerator,
            items: const ['classic', 'arachne'],
            labelBuilder: (e) => e == 'arachne' ? 'Arachne (Variable Width)' : 'Classic',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(wallGenerator: v)),
          ),
        if (_matches('Order of Walls', q))
          SettingDropdownRow<String>(
            label: 'Order of Walls',
            value: p.wallOrder,
            items: const ['inner/outer', 'outer/inner', 'inner/outer/inner'],
            labelBuilder: (e) => e,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(wallOrder: v)),
          ),
        if (_matches('Ironing Top Surface', q))
          SettingDropdownRow<String>(
            label: 'Ironing Type',
            value: p.ironingType,
            items: const ['no_ironing', 'top_surfaces', 'topmost_surface', 'all_solid'],
            labelBuilder: (e) => e.replaceAll('_', ' '),
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(ironingType: v)),
          ),
        if (vm.showAdvancedSettings && _matches('Arc Fitting G2 G3', q))
          SettingSwitchRow(
            label: 'Arc Fitting (G2/G3)',
            value: p.enableArcFitting,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(enableArcFitting: v)),
          ),
        if (vm.showAdvancedSettings && _matches('X-Y Hole Compensation', q))
          SettingSliderRow(
            label: 'X-Y Hole Compensation',
            value: p.xyHoleCompensation,
            min: -0.5,
            max: 0.5,
            decimals: 2,
            unit: ' mm',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(xyHoleCompensation: v)),
          ),
      ],
    );
  }

  Widget _buildStrengthTab(StudioWorkspaceViewModel vm, ProcessSettings p, String q) {
    return ListView(
      children: [
        if (_matches('Wall Loops', q))
          SettingSliderRow(
            label: 'Wall Loops',
            value: p.wallLoops.toDouble(),
            min: 1,
            max: 12,
            divisions: 11,
            unit: ' loops',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(wallLoops: v.round())),
          ),
        if (_matches('Top Shell Layers', q))
          SettingSliderRow(
            label: 'Top Shell Layers',
            value: p.topShellLayers.toDouble(),
            min: 0,
            max: 12,
            divisions: 12,
            unit: ' layers',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(topShellLayers: v.round())),
          ),
        if (_matches('Bottom Shell Layers', q))
          SettingSliderRow(
            label: 'Bottom Shell Layers',
            value: p.bottomShellLayers.toDouble(),
            min: 0,
            max: 12,
            divisions: 12,
            unit: ' layers',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(bottomShellLayers: v.round())),
          ),
        if (_matches('Sparse Infill Density', q))
          SettingSliderRow(
            label: 'Sparse Infill Density',
            value: p.sparseInfillDensity.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            unit: '%',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(sparseInfillDensity: v.round())),
          ),
        if (_matches('Sparse Infill Pattern', q))
          SettingDropdownRow<String>(
            label: 'Sparse Infill Pattern',
            value: p.sparseInfillPattern,
            items: const [
              'gyroid',
              'grid',
              'cubic',
              'adaptivecubic',
              'crosshatch',
              'rectilinear',
              'honeycomb',
              'triangles',
              'lightning',
            ],
            labelBuilder: (e) => e,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(sparseInfillPattern: v)),
          ),
        if (_matches('Top Surface Pattern', q))
          SettingDropdownRow<String>(
            label: 'Top Surface Pattern',
            value: p.topSurfacePattern,
            items: const [
              'monotonicline',
              'monotonic',
              'concentric',
              'hilbertcurve',
              'octagramspiral',
            ],
            labelBuilder: (e) => e,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(topSurfacePattern: v)),
          ),
        if (_matches('Alternate Extra Wall', q))
          SettingSwitchRow(
            label: 'Alternate Extra Wall',
            value: p.alternateExtraWall,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(alternateExtraWall: v)),
          ),
        if (vm.showAdvancedSettings && _matches('Infill Wall Overlap', q))
          SettingSliderRow(
            label: 'Infill / Wall Overlap',
            value: p.infillWallOverlap.toDouble(),
            min: 0,
            max: 45,
            unit: '%',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(infillWallOverlap: v.round())),
          ),
      ],
    );
  }

  Widget _buildSpeedTab(StudioWorkspaceViewModel vm, ProcessSettings p, String q) {
    return ListView(
      children: [
        if (_matches('Initial Layer Speed', q))
          SettingSliderRow(
            label: 'Initial Layer Speed',
            value: p.initialLayerSpeed.toDouble(),
            min: 15,
            max: 150,
            unit: ' mm/s',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(initialLayerSpeed: v.round())),
          ),
        if (_matches('Outer Wall Speed', q))
          SettingSliderRow(
            label: 'Outer Wall Speed',
            value: p.outerWallSpeed.toDouble(),
            min: 40,
            max: 400,
            unit: ' mm/s',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(outerWallSpeed: v.round())),
          ),
        if (_matches('Inner Wall Speed', q))
          SettingSliderRow(
            label: 'Inner Wall Speed',
            value: p.innerWallSpeed.toDouble(),
            min: 50,
            max: 500,
            unit: ' mm/s',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(innerWallSpeed: v.round())),
          ),
        if (_matches('Sparse Infill Speed', q))
          SettingSliderRow(
            label: 'Sparse Infill Speed',
            value: p.sparseInfillSpeed.toDouble(),
            min: 50,
            max: 500,
            unit: ' mm/s',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(sparseInfillSpeed: v.round())),
          ),
        if (_matches('Top Surface Speed', q))
          SettingSliderRow(
            label: 'Top Surface Speed',
            value: p.topSurfaceSpeed.toDouble(),
            min: 40,
            max: 350,
            unit: ' mm/s',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(topSurfaceSpeed: v.round())),
          ),
        if (_matches('Travel Speed', q))
          SettingSliderRow(
            label: 'Travel Speed',
            value: p.travelSpeed.toDouble(),
            min: 150,
            max: 700,
            unit: ' mm/s',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(travelSpeed: v.round())),
          ),
        if (_matches('Slow Down For Overhangs', q))
          SettingSwitchRow(
            label: 'Slow Down for Overhangs',
            value: p.slowDownForOverhangs,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(slowDownForOverhangs: v)),
          ),
        if (vm.showAdvancedSettings && _matches('Normal Printing Acceleration', q))
          SettingSliderRow(
            label: 'Normal Acceleration',
            value: p.defaultAcceleration.toDouble(),
            min: 1000,
            max: 20000,
            unit: ' mm/s²',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(defaultAcceleration: v.round())),
          ),
      ],
    );
  }

  Widget _buildSupportTab(StudioWorkspaceViewModel vm, ProcessSettings p, String q) {
    return ListView(
      children: [
        if (_matches('Enable Support', q))
          SettingSwitchRow(
            label: 'Enable Support',
            value: p.enableSupport,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(enableSupport: v)),
          ),
        if (_matches('Support Type Tree Normal', q))
          SettingDropdownRow<String>(
            label: 'Support Type',
            value: p.supportType,
            items: const ['tree(auto)', 'tree(manual)', 'normal(auto)', 'normal(manual)'],
            labelBuilder: (e) => e,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(supportType: v)),
          ),
        if (_matches('Support Style Slim Strong Hybrid Organic', q))
          SettingDropdownRow<String>(
            label: 'Style',
            value: p.supportStyle,
            items: const ['default', 'tree_slim', 'tree_strong', 'tree_hybrid', 'tree_organic', 'grid', 'snug'],
            labelBuilder: (e) => e,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(supportStyle: v)),
          ),
        if (_matches('Threshold Angle', q))
          SettingSliderRow(
            label: 'Threshold Angle',
            value: p.supportThresholdAngle.toDouble(),
            min: 10,
            max: 60,
            unit: '°',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(supportThresholdAngle: v.round())),
          ),
        if (_matches('On Build Plate Only', q))
          SettingSwitchRow(
            label: 'On Build Plate Only',
            value: p.supportOnBuildPlateOnly,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(supportOnBuildPlateOnly: v)),
          ),
        if (_matches('Top Z Distance', q))
          SettingSliderRow(
            label: 'Top Z Distance',
            value: p.supportTopZDistance,
            min: 0.0,
            max: 0.4,
            decimals: 2,
            unit: ' mm',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(supportTopZDistance: v)),
          ),
        if (_matches('Raft Layers', q))
          SettingSliderRow(
            label: 'Raft Layers',
            value: p.raftLayers.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            unit: ' layers',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(raftLayers: v.round())),
          ),
        if (_matches('Support Interface Filament', q))
          SettingDropdownRow<int>(
            label: 'Support/Raft Interface',
            value: p.supportInterfaceFilamentSlot,
            items: [0, for (var i = 1; i <= vm.projectFilaments.length; i++) i],
            labelBuilder: (i) => i == 0 ? 'Default (Same as Model)' : 'AMS Slot $i',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(supportInterfaceFilamentSlot: v)),
          ),
      ],
    );
  }

  Widget _buildOthersTab(StudioWorkspaceViewModel vm, ProcessSettings p, String q) {
    return ListView(
      children: [
        if (_matches('Brim Type', q))
          SettingDropdownRow<String>(
            label: 'Brim Type',
            value: p.brimType,
            items: const ['auto_brim', 'outer_only', 'inner_only', 'outer_and_inner', 'no_brim'],
            labelBuilder: (e) => e.replaceAll('_', ' '),
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(brimType: v)),
          ),
        if (_matches('Brim Width', q))
          SettingSliderRow(
            label: 'Brim Width',
            value: p.brimWidth,
            min: 0,
            max: 15,
            decimals: 1,
            unit: ' mm',
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(brimWidth: v)),
          ),
        if (_matches('Enable Prime Tower', q))
          SettingSwitchRow(
            label: 'Enable Prime Tower',
            value: p.enablePrimeTower,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(enablePrimeTower: v)),
          ),
        if (_matches('Flush Into Infill', q))
          SettingSwitchRow(
            label: "Flush into Objects' Infill",
            value: p.flushIntoInfill,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(flushIntoInfill: v)),
          ),
        if (_matches('Flush Into Support', q))
          SettingSwitchRow(
            label: "Flush into Objects' Support",
            value: p.flushIntoSupport,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(flushIntoSupport: v)),
          ),
        if (_matches('Print Sequence Layer Object', q))
          SettingDropdownRow<String>(
            label: 'Print Sequence',
            value: p.printSequence,
            items: const ['by_layer', 'by_object'],
            labelBuilder: (e) => e == 'by_layer' ? 'By Layer' : 'By Object',
            onChanged: (v) {
              vm.updateActiveProcess((s) => s.copyWith(printSequence: v));
              vm.updatePlatePrintSequence(v);
            },
          ),
        if (_matches('Spiral Vase Mode', q))
          SettingSwitchRow(
            label: 'Spiral Vase Mode',
            value: p.spiralVase,
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(spiralVase: v)),
          ),
        if (_matches('Timelapse Traditional Smooth', q))
          SettingDropdownRow<String>(
            label: 'Timelapse Mode',
            value: p.timelapseType,
            items: const ['traditional', 'smooth'],
            labelBuilder: (e) => e.toUpperCase(),
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(timelapseType: v)),
          ),
        if (_matches('Fuzzy Skin', q))
          SettingDropdownRow<String>(
            label: 'Fuzzy Skin',
            value: p.fuzzySkin,
            items: const ['none', 'contour', 'all_walls'],
            labelBuilder: (e) => e.replaceAll('_', ' '),
            onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(fuzzySkin: v)),
          ),
      ],
    );
  }

  Widget _buildGcodeTab(StudioWorkspaceViewModel vm, ProcessSettings p) {
    return ListView(
      children: [
        const Text('Machine Start G-Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: p.startGcode,
          maxLines: 4,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
          onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(startGcode: v)),
        ),
        const SizedBox(height: 10),
        const Text('Machine End G-Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: p.endGcode,
          maxLines: 4,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
          onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(endGcode: v)),
        ),
        const SizedBox(height: 10),
        const Text('AMS Filament Change G-Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: p.filamentChangeGcode,
          maxLines: 3,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
          onChanged: (v) => vm.updateActiveProcess((s) => s.copyWith(filamentChangeGcode: v)),
        ),
      ],
    );
  }

  void _showEditFilamentSheet(
    BuildContext context,
    StudioWorkspaceViewModel vm,
    AmsProjectFilament slot,
  ) {
    final catalog = vm.catalog!;
    final swatchColors = [
      '#00AE42', '#2B2D42', '#ECEFF1', '#FF6D00',
      '#1976D2', '#D50000', '#FFCA28', '#8E24AA',
      '#00ACC1', '#F06292', '#8D6E63', '#000000',
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BambuColors.surfaceDark,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: vm,
          builder: (ctx, _) {
            final current = vm.projectFilaments[slot.slotIndex];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AMS Filament Slot ${slot.slotIndex + 1}',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<FilamentProfile>(
                      initialValue: catalog.filaments.any((f) => f.name == current.profile.name)
                          ? catalog.filaments.firstWhere((f) => f.name == current.profile.name)
                          : catalog.filaments.first,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Filament Profile (from BBL repo)'),
                      items: catalog.filaments
                          .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text('${f.name} (${f.type})', overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (f) {
                        if (f != null) {
                          vm.updateProjectFilament(slot.slotIndex, profile: f);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Spool Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: swatchColors.map((hex) {
                        final col = Color(int.parse('FF${hex.substring(1)}', radix: 16));
                        final selected = current.customColorHex.toUpperCase() == hex;
                        return GestureDetector(
                          onTap: () => vm.updateProjectFilament(slot.slotIndex, colorHex: hex),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? BambuColors.green : Colors.white24,
                                width: selected ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    SettingSliderRow(
                      label: 'Nozzle Temperature',
                      value: current.profile.nozzleTemp.toDouble(),
                      min: 170,
                      max: 320,
                      unit: '°C',
                      onChanged: (v) => vm.updateProjectFilament(
                        slot.slotIndex,
                        profile: current.profile.copyWith(nozzleTemp: v.round()),
                      ),
                    ),
                    SettingSliderRow(
                      label: 'Bed Temperature',
                      value: current.profile.bedTemp.toDouble(),
                      min: 0,
                      max: 120,
                      unit: '°C',
                      onChanged: (v) => vm.updateProjectFilament(
                        slot.slotIndex,
                        profile: current.profile.copyWith(bedTemp: v.round()),
                      ),
                    ),
                    SettingSliderRow(
                      label: 'Flow Ratio',
                      value: current.profile.flowRatio,
                      min: 0.80,
                      max: 1.15,
                      decimals: 2,
                      unit: '',
                      onChanged: (v) => vm.updateProjectFilament(
                        slot.slotIndex,
                        profile: current.profile.copyWith(flowRatio: v),
                      ),
                    ),
                    SettingSliderRow(
                      label: 'Max Volumetric Speed',
                      value: current.profile.maxVolumetricSpeed,
                      min: 4,
                      max: 35,
                      decimals: 1,
                      unit: ' mm³/s',
                      onChanged: (v) => vm.updateProjectFilament(
                        slot.slotIndex,
                        profile: current.profile.copyWith(maxVolumetricSpeed: v),
                      ),
                    ),
                    SettingSliderRow(
                      label: 'Pressure Advance (K-Factor)',
                      value: current.profile.pressureAdvanceK,
                      min: 0.0,
                      max: 0.12,
                      decimals: 3,
                      unit: '',
                      onChanged: (v) => vm.updateProjectFilament(
                        slot.slotIndex,
                        profile: current.profile.copyWith(pressureAdvanceK: v),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFlushingVolumesDialog(
    BuildContext context,
    StudioWorkspaceViewModel vm,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: vm,
        builder: (ctx, _) {
          final count = vm.projectFilaments.length.clamp(1, 6);
          return AlertDialog(
            backgroundColor: BambuColors.surfaceDark,
            title: const Text('Flushing Volumes (mm³)'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Calculated from BambuStudio flush_data_material_pair.json + color luminance delta.',
                    style: TextStyle(fontSize: 11.5, color: BambuColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  SettingSliderRow(
                    label: 'Flushing Multiplier',
                    value: vm.flushMultiplier,
                    min: 0.2,
                    max: 2.0,
                    decimals: 2,
                    unit: 'x',
                    onChanged: vm.setFlushMultiplier,
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 14,
                      headingRowHeight: 32,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 34,
                      columns: [
                        const DataColumn(label: Text('From \\ To', style: TextStyle(fontSize: 11))),
                        for (var c = 0; c < count; c++)
                          DataColumn(
                            label: CircleAvatar(
                              radius: 8,
                              backgroundColor: vm.projectFilaments[c].color,
                              child: Text('${c + 1}', style: const TextStyle(fontSize: 9, color: Colors.black)),
                            ),
                          ),
                      ],
                      rows: [
                        for (var r = 0; r < count; r++)
                          DataRow(cells: [
                            DataCell(Text('Slot ${r + 1}', style: const TextStyle(fontSize: 11))),
                            for (var c = 0; c < count; c++)
                              DataCell(Text(
                                r == c ? '—' : '${vm.computeFlushVolume(r, c)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: r == c ? BambuColors.textSecondary : BambuColors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              )),
                          ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }
}
