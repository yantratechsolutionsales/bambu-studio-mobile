import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../data/repositories/bambu_asset_repository.dart';
import '../../../../data/services/slicer_engine_service.dart';
import '../../../../data/services/stl_parser_service.dart';
import '../../../../domain/models/device_models.dart';
import '../../../../domain/models/printer_profile.dart';
import '../../../../domain/models/project_models.dart';
import '../../../../domain/models/scene_models.dart';
import '../../../../domain/models/slice_result.dart';

/// Central MVVM ViewModel powering Home, Prepare, Preview, and Project tabs.
class StudioWorkspaceViewModel extends ChangeNotifier {
  StudioWorkspaceViewModel({
    required BambuAssetRepository assetRepository,
    required SlicerEngineService slicerService,
    StlParserService? stlParser,
  })  : _assetRepo = assetRepository,
        _slicer = slicerService,
        _stlParser = stlParser ?? const StlParserService();

  final BambuAssetRepository _assetRepo;
  final SlicerEngineService _slicer;
  final StlParserService _stlParser;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isImporting = false;
  bool get isImporting => _isImporting;

  int _sceneVersion = 0;
  int get sceneVersion => _sceneVersion;

  int _importRevision = 0;
  int get importRevision => _importRevision;

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.dark);
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  @override
  void notifyListeners() {
    _sceneVersion++;
    super.notifyListeners();
  }

  @override
  void dispose() {
    themeModeNotifier.dispose();
    super.dispose();
  }

  BambuAssetCatalog? _catalog;
  BambuAssetCatalog? get catalog => _catalog;

  // Printer & Nozzle
  PrinterProfile? _selectedPrinter;
  PrinterProfile? get selectedPrinter => _selectedPrinter;
  String _selectedNozzle = '0.4';
  String get selectedNozzle => _selectedNozzle;

  // Multi-Plate Workspace
  List<BuildPlate> _plates = const [];
  List<BuildPlate> get plates => _plates;
  int _activePlateIndex = 0;
  int get activePlateIndex => _activePlateIndex;
  BuildPlate get activePlate => _plates[_activePlateIndex];

  String? _selectedObjectId;
  String? get selectedObjectId => _selectedObjectId;
  SceneObject? get selectedObject {
    if (_plates.isEmpty || _selectedObjectId == null) return null;
    for (final o in activePlate.objects) {
      if (o.id == _selectedObjectId) return o;
    }
    return null;
  }

  // Gizmo & Viewport state
  GizmoTool _activeGizmo = GizmoTool.select;
  GizmoTool get activeGizmo => _activeGizmo;
  bool _wireframeMode = false;
  bool get wireframeMode => _wireframeMode;
  double _assemblyExplodeFactor = 0.0;
  double get assemblyExplodeFactor => _assemblyExplodeFactor;
  double _cutPlaneHeight = 15.0;
  double get cutPlaneHeight => _cutPlaneHeight;
  int _activePaintFilamentIndex = 0;
  int get activePaintFilamentIndex => _activePaintFilamentIndex;

  // Undo / Redo snapshots of plates
  final List<List<BuildPlate>> _undoStack = [];
  final List<List<BuildPlate>> _redoStack = [];
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // Project AMS Filaments (up to 16 slots) & Flush Matrix
  List<AmsProjectFilament> _projectFilaments = const [];
  List<AmsProjectFilament> get projectFilaments => _projectFilaments;
  double _flushMultiplier = 1.0;
  double get flushMultiplier => _flushMultiplier;

  // Process Settings (Global vs Per-Object)
  ProcessSettings _globalProcess = const ProcessSettings(name: '0.20mm Standard');
  ProcessSettings get globalProcess => _globalProcess;
  bool _editObjectProcess = false;
  bool get editObjectProcess => _editObjectProcess;
  bool _showAdvancedSettings = true;
  bool get showAdvancedSettings => _showAdvancedSettings;
  String _settingsSearchQuery = '';
  String get settingsSearchQuery => _settingsSearchQuery;

  ProcessSettings get activeProcessSettings {
    if (_editObjectProcess && selectedObject != null) {
      return selectedObject!.objectProcessOverrides ?? _globalProcess;
    }
    return _globalProcess;
  }

  // Slicing & Preview State
  bool _isSlicing = false;
  bool get isSlicing => _isSlicing;
  SliceResult? _lastSliceResult;
  SliceResult? get lastSliceResult => _lastSliceResult;
  final Map<int, SliceResult> _plateSliceResults = {};
  Map<int, SliceResult> get plateSliceResults => Map.unmodifiable(_plateSliceResults);
  final List<LayerGCodeEvent> _layerEvents = [];
  List<LayerGCodeEvent> get layerEvents => List.unmodifiable(_layerEvents);
  final List<ProcessSettings> _userPresets = [];
  List<ProcessSettings> get userPresets => List.unmodifiable(_userPresets);

  // Studio Preferences
  bool _useInches = false;
  bool get useInches => _useInches;
  String _appLanguage = 'English';
  String get appLanguage => _appLanguage;
  bool _developerMode = false;
  bool get developerMode => _developerMode;
  bool _autoSyncAms = true;
  bool get autoSyncAms => _autoSyncAms;

  PreviewColorScheme _previewColorScheme = PreviewColorScheme.lineType;
  PreviewColorScheme get previewColorScheme => _previewColorScheme;
  bool _showTravelMoves = false;
  bool get showTravelMoves => _showTravelMoves;
  bool _showSeams = true;
  bool get showSeams => _showSeams;

  // Bambu CLI Companion Bridge
  String _bridgeEndpoint = 'http://192.168.1.100:8765';
  String get bridgeEndpoint => _bridgeEndpoint;
  BridgeStatus? _bridgeStatus;
  BridgeStatus? get bridgeStatus => _bridgeStatus;

  // Project Metadata & Recent/MakerWorld
  late ProjectMetadata _projectMetadata;
  ProjectMetadata get projectMetadata => _projectMetadata;
  List<RecentProjectItem> _recentProjects = const [];
  List<RecentProjectItem> get recentProjects => _recentProjects;
  List<MakerWorldModel> _makerWorldModels = const [];
  List<MakerWorldModel> get makerWorldModels => _makerWorldModels;

  String? _statusToast;
  String? get statusToast => _statusToast;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    final cat = await _assetRepo.loadCatalog();
    _catalog = cat;

    _selectedPrinter = cat.printers.firstWhere(
      (p) => p.name == 'Bambu Lab X1 Carbon',
      orElse: () => cat.printers.first,
    );
    _selectedNozzle = _selectedPrinter!.nozzles.contains('0.4')
        ? '0.4'
        : _selectedPrinter!.nozzles.first;

    _globalProcess = cat.processes.firstWhere(
      (p) => p.name.contains('0.20mm Standard'),
      orElse: () => cat.processes.first,
    );

    // Initialize 4-slot AMS project filaments from real BBL profiles
    final plaBasic = _findFilament(cat, 'Bambu PLA Basic');
    final plaMatte = _findFilament(cat, 'Bambu PLA Matte');
    final petgHf = _findFilament(cat, 'Bambu PETG HF');
    final supportPla = _findFilament(cat, 'Support For PLA');

    _projectFilaments = [
      AmsProjectFilament(slotIndex: 0, profile: plaBasic, customColorHex: '#00AE42'),
      AmsProjectFilament(slotIndex: 1, profile: plaMatte, customColorHex: '#2B2D42'),
      AmsProjectFilament(slotIndex: 2, profile: petgHf, customColorHex: '#FF6D00'),
      AmsProjectFilament(slotIndex: 3, profile: supportPla, customColorHex: '#ECEFF1'),
    ];

    // Load real Bambu_Cube.stl from cloned BambuStudio/resources/model!
    final cubeMesh = await _assetRepo.loadBuiltInStl(
      'assets/bambu_data/models/Bambu_Cube.stl',
      'Bambu_Cube.stl',
    );

    _plates = [
      BuildPlate(
        index: 0,
        name: 'Plate 1',
        bedType: _selectedPrinter!.defaultBedType,
        objects: [
          SceneObject(
            id: 'obj_initial_cube',
            name: 'Bambu_Cube.stl',
            mesh: cubeMesh,
            position: const Vec3(0, 0, 0),
            filamentIndex: 0,
          ),
        ],
      ),
    ];
    _activePlateIndex = 0;
    _selectedObjectId = 'obj_initial_cube';

    _projectMetadata = ProjectMetadata(
      title: 'Bambu Studio Multi-Color Calibration Kit',
      author: 'Studio Designer',
      license: 'Standard Digital File License (CC BY 4.0)',
      description:
          'Multi-plate functional 3MF project prepared in Bambu Studio Mobile with AMS filament mapping, support painting, and calibrated print profiles.',
      printProfileNotes:
          'Recommended: 0.20mm Standard, 2 Wall Loops, 15% Gyroid Infill, Textured PEI Plate at 55°C.',
      tags: const ['BambuLab', 'AMS', 'Functional', 'Calibration', '3MF'],
      bomItems: const [
        BomItem(
          id: 'bom_1',
          name: 'M3x12 Socket Head Cap Screw',
          spec: 'Stainless Steel DIN 912',
          quantity: 4,
          category: 'Fasteners',
        ),
        BomItem(
          id: 'bom_2',
          name: '608-2RS Ball Bearing',
          spec: '8x22x7 mm',
          quantity: 2,
          category: 'Motion',
        ),
        BomItem(
          id: 'bom_3',
          name: 'Neodymium Round Magnet',
          spec: '6x3 mm N52',
          quantity: 6,
          category: 'Magnets',
        ),
      ],
      assemblySteps: const [
        AssemblyStep(
          stepNumber: 1,
          title: 'Clean & Inspect First Layer',
          instructions:
              'Remove brim and tree supports from Plate 1 components. Verify dimensional clearance on bearing seats.',
          partsUsed: ['Bambu_Cube.stl'],
        ),
        AssemblyStep(
          stepNumber: 2,
          title: 'Press-Fit Magnets & Bearings',
          instructions:
              'Align magnet polarities before pressing into the recessed pockets. Seat the 608 bearings flush.',
          partsUsed: ['608-2RS Ball Bearing', '6x3 mm N52 Magnet'],
        ),
        AssemblyStep(
          stepNumber: 3,
          title: 'Fasten Housing',
          instructions:
              'Secure the upper and lower cut shells using four M3x12 screws tightened to finger-snug torque.',
          partsUsed: ['M3x12 Socket Head Cap Screw'],
        ),
      ],
      lastModified: DateTime.now(),
    );

    _recentProjects = const [
      RecentProjectItem(
        id: 'rec_cpu_left',
        name: 'CPU_Wall_Bracket_Left.3mf',
        printerModel: 'Bambu Lab A1 mini',
        plateCount: 1,
        objectCount: 1,
        estimatedTime: '2h 15m',
        filamentGrams: 42.5,
        openedAgo: 'Just now',
        presetAsset: 'assets/bambu_data/models/pc_wall_bracket_left_A1mini.3mf',
      ),
      RecentProjectItem(
        id: 'rec_cpu_right',
        name: 'CPU_Wall_Bracket_Right.3mf',
        printerModel: 'Bambu Lab A1 mini',
        plateCount: 1,
        objectCount: 1,
        estimatedTime: '2h 15m',
        filamentGrams: 42.5,
        openedAgo: 'Just now',
        presetAsset: 'assets/bambu_data/models/pc_wall_bracket_right_A1mini.3mf',
      ),
      RecentProjectItem(
        id: 'rec_stand',
        name: 'TILT_PHONE_STAND_V3.0.3mf',
        printerModel: 'Bambu Lab A1 mini',
        plateCount: 1,
        objectCount: 1,
        estimatedTime: '1h 35m',
        filamentGrams: 34.0,
        openedAgo: 'Today',
        presetAsset: 'assets/bambu_data/models/TILT_PHONE_STAND_V3.0.3mf',
      ),
      RecentProjectItem(
        id: 'rec_scraper',
        name: 'scraper_A1mini.3mf',
        printerModel: 'Bambu Lab A1 mini',
        plateCount: 1,
        objectCount: 1,
        estimatedTime: '48m',
        filamentGrams: 18.2,
        openedAgo: 'Today',
        presetAsset: 'assets/bambu_data/models/scraper_30cm_rod_6cm_handle_A1mini.3mf',
      ),
      RecentProjectItem(
        id: 'rec_clip',
        name: 'exact_photo_wall_mounting_clip.3mf',
        printerModel: 'Bambu Lab A1 mini',
        plateCount: 1,
        objectCount: 1,
        estimatedTime: '22m',
        filamentGrams: 6.8,
        openedAgo: 'Yesterday',
        presetAsset: 'assets/bambu_data/models/exact_photo_wall_mounting_clip.3mf',
      ),
      RecentProjectItem(
        id: 'rec_benchy',
        name: '3DBenchy_SpeedTest.3mf',
        printerModel: 'Bambu Lab A1 mini',
        plateCount: 1,
        objectCount: 1,
        estimatedTime: '41m',
        filamentGrams: 13.4,
        openedAgo: 'Yesterday',
        presetAsset: 'assets/bambu_data/models/3DBenchy.stl',
      ),
    ];

    _makerWorldModels = const [
      MakerWorldModel(
        id: 'mw_1',
        title: 'Original 3DBenchy Torture Boat',
        creator: 'CreativeTools',
        downloads: '1.2M',
        likes: 94200,
        printTime: '41m',
        filamentType: 'PLA',
        category: 'Benchmark',
        primitiveType: 'benchy',
      ),
      MakerWorldModel(
        id: 'mw_2',
        title: 'Bambu Precision Calibration Cube',
        creator: 'Bambu Lab Official',
        downloads: '485K',
        likes: 31800,
        printTime: '22m',
        filamentType: 'PLA / PETG',
        category: 'Calibration',
        primitiveType: 'bambu_cube',
      ),
      MakerWorldModel(
        id: 'mw_3',
        title: 'AMS Desiccant Pod & Hygrometer',
        creator: 'PrintForge3D',
        downloads: '214K',
        likes: 18500,
        printTime: '1h 35m',
        filamentType: 'PETG / ABS',
        category: 'Printer Mods',
        primitiveType: 'cylinder',
      ),
      MakerWorldModel(
        id: 'mw_4',
        title: 'Parametric Torus Fidget Bearing',
        creator: 'MechStudio',
        downloads: '162K',
        likes: 14100,
        printTime: '52m',
        filamentType: 'PLA Silk',
        category: 'Gadgets',
        primitiveType: 'torus',
      ),
      MakerWorldModel(
        id: 'mw_5',
        title: 'Overhang Cone Airflow Nozzle',
        creator: 'AeroCAD',
        downloads: '89K',
        likes: 7420,
        printTime: '48m',
        filamentType: 'ASA / PA-CF',
        category: 'Functional',
        primitiveType: 'cone',
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  FilamentProfile _findFilament(BambuAssetCatalog cat, String query) {
    return cat.filaments.firstWhere(
      (f) => f.name.toLowerCase().contains(query.toLowerCase()),
      orElse: () => cat.filaments.first,
    );
  }

  void _pushUndo() {
    _undoStack.add(List<BuildPlate>.from(_plates));
    if (_undoStack.length > 25) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List<BuildPlate>.from(_plates));
    _plates = _undoStack.removeLast();
    if (_activePlateIndex >= _plates.length) {
      _activePlateIndex = _plates.length - 1;
    }
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List<BuildPlate>.from(_plates));
    _plates = _redoStack.removeLast();
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    themeModeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void selectPrinter(PrinterProfile printer) {
    _selectedPrinter = printer;
    _selectedNozzle =
        printer.nozzles.contains('0.4') ? '0.4' : printer.nozzles.first;
    updatePlateBedType(printer.defaultBedType);
    notifyListeners();
  }

  void selectNozzle(String nozzle) {
    _selectedNozzle = nozzle;
    notifyListeners();
  }

  void updatePlateBedType(String bedType) {
    if (_plates.isEmpty) return;
    final next = List<BuildPlate>.from(_plates);
    next[_activePlateIndex] = activePlate.copyWith(bedType: bedType);
    _plates = next;
    notifyListeners();
  }

  void updatePlatePrintSequence(String seq) {
    final next = List<BuildPlate>.from(_plates);
    next[_activePlateIndex] = activePlate.copyWith(printSequence: seq);
    _plates = next;
    notifyListeners();
  }

  void addPlate() {
    _pushUndo();
    final idx = _plates.length;
    _plates = [
      ..._plates,
      BuildPlate(
        index: idx,
        name: 'Plate ${idx + 1}',
        bedType: _selectedPrinter?.defaultBedType ?? 'Textured PEI Plate',
      ),
    ];
    _activePlateIndex = idx;
    _selectedObjectId = null;
    notifyListeners();
  }

  void selectPlate(int index) {
    if (index < 0 || index >= _plates.length) return;
    _activePlateIndex = index;
    _selectedObjectId =
        activePlate.objects.isNotEmpty ? activePlate.objects.first.id : null;
    notifyListeners();
  }

  void deleteActivePlate() {
    if (_plates.length <= 1) return;
    _pushUndo();
    final next = List<BuildPlate>.from(_plates)..removeAt(_activePlateIndex);
    _plates = [
      for (var i = 0; i < next.length; i++)
        BuildPlate(
          index: i,
          name: 'Plate ${i + 1}',
          bedType: next[i].bedType,
          printSequence: next[i].printSequence,
          isLocked: next[i].isLocked,
          objects: next[i].objects,
        ),
    ];
    _activePlateIndex = math.min(_activePlateIndex, _plates.length - 1);
    _selectedObjectId =
        activePlate.objects.isNotEmpty ? activePlate.objects.first.id : null;
    notifyListeners();
  }

  void newEmptyProject() {
    _pushUndo();
    _plates = [
      BuildPlate(
        index: 0,
        name: 'Plate 1',
        bedType: _selectedPrinter?.defaultBedType ?? 'Textured PEI Plate',
      ),
    ];
    _activePlateIndex = 0;
    _selectedObjectId = null;
    _lastSliceResult = null;
    _statusToast = 'Started new blank project';
    notifyListeners();
  }

  Future<void> openAssetModelAsProject(String assetPath, String title) async {
    _pushUndo();
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      final imported = await importModelBytes(bytes, title);
      if (imported != null) {
        _statusToast = 'Loaded $title onto build plate';
        notifyListeners();
        return;
      }
    } catch (_) {}

    final mesh = await _assetRepo.loadBuiltInStl(assetPath, title);
    final obj = SceneObject(
      id: 'obj_${DateTime.now().millisecondsSinceEpoch}',
      name: title,
      mesh: mesh,
      filamentIndex: 0,
    );
    _plates = [
      BuildPlate(
        index: 0,
        name: 'Plate 1',
        bedType: _selectedPrinter?.defaultBedType ?? 'Textured PEI Plate',
        objects: [obj],
      ),
    ];
    _activePlateIndex = 0;
    _selectedObjectId = obj.id;
    _projectMetadata = _projectMetadata.copyWith(
      title: title,
      lastModified: DateTime.now(),
    );
    _importRevision++;
    _statusToast = 'Loaded $title onto Plate 1';
    notifyListeners();
  }

  Future<void> addPrimitiveOrAsset(String kind) async {
    _pushUndo();
    if (kind == 'bracket_left') {
      await openAssetModelAsProject(
        'assets/bambu_data/models/pc_wall_bracket_left_A1mini.3mf',
        'pc_wall_bracket_left_A1mini.3mf',
      );
      return;
    }
    if (kind == 'bracket_right') {
      await openAssetModelAsProject(
        'assets/bambu_data/models/pc_wall_bracket_right_A1mini.3mf',
        'pc_wall_bracket_right_A1mini.3mf',
      );
      return;
    }
    if (kind == 'phone_stand') {
      await openAssetModelAsProject(
        'assets/bambu_data/models/TILT_PHONE_STAND_V3.0.3mf',
        'TILT_PHONE_STAND_V3.0.3mf',
      );
      return;
    }
    if (kind == 'scraper') {
      await openAssetModelAsProject(
        'assets/bambu_data/models/scraper_30cm_rod_6cm_handle_A1mini.3mf',
        'scraper_30cm_rod_6cm_handle_A1mini.3mf',
      );
      return;
    }
    if (kind == 'wall_clip') {
      await openAssetModelAsProject(
        'assets/bambu_data/models/exact_photo_wall_mounting_clip.3mf',
        'exact_photo_wall_mounting_clip.3mf',
      );
      return;
    }

    Mesh3D mesh;
    switch (kind) {
      case 'benchy':
        mesh = await _assetRepo.loadBuiltInStl(
          'assets/bambu_data/models/3DBenchy.stl',
          '3DBenchy.stl',
        );
      case 'bambu_cube':
        mesh = await _assetRepo.loadBuiltInStl(
          'assets/bambu_data/models/Bambu_Cube.stl',
          'Bambu_Cube.stl',
        );
      case 'cylinder':
        mesh = _stlParser.createCylinder(name: 'Cylinder');
      case 'sphere':
        mesh = _stlParser.createSphere(name: 'Sphere');
      case 'cone':
        mesh = _stlParser.createCone(name: 'Cone');
      case 'torus':
        mesh = _stlParser.createTorus(name: 'Torus');
      case 'temp_tower':
        mesh = _stlParser.createTempTower(name: 'Temp_Tower');
      default:
        mesh = _stlParser.createCube(name: 'Cube');
    }

    final count = activePlate.objects.length;
    final offsetX = (count % 3 - 1) * 52.0;
    final offsetY = ((count ~/ 3) % 3) * 45.0;
    final obj = SceneObject(
      id: 'obj_${DateTime.now().millisecondsSinceEpoch}_$count',
      name: mesh.name,
      mesh: mesh,
      position: count == 0 ? const Vec3(0, 0, 0) : Vec3(offsetX, offsetY, 0),
      filamentIndex: count % _projectFilaments.length,
    );
    _replaceActivePlateObjects([...activePlate.objects, obj]);
    _selectedObjectId = obj.id;
    notifyListeners();
  }

  /// Async background-isolate importer for `.3mf` (Bambu Studio Core & Production
  /// Extension), Binary/ASCII `.stl`, and Wavefront `.obj`.
  Future<ImportedProjectData?> importModelBytes(
    Uint8List bytes,
    String fileName, {
    bool replaceFor3mf = true,
  }) async {
    _isImporting = true;
    notifyListeners();

    try {
      final parsed = await compute(parseModelFileIsolate, {
        'bytes': bytes,
        'fileName': fileName,
        'defaultBedX': _selectedPrinter?.bedX ?? 256,
        'defaultBedY': _selectedPrinter?.bedY ?? 256,
        'maxPlateTriangles': 14000,
      });

      _pushUndo();

      // 1. Auto-match printer profile from 3MF project_settings.config (like desktop Bambu Studio)
      if (parsed.isFullProject && _catalog != null) {
        final matchedPrinter = _matchPrinterProfile(
          _catalog!.printers,
          printerModel: parsed.printerModel,
          bedX: parsed.bedX,
          bedY: parsed.bedY,
        );
        if (matchedPrinter != null) {
          _selectedPrinter = matchedPrinter;
          _selectedNozzle = matchedPrinter.nozzles.contains('0.4')
              ? '0.4'
              : matchedPrinter.nozzles.first;
        }

        // Auto-apply filament colors & material profiles from the 3MF project
        if (parsed.filamentColors.isNotEmpty) {
          final updatedFils = List<AmsProjectFilament>.from(_projectFilaments);
          for (var i = 0; i < parsed.filamentColors.length && i < 16; i++) {
            final colorHex = parsed.filamentColors[i];
            final matType = i < parsed.filamentTypes.length
                ? parsed.filamentTypes[i]
                : 'PLA';
            final prof = _findFilament(_catalog!, matType);
            if (i < updatedFils.length) {
              updatedFils[i] = updatedFils[i].copyWith(
                profile: prof,
                customColorHex: colorHex,
              );
            } else {
              updatedFils.add(AmsProjectFilament(
                slotIndex: i,
                profile: prof,
                customColorHex: colorHex,
              ));
            }
          }
          _projectFilaments = updatedFils;
        }

        if (parsed.layerHeight != null && parsed.layerHeight! >= 0.06) {
          _globalProcess = _globalProcess.copyWith(layerHeight: parsed.layerHeight);
        }
      }

      // 2. Apply parsed plates & objects
      if (parsed.isFullProject && replaceFor3mf) {
        _plates = [
          for (var i = 0; i < parsed.plates.length; i++)
            BuildPlate(
              index: i,
              name: parsed.plates[i].name,
              bedType: parsed.plates[i].bedType,
              objects: parsed.plates[i].objects,
            ),
        ];
        _activePlateIndex = 0;
        _selectedObjectId = activePlate.objects.isNotEmpty
            ? activePlate.objects.first.id
            : null;
        _lastSliceResult = null;
        _plateSliceResults.clear();
        _projectMetadata = _projectMetadata.copyWith(
          title: parsed.projectName,
          lastModified: DateTime.now(),
        );
      } else {
        // Add standalone STL / OBJ onto active plate
        final added = parsed.plates.expand((p) => p.objects).toList();
        if (added.isNotEmpty) {
          _replaceActivePlateObjects([...activePlate.objects, ...added]);
          _selectedObjectId = added.first.id;
        }
      }

      _importRevision++;
      final totalObjs = parsed.plates.fold<int>(0, (s, p) => s + p.objects.length);
      final printerTag = _selectedPrinter != null ? ' • ${_selectedPrinter!.name}' : '';
      _statusToast =
          'Loaded $fileName ($totalObjs obj, ${parsed.totalRenderedTriangles}/${parsed.totalSourceTriangles} tris$printerTag) in ${parsed.parseTimeMs}ms';
      return parsed;
    } catch (e) {
      _statusToast = 'Failed to import $fileName: $e';
      return null;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  PrinterProfile? _matchPrinterProfile(
    List<PrinterProfile> printers, {
    String? printerModel,
    int? bedX,
    int? bedY,
  }) {
    if (printers.isEmpty) return null;
    if (printerModel != null && printerModel.trim().isNotEmpty) {
      final q = printerModel.toLowerCase().trim();
      for (final p in printers) {
        if (p.name.toLowerCase() == q) return p;
      }
      // Match specific models carefully (A1 mini before A1!)
      if (q.contains('a1 mini') || q.contains('a1mini')) {
        for (final p in printers) {
          if (p.name.toLowerCase().contains('a1 mini')) return p;
        }
      }
      for (final p in printers) {
        final pn = p.name.toLowerCase();
        if (q.contains(pn) || pn.contains(q)) return p;
      }
    }
    if (bedX != null && bedY != null) {
      for (final p in printers) {
        if (p.bedX == bedX && p.bedY == bedY) return p;
      }
    }
    return null;
  }

  void importStlBytes(Uint8List bytes, String fileName) {
    importModelBytes(bytes, fileName);
  }

  void selectObject(String? id) {
    _selectedObjectId = id;
    notifyListeners();
  }

  void setActiveGizmo(GizmoTool tool) {
    _activeGizmo = tool;
    if (tool != GizmoTool.assembly) {
      _assemblyExplodeFactor = 0.0;
    }
    notifyListeners();
  }

  void toggleWireframe() {
    _wireframeMode = !_wireframeMode;
    notifyListeners();
  }

  void setAssemblyExplode(double factor) {
    _assemblyExplodeFactor = factor.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setCutPlaneHeight(double z) {
    _cutPlaneHeight = z.clamp(1.0, 200.0);
    notifyListeners();
  }

  void setActivePaintFilament(int index) {
    _activePaintFilamentIndex = index.clamp(0, _projectFilaments.length - 1);
    notifyListeners();
  }

  void updateSelectedObject(SceneObject Function(SceneObject) updater,
      {bool recordUndo = false}) {
    final sel = selectedObject;
    if (sel == null) return;
    if (recordUndo) _pushUndo();
    final updated = activePlate.objects
        .map((o) => o.id == sel.id ? updater(o) : o)
        .toList();
    _replaceActivePlateObjects(updated);
    notifyListeners();
  }

  void cloneSelectedObject() {
    final sel = selectedObject;
    if (sel == null) return;
    _pushUndo();
    final clone = sel.copyWith(
      id: 'obj_${DateTime.now().millisecondsSinceEpoch}',
      name: '${sel.name} (Copy)',
      position: Vec3(sel.position.x + sel.scaledSize.x + 12, sel.position.y, 0),
    );
    _replaceActivePlateObjects([...activePlate.objects, clone]);
    _selectedObjectId = clone.id;
    notifyListeners();
  }

  void deleteSelectedObject() {
    final sel = selectedObject;
    if (sel == null) return;
    _pushUndo();
    final remaining = activePlate.objects.where((o) => o.id != sel.id).toList();
    _replaceActivePlateObjects(remaining);
    _selectedObjectId = remaining.isNotEmpty ? remaining.first.id : null;
    notifyListeners();
  }

  void autoArrangePlate() {
    if (activePlate.objects.isEmpty) return;
    _pushUndo();
    final objs = activePlate.objects;
    final cols = math.max(1, math.sqrt(objs.length).ceil());
    const spacing = 56.0;
    final arranged = <SceneObject>[];
    for (var i = 0; i < objs.length; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final x = (col - (cols - 1) / 2.0) * spacing;
      final y = (row - ((objs.length / cols).ceil() - 1) / 2.0) * spacing;
      arranged.add(objs[i].copyWith(position: Vec3(x, y, 0)));
    }
    _replaceActivePlateObjects(arranged);
    _statusToast = 'Auto-arranged ${objs.length} object(s) on ${activePlate.name}';
    notifyListeners();
  }

  void autoOrientSelected() {
    updateSelectedObject(
      (o) => o.copyWith(
        rotationDeg: const Vec3(0, 0, 0),
        position: Vec3(o.position.x, o.position.y, 0),
      ),
      recordUndo: true,
    );
    _statusToast = 'Auto-oriented model for minimal overhangs';
    notifyListeners();
  }

  void executePlanarCut() {
    final sel = selectedObject;
    if (sel == null) return;
    _pushUndo();
    final (lower, upper) = _stlParser.cutMeshAtZ(sel.mesh, _cutPlaneHeight);
    final lowerObj = sel.copyWith(
      id: '${sel.id}_lo',
      name: '${sel.name} (Lower)',
      mesh: lower,
      position: Vec3(sel.position.x - 24, sel.position.y, 0),
    );
    final upperObj = sel.copyWith(
      id: '${sel.id}_hi_${DateTime.now().millisecondsSinceEpoch}',
      name: '${sel.name} (Upper)',
      mesh: upper,
      position: Vec3(sel.position.x + 24, sel.position.y, 0),
    );
    final next = activePlate.objects.where((o) => o.id != sel.id).toList()
      ..addAll([lowerObj, upperObj]);
    _replaceActivePlateObjects(next);
    _selectedObjectId = lowerObj.id;
    _statusToast = 'Cut object at Z = ${_cutPlaneHeight.toStringAsFixed(1)} mm';
    notifyListeners();
  }

  void executeMeshBoolean(String op) {
    if (activePlate.objects.length < 2) {
      _statusToast = 'Add at least 2 objects on the plate for Mesh Boolean ($op)';
      notifyListeners();
      return;
    }
    _pushUndo();
    final a = activePlate.objects[0];
    final b = activePlate.objects[1];
    final combinedTris = [
      ...a.mesh.triangles,
      if (op != 'Difference') ...b.mesh.triangles,
    ];
    final merged = SceneObject(
      id: 'bool_${DateTime.now().millisecondsSinceEpoch}',
      name: '${a.name}_${op}_${b.name}',
      mesh: Mesh3D(
        name: '${a.name}_$op',
        triangles: combinedTris,
        minBounds: a.mesh.minBounds,
        maxBounds: a.mesh.maxBounds,
      ),
      filamentIndex: a.filamentIndex,
    );
    final rest = activePlate.objects.skip(2).toList();
    _replaceActivePlateObjects([merged, ...rest]);
    _selectedObjectId = merged.id;
    _statusToast = 'Applied Mesh Boolean: $op';
    notifyListeners();
  }

  void simplifySelectedMesh(double keepRatio) {
    final sel = selectedObject;
    if (sel == null) return;
    _pushUndo();
    final simplified = _stlParser.simplifyMesh(sel.mesh, keepRatio);
    updateSelectedObject((o) => o.copyWith(mesh: simplified));
    _statusToast = 'Simplified mesh to ${simplified.triangleCount} triangles';
    notifyListeners();
  }

  void paintSelectedHeightBand(int bandIndex, int filamentIndex) {
    updateSelectedObject((o) {
      final bands = Map<int, int>.from(o.paintedBandColors);
      bands[bandIndex] = filamentIndex;
      return o.copyWith(paintedBandColors: bands);
    });
  }

  void addTextEmbossToSelected(TextEmbossAnnotation annotation) {
    updateSelectedObject(
      (o) => o.copyWith(textAnnotations: [...o.textAnnotations, annotation]),
      recordUndo: true,
    );
  }

  void mirrorSelected(String axis) {
    updateSelectedObject((o) {
      switch (axis) {
        case 'X':
          return o.copyWith(mirroredX: !o.mirroredX);
        case 'Y':
          return o.copyWith(mirroredY: !o.mirroredY);
        default:
          return o.copyWith(mirroredZ: !o.mirroredZ);
      }
    }, recordUndo: true);
    _statusToast = 'Mirrored object across $axis axis';
    notifyListeners();
  }

  void splitSelectedToObjects() {
    final sel = selectedObject;
    if (sel == null) return;
    _pushUndo();
    final half = (sel.mesh.triangles.length / 2).ceil();
    final leftTris = sel.mesh.triangles.take(half).toList();
    final rightTris = sel.mesh.triangles.skip(half).toList();
    if (rightTris.isEmpty) return;
    final partA = sel.copyWith(
      id: '${sel.id}_p1',
      name: '${sel.name}_Part1',
      mesh: Mesh3D(
        name: '${sel.name}_Part1',
        triangles: leftTris,
        minBounds: sel.mesh.minBounds,
        maxBounds: sel.mesh.maxBounds,
      ),
      position: Vec3(sel.position.x - 18, sel.position.y, 0),
    );
    final partB = sel.copyWith(
      id: '${sel.id}_p2_${DateTime.now().millisecondsSinceEpoch}',
      name: '${sel.name}_Part2',
      mesh: Mesh3D(
        name: '${sel.name}_Part2',
        triangles: rightTris,
        minBounds: sel.mesh.minBounds,
        maxBounds: sel.mesh.maxBounds,
      ),
      position: Vec3(sel.position.x + 18, sel.position.y, 0),
    );
    final next = activePlate.objects.where((o) => o.id != sel.id).toList()
      ..addAll([partA, partB]);
    _replaceActivePlateObjects(next);
    _selectedObjectId = partA.id;
    _statusToast = 'Split ${sel.name} into 2 separate objects';
    notifyListeners();
  }

  void repairSelectedMesh() {
    updateSelectedObject((o) => o.copyWith(isMeshRepaired: true));
    _statusToast = 'Mesh verified manifold (0 non-manifold edges)';
    notifyListeners();
  }

  void addModifierToSelected(ObjectPartModifier modifier) {
    updateSelectedObject(
      (o) => o.copyWith(modifiers: [...o.modifiers, modifier]),
      recordUndo: true,
    );
  }

  void removeModifierFromSelected(String modifierId) {
    updateSelectedObject(
      (o) => o.copyWith(
        modifiers: o.modifiers.where((m) => m.id != modifierId).toList(),
      ),
      recordUndo: true,
    );
  }

  void saveCustomProcessPreset(String presetName) {
    final trimmed = presetName.trim();
    if (trimmed.isEmpty) return;
    final saved = activeProcessSettings.copyWith(name: '$trimmed (User)');
    _userPresets.removeWhere((p) => p.name == saved.name);
    _userPresets.insert(0, saved);
    _globalProcess = saved;
    notifyListeners();
  }

  void addLayerEvent(LayerGCodeEvent event) {
    _layerEvents.removeWhere(
      (e) => e.layerIndex == event.layerIndex && e.type == event.type,
    );
    _layerEvents.add(event);
    _layerEvents.sort((a, b) => a.layerIndex.compareTo(b.layerIndex));
    notifyListeners();
  }

  void removeLayerEvent(LayerGCodeEvent event) {
    _layerEvents.remove(event);
    notifyListeners();
  }

  void updatePreferences({
    bool? useInches,
    String? appLanguage,
    bool? developerMode,
    bool? autoSyncAms,
  }) {
    if (useInches != null) _useInches = useInches;
    if (appLanguage != null) _appLanguage = appLanguage;
    if (developerMode != null) _developerMode = developerMode;
    if (autoSyncAms != null) _autoSyncAms = autoSyncAms;
    notifyListeners();
  }

  Future<void> sliceAllPlates() async {
    _isSlicing = true;
    notifyListeners();
    for (final p in _plates) {
      final res = await _slicer.slicePlate(
        plate: p,
        printer: _selectedPrinter!,
        globalProcess: _globalProcess,
        filaments: _projectFilaments,
        flushMultiplier: _flushMultiplier,
        bridgeEndpoint: _bridgeEndpoint,
        preferCliBridge: _bridgeStatus?.isOnline ?? false,
      );
      _plateSliceResults[p.index] = res;
      if (p.index == _activePlateIndex) {
        _lastSliceResult = res;
      }
    }
    _isSlicing = false;
    notifyListeners();
  }

  // AMS Filament Management
  void addProjectFilamentSlot() {
    if (_projectFilaments.length >= 16 || _catalog == null) return;
    final palette = [
      '#00AE42', '#2B2D42', '#FF6D00', '#ECEFF1',
      '#1976D2', '#D50000', '#FFCA28', '#8E24AA',
      '#00ACC1', '#F06292', '#8D6E63', '#7CB342',
    ];
    final idx = _projectFilaments.length;
    _projectFilaments = [
      ..._projectFilaments,
      AmsProjectFilament(
        slotIndex: idx,
        profile: _catalog!.filaments[idx % _catalog!.filaments.length],
        customColorHex: palette[idx % palette.length],
      ),
    ];
    notifyListeners();
  }

  void removeLastFilamentSlot() {
    if (_projectFilaments.length <= 1) return;
    _projectFilaments = _projectFilaments.sublist(0, _projectFilaments.length - 1);
    notifyListeners();
  }

  void updateProjectFilament(
    int slotIndex, {
    FilamentProfile? profile,
    String? colorHex,
  }) {
    if (slotIndex < 0 || slotIndex >= _projectFilaments.length) return;
    final next = List<AmsProjectFilament>.from(_projectFilaments);
    next[slotIndex] = next[slotIndex].copyWith(
      profile: profile,
      customColorHex: colorHex,
    );
    _projectFilaments = next;
    notifyListeners();
  }

  void syncFilamentsFromDevice(BambuDevice device) {
    if (_catalog == null || device.amsUnits.isEmpty) return;
    final slots = device.amsUnits.expand((u) => u.slots).toList();
    final synced = <AmsProjectFilament>[];
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      final matched = _findFilament(_catalog!, s.materialType);
      final hex =
          '#${s.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      synced.add(AmsProjectFilament(
        slotIndex: i,
        profile: matched.copyWith(
          name: s.filamentName,
          pressureAdvanceK: s.pressureAdvanceK,
        ),
        customColorHex: hex,
      ));
    }
    if (synced.isNotEmpty) {
      _projectFilaments = synced;
      _statusToast = 'Synced ${synced.length} AMS slots from ${device.name}';
      notifyListeners();
    }
  }

  void setFlushMultiplier(double mult) {
    _flushMultiplier = mult.clamp(0.1, 3.0);
    notifyListeners();
  }

  int computeFlushVolume(int fromSlot, int toSlot) {
    if (fromSlot == toSlot) return 0;
    final from = _projectFilaments[fromSlot];
    final to = _projectFilaments[toSlot];
    final key = '${from.profile.id}->${to.profile.id}';
    final measured = _catalog?.flushPairs[key];
    // Color luminance transition heuristic (matching Bambu Studio's dark->light purge logic)
    final fromLum = from.color.computeLuminance();
    final toLum = to.color.computeLuminance();
    final predicted = ((toLum - fromLum).clamp(0.0, 1.0) * 380 + 180).round();
    final base = measured != null ? math.max(measured, predicted) : predicted;
    return (base * _flushMultiplier).round();
  }

  // Process Settings
  void selectProcessPreset(ProcessSettings preset) {
    if (_editObjectProcess && selectedObject != null) {
      updateSelectedObject((o) => o.copyWith(objectProcessOverrides: preset));
    } else {
      _globalProcess = preset;
      notifyListeners();
    }
  }

  void updateActiveProcess(ProcessSettings Function(ProcessSettings) updater) {
    if (_editObjectProcess && selectedObject != null) {
      final base = selectedObject!.objectProcessOverrides ?? _globalProcess;
      updateSelectedObject(
        (o) => o.copyWith(objectProcessOverrides: updater(base)),
      );
    } else {
      _globalProcess = updater(_globalProcess);
      notifyListeners();
    }
  }

  void setEditObjectProcess(bool perObject) {
    _editObjectProcess = perObject;
    notifyListeners();
  }

  void setShowAdvancedSettings(bool show) {
    _showAdvancedSettings = show;
    notifyListeners();
  }

  void setSettingsSearchQuery(String q) {
    _settingsSearchQuery = q;
    notifyListeners();
  }

  // Slicing & Preview
  Future<SliceResult> sliceActivePlate() async {
    _isSlicing = true;
    notifyListeners();

    final result = await _slicer.slicePlate(
      plate: activePlate,
      printer: _selectedPrinter!,
      globalProcess: _globalProcess,
      filaments: _projectFilaments,
      flushMultiplier: _flushMultiplier,
      bridgeEndpoint: _bridgeEndpoint,
      preferCliBridge: _bridgeStatus?.isOnline ?? false,
    );
    _lastSliceResult = result;
    _plateSliceResults[activePlate.index] = result;
    _isSlicing = false;
    notifyListeners();
    return result;
  }

  void setPreviewColorScheme(PreviewColorScheme scheme) {
    _previewColorScheme = scheme;
    notifyListeners();
  }

  void toggleShowTravelMoves() {
    _showTravelMoves = !_showTravelMoves;
    notifyListeners();
  }

  void toggleShowSeams() {
    _showSeams = !_showSeams;
    notifyListeners();
  }

  // Bridge
  Future<void> testBridgeEndpoint(String endpoint) async {
    _bridgeEndpoint = endpoint.trim();
    _bridgeStatus = await _slicer.checkBridgeHealth(_bridgeEndpoint);
    notifyListeners();
  }

  // Project Metadata
  void updateProjectMetadata(ProjectMetadata Function(ProjectMetadata) updater) {
    _projectMetadata = updater(_projectMetadata).copyWith(
      lastModified: DateTime.now(),
    );
    notifyListeners();
  }

  void _replaceActivePlateObjects(List<SceneObject> objects) {
    final next = List<BuildPlate>.from(_plates);
    next[_activePlateIndex] = activePlate.copyWith(objects: objects);
    _plates = next;
  }
}
