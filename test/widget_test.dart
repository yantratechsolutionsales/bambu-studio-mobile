import 'dart:ui';

import 'package:bambu_studio_flutter/data/services/slicer_engine_service.dart';
import 'package:bambu_studio_flutter/data/services/stl_parser_service.dart';
import 'package:bambu_studio_flutter/domain/models/printer_profile.dart';
import 'package:bambu_studio_flutter/domain/models/scene_models.dart';
import 'package:bambu_studio_flutter/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('STL parser & pure-Dart 3D slicer produce valid layers and G-code', () async {
    const parser = StlParserService();
    final cube = parser.createCube(name: 'TestCube', size: 20);
    expect(cube.triangleCount, 12);
    expect(cube.size.x, closeTo(20, 0.01));

    final stlText = cube.toAsciiStl();
    expect(stlText, contains('solid TestCube'));
    expect(stlText, contains('endsolid TestCube'));

    final slicer = SlicerEngineService();
    final plate = BuildPlate(
      index: 0,
      name: 'Plate 1',
      objects: [
        SceneObject(id: 'o1', name: 'TestCube', mesh: cube, filamentIndex: 0),
      ],
    );
    const printer = PrinterProfile(
      id: 'BL-P001',
      name: 'Bambu Lab X1 Carbon',
      family: 'BBL-3DP',
      nozzles: ['0.4'],
      defaultBedType: 'Textured PEI Plate',
      defaultPrintProfile: '0.20mm Standard @BBL X1C',
      bedX: 256,
      bedY: 256,
      bedZ: 256,
      maxSpeed: 500,
      maxAccel: 20000,
      hasEnclosedChamber: true,
      hasLidar: true,
      isDualExtruder: false,
    );
    const fil = FilamentProfile(
      id: 'GFA00',
      name: 'Bambu PLA Basic',
      vendor: 'Bambu',
      type: 'PLA',
      nozzleTemp: 220,
      nozzleTempInitial: 220,
      bedTemp: 55,
      flowRatio: 0.98,
      maxVolumetricSpeed: 21,
      density: 1.24,
      costPerKg: 24.99,
      pressureAdvanceK: 0.02,
      fanMin: 60,
      fanMax: 100,
      colorHex: '#00AE42',
    );

    final result = await slicer.slicePlate(
      plate: plate,
      printer: printer,
      globalProcess: const ProcessSettings(name: '0.20mm Standard'),
      filaments: const [
        AmsProjectFilament(slotIndex: 0, profile: fil, customColorHex: '#00AE42'),
      ],
      flushMultiplier: 1.0,
      preferCliBridge: false,
    );

    expect(result.layers.isNotEmpty, isTrue);
    expect(result.totalSeconds, greaterThan(0));
    expect(result.totalGrams, greaterThan(0));
    expect(result.gcodeText, contains('G1'));
  });

  testWidgets('BambuStudioApp loads real assets and navigates across all 7 tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BambuStudioApp());
    // Allow async rootBundle asset loading (printers, filaments, processes, HMS, Bambu_Cube.stl)
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // App bar & Prepare view loaded with real Bambu_Cube.stl
    expect(find.text('Bambu Studio'), findsWidgets);
    expect(find.text('Slice Plate'), findsOneWidget);

    // Tap Slice Plate -> slices on-device & navigates to Preview
    await tester.ensureVisible(find.text('Slice Plate'));
    await tester.tap(find.text('Slice Plate'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Print Plate'), findsOneWidget);

    Future<void> pumpTransition() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
    }

    // Navigate to Device tab via bottom NavigationBar
    await tester.tap(find.text('Device').last);
    await pumpTransition();
    expect(find.text('Active Printer'), findsOneWidget);
    expect(find.text('Print Speed Mode'), findsOneWidget);

    // Navigate to Multi-Device Farm tab via More sheet
    await tester.tap(find.text('More'));
    await pumpTransition();
    await tester.tap(find.text('Multi-Device Print Farm'));
    await pumpTransition();
    expect(find.text('Multi-Device Print Farm'), findsOneWidget);

    // Navigate to Project tab via More sheet
    await tester.tap(find.text('More'));
    await pumpTransition();
    await tester.tap(find.text('Project (3MF Metadata, BOM & Assembly)'));
    await pumpTransition();
    expect(find.text('3MF Project Overview & Metadata'), findsOneWidget);

    // Navigate to Calibration tab via More sheet
    await tester.tap(find.text('More'));
    await pumpTransition();
    await tester.tap(find.text('Calibration Center (PA, Flow, Temp, Retraction)'));
    await pumpTransition();
    expect(find.text('Bambu Studio Calibration Center'), findsOneWidget);

    // Navigate to Home tab via bottom NavigationBar
    await tester.tap(find.text('Home').last);
    await pumpTransition();
    expect(find.text('Bambu Studio Mobile'), findsOneWidget);
  });
}
