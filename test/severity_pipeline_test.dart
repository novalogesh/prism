import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism/core/models/hazard_report.dart';
import 'package:prism/core/services/risk_engine.dart';
import 'package:prism/core/storage/report_storage.dart';
import 'package:prism/features/map/models/hazard.dart';
import 'package:prism/features/map/utils/hazard_report_mapper.dart';
import 'package:prism/features/reports/report_details_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const severities = ['LOW', 'MODERATE', 'HIGH', 'CRITICAL'];
  const expectedScores = [0.475, 0.625, 0.775, 0.925];
  const expectedRiskLevels = [
    RiskLevel.moderate,
    RiskLevel.high,
    RiskLevel.critical,
    RiskLevel.critical,
  ];

  late List<HazardReport> savedReports;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = ReportStorage();
    final now = DateTime.now();

    for (var index = 0; index < severities.length; index++) {
      await storage.saveReport(
        HazardReport(
          id: 'severity-$index',
          hazardType: 'OPEN MANHOLE',
          severity: severities[index],
          description: 'Test hazard',
          capturedAt: now,
          latitude: 13.0827,
          longitude: 80.2707,
          createdAt: now,
        ),
      );
    }

    savedReports = await storage.getReports();
  });

  test('all selected values survive storage and map conversion', () {
    final engine = const RiskEngine();
    final hazards = savedReports
        .map((report) => mapHazardFromReport(report, engine))
        .toList();

    expect(savedReports.map((report) => report.severity), severities);
    expect(hazards.map((hazard) => hazard.selectedSeverity), severities);

    for (var index = 0; index < severities.length; index++) {
      expect(hazards[index].riskScore, closeTo(expectedScores[index], 1e-9));
      expect(hazards[index].riskLevel, expectedRiskLevels[index]);
    }

    expect(hazards[2].selectedSeverity, 'HIGH');
    expect(hazards[2].riskLevel, RiskLevel.critical);
  });

  for (final severity in severities) {
    testWidgets('saved report details display $severity severity', (
      tester,
    ) async {
      final report = savedReports.firstWhere(
        (item) => item.severity == severity,
      );

      await tester.pumpWidget(
        MaterialApp(home: ReportDetailsPage(report: report)),
      );

      expect(find.text(severity), findsOneWidget);
    });
  }
}