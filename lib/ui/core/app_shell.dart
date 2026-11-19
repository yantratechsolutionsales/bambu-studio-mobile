import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../features/device/view_models/device_view_model.dart';
import '../features/prepare/view_models/studio_workspace_view_model.dart';
import 'bambu_theme.dart';

class NavTabDef {
  const NavTabDef(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<NavTabDef> bambuTabs = [
  NavTabDef('Home', Icons.home_outlined, Icons.home),
  NavTabDef('Prepare', Icons.view_in_ar_outlined, Icons.view_in_ar),
  NavTabDef('Preview', Icons.layers_outlined, Icons.layers),
  NavTabDef('Device', Icons.print_outlined, Icons.print),
  NavTabDef('Farm', Icons.hub_outlined, Icons.hub),
  NavTabDef('Project', Icons.description_outlined, Icons.description),
  NavTabDef('Calibrate', Icons.science_outlined, Icons.science),
];

/// Adaptive Bambu Studio Shell:
/// - Phones (width < 720): Top Bambu Studio Header + Scrollable All-7-Tabs Studio Bar + Mobile Bottom Nav
/// - Tablets / Landscape / Desktop (width >= 720): Left NavigationRail with all 7 tabs + Top Header
class BambuAppShell extends StatelessWidget {
  const BambuAppShell({
    super.key,
    required this.navigationShell,
    required this.workspaceVm,
    required this.deviceVm,
  });

  final StatefulNavigationShell navigationShell;
  final StudioWorkspaceViewModel workspaceVm;
  final DeviceViewModel deviceVm;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLarge = constraints.maxWidth >= 720;
        final currentIdx = navigationShell.currentIndex;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: BambuColors.green,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.layers, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Bambu Studio',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: BambuColors.greenSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bambuTabs[currentIdx].label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: BambuColors.green,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              ListenableBuilder(
                listenable: workspaceVm,
                builder: (ctx, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (workspaceVm.selectedPrinter != null && isLarge)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          avatar: const Icon(Icons.precision_manufacturing, size: 15, color: BambuColors.green),
                          label: Text(
                            '${workspaceVm.selectedPrinter!.name} (${workspaceVm.selectedNozzle}mm)',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Quick Slice Plate',
                      icon: const Icon(Icons.play_circle_fill, color: BambuColors.green),
                      onPressed: workspaceVm.isSlicing
                          ? null
                          : () async {
                              await workspaceVm.sliceActivePlate();
                              _goBranch(2); // Jump to Preview
                            },
                    ),
                    IconButton(
                      tooltip: 'Bambu Studio Preferences',
                      icon: const Icon(Icons.settings_outlined, size: 20),
                      onPressed: () => _showPreferencesModal(context),
                    ),
                  ],
                ),
              ),
            ],
            bottom: !isLarge
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(42),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: BambuColors.borderDark, width: 0.7)),
                      ),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: bambuTabs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (ctx, idx) {
                          final tab = bambuTabs[idx];
                          final selected = idx == currentIdx;
                          return ChoiceChip(
                            avatar: Icon(
                              selected ? tab.selectedIcon : tab.icon,
                              size: 15,
                              color: selected ? BambuColors.green : BambuColors.textSecondary,
                            ),
                            label: Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            selected: selected,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => _goBranch(idx),
                          );
                        },
                      ),
                    ),
                  )
                : null,
          ),
          body: isLarge
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: currentIdx,
                      onDestinationSelected: _goBranch,
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: BambuColors.surfaceDark,
                      indicatorColor: BambuColors.greenSoft,
                      selectedIconTheme: const IconThemeData(color: BambuColors.green),
                      selectedLabelTextStyle: const TextStyle(
                        color: BambuColors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      destinations: bambuTabs
                          .map((t) => NavigationRailDestination(
                                icon: Icon(t.icon),
                                selectedIcon: Icon(t.selectedIcon),
                                label: Text(t.label),
                              ))
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: navigationShell),
                  ],
                )
              : navigationShell,
          bottomNavigationBar: isLarge
              ? null
              : NavigationBar(
                  height: 62,
                  selectedIndex: currentIdx < 5 ? currentIdx : 4,
                  onDestinationSelected: (idx) {
                    if (idx < 4) {
                      _goBranch(idx);
                    } else {
                      _showMoreTabsSheet(context, currentIdx);
                    }
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.view_in_ar_outlined),
                      selectedIcon: Icon(Icons.view_in_ar),
                      label: 'Prepare',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.layers_outlined),
                      selectedIcon: Icon(Icons.layers),
                      label: 'Preview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.print_outlined),
                      selectedIcon: Icon(Icons.print),
                      label: 'Device',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view),
                      label: 'More',
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _showPreferencesModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BambuColors.surfaceDark,
      builder: (ctx) => ListenableBuilder(
        listenable: workspaceVm,
        builder: (ctx, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bambu Studio Preferences',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: workspaceVm.appLanguage,
                  decoration: const InputDecoration(labelText: 'Language (BambuStudio i18n)'),
                  items: const [
                    DropdownMenuItem(value: 'English', child: Text('English')),
                    DropdownMenuItem(value: 'Deutsch', child: Text('Deutsch')),
                    DropdownMenuItem(value: 'Español', child: Text('Español')),
                    DropdownMenuItem(value: 'Français', child: Text('Français')),
                    DropdownMenuItem(value: '日本語', child: Text('日本語')),
                    DropdownMenuItem(value: '한국어', child: Text('한국어')),
                    DropdownMenuItem(value: '简体中文', child: Text('简体中文')),
                  ],
                  onChanged: (v) {
                    if (v != null) workspaceVm.updatePreferences(appLanguage: v);
                  },
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: BambuColors.green,
                  title: const Text('Dark Mode'),
                  value: workspaceVm.isDarkMode,
                  onChanged: (_) => workspaceVm.toggleTheme(),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: BambuColors.green,
                  title: const Text('Use Imperial Units (Inches)'),
                  value: workspaceVm.useInches,
                  onChanged: (v) => workspaceVm.updatePreferences(useInches: v),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: BambuColors.green,
                  title: const Text('Developer Mode (Extra Process Controls)'),
                  value: workspaceVm.developerMode,
                  onChanged: (v) => workspaceVm.updatePreferences(developerMode: v),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: BambuColors.green,
                  title: const Text('Auto-Sync AMS Filaments Before Print'),
                  value: workspaceVm.autoSyncAms,
                  onChanged: (v) => workspaceVm.updatePreferences(autoSyncAms: v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreTabsSheet(BuildContext context, int currentIdx) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BambuColors.surfaceDark,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'More Bambu Studio Workspaces',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              for (final idx in const [4, 5, 6])
                ListTile(
                  leading: Icon(
                    bambuTabs[idx].selectedIcon,
                    color: currentIdx == idx ? BambuColors.green : BambuColors.textSecondary,
                  ),
                  title: Text(
                    idx == 4
                        ? 'Multi-Device Print Farm'
                        : idx == 5
                            ? 'Project (3MF Metadata, BOM & Assembly)'
                            : 'Calibration Center (PA, Flow, Temp, Retraction)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _goBranch(idx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
