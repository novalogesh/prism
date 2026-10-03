import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism/core/models/hazard_report.dart';
import 'package:prism/core/storage/report_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

HazardReport _report(String id, {double? latitude, double? longitude}) {
  final now = DateTime.utc(2026, 10, 3, 9);
  return HazardReport(
    id: id,
    hazardType: 'FLOODED ROAD',
    severity: 'HIGH',
    description: 'test $id',
    capturedAt: now,
    createdAt: now,
    latitude: latitude,
    longitude: longitude,
  );
}

// jsonEncode throws on NaN, so this report fails inside a real write
// (after the read, before anything is stored).
HazardReport _unencodableReport(String id) =>
    _report(id, latitude: double.nan, longitude: 80.0);

Future<Set<String>> _storedIds() async {
  final reports = await ReportStorage().getReports();
  return reports.map((report) => report.id).toSet();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('serialised writes', () {
    test('50 concurrent saves across several instances all persist', () async {
      final instances = List.generate(5, (_) => ReportStorage());

      await Future.wait([
        for (var i = 0; i < 50; i++)
          instances[i % instances.length].saveReport(_report('r$i')),
      ]);

      expect(await _storedIds(), {for (var i = 0; i < 50; i++) 'r$i'});
    });

    test('interleaved saves and deletes leave the expected set', () async {
      final a = ReportStorage();
      final b = ReportStorage();
      await a.saveReport(_report('one'));
      await a.saveReport(_report('two'));
      await a.saveReport(_report('three'));

      await Future.wait([
        a.deleteReport('two'),
        b.saveReport(_report('four')),
        a.saveReport(_report('five')),
        b.deleteReport('one'),
      ]);

      expect(await _storedIds(), {'three', 'four', 'five'});
    });

    test('saving an existing id replaces it without duplicating', () async {
      final storage = ReportStorage();
      await Future.wait([
        storage.saveReport(_report('same')),
        ReportStorage().saveReport(_report('same')),
      ]);

      final reports = await storage.getReports();
      expect(reports.where((report) => report.id == 'same'), hasLength(1));
    });
  });

  group('failure handling', () {
    test('a failed save propagates its error and stores nothing', () async {
      final storage = ReportStorage();
      await storage.saveReport(_report('kept'));

      await expectLater(
        storage.saveReport(_unencodableReport('bad')),
        throwsA(anything),
      );

      expect(await _storedIds(), {'kept'});
    });

    test('the queue keeps running after a failed write', () async {
      final storage = ReportStorage();

      final failing = storage.saveReport(_unencodableReport('bad'));
      final following = ReportStorage().saveReport(_report('after'));

      await expectLater(failing, throwsA(anything));
      await following;
      await storage.saveReport(_report('later'));

      expect(await _storedIds(), {'after', 'later'});
    });
  });

  group('change signal', () {
    late int notifications;
    void onChange() => notifications++;

    setUp(() {
      notifications = 0;
      ReportStorage.changes.addListener(onChange);
    });

    tearDown(() {
      ReportStorage.changes.removeListener(onChange);
    });

    test('fires once per successful save, delete and clear', () async {
      final storage = ReportStorage();

      await storage.saveReport(_report('x'));
      expect(notifications, 1);

      await storage.deleteReport('x');
      expect(notifications, 2);

      await storage.saveReport(_report('y'));
      await storage.clearAll();
      expect(notifications, 4);
    });

    test('does not fire for a failed write', () async {
      final storage = ReportStorage();

      await expectLater(
        storage.saveReport(_unencodableReport('bad')),
        throwsA(anything),
      );

      expect(notifications, 0);
    });

    test('a listener reloading on change sees the committed data', () async {
      final storage = ReportStorage();
      final loaded = Completer<Set<String>>();
      void reload() {
        storage.getReports().then((reports) {
          if (!loaded.isCompleted) {
            loaded.complete(reports.map((report) => report.id).toSet());
          }
        });
      }

      ReportStorage.changes.addListener(reload);
      addTearDown(() => ReportStorage.changes.removeListener(reload));

      await storage.saveReport(_report('visible'));

      expect(
        await loaded.future.timeout(const Duration(seconds: 2)),
        {'visible'},
      );
    });
  });

  group('storage format', () {
    test('keeps the prism_reports key and existing JSON fields', () async {
      final storage = ReportStorage();
      await storage.saveReport(
        _report('format', latitude: 13.4, longitude: 80.1),
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('prism_reports');
      expect(raw, isNotNull);

      final decoded = jsonDecode(raw!) as List;
      expect(decoded, hasLength(1));
      final json = Map<String, dynamic>.from(decoded.single as Map);
      expect(json['id'], 'format');
      expect(json['hazardType'], 'FLOODED ROAD');
      expect(json['severity'], 'HIGH');
      expect(json['latitude'], 13.4);
      expect(json['syncState'], 'UNSYNCED');
      expect(json['lifecycleStatus'], 'UNDER_REVIEW');
    });

    test('clearAll removes the stored key', () async {
      final storage = ReportStorage();
      await storage.saveReport(_report('gone'));
      await storage.clearAll();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('prism_reports'), isFalse);
      expect(await storage.getReports(), isEmpty);
    });
  });
}
