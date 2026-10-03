import 'package:flutter_test/flutter_test.dart';
import 'package:prism/core/storage/report_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('skips malformed entries and preserves valid legacy report data', () async {
    final capturedAt = DateTime.utc(2026, 9, 20, 8, 30);
    final createdAt = DateTime.utc(2026, 9, 20, 8, 31);
    SharedPreferences.setMockInitialValues({
      'prism_reports': '''
[
  {
    "id": "report-1",
    "hazardType": "FLOOD",
    "severity": "HIGH",
    "description": "Flooded underpass",
    "photoPath": "/photos/one.jpg",
    "capturedAt": "${capturedAt.toIso8601String()}",
    "latitude": 13.0827,
    "longitude": 80.2707,
    "locationName": "Main Road",
    "reporterAddress": "Near station",
    "status": "UNSYNCED",
    "sharedNearby": false,
    "createdAt": "${createdAt.toIso8601String()}"
  },
  {"id": "broken", "hazardType": "DAMAGED ROAD", "capturedAt": "bad-date"},
  {
    "id": "report-2",
    "hazardType": "ELECTRICAL",
    "description": "Wire on road",
    "capturedAt": "${capturedAt.add(const Duration(hours: 1)).toIso8601String()}",
    "createdAt": "${createdAt.add(const Duration(hours: 1)).toIso8601String()}"
  }
]
''',
    });

    final reports = await ReportStorage().getReports();

    expect(reports.map((report) => report.id), ['report-1', 'report-2']);
    expect(reports.first.hazardType, 'FLOODED ROAD');
    expect(reports.first.severity, 'HIGH');
    expect(reports.first.capturedAt, capturedAt);
    expect(reports.first.createdAt, createdAt);
    expect(reports.first.latitude, 13.0827);
    expect(reports.first.longitude, 80.2707);
    expect(reports.first.photoPath, '/photos/one.jpg');
    expect(reports.first.locationName, 'Main Road');
    expect(reports.first.reporterAddress, 'Near station');

    expect(reports.last.hazardType, 'ELECTRIC HAZARD');
    expect(reports.last.severity, isNull);
    expect(reports.last.latitude, isNull);
    expect(reports.last.status, 'UNSYNCED');
    expect(reports.last.sharedNearby, isFalse);
  });
}