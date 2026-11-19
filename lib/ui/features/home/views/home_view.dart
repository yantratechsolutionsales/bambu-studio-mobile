import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/bambu_theme.dart';
import '../../../core/shared_widgets.dart';
import '../../prepare/view_models/studio_workspace_view_model.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.workspaceVm,
    required this.onNavigateToPrepare,
  });

  final StudioWorkspaceViewModel workspaceVm;
  final VoidCallback onNavigateToPrepare;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final TextEditingController _bridgeCtrl;

  @override
  void initState() {
    super.initState();
    _bridgeCtrl = TextEditingController(text: widget.workspaceVm.bridgeEndpoint);
  }

  @override
  void dispose() {
    _bridgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndOpenFile(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (files.isNotEmpty) {
        final f = files.first;
        final ext = (f.extension ?? (f.name.contains('.') ? f.name.split('.').last : '')).toLowerCase();
        if (!['3mf', 'stl', 'obj', 'gcode'].contains(ext)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please select a 3D model (.3mf, .stl, or .obj). Selected: ${f.name}'),
                backgroundColor: BambuColors.warning,
              ),
            );
          }
          return;
        }

        final bytes = await f.readAsBytes();
        if (bytes.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not read ${f.name}. Please ensure storage permissions are granted.'),
                backgroundColor: BambuColors.danger,
              ),
            );
          }
          return;
        }

        widget.onNavigateToPrepare();
        final imported = await widget.workspaceVm.importModelBytes(bytes, f.name);
        if (context.mounted && imported != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded ${f.name} successfully onto build plate'),
              backgroundColor: BambuColors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File picker error: $e'),
            backgroundColor: BambuColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.workspaceVm,
      builder: (context, _) {
        final vm = widget.workspaceVm;
        final catalog = vm.catalog;
        final bridge = vm.bridgeStatus;

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Hero Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A2E1A), Color(0xFF1A2229)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BambuColors.green.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BambuColors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bambu Studio Mobile',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              catalog != null
                                  ? '${catalog.printers.length} Printers • ${catalog.filaments.length} Filaments • ${catalog.processes.length} Presets • ${catalog.hmsCodes.length} HMS Codes'
                                  : 'Loading authentic Bambu Studio repository data...',
                              style: const TextStyle(fontSize: 11.5, color: BambuColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Toggle Dark / Light Theme',
                        icon: Icon(vm.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                        onPressed: vm.toggleTheme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: BambuColors.green),
                        icon: const Icon(Icons.add_box_outlined, size: 18),
                        label: const Text('New Project'),
                        onPressed: () {
                          vm.newEmptyProject();
                          widget.onNavigateToPrepare();
                        },
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Open STL / 3MF'),
                        onPressed: () => _pickAndOpenFile(context),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.architecture, size: 18, color: BambuColors.green),
                        label: const Text('CPU Bracket (Left)'),
                        onPressed: () async {
                          await vm.openAssetModelAsProject(
                            'assets/bambu_data/models/pc_wall_bracket_left_A1mini.3mf',
                            'pc_wall_bracket_left_A1mini.3mf',
                          );
                          widget.onNavigateToPrepare();
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.architecture, size: 18, color: BambuColors.green),
                        label: const Text('CPU Bracket (Right)'),
                        onPressed: () async {
                          await vm.openAssetModelAsProject(
                            'assets/bambu_data/models/pc_wall_bracket_right_A1mini.3mf',
                            'pc_wall_bracket_right_A1mini.3mf',
                          );
                          widget.onNavigateToPrepare();
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.directions_boat_outlined, size: 18),
                        label: const Text('Load 3DBenchy'),
                        onPressed: () async {
                          await vm.openAssetModelAsProject(
                            'assets/bambu_data/models/3DBenchy.stl',
                            '3DBenchy.stl',
                          );
                          widget.onNavigateToPrepare();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bambu Studio CLI Companion Bridge Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BambuSectionHeader(
                      title: 'Hybrid Slicer Engine & CLI Bridge',
                      icon: Icons.hub_outlined,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (bridge?.isOnline ?? false)
                              ? BambuColors.greenSoft
                              : BambuColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (bridge?.isOnline ?? false)
                                ? BambuColors.green
                                : BambuColors.borderDark,
                          ),
                        ),
                        child: Text(
                          (bridge?.isOnline ?? false) ? 'CLI Connected' : 'On-Device Mode',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: (bridge?.isOnline ?? false)
                                ? BambuColors.green
                                : BambuColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      'Connect to your PC running bambu_bridge_server.py to slice with desktop C++ libslic3r, or slice directly offline on Android/iOS.',
                      style: TextStyle(fontSize: 11.5, color: BambuColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _bridgeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'PC Bridge URL',
                              hintText: 'http://192.168.1.100:8765',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => vm.testBridgeEndpoint(_bridgeCtrl.text),
                          child: const Text('Test'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recent Projects
            const BambuSectionHeader(
              title: 'Recent Projects',
              icon: Icons.history,
            ),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: vm.recentProjects.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, idx) {
                  final rec = vm.recentProjects[idx];
                  return InkWell(
                    onTap: () async {
                      await vm.openAssetModelAsProject(rec.presetAsset, rec.name);
                      widget.onNavigateToPrepare();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 230,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BambuColors.surfaceDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: BambuColors.borderDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.insert_drive_file_outlined, size: 18, color: BambuColors.green),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  rec.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${rec.printerModel} • ${rec.plateCount} Plate(s)',
                            style: const TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${rec.estimatedTime} • ${rec.filamentGrams}g',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: BambuColors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                rec.openedAgo,
                                style: const TextStyle(fontSize: 10, color: BambuColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // MakerWorld Online Models Explorer
            const BambuSectionHeader(
              title: 'MakerWorld Featured Models',
              icon: Icons.public,
            ),
            ...vm.makerWorldModels.map((m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: BambuColors.greenSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.view_in_ar, color: BambuColors.green),
                    ),
                    title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: Text(
                      'by ${m.creator} • ${m.printTime} • ${m.filamentType} • ${m.downloads} DL',
                      style: const TextStyle(fontSize: 11.5, color: BambuColors.textSecondary),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        await vm.addPrimitiveOrAsset(m.primitiveType);
                        widget.onNavigateToPrepare();
                      },
                      child: const Text('Open'),
                    ),
                  ),
                )),
            const SizedBox(height: 10),

            // Daily Tip (Matching BambuStudio/resources/dailytip)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates_outlined, color: BambuColors.warning, size: 26),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bambu Studio Daily Tip',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Enable "Scarf Joint Seam" in Process → Quality and "Flush into Objects\' Infill" in Others to cut AMS purge waste by up to 40%.',
                            style: TextStyle(fontSize: 11.5, color: BambuColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
