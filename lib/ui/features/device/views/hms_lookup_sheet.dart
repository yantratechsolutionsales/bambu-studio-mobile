import 'package:material_ui/material_ui.dart';
import '../../../../domain/models/device_models.dart';
import '../../../core/bambu_theme.dart';

class HmsLookupSheet extends StatefulWidget {
  const HmsLookupSheet({super.key, required this.hmsCatalog});

  final List<HmsCodeEntry> hmsCatalog;

  @override
  State<HmsLookupSheet> createState() => _HmsLookupSheetState();
}

class _HmsLookupSheetState extends State<HmsLookupSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = widget.hmsCatalog.where((e) {
      if (q.isEmpty) return true;
      return e.code.toLowerCase().contains(q) ||
          e.rawCode.toLowerCase().contains(q) ||
          e.module.toLowerCase().contains(q) ||
          e.message.toLowerCase().contains(q);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.health_and_safety_outlined, color: BambuColors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bambu HMS Diagnostics (${widget.hmsCatalog.length} codes)',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search HMS code (e.g. 0C00, 0700, AMS, laser, motor)...',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(14),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final item = filtered[idx];
                final isErr = item.severity == 'Error';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isErr ? BambuColors.danger : BambuColors.warning)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.code,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isErr ? BambuColors.danger : BambuColors.warning,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.module,
                              style: const TextStyle(fontSize: 11, color: BambuColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(item.message, style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
