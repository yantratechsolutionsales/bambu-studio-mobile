import 'package:material_ui/material_ui.dart';
import '../../../../domain/models/device_models.dart';
import '../../../core/bambu_theme.dart';
import '../../../core/shared_widgets.dart';
import '../../device/view_models/device_view_model.dart';

class MultiDeviceView extends StatelessWidget {
  const MultiDeviceView({
    super.key,
    required this.deviceVm,
    required this.onInspectDevice,
  });

  final DeviceViewModel deviceVm;
  final VoidCallback onInspectDevice;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deviceVm,
      builder: (context, _) {
        final fleet = deviceVm.filteredFleet;
        final printingCount = deviceVm.devices
            .where((d) => d.stage == PrinterJobStage.printing)
            .length;
        final alertCount = deviceVm.devices
            .where((d) => d.activeHmsAlerts.isNotEmpty)
            .length;

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Fleet KPIs + Batch Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BambuSectionHeader(
                      title: 'Multi-Device Print Farm',
                      icon: Icons.hub_outlined,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        BambuMetricChip(label: 'Printers', value: '${deviceVm.devices.length}'),
                        BambuMetricChip(
                          label: 'Active Prints',
                          value: '$printingCount',
                          color: BambuColors.info,
                        ),
                        BambuMetricChip(
                          label: 'HMS Warnings',
                          value: '$alertCount',
                          color: alertCount > 0 ? BambuColors.warning : BambuColors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.pause_circle_outline, size: 17),
                          label: const Text('Pause All'),
                          onPressed: deviceVm.batchPauseAll,
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.play_circle_outline, size: 17),
                          label: const Text('Resume All'),
                          onPressed: deviceVm.batchResumeAll,
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.lightbulb_outline, size: 17),
                          label: const Text('All Lights ON'),
                          onPressed: () => deviceVm.batchToggleLights(true),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.lightbulb_outline, size: 17),
                          label: const Text('All Lights OFF'),
                          onPressed: () => deviceVm.batchToggleLights(false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Status Filters
            Wrap(
              spacing: 8,
              children: const ['All', 'Printing', 'Idle', 'Attention']
                  .map((f) => ChoiceChip(
                        label: Text(f),
                        selected: deviceVm.fleetFilter == f,
                        onSelected: (_) => deviceVm.setFleetFilter(f),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),

            // Responsive Fleet Grid
            LayoutBuilder(
              builder: (ctx, c) {
                final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: fleet.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 205,
                  ),
                  itemBuilder: (ctx, idx) {
                    final d = fleet[idx];
                    final realIdx = deviceVm.devices.indexOf(d);
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          deviceVm.selectDevice(realIdx);
                          onInspectDevice();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.circle, size: 10, color: d.stage.color),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      d.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    d.stage.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: d.stage.color,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${d.modelName} • ${d.ipAddress}',
                                style: const TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                d.currentJobName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: d.progressPercent / 100.0,
                                color: d.stage.color,
                                backgroundColor: BambuColors.surfaceElevated,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('${d.progressPercent}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  Text(
                                    'Nozzle ${d.nozzleTemp.round()}°C • Bed ${d.bedTemp.round()}°C',
                                    style: const TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  if (d.amsUnits.isNotEmpty)
                                    ...d.amsUnits.first.slots.map((s) => Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: CircleAvatar(radius: 6, backgroundColor: s.color),
                                        )),
                                  const Spacer(),
                                  if (d.activeHmsAlerts.isNotEmpty)
                                    const Icon(Icons.warning_amber, size: 16, color: BambuColors.warning),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Open Control →',
                                    style: TextStyle(fontSize: 11, color: BambuColors.green, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
