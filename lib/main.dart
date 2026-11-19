import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'data/repositories/bambu_asset_repository.dart';
import 'data/services/slicer_engine_service.dart';
import 'router.dart';
import 'ui/core/bambu_theme.dart';
import 'ui/features/calibration/view_models/calibration_view_model.dart';
import 'ui/features/device/view_models/device_view_model.dart';
import 'ui/features/prepare/view_models/studio_workspace_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BambuStudioApp());
}

class BambuStudioApp extends StatefulWidget {
  const BambuStudioApp({super.key});

  @override
  State<BambuStudioApp> createState() => _BambuStudioAppState();
}

class _BambuStudioAppState extends State<BambuStudioApp> {
  static final ThemeData _lightTheme = BambuTheme.lightTheme();
  static final ThemeData _darkTheme = BambuTheme.darkTheme();

  late final BambuAssetRepository _assetRepo;
  late final StudioWorkspaceViewModel _workspaceVm;
  late final DeviceViewModel _deviceVm;
  late final CalibrationViewModel _calibVm;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _assetRepo = BambuAssetRepository();
    _workspaceVm = StudioWorkspaceViewModel(
      assetRepository: _assetRepo,
      slicerService: SlicerEngineService(),
    );
    _deviceVm = DeviceViewModel();
    _calibVm = CalibrationViewModel();
    _router = createBambuRouter(
      workspaceVm: _workspaceVm,
      deviceVm: _deviceVm,
      calibVm: _calibVm,
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _workspaceVm.initialize();
    final hms = _workspaceVm.catalog?.hmsCodes ?? const [];
    _deviceVm.initialize(hms);
  }

  @override
  void dispose() {
    _router.dispose();
    _workspaceVm.dispose();
    _deviceVm.dispose();
    _calibVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only rebuild MaterialApp when ThemeMode actually changes (not on every 3D edit!)
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _workspaceVm.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp.router(
          title: 'Bambu Studio Mobile',
          debugShowCheckedModeBanner: false,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: themeMode,
          routerConfig: _router,
        );
      },
    );
  }
}
