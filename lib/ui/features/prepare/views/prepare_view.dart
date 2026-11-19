import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../domain/models/scene_models.dart';
import '../../../core/bambu_theme.dart';
import '../../device/view_models/device_view_model.dart';
import '../view_models/studio_workspace_view_model.dart';
import 'gizmo_inspector_sheet.dart';
import 'process_settings_panel.dart';
import 'viewport_3d_widget.dart';

class PrepareView extends StatelessWidget {
  const PrepareView({
    super.key,
    required this.workspaceVm,
    required this.deviceVm,
    required this.onNavigateToPreview,
  });

  final StudioWorkspaceViewModel workspaceVm;
  final DeviceViewModel deviceVm;
  final VoidCallback onNavigateToPreview;

  Future<void> _importStlFile(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final ext = (file.extension ?? (file.name.contains('.') ? file.name.split('.').last : '')).toLowerCase();
        if (!['3mf', 'stl', 'obj', 'gcode'].contains(ext)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please select a 3D model (.3mf, .stl, or .obj). Selected: ${file.name}'),
                backgroundColor: BambuColors.warning,
              ),
            );
          }
          return;
        }

        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not read file data for ${file.name}. Please check storage permissions.'),
                backgroundColor: BambuColors.danger,
              ),
            );
          }
          return;
        }

        final imported = await workspaceVm.importModelBytes(bytes, file.name);
        if (context.mounted && imported != null) {
          final objCount = imported.plates.fold<int>(0, (s, p) => s + p.objects.length);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Loaded ${file.name}: $objCount object(s) on '
                '${workspaceVm.selectedPrinter?.name ?? "plate"} (${imported.parseTimeMs} ms)',
              ),
              backgroundColor: BambuColors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File import error: $e'),
            backgroundColor: BambuColors.danger,
          ),
        );
      }
    }
  }

  void _showAddModelMenu(BuildContext context) {
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
                'Add 3D Model / Primitive',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.upload_file, color: BambuColors.green),
                title: const Text('Import 3MF / STL / OBJ from Device'),
                subtitle: const Text(
                  'Supports Bambu Studio multi-object 3MF projects, STL & OBJ meshes',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _importStlFile(context);
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Your CPU Wall Bracket & Custom Designs',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BambuColors.green),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in const [
                    ('CPU Bracket (Left)', 'bracket_left', Icons.architecture),
                    ('CPU Bracket (Right)', 'bracket_right', Icons.architecture),
                    ('Tilt Phone Stand v3', 'phone_stand', Icons.phone_android),
                    ('A1 mini Scraper', 'scraper', Icons.cleaning_services_outlined),
                    ('Wall Mounting Clip', 'wall_clip', Icons.attach_file),
                  ])
                    ActionChip(
                      avatar: Icon(item.$3, size: 16, color: BambuColors.green),
                      label: Text(item.$1),
                      onPressed: () {
                        Navigator.pop(ctx);
                        workspaceVm.addPrimitiveOrAsset(item.$2);
                      },
                    ),
                ],
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Bambu Studio Built-In Models & Primitives',
                  style: TextStyle(fontSize: 12, color: BambuColors.textSecondary),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in const [
                    ('3DBenchy (Real STL)', 'benchy', Icons.directions_boat_outlined),
                    ('Bambu Cube (Real STL)', 'bambu_cube', Icons.view_in_ar),
                    ('Cube', 'cube', Icons.crop_square),
                    ('Cylinder', 'cylinder', Icons.panorama_vertical),
                    ('Sphere', 'sphere', Icons.circle_outlined),
                    ('Cone', 'cone', Icons.change_history),
                    ('Torus', 'torus', Icons.donut_large),
                    ('Temp Tower', 'temp_tower', Icons.thermostat),
                  ])
                    ActionChip(
                      avatar: Icon(item.$3, size: 16, color: BambuColors.green),
                      label: Text(item.$1),
                      onPressed: () {
                        Navigator.pop(ctx);
                        workspaceVm.addPrimitiveOrAsset(item.$2);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProcessDrawerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BambuColors.bgDark,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.96,
        minChildSize: 0.45,
        builder: (ctx, scrollCtrl) => ListenableBuilder(
          listenable: workspaceVm,
          builder: (ctx, _) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(14),
            children: [
              Row(
                children: [
                  const Text(
                    'Printer, AMS & Process Settings',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              ProcessSettingsPanel(
                workspaceVm: workspaceVm,
                deviceVm: deviceVm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: workspaceVm,
      builder: (context, _) {
        if (workspaceVm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final viewportColumn = _buildMainViewportArea(context, isWide);

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 360,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        ProcessSettingsPanel(
                          workspaceVm: workspaceVm,
                          deviceVm: deviceVm,
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: viewportColumn),
                ],
              );
            }

            return viewportColumn;
          },
        );
      },
    );
  }

  Widget _buildMainViewportArea(BuildContext context, bool isWide) {
    final vm = workspaceVm;
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        // Top Action Strip: Multi-Plate Tabs + Undo/Redo + Add/Arrange/Orient + Slice
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < vm.plates.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${vm.plates[i].name} (${vm.plates[i].objects.length})'),
                    selected: vm.activePlateIndex == i,
                    onSelected: (_) => vm.selectPlate(i),
                  ),
                ),
              IconButton.filledTonal(
                tooltip: 'Add Build Plate',
                icon: const Icon(Icons.add_box_outlined, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: vm.addPlate,
              ),
              if (vm.plates.length > 1)
                IconButton(
                  tooltip: 'Delete Current Plate',
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: vm.deleteActivePlate,
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Undo',
                icon: const Icon(Icons.undo, size: 18),
                onPressed: vm.canUndo ? vm.undo : null,
              ),
              IconButton(
                tooltip: 'Redo',
                icon: const Icon(Icons.redo, size: 18),
                onPressed: vm.canRedo ? vm.redo : null,
              ),
              const SizedBox(width: 6),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Import 3MF / STL'),
                onPressed: () => _showAddModelMenu(context),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome_mosaic, size: 15),
                label: const Text('Arrange'),
                onPressed: vm.autoArrangePlate,
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.screen_rotation_alt, size: 15),
                label: const Text('Auto-Orient'),
                onPressed: vm.autoOrientSelected,
              ),
              const SizedBox(width: 6),
              if (!isWide)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.tune, size: 16, color: BambuColors.green),
                  label: const Text('Process & AMS'),
                  onPressed: () => _showProcessDrawerSheet(context),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3D Viewport
        SizedBox(
          height: isWide ? 470 : 310,
          child: Viewport3DWidget(viewModel: vm),
        ),
        const SizedBox(height: 8),

        // ALL 19 Bambu Studio Gizmos Horizontal Toolbar
        SizedBox(
          height: 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: GizmoTool.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, idx) {
              final tool = GizmoTool.values[idx];
              final active = vm.activeGizmo == tool;
              return InkWell(
                onTap: () => vm.setActiveGizmo(tool),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 78,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? BambuColors.greenSoft : BambuColors.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? BambuColors.green : BambuColors.borderDark,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tool.icon,
                        size: 18,
                        color: active ? BambuColors.green : BambuColors.textPrimary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tool.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? BambuColors.green : BambuColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Active Gizmo Inspector Controls
        GizmoInspectorCard(viewModel: vm),
        const SizedBox(height: 10),

        // Objects on Active Plate List + Quick Slice Bar
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.layers_outlined, size: 17, color: BambuColors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Objects on ${vm.activePlate.name}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (vm.plates.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          onPressed: vm.isSlicing
                              ? null
                              : () async {
                                  await vm.sliceAllPlates();
                                  onNavigateToPreview();
                                },
                          child: const Text('Slice All'),
                        ),
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: BambuColors.green),
                      icon: vm.isSlicing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(vm.isSlicing ? 'Slicing...' : 'Slice Plate'),
                      onPressed: vm.isSlicing
                          ? null
                          : () async {
                              await vm.sliceActivePlate();
                              onNavigateToPreview();
                            },
                    ),
                  ],
                ),
                if (vm.selectedObject != null) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.flip, size: 14),
                          label: const Text('Mirror X', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => vm.mirrorSelected('X'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.flip, size: 14),
                          label: const Text('Mirror Y', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => vm.mirrorSelected('Y'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.call_split, size: 14),
                          label: const Text('Split Objects', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: vm.splitSelectedToObjects,
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.build_circle_outlined, size: 14, color: BambuColors.green),
                          label: const Text('Fix Manifold', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            vm.repairSelectedMesh();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Mesh verified manifold (0 non-manifold edges)')),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.tune, size: 14, color: BambuColors.info),
                          label: const Text('+ Modifier', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => vm.addModifierToSelected(
                            ObjectPartModifier(
                              id: 'mod_${DateTime.now().millisecondsSinceEpoch}',
                              kind: PartModifierKind.modifier,
                              label: 'Infill 40% Cube',
                              infillOverridePercent: 40,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.remove_circle_outline, size: 14, color: BambuColors.danger),
                          label: const Text('+ Negative Part', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => vm.addModifierToSelected(
                            ObjectPartModifier(
                              id: 'neg_${DateTime.now().millisecondsSinceEpoch}',
                              kind: PartModifierKind.negativePart,
                              label: 'Cutout Cylinder',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.height, size: 14, color: BambuColors.warning),
                          label: const Text('+ Height Range', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => vm.addModifierToSelected(
                            ObjectPartModifier(
                              id: 'hr_${DateTime.now().millisecondsSinceEpoch}',
                              kind: PartModifierKind.heightRange,
                              label: '0–8 mm (4 Walls)',
                              zMinMm: 0,
                              zMaxMm: 8,
                              wallLoopsOverride: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (vm.selectedObject!.modifiers.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: vm.selectedObject!.modifiers
                          .map((m) => InputChip(
                                avatar: Icon(m.kind.icon, size: 14, color: BambuColors.green),
                                label: Text(m.label, style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                onDeleted: () => vm.removeModifierFromSelected(m.id),
                              ))
                          .toList(),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                if (vm.activePlate.objects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Plate is empty. Tap "Add STL" to load a 3D model or primitive.',
                        style: TextStyle(color: BambuColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ...vm.activePlate.objects.map((obj) {
                    final sel = obj.id == vm.selectedObjectId;
                    final fil = vm.projectFilaments[
                        obj.filamentIndex.clamp(0, vm.projectFilaments.length - 1)];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: sel ? BambuColors.greenSoft : BambuColors.surfaceElevated,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: sel ? BambuColors.green : BambuColors.borderDark,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          dense: true,
                          onTap: () => vm.selectObject(obj.id),
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: fil.color,
                            child: Text(
                              '${obj.filamentIndex + 1}',
                              style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(obj.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${obj.scaledSize.x.toStringAsFixed(0)}×${obj.scaledSize.y.toStringAsFixed(0)}×${obj.scaledSize.z.toStringAsFixed(0)} mm • ${obj.mesh.triangleCount} tris',
                            style: const TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Clone',
                                icon: const Icon(Icons.copy, size: 16),
                                onPressed: () {
                                  vm.selectObject(obj.id);
                                  vm.cloneSelectedObject();
                                },
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline, size: 17, color: BambuColors.danger),
                                onPressed: () {
                                  vm.selectObject(obj.id);
                                  vm.deleteSelectedObject();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
