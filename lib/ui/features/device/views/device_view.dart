import 'package:material_ui/material_ui.dart';
import '../../../../domain/models/device_models.dart';
import '../../../core/bambu_theme.dart';
import '../../../core/shared_widgets.dart';
import '../view_models/device_view_model.dart';
import 'hms_lookup_sheet.dart';

class DeviceView extends StatefulWidget {
  const DeviceView({super.key, required this.deviceVm});

  final DeviceViewModel deviceVm;

  @override
  State<DeviceView> createState() => _DeviceViewState();
}

class _DeviceViewState extends State<DeviceView> {
  double _jogStepMm = 10.0;
  int _selectedSubTab = 0; // 0: Status & Control, 1: AMS & Dry, 2: MicroSD & AI, 3: MQTT & Info

  void _showAddLanPrinterDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'My Bambu A1 mini');
    final ipCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final snCtrl = TextEditingController();
    String model = 'Bambu Lab A1 mini';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: BambuColors.surfaceDark,
          title: const Text('Connect Bambu Printer via LAN'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Connect directly to your Bambu printer over MQTTS (port 8883) on your local Wi-Fi. Ensure "LAN Only Mode" is enabled on your printer screen.',
                  style: TextStyle(fontSize: 11.5, color: BambuColors.textSecondary),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: model,
                  decoration: const InputDecoration(labelText: 'Printer Model'),
                  items: const [
                    DropdownMenuItem(value: 'Bambu Lab A1 mini', child: Text('Bambu Lab A1 mini')),
                    DropdownMenuItem(value: 'Bambu Lab A1', child: Text('Bambu Lab A1')),
                    DropdownMenuItem(value: 'Bambu Lab P1S', child: Text('Bambu Lab P1S')),
                    DropdownMenuItem(value: 'Bambu Lab P1P', child: Text('Bambu Lab P1P')),
                    DropdownMenuItem(value: 'Bambu Lab X1 Carbon', child: Text('Bambu Lab X1 Carbon')),
                    DropdownMenuItem(value: 'Bambu Lab H2D Pro', child: Text('Bambu Lab H2D Pro')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlg(() => model = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'Printer IP Address (from A1 mini screen)', hintText: '192.168.1.xxx')),
                const SizedBox(height: 8),
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'LAN Access Code (8 digits from screen)', hintText: '8-digit PIN')),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name')),
                const SizedBox(height: 8),
                TextField(controller: snCtrl, decoration: const InputDecoration(labelText: 'Serial Number (Optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final ip = ipCtrl.text.trim();
                final code = codeCtrl.text.trim();
                if (ip.isEmpty || code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide IP Address and Access Code')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await widget.deviceVm.connectLanPrinter(
                  name: nameCtrl.text.trim(),
                  modelName: model,
                  ipAddress: ip,
                  accessCode: code,
                  serialNumber: snCtrl.text.trim(),
                );
                if (context.mounted && widget.deviceVm.lastLanTestResult != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(widget.deviceVm.lastLanTestResult!)),
                  );
                }
              },
              child: const Text('Connect LAN'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.deviceVm,
      builder: (context, _) {
        final vm = widget.deviceVm;
        final dev = vm.activeDevice;
        if (dev == null) {
          return _buildNoPrinterConnectedView(context, vm);
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (vm.demoMode)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science_outlined, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Demo Mode: Showing simulated test printers.',
                        style: TextStyle(fontSize: 11.5, color: Colors.amber),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.amber,
                      ),
                      onPressed: vm.toggleDemoMode,
                      child: const Text('Exit Demo'),
                    ),
                  ],
                ),
              ),

            // Printer Selector + Bind LAN + Disconnect + HMS Lookup
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: vm.selectedIndex >= 0 && vm.selectedIndex < vm.devices.length ? vm.selectedIndex : 0,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Active Printer',
                      prefixIcon: Icon(Icons.print, size: 18, color: BambuColors.green),
                    ),
                    items: [
                      for (var i = 0; i < vm.devices.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${vm.devices[i].name} • ${vm.devices[i].stage.label}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (i) {
                      if (i != null) vm.selectDevice(i);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Connect Another Printer (LAN)',
                  icon: const Icon(Icons.add_link),
                  onPressed: () => _showAddLanPrinterDialog(context),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Disconnect This Printer',
                  icon: const Icon(Icons.link_off, color: Colors.redAccent),
                  onPressed: () => _confirmRemovePrinter(context, vm, vm.selectedIndex),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'HMS Diagnostic Dictionary',
                  icon: const Icon(Icons.health_and_safety_outlined, color: BambuColors.warning),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: BambuColors.bgDark,
                    builder: (_) => HmsLookupSheet(hmsCatalog: vm.hmsCatalog),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Active HMS Alerts Banner
            if (dev.activeHmsAlerts.isNotEmpty)
              ...dev.activeHmsAlerts.map((alert) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BambuColors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BambuColors.warning),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: BambuColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HMS ${alert.code} (${alert.module})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: BambuColors.warning,
                                ),
                              ),
                              Text(alert.message, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => vm.dismissHmsAlert(alert.code),
                        ),
                      ],
                    ),
                  )),

            // Sub-Tab Switcher for clean Mobile ergonomics
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Control'), icon: Icon(Icons.dashboard_outlined, size: 15)),
                  ButtonSegment(value: 1, label: Text('AMS & Dry'), icon: Icon(Icons.view_column_outlined, size: 15)),
                  ButtonSegment(value: 2, label: Text('SD & AI'), icon: Icon(Icons.sd_storage_outlined, size: 15)),
                  ButtonSegment(value: 3, label: Text('LAN & Info'), icon: Icon(Icons.terminal, size: 15)),
                ],
                selected: {_selectedSubTab},
                onSelectionChanged: (s) => setState(() => _selectedSubTab = s.first),
              ),
            ),
            const SizedBox(height: 12),

            if (_selectedSubTab == 0) ...[
              _buildCameraAndJobCard(context, vm, dev),
              const SizedBox(height: 12),
              _buildThermalAndFansCard(vm, dev),
              const SizedBox(height: 12),
              _buildMotionAndExtruderCard(vm),
            ] else if (_selectedSubTab == 1) ...[
              _buildAmsPanel(context, vm, dev),
            ] else if (_selectedSubTab == 2) ...[
              _buildAiOptionsCard(vm, dev),
              const SizedBox(height: 12),
              _buildSdCardPanel(vm, dev),
            ] else ...[
              _buildDeviceInfoAndMqttPanel(vm, dev),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCameraAndJobCard(BuildContext context, DeviceViewModel vm, BambuDevice dev) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Chamber Camera Viewport
            Container(
              height: 175,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: dev.chamberLightOn
                      ? const [Color(0xFF1E262E), Color(0xFF12181D)]
                      : const [Color(0xFF0A0C0E), Color(0xFF121518)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BambuColors.borderDark),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dev.coverAsset != null)
                          Opacity(
                            opacity: dev.chamberLightOn ? 0.92 : 0.35,
                            child: Image.asset(
                              dev.coverAsset!,
                              height: 92,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.videocam_outlined,
                                size: 42,
                                color: BambuColors.green,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          'RTSPS LAN Stream • ${dev.ipAddress}:322 (${dev.cameraResolution})',
                          style: const TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: dev.stage.color),
                          const SizedBox(width: 5),
                          Text(
                            'LIVE • ${dev.stage.label}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Chamber Light',
                          icon: Icon(
                            dev.chamberLightOn ? Icons.lightbulb : Icons.lightbulb_outline,
                            size: 18,
                            color: dev.chamberLightOn ? BambuColors.warning : null,
                          ),
                          onPressed: vm.toggleChamberLight,
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          tooltip: 'Toggle Timelapse',
                          icon: Icon(
                            Icons.timelapse,
                            size: 18,
                            color: dev.timelapseEnabled ? BambuColors.green : null,
                          ),
                          onPressed: vm.toggleTimelapse,
                        ),
                        const SizedBox(width: 4),
                        ActionChip(
                          label: Text(dev.cameraResolution, style: const TextStyle(fontSize: 10.5)),
                          onPressed: () => vm.setCameraResolution(
                            dev.cameraResolution == '1080p' ? '720p' : '1080p',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Job Progress & Controls
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dev.currentJobName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        'Layer ${dev.currentLayer}/${dev.totalLayers} • ${dev.remainingMinutes} min remaining',
                        style: const TextStyle(fontSize: 11.5, color: BambuColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${dev.progressPercent}%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: BambuColors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: dev.progressPercent / 100.0,
              color: BambuColors.green,
              backgroundColor: BambuColors.surfaceElevated,
              minHeight: 7,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 12),

            // Pause / Resume / Stop / Skip Objects
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (dev.stage == PrinterJobStage.printing)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.pause, size: 17),
                    label: const Text('Pause'),
                    onPressed: vm.pausePrint,
                  )
                else if (dev.stage == PrinterJobStage.paused)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: BambuColors.green),
                    icon: const Icon(Icons.play_arrow, size: 17),
                    label: const Text('Resume'),
                    onPressed: vm.resumePrint,
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop, size: 17, color: BambuColors.danger),
                  label: const Text('Stop', style: TextStyle(color: BambuColors.danger)),
                  onPressed: dev.stage == PrinterJobStage.idle ? null : vm.stopPrint,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.block, size: 16),
                  label: Text('Skip Object (${dev.skippedObjectIds.length})'),
                  onPressed: () {
                    vm.skipObjectInPrint('Part_${dev.skippedObjectIds.length + 1}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sent Skip Object MQTT command')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Speed Profile Selector (Silent / Standard / Sport / Ludicrous)
            const Text('Print Speed Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: PrinterSpeedProfile.values.map((sp) {
                return ChoiceChip(
                  label: Text('${sp.label} (${sp.multiplier})', style: const TextStyle(fontSize: 11.5)),
                  selected: dev.speedProfile == sp,
                  onSelected: (_) => vm.setSpeedProfile(sp),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThermalAndFansCard(DeviceViewModel vm, BambuDevice dev) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BambuSectionHeader(
              title: 'Temperatures & Cooling Fans',
              icon: Icons.thermostat_outlined,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BambuMetricChip(
                  label: 'Nozzle',
                  value: '${dev.nozzleTemp.toStringAsFixed(0)}° / ${dev.nozzleTargetTemp}°C',
                  color: const Color(0xFFFF7043),
                ),
                BambuMetricChip(
                  label: 'Heatbed',
                  value: '${dev.bedTemp.toStringAsFixed(0)}° / ${dev.bedTargetTemp}°C',
                  color: BambuColors.warning,
                ),
                BambuMetricChip(
                  label: 'Chamber',
                  value: '${dev.chamberTemp.toStringAsFixed(1)}°C',
                  color: BambuColors.info,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SettingSliderRow(
              label: 'Nozzle Target Temp',
              value: dev.nozzleTargetTemp.toDouble(),
              min: 0,
              max: 300,
              unit: '°C',
              onChanged: (v) => vm.setNozzleTarget(v.round()),
            ),
            SettingSliderRow(
              label: 'Heatbed Target Temp',
              value: dev.bedTargetTemp.toDouble(),
              min: 0,
              max: 110,
              unit: '°C',
              onChanged: (v) => vm.setBedTarget(v.round()),
            ),
            SettingSliderRow(
              label: 'Part Cooling Fan',
              value: dev.partFanPercent.toDouble(),
              min: 0,
              max: 100,
              unit: '%',
              onChanged: (v) => vm.setPartFan(v.round()),
            ),
            SettingSliderRow(
              label: 'Auxiliary Part Fan',
              value: dev.auxFanPercent.toDouble(),
              min: 0,
              max: 100,
              unit: '%',
              onChanged: (v) => vm.setAuxFan(v.round()),
            ),
            SettingSliderRow(
              label: 'Chamber Exhaust Fan',
              value: dev.chamberFanPercent.toDouble(),
              min: 0,
              max: 100,
              unit: '%',
              onChanged: (v) => vm.setChamberFan(v.round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotionAndExtruderCard(DeviceViewModel vm) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BambuSectionHeader(
              title: 'Motion Axes & Extruder',
              icon: Icons.gamepad_outlined,
              trailing: SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.1, label: Text('0.1')),
                  ButtonSegment(value: 1.0, label: Text('1')),
                  ButtonSegment(value: 10.0, label: Text('10mm')),
                ],
                selected: {_jogStepMm},
                onSelectionChanged: (s) => setState(() => _jogStepMm = s.first),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // XY Pad
                Column(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: () => vm.jogAxis('Y', _jogStepMm),
                    ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.keyboard_arrow_left),
                          onPressed: () => vm.jogAxis('X', -_jogStepMm),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: BambuColors.green),
                          tooltip: 'Home All (G28)',
                          icon: const Icon(Icons.home, color: Colors.white),
                          onPressed: vm.homeAllAxes,
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.keyboard_arrow_right),
                          onPressed: () => vm.jogAxis('X', _jogStepMm),
                        ),
                      ],
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: () => vm.jogAxis('Y', -_jogStepMm),
                    ),
                    const Text('X / Y Axes', style: TextStyle(fontSize: 11, color: BambuColors.textSecondary)),
                  ],
                ),
                // Z Bed Pad
                Column(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: () => vm.jogAxis('Z', -_jogStepMm),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Z Bed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: () => vm.jogAxis('Z', _jogStepMm),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final act in const ['Load', 'Unload', 'Extrude', 'Retract'])
                  OutlinedButton(
                    onPressed: () => vm.extruderAction(act),
                    child: Text(act),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmsPanel(BuildContext context, DeviceViewModel vm, BambuDevice dev) {
    return Column(
      children: [
        for (var uIdx = 0; uIdx < dev.amsUnits.length; uIdx++) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BambuSectionHeader(
                    title: dev.amsUnits[uIdx].name,
                    icon: Icons.view_week_outlined,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.water_drop_outlined,
                          size: 15,
                          color: dev.amsUnits[uIdx].humidityLevel <= 2
                              ? BambuColors.green
                              : BambuColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Dry Index ${dev.amsUnits[uIdx].humidityLevel}/5 • ${dev.amsUnits[uIdx].tempC.toStringAsFixed(0)}°C',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dev.amsUnits[uIdx].slots.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.55,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (ctx, sIdx) {
                      final slot = dev.amsUnits[uIdx].slots[sIdx];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BambuColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: slot.isLoaded ? BambuColors.green : BambuColors.borderDark,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(radius: 9, backgroundColor: slot.color),
                                const SizedBox(width: 6),
                                Text(
                                  '${slot.trayLabel} • ${slot.materialType}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                                const Spacer(),
                                if (slot.isLoaded)
                                  const Icon(Icons.check_circle, size: 14, color: BambuColors.green),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              slot.filamentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Text(
                                  'K ${slot.pressureAdvanceK.toStringAsFixed(3)}',
                                  style: const TextStyle(fontSize: 10.5, color: BambuColors.green),
                                ),
                                const Spacer(),
                                Text(
                                  '${slot.remainingPercent}% left',
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  SettingSwitchRow(
                    label: 'AMS Auto-Refill / Backup',
                    subtitle: 'Automatically switches to identical spool when empty',
                    value: dev.amsUnits[uIdx].autoRefillEnabled,
                    onChanged: (v) => vm.toggleAmsAutoRefill(uIdx, v),
                  ),
                  const Divider(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.air, size: 18, color: BambuColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AMS Active Filament Drying', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(
                              dev.amsUnits[uIdx].isDrying
                                  ? 'Drying at ${dev.amsUnits[uIdx].dryTargetTempC}°C • ${dev.amsUnits[uIdx].dryRemainingMinutes} min left'
                                  : 'Idle — ready for PLA (55°C) or PETG/ABS (65°C) drying',
                              style: const TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => vm.setAmsDrying(
                          uIdx,
                          start: !dev.amsUnits[uIdx].isDrying,
                          targetTemp: 65,
                          minutes: 480,
                        ),
                        child: Text(dev.amsUnits[uIdx].isDrying ? 'Stop Dry' : 'Start Dry'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        // External Spool Holder (Non-AMS / TPU / Abrasive filaments)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BambuSectionHeader(
                  title: 'External Spool Holder (Side/Rear)',
                  icon: Icons.album_outlined,
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: vm.externalSpoolColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: vm.externalSpoolMaterial,
                        decoration: const InputDecoration(labelText: 'Loaded External Material'),
                        items: const [
                          DropdownMenuItem(value: 'TPU 95A', child: Text('Bambu TPU 95A (Non-AMS)')),
                          DropdownMenuItem(value: 'PAHT-CF', child: Text('Bambu PAHT-CF')),
                          DropdownMenuItem(value: 'PLA-CF', child: Text('Bambu PLA-CF')),
                          DropdownMenuItem(value: 'PETG-CF', child: Text('Bambu PETG-CF')),
                          DropdownMenuItem(value: 'PVA', child: Text('PVA Support')),
                        ],
                        onChanged: (v) {
                          if (v != null) vm.updateExternalSpool(material: v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiOptionsCard(DeviceViewModel vm, BambuDevice dev) {
    final ai = dev.aiOptions;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BambuSectionHeader(
              title: 'Print Options & AI Vision Detection',
              icon: Icons.visibility_outlined,
            ),
            SettingSwitchRow(
              label: 'First Layer Inspection (LiDAR / AI)',
              value: ai.firstLayerInspection,
              onChanged: (v) => vm.updateAiOptions((o) => o.copyWith(firstLayerInspection: v)),
            ),
            SettingSwitchRow(
              label: 'Spaghetti Detection (${ai.spaghettiSensitivity})',
              value: ai.spaghettiDetection,
              onChanged: (v) => vm.updateAiOptions((o) => o.copyWith(spaghettiDetection: v)),
            ),
            SettingSwitchRow(
              label: 'Nozzle Clumping Detection',
              value: ai.nozzleClumpingDetection,
              onChanged: (v) => vm.updateAiOptions((o) => o.copyWith(nozzleClumpingDetection: v)),
            ),
            SettingSwitchRow(
              label: 'Build Plate Localization Marker Check',
              value: ai.buildPlateMarkerDetection,
              onChanged: (v) => vm.updateAiOptions((o) => o.copyWith(buildPlateMarkerDetection: v)),
            ),
            SettingSwitchRow(
              label: 'Auto-Recovery from Step Loss',
              value: ai.autoRecoveryStepLoss,
              onChanged: (v) => vm.updateAiOptions((o) => o.copyWith(autoRecoveryStepLoss: v)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSdCardPanel(DeviceViewModel vm, BambuDevice dev) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BambuSectionHeader(
              title: 'MicroSD Card & Timelapses',
              icon: Icons.sd_card_outlined,
            ),
            if (dev.sdCardFiles.isEmpty)
              const Text('No files stored on MicroSD.', style: TextStyle(color: BambuColors.textSecondary))
            else
              ...dev.sdCardFiles.map((f) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      f.isTimelapse ? Icons.movie_outlined : Icons.view_in_ar,
                      color: f.isTimelapse ? BambuColors.info : BambuColors.green,
                    ),
                    title: Text(f.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('${f.sizeMb} MB • ${f.estimatedTime} • ${f.modifiedAt}', style: const TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!f.isTimelapse)
                          IconButton(
                            tooltip: 'Print from SD',
                            icon: const Icon(Icons.play_arrow, color: BambuColors.green),
                            onPressed: () => vm.startSdCardPrint(f),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: BambuColors.danger),
                          onPressed: () => vm.deleteSdCardFile(f),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoAndMqttPanel(DeviceViewModel vm, BambuDevice dev) {
    final gcodeInputCtrl = TextEditingController();
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BambuSectionHeader(
                  title: 'Printer Hardware, Nozzle & Firmware',
                  icon: Icons.memory,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.system_update, size: 16),
                    label: const Text('Check FW'),
                    onPressed: vm.checkFirmwareUpdate,
                  ),
                ),
                _infoRow('Model', dev.modelName),
                _infoRow('Serial Number', dev.serialNumber),
                _infoRow('LAN IP (MQTTS 8883)', dev.ipAddress),
                _infoRow('Firmware Version', dev.firmwareVersion),
                _infoRow('Update Status', vm.firmwareStatus),
                _infoRow('Hotend / Nozzle', '${dev.nozzleDiameter} • ${dev.nozzleMaterial}'),
                _infoRow('Wi-Fi Signal', '${dev.wifiRssi} dBm'),
                _infoRow('Total Print Hours', '${dev.printHours} hrs'),
                const Divider(height: 16),
                const Text('Configure Installed Nozzle / Hotend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in const ['0.2 mm', '0.4 mm', '0.6 mm', '0.8 mm'])
                      ChoiceChip(
                        label: Text(d),
                        selected: dev.nozzleDiameter.startsWith(d.substring(0, 3)),
                        onSelected: (_) => vm.updateHotendHardware(
                          diameter: d,
                          material: dev.nozzleMaterial,
                        ),
                      ),
                    for (final m in const ['Stainless Steel', 'Hardened Steel', 'Hardened Steel HF'])
                      ChoiceChip(
                        label: Text(m, style: const TextStyle(fontSize: 11)),
                        selected: dev.nozzleMaterial == m,
                        onSelected: (_) => vm.updateHotendHardware(
                          diameter: dev.nozzleDiameter,
                          material: m,
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
                  title: 'Live LAN MQTT / G-Code Console',
                  icon: Icons.terminal,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: gcodeInputCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Send G-Code (e.g. G28, M104 S220, M400)...',
                        ),
                        onSubmitted: (v) {
                          vm.sendCustomGcodeLine(v);
                          gcodeInputCtrl.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        vm.sendCustomGcodeLine(gcodeInputCtrl.text);
                        gcodeInputCtrl.clear();
                      },
                      child: const Text('Send'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 220,
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BambuColors.borderDark),
                  ),
                  child: ListView.builder(
                    itemCount: vm.mqttLog.length,
                    itemBuilder: (_, idx) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        vm.mqttLog[idx],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          color: Color(0xFFA5D6A7),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(k, style: const TextStyle(fontSize: 12.5, color: BambuColors.textSecondary)),
          const Spacer(),
          Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _stepRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BambuColors.greenSoft,
              shape: BoxShape.circle,
              border: Border.all(color: BambuColors.green, width: 1.5),
            ),
            child: Text(
              num,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BambuColors.green),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: BambuColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemovePrinter(BuildContext context, DeviceViewModel vm, int index) {
    if (index < 0 || index >= vm.devices.length) return;
    final dev = vm.devices[index];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BambuColors.surfaceDark,
        title: const Text('Disconnect Printer?'),
        content: Text('Are you sure you want to disconnect and remove "${dev.name}" (${dev.ipAddress})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              vm.removeDevice(index);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed ${dev.name}')),
              );
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPrinterConnectedView(BuildContext context, DeviceViewModel vm) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: BambuColors.greenSoft,
              shape: BoxShape.circle,
              border: Border.all(color: BambuColors.green, width: 2),
            ),
            child: const Icon(Icons.print_outlined, color: BambuColors.green, size: 40),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'Connect Your Bambu Lab Printer',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Direct LAN-Only Mode • Real-time Monitoring & Control',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: BambuColors.textSecondary),
          ),
        ),
        const SizedBox(height: 18),

        // Steps guide
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BambuColors.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BambuColors.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: BambuColors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'How to connect your Bambu Lab A1 mini:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _stepRow('1', 'On your A1 mini touch screen, tap Settings ⚙️ → WLAN.'),
              _stepRow('2', 'Turn ON the "LAN Only Mode" switch.'),
              _stepRow('3', 'Note the IP Address (e.g. 192.168.1.xxx) and 8-digit Access Code shown on screen.'),
              _stepRow('4', 'Make sure your phone or PC is connected to the same Wi-Fi.'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Connect Card
        _QuickConnectPrinterCard(
          onConnect: (name, model, ip, code, sn) async {
            await vm.connectLanPrinter(
              name: name,
              modelName: model,
              ipAddress: ip,
              accessCode: code,
              serialNumber: sn,
            );
            if (context.mounted && vm.lastLanTestResult != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(vm.lastLanTestResult!)),
              );
            }
          },
          onAutoDiscover: () async {
            final discovered = await vm.discoverPrinters();
            if (context.mounted) {
              if (discovered.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No printer found via auto-discovery. Please enter your A1 mini IP manually above.'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Found ${discovered.length} printer(s)! Select from list.'),
                    backgroundColor: BambuColors.green,
                  ),
                );
              }
            }
          },
          isScanning: vm.isScanning,
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),

        // Offline / Demo Mode Toggle
        Row(
          children: [
            const Icon(Icons.science_outlined, size: 20, color: BambuColors.textSecondary),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Demo Fleet',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    'Load simulated printers for UI testing without physical hardware',
                    style: TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                  ),
                ],
              ),
            ),
            Switch(
              value: vm.demoMode,
              activeTrackColor: BambuColors.green,
              onChanged: (_) => vm.toggleDemoMode(),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _QuickConnectPrinterCard extends StatefulWidget {
  const _QuickConnectPrinterCard({
    required this.onConnect,
    required this.onAutoDiscover,
    required this.isScanning,
  });

  final Future<void> Function(String name, String model, String ip, String code, String sn) onConnect;
  final VoidCallback onAutoDiscover;
  final bool isScanning;

  @override
  State<_QuickConnectPrinterCard> createState() => _QuickConnectPrinterCardState();
}

class _QuickConnectPrinterCardState extends State<_QuickConnectPrinterCard> {
  final _nameCtrl = TextEditingController(text: 'My Bambu A1 mini');
  final _ipCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _snCtrl = TextEditingController();
  String _selectedModel = 'Bambu Lab A1 mini';
  bool _isConnecting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _codeCtrl.dispose();
    _snCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ip = _ipCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your printer IP address (from A1 mini screen)'),
          backgroundColor: BambuColors.warning,
        ),
      );
      return;
    }
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 8-digit LAN Access Code (from A1 mini screen)'),
          backgroundColor: BambuColors.warning,
        ),
      );
      return;
    }
    setState(() => _isConnecting = true);
    try {
      await widget.onConnect(
        _nameCtrl.text.trim(),
        _selectedModel,
        ip,
        code,
        _snCtrl.text.trim(),
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BambuSectionHeader(
              title: 'Printer Connection Details',
              icon: Icons.wifi,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedModel,
              decoration: const InputDecoration(labelText: 'Printer Model'),
              items: const [
                DropdownMenuItem(value: 'Bambu Lab A1 mini', child: Text('Bambu Lab A1 mini')),
                DropdownMenuItem(value: 'Bambu Lab A1', child: Text('Bambu Lab A1')),
                DropdownMenuItem(value: 'Bambu Lab P1S', child: Text('Bambu Lab P1S')),
                DropdownMenuItem(value: 'Bambu Lab P1P', child: Text('Bambu Lab P1P')),
                DropdownMenuItem(value: 'Bambu Lab X1 Carbon', child: Text('Bambu Lab X1 Carbon')),
                DropdownMenuItem(value: 'Bambu Lab H2D Pro', child: Text('Bambu Lab H2D Pro')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedModel = v);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ipCtrl,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'Printer IP Address *',
                hintText: 'e.g. 192.168.1.150',
                prefixIcon: Icon(Icons.lan_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'LAN Access Code (8 digits) *',
                hintText: 'e.g. 12345678',
                prefixIcon: Icon(Icons.password_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Printer Custom Name',
                prefixIcon: Icon(Icons.badge_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BambuColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isConnecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(_isConnecting ? 'Connecting...' : 'Connect to Bambu Printer'),
                onPressed: _isConnecting ? null : _submit,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: widget.isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search, size: 18),
                label: Text(widget.isScanning ? 'Scanning Wi-Fi...' : 'Auto-Discover on Wi-Fi'),
                onPressed: widget.isScanning ? null : widget.onAutoDiscover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
