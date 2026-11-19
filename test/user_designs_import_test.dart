import 'dart:io';
import 'package:bambu_studio_flutter/data/services/stl_parser_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tiltPath =
      r'C:/Users/MJ/.gemini/antigravity/brain/b467175c-d660-42e9-814d-dcc25d51e361/.user_uploaded/media_1795008208193_66a0352f.3mf';
  const scraperPath =
      r'C:/Users/MJ/.gemini/antigravity/brain/b467175c-d660-42e9-814d-dcc25d51e361/.user_uploaded/media_1795008208207_fc6e7779.3mf';
  const clipPath =
      r'C:/Users/MJ/.gemini/antigravity/brain/b467175c-d660-42e9-814d-dcc25d51e361/.user_uploaded/media_1795008208187_57e82d02.3mf';

  test('TILT_PHONE_STAND_V3.0.3mf parses accurately as multi-object desktop Bambu Studio project', () {
    final file = File(tiltPath);
    expect(file.existsSync(), isTrue, reason: 'Attached tilt stand file should exist');
    final bytes = file.readAsBytesSync();

    final result = parseModelFileIsolate({
      'bytes': bytes,
      'fileName': 'TILT_PHONE_STAND_V3.0.3mf',
      'defaultBedX': 256,
      'defaultBedY': 256,
      'maxPlateTriangles': 14000,
    });

    expect(result.isFullProject, isTrue);
    expect(result.plates.isNotEmpty, isTrue);
    final p1 = result.plates.first;
    expect(p1.objects.length, equals(5), reason: 'Desktop Bambu Studio has exactly 5 separate objects on Plate 1');
    expect(result.totalSourceTriangles, greaterThan(200000));
    expect(result.totalRenderedTriangles, lessThanOrEqualTo(20000));
    expect(result.printerModel, contains('P1P'));
    expect(result.filamentColors, contains('#004B7C'));
    expect(result.filamentTypes, contains('PLA'));
    expect(result.bedX, equals(256));
    expect(result.bedY, equals(256));

    final names = p1.objects.map((o) => o.name).toList();
    expect(names, contains('01_Stand.stl'));
    expect(names, contains('02_Gear.stl'));
    expect(names, contains('03_Base.stl'));
    expect(names, contains('04_Adjustable_Gear.stl'));
    expect(names, contains('5_Screw.stl'));
  });

  test('scraper_30cm_rod_6cm_handle_A1mini.3mf parses accurately with 6 objects on A1 mini bed', () {
    final file = File(scraperPath);
    expect(file.existsSync(), isTrue, reason: 'Attached scraper file should exist');
    final bytes = file.readAsBytesSync();

    final result = parseModelFileIsolate({
      'bytes': bytes,
      'fileName': 'scraper_30cm_rod_6cm_handle_A1mini.3mf',
      'defaultBedX': 256,
      'defaultBedY': 256,
      'maxPlateTriangles': 14000,
    });

    expect(result.isFullProject, isTrue);
    expect(result.plates.isNotEmpty, isTrue);
    final p1 = result.plates.first;
    expect(p1.objects.length, equals(6), reason: 'Desktop Bambu Studio has 6 modular scraper rod parts');
    expect(result.printerModel, contains('A1 mini'));
    expect(result.bedX, equals(180), reason: 'A1 mini bed X must be 180mm');
    expect(result.bedY, equals(180), reason: 'A1 mini bed Y must be 180mm');
    expect(result.filamentTypes, contains('PETG'));
    expect(result.filamentColors, contains('#000000'));
    expect(result.totalSourceTriangles, equals(35246));

    final names = p1.objects.map((o) => o.name).toList();
    expect(names, contains('Original_Scraper_Main_Body'));
    expect(names, contains('Original_Scraper_Blade_Plate'));
    expect(names, contains('Rod_Segment_A_168mm_including_head_pin'));
    expect(names, contains('Rod_Segment_B_165mm_including_handle_pin'));
    expect(names, contains('Centre_Coupler_Sleeve_25mm'));
    expect(names, contains('Grip_Handle_60mm'));
  });

  test('exact_photo_wall_mounting_clip.3mf parses cleanly as single-object plate', () {
    final file = File(clipPath);
    expect(file.existsSync(), isTrue, reason: 'Attached clip file should exist');
    final bytes = file.readAsBytesSync();

    final result = parseModelFileIsolate({
      'bytes': bytes,
      'fileName': 'exact_photo_wall_mounting_clip.3mf',
      'defaultBedX': 180,
      'defaultBedY': 180,
      'maxPlateTriangles': 14000,
    });

    expect(result.plates.isNotEmpty, isTrue);
    final p1 = result.plates.first;
    expect(p1.objects.length, equals(1));
    expect(p1.objects.first.name, equals('exact_photo_wall_mounting_clip'));
    expect(result.totalSourceTriangles, equals(428));
  });
}
