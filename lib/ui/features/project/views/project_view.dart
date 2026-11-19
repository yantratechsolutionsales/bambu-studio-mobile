import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../../domain/models/project_models.dart';
import '../../../core/bambu_theme.dart';
import '../../../core/shared_widgets.dart';
import '../../prepare/view_models/studio_workspace_view_model.dart';

class ProjectView extends StatefulWidget {
  const ProjectView({super.key, required this.workspaceVm});

  final StudioWorkspaceViewModel workspaceVm;

  @override
  State<ProjectView> createState() => _ProjectViewState();
}

class _ProjectViewState extends State<ProjectView> {
  void _addBomItemDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '2');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BambuColors.surfaceDark,
        title: const Text('Add Hardware / BOM Part'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Part Name')),
            const SizedBox(height: 8),
            TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Specification')),
            const SizedBox(height: 8),
            TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              widget.workspaceVm.updateProjectMetadata((m) => m.copyWith(
                    bomItems: [
                      ...m.bomItems,
                      BomItem(
                        id: 'bom_${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text.trim(),
                        spec: specCtrl.text.trim().isEmpty ? 'Standard' : specCtrl.text.trim(),
                        quantity: int.tryParse(qtyCtrl.text) ?? 1,
                        category: 'Hardware',
                      ),
                    ],
                  ));
              Navigator.pop(ctx);
            },
            child: const Text('Add Part'),
          ),
        ],
      ),
    );
  }

  void _addAssemblyStepDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final instCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BambuColors.surfaceDark,
        title: const Text('Add Assembly Step'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Step Title')),
            const SizedBox(height: 8),
            TextField(controller: instCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Instructions')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              widget.workspaceVm.updateProjectMetadata((m) => m.copyWith(
                    assemblySteps: [
                      ...m.assemblySteps,
                      AssemblyStep(
                        stepNumber: m.assemblySteps.length + 1,
                        title: titleCtrl.text.trim(),
                        instructions: instCtrl.text.trim(),
                        partsUsed: const [],
                      ),
                    ],
                  ));
              Navigator.pop(ctx);
            },
            child: const Text('Add Step'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.workspaceVm,
      builder: (context, _) {
        final vm = widget.workspaceVm;
        final meta = vm.projectMetadata;

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // 3MF Metadata Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BambuSectionHeader(
                      title: '3MF Project Overview & Metadata',
                      icon: Icons.description_outlined,
                      trailing: FilledButton.tonalIcon(
                        icon: const Icon(Icons.ios_share, size: 16),
                        label: const Text('Export Guide'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: meta.toMarkdownGuide()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Exported Assembly Guide Markdown to clipboard')),
                          );
                        },
                      ),
                    ),
                    TextFormField(
                      initialValue: meta.title,
                      decoration: const InputDecoration(labelText: 'Project Title'),
                      onChanged: (v) => vm.updateProjectMetadata((m) => m.copyWith(title: v)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: meta.author,
                            decoration: const InputDecoration(labelText: 'Designer / Author'),
                            onChanged: (v) => vm.updateProjectMetadata((m) => m.copyWith(author: v)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: meta.license,
                            decoration: const InputDecoration(labelText: 'License'),
                            onChanged: (v) => vm.updateProjectMetadata((m) => m.copyWith(license: v)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: meta.description,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Project Description (Markdown)'),
                      onChanged: (v) => vm.updateProjectMetadata((m) => m.copyWith(description: v)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: meta.printProfileNotes,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Print Profile Notes'),
                      onChanged: (v) => vm.updateProjectMetadata((m) => m.copyWith(printProfileNotes: v)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: meta.tags.map((t) => Chip(label: Text('#$t'))).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Plates Summary inside 3MF Package
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BambuSectionHeader(
                      title: '3MF Plates & Objects Manifest',
                      icon: Icons.layers_outlined,
                    ),
                    ...vm.plates.map((p) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.crop_square, color: BambuColors.green),
                          title: Text('${p.name} • ${p.bedType}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${p.objects.length} object(s) • Sequence: ${p.printSequence}'),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Bill of Materials (BOM)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BambuSectionHeader(
                      title: 'Bill of Materials (Maker\'s Supply / Hardware)',
                      icon: Icons.build_outlined,
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: BambuColors.green),
                        onPressed: () => _addBomItemDialog(context),
                      ),
                    ),
                    ...meta.bomItems.map((b) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: BambuColors.greenSoft,
                            child: Text(
                              '${b.quantity}x',
                              style: const TextStyle(fontSize: 11, color: BambuColors.green, fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text('${b.spec} • ${b.category}', style: const TextStyle(fontSize: 11.5)),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Assembly Guide Steps (Matching BambuStudio Overview / AssemblyStepsUtils)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BambuSectionHeader(
                      title: 'Assembly Guide Steps',
                      icon: Icons.menu_book_outlined,
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: BambuColors.green),
                        onPressed: () => _addAssemblyStepDialog(context),
                      ),
                    ),
                    ...meta.assemblySteps.map((s) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: BambuColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: BambuColors.borderDark),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Step ${s.stepNumber}: ${s.title}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: BambuColors.green,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(s.instructions, style: const TextStyle(fontSize: 12)),
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
}
