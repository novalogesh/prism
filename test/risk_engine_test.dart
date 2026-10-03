import 'package:flutter_test/flutter_test.dart';
import 'package:prism/core/models/hazard_report.dart';
import 'package:prism/core/services/risk_engine.dart';

HazardReport _report({
  required String hazardType,
  String? severity,
  DateTime? capturedAt,
}) {
  final now = DateTime.now();
  return HazardReport(
    id: 'test-report',
    hazardType: hazardType,
    severity: severity,
    description: '',
    capturedAt: capturedAt ?? now,
    createdAt: capturedAt ?? now,
  );
}

void main() {
  test('selected severity round-trips through report JSON', () {
    final original = _report(
      hazardType: 'OPEN MANHOLE',
      severity: 'LOW',
    );

    final restored = HazardReport.fromJson(original.toJson());

    expect(restored.severity, 'LOW');
    expect(restored.id, original.id);
    expect(restored.capturedAt, original.capturedAt);
    expect(restored.createdAt, original.createdAt);
  });

  test('explicit report severity is used in the existing risk formula', () {
    final engine = const RiskEngine();
    final report = _report(
      hazardType: 'OPEN MANHOLE',
      severity: 'LOW',
    );

    expect(engine.calculateRisk(report), closeTo(0.475, 1e-9));
  });

  test('legacy report without severity retains type-derived risk', () {
    final engine = const RiskEngine();
    final report = HazardReport.fromJson({
      'id': 'legacy-report',
      'hazardType': 'OPEN MANHOLE',
      'description': '',
      'capturedAt': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    });

    expect(report.severity, isNull);
    expect(engine.calculateRisk(report), closeTo(0.895, 1e-9));
  });

  test('RiskEngine accepts old FLOOD and ELECTRICAL type labels', () {
    final engine = const RiskEngine();

    expect(
      engine.calculateRisk(_report(hazardType: 'FLOOD')),
      closeTo(engine.calculateRisk(_report(hazardType: 'FLOODED ROAD')), 1e-9),
    );
    expect(
      engine.calculateRisk(_report(hazardType: 'ELECTRICAL')),
      closeTo(
        engine.calculateRisk(_report(hazardType: 'ELECTRIC HAZARD')),
        1e-9,
      ),
    );
  });
}