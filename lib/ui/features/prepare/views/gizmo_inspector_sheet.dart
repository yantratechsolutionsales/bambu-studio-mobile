import 'package:material_ui/material_ui.dart';
import '../../../../domain/models/scene_models.dart';
import '../../../core/bambu_theme.dart';
import '../../../core/shared_widgets.dart';
import '../view_models/studio_workspace_view_model.dart';

/// Interactive control panel for ALL 19 Bambu Studio 3D Gizmos.
class GizmoInspectorCard extends StatefulWidget {
  const GizmoInspectorCard({super.key, required this.viewModel});

  final StudioWorkspaceViewModel viewModel;

  @override
  State<GizmoInspectorCard> createState() => _GizmoInspectorCardState();
}

class _GizmoInspectorCardState extends State<GizmoInspectorCard> {
  final TextEditingController _textCtrl = TextEditingController(text: 'BAMBU');
  double _simplifyRatio = 0.6;
  bool _uniformScale = true;
  bool _textDeboss = false;
  String _selectedSvg = 'Bambu Logo Badge';

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final tool = vm.activeGizmo;
    final sel = vm.selectedObject;

    if (tool == GizmoTool.select) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BambuColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BambuColors.green.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tool.icon, size: 17, color: BambuColors.green),
              const SizedBox(width: 6),
              Text(
                tool.label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tool.tooltip,
                  style: const TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => vm.setActiveGizmo(GizmoTool.select),
              ),
            ],
          ),
          const Divider(height: 14),
          if (sel == null && tool != GizmoTool.assembly)
            const Text(
              'Select an object on the build plate first.',
              style: TextStyle(color: BambuColors.textSecondary, fontSize: 12),
            )
          else
            _buildToolControls(context, vm, tool, sel),
        ],
      ),
    );
  }

  Widget _buildToolControls(
    BuildContext context,
    StudioWorkspaceViewModel vm,
    GizmoTool tool,
    SceneObject? sel,
  ) {
    switch (tool) {
      case GizmoTool.move:
        return Column(
          children: [
            SettingSliderRow(
              label: 'Position X',
              value: sel!.position.x,
              min: -110,
              max: 110,
              unit: ' mm',
              decimals: 1,
              onChanged: (v) => vm.updateSelectedObject(
                (o) => o.copyWith(position: Vec3(v, o.position.y, o.position.z)),
              ),
            ),
            SettingSliderRow(
              label: 'Position Y',
              value: sel.position.y,
              min: -110,
              max: 110,
              unit: ' mm',
              decimals: 1,
              onChanged: (v) => vm.updateSelectedObject(
                (o) => o.copyWith(position: Vec3(o.position.x, v, o.position.z)),
              ),
            ),
            SettingSliderRow(
              label: 'Elevation Z',
              value: sel.position.z,
              min: 0,
              max: 120,
              unit: ' mm',
              decimals: 1,
              onChanged: (v) => vm.updateSelectedObject(
                (o) => o.copyWith(position: Vec3(o.position.x, o.position.y, v)),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.center_focus_weak, size: 16),
                label: const Text('Center on Plate'),
                onPressed: () => vm.updateSelectedObject(
                  (o) => o.copyWith(position: const Vec3(0, 0, 0)),
                  recordUndo: true,
                ),
              ),
            ),
          ],
        );

      case GizmoTool.rotate:
        return Column(
          children: [
            SettingSliderRow(
              label: 'Rotate X',
              value: sel!.rotationDeg.x,
              min: -180,
              max: 180,
              unit: '°',
              onChanged: (v) => vm.updateSelectedObject(
                (o) => o.copyWith(rotationDeg: Vec3(v, o.rotationDeg.y, o.rotationDeg.z)),
              ),
            ),
            SettingSliderRow(
              label: 'Rotate Y',
              value: sel.rotationDeg.y,
              min: -180,
              max: 180,
              unit: '°',
              onChanged: (v) => vm.updateSelectedObject(
                (o) => o.copyWith(rotationDeg: Vec3(o.rotationDeg.x, v, o.rotationDeg.z)),
              ),
            ),
            SettingSliderRow(
              label: 'Rotate Z',
              value: sel.rotationDeg.z,
              min: -180,
              max: 180,
              unit: '°',
              onChanged: (v) => vm.updateSelectedObject(
                (o) => o.copyWith(rotationDeg: Vec3(o.rotationDeg.x, o.rotationDeg.y, v)),
              ),
            ),
          ],
        );

      case GizmoTool.scale:
        return Column(
          children: [
            SettingSwitchRow(
              label: 'Uniform Scale',
              value: _uniformScale,
              onChanged: (v) => setState(() => _uniformScale = v),
            ),
            SettingSliderRow(
              label: _uniformScale ? 'Scale (X/Y/Z)' : 'Scale X',
              value: sel!.scale.x * 100,
              min: 20,
              max: 300,
              unit: '%',
              onChanged: (v) {
                final f = v / 100.0;
                vm.updateSelectedObject((o) => o.copyWith(
                      scale: _uniformScale
                          ? Vec3(f, f, f)
                          : Vec3(f, o.scale.y, o.scale.z),
                    ));
              },
            ),
            if (!_uniformScale) ...[
              SettingSliderRow(
                label: 'Scale Y',
                value: sel.scale.y * 100,
                min: 20,
                max: 300,
                unit: '%',
                onChanged: (v) => vm.updateSelectedObject(
                  (o) => o.copyWith(scale: Vec3(o.scale.x, v / 100.0, o.scale.z)),
                ),
              ),
              SettingSliderRow(
                label: 'Scale Z',
                value: sel.scale.z * 100,
                min: 20,
                max: 300,
                unit: '%',
                onChanged: (v) => vm.updateSelectedObject(
                  (o) => o.copyWith(scale: Vec3(o.scale.x, o.scale.y, v / 100.0)),
                ),
              ),
            ],
          ],
        );

      case GizmoTool.layOnFace:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final face in [
              ('Bottom (0°)', const Vec3(0, 0, 0)),
              ('Top (180°)', const Vec3(180, 0, 0)),
              ('Front (+90° X)', const Vec3(90, 0, 0)),
              ('Back (-90° X)', const Vec3(-90, 0, 0)),
              ('Left (+90° Y)', const Vec3(0, 90, 0)),
              ('Right (-90° Y)', const Vec3(0, -90, 0)),
            ])
              ActionChip(
                label: Text(face.$1),
                onPressed: () => vm.updateSelectedObject(
                  (o) => o.copyWith(
                    rotationDeg: face.$2,
                    position: Vec3(o.position.x, o.position.y, 0),
                  ),
                  recordUndo: true,
                ),
              ),
          ],
        );

      case GizmoTool.cut:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingSliderRow(
              label: 'Cut Plane Height (Z)',
              value: vm.cutPlaneHeight,
              min: 2,
              max: (sel!.scaledSize.z - 1).clamp(10, 200),
              unit: ' mm',
              decimals: 1,
              onChanged: vm.setCutPlaneHeight,
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Splits mesh into Lower & Upper parts with optional dowel/snap connectors.',
                    style: TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: vm.executePlanarCut,
                  icon: const Icon(Icons.content_cut, size: 16),
                  label: const Text('Perform Cut'),
                ),
              ],
            ),
          ],
        );

      case GizmoTool.meshBoolean:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => vm.executeMeshBoolean('Union'),
              icon: const Icon(Icons.join_full, size: 16),
              label: const Text('Union'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => vm.executeMeshBoolean('Difference'),
              icon: const Icon(Icons.join_left, size: 16),
              label: const Text('Difference'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => vm.executeMeshBoolean('Intersection'),
              icon: const Icon(Icons.join_inner, size: 16),
              label: const Text('Intersection'),
            ),
          ],
        );

      case GizmoTool.colorPainting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select AMS Filament & tap height bands to paint multi-color regions:',
              style: TextStyle(fontSize: 11.5, color: BambuColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < vm.projectFilaments.length; i++)
                  ChoiceChip(
                    avatar: CircleAvatar(
                      backgroundColor: vm.projectFilaments[i].color,
                      radius: 7,
                    ),
                    label: Text('A${i + 1}'),
                    selected: vm.activePaintFilamentIndex == i,
                    onSelected: (_) => vm.setActivePaintFilament(i),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var band = 0; band < 5; band++)
                  ActionChip(
                    label: Text('Height Band ${band + 1}'),
                    backgroundColor: sel!.paintedBandColors[band] != null
                        ? vm.projectFilaments[sel.paintedBandColors[band]!]
                            .color
                            .withValues(alpha: 0.35)
                        : null,
                    onPressed: () => vm.paintSelectedHeightBand(
                      band,
                      vm.activePaintFilamentIndex,
                    ),
                  ),
                TextButton(
                  onPressed: () => vm.updateSelectedObject(
                    (o) => o.copyWith(paintedBandColors: const {}),
                  ),
                  child: const Text('Clear Paint'),
                ),
              ],
            ),
          ],
        );

      case GizmoTool.supportPainting:
        return SettingSwitchRow(
          label: 'Enforce Tree Supports on Overhangs',
          subtitle: 'Highlights overhang faces > 30° in neon green on the 3D viewport',
          value: sel!.hasSupportEnforcers,
          onChanged: (v) => vm.updateSelectedObject(
            (o) => o.copyWith(hasSupportEnforcers: v),
          ),
        );

      case GizmoTool.seamPainting:
        return SettingSwitchRow(
          label: 'Custom Painted Rear Z-Seam Alignment',
          subtitle: 'Forces scarf/aligned seam along rear edge of selected model',
          value: sel!.hasSeamOverride,
          onChanged: (v) => vm.updateSelectedObject(
            (o) => o.copyWith(hasSeamOverride: v),
          ),
        );

      case GizmoTool.fuzzySkin:
        return SettingSwitchRow(
          label: 'Paint Fuzzy Skin on Outer Contours',
          subtitle: 'Applies textured grip surface (0.8 mm point dist / 0.3 mm thickness)',
          value: sel!.hasFuzzyZone,
          onChanged: (v) => vm.updateSelectedObject(
            (o) => o.copyWith(hasFuzzyZone: v),
          ),
        );

      case GizmoTool.variableLayerHeight:
        return Column(
          children: [
            SettingSwitchRow(
              label: 'Enable Adaptive Variable Layer Height',
              value: sel!.hasVariableLayerHeight,
              onChanged: (v) => vm.updateSelectedObject(
                (o) => o.copyWith(hasVariableLayerHeight: v),
              ),
            ),
            if (sel.hasVariableLayerHeight)
              SettingSliderRow(
                label: 'Quality vs Speed Bias',
                value: sel.variableLayerQuality * 100,
                min: 0,
                max: 100,
                unit: '%',
                subtitle: '0% = Finest 0.08mm curves • 100% = Fastest 0.28mm',
                onChanged: (v) => vm.updateSelectedObject(
                  (o) => o.copyWith(variableLayerQuality: v / 100.0),
                ),
              ),
          ],
        );

      case GizmoTool.textEmboss:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: const InputDecoration(labelText: 'Surface Text'),
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(_textDeboss ? 'Deboss' : 'Emboss'),
                  selected: true,
                  onSelected: (_) => setState(() => _textDeboss = !_textDeboss),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    if (_textCtrl.text.trim().isEmpty) return;
                    vm.addTextEmbossToSelected(TextEmbossAnnotation(
                      text: _textCtrl.text.trim(),
                      sizeMm: 12,
                      thicknessMm: 1.2,
                      isDeboss: _textDeboss,
                      filamentIndex: vm.activePaintFilamentIndex,
                    ));
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            if (sel!.textAnnotations.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: sel.textAnnotations
                    .map((a) => Chip(
                          label: Text(
                            '${a.isDeboss ? "Deboss" : "Emboss"}: "${a.text}"',
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        );

      case GizmoTool.svgEmboss:
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedSvg,
                items: const [
                  DropdownMenuItem(value: 'Bambu Logo Badge', child: Text('Bambu Logo Badge')),
                  DropdownMenuItem(value: 'Hexagon Vent Pattern', child: Text('Hexagon Vent Pattern')),
                  DropdownMenuItem(value: 'Recycling PLA Symbol', child: Text('Recycling PLA Symbol')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedSvg = v);
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => vm.updateSelectedObject(
                (o) => o.copyWith(svgBadgeName: _selectedSvg),
                recordUndo: true,
              ),
              child: const Text('Apply SVG'),
            ),
          ],
        );

      case GizmoTool.measure:
        final sz = sel!.scaledSize;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BambuMetricChip(label: 'Width (X)', value: '${sz.x.toStringAsFixed(2)} mm'),
            BambuMetricChip(label: 'Depth (Y)', value: '${sz.y.toStringAsFixed(2)} mm'),
            BambuMetricChip(label: 'Height (Z)', value: '${sz.z.toStringAsFixed(2)} mm'),
            BambuMetricChip(
              label: 'Triangles',
              value: '${sel.mesh.triangleCount}',
              color: BambuColors.info,
            ),
          ],
        );

      case GizmoTool.simplify:
        return Column(
          children: [
            SettingSliderRow(
              label: 'Retain Detail Ratio',
              value: _simplifyRatio * 100,
              min: 15,
              max: 95,
              unit: '%',
              subtitle: 'Current triangles: ${sel!.mesh.triangleCount}',
              onChanged: (v) => setState(() => _simplifyRatio = v / 100.0),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => vm.simplifySelectedMesh(_simplifyRatio),
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('Decimate Mesh'),
              ),
            ),
          ],
        );

      case GizmoTool.assembly:
        return SettingSliderRow(
          label: 'Exploded Assembly View',
          value: vm.assemblyExplodeFactor * 100,
          min: 0,
          max: 100,
          unit: '%',
          subtitle: 'Separates multi-part objects visually in 3D space',
          onChanged: (v) => vm.setAssemblyExplode(v / 100.0),
        );

      case GizmoTool.brimEars:
        return SettingSliderRow(
          label: 'Corner Brim Helper Discs',
          value: sel!.brimEarCount.toDouble(),
          min: 0,
          max: 4,
          divisions: 4,
          unit: ' ears',
          subtitle: 'Prevents corner warping on ABS / ASA / PA-CF prints',
          onChanged: (v) => vm.updateSelectedObject(
            (o) => o.copyWith(brimEarCount: v.round()),
          ),
        );

      case GizmoTool.hollow:
        return SettingSliderRow(
          label: 'Hollow Shell Wall Thickness',
          value: sel!.hollowWallThickness,
          min: 0,
          max: 6,
          unit: ' mm',
          decimals: 1,
          subtitle: '0 mm = Solid mesh • >0 mm = Hollow cavity with drain ports',
          onChanged: (v) => vm.updateSelectedObject(
            (o) => o.copyWith(hollowWallThickness: v),
          ),
        );

      case GizmoTool.select:
        return const SizedBox.shrink();
    }
  }
}
