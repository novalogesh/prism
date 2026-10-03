import 'package:flutter_test/flutter_test.dart';
import 'package:prism/core/models/hazard_report.dart';
import 'package:prism/core/services/risk_engine.dart';
import 'package:prism/features/map/models/hazard.dart';
import 'package:prism/features/map/utils/hazard_report_mapper.dart';

// Fixed fixture: severity HIGH (0.75), UNDER_REVIEW, not shared nearby
// (uncertainty 0.50). With the existing weights the score is
//
//   0.60 * 0.75 + 0.25 * freshness + 0.15 * 0.50 = 0.525 + 0.25 * freshness
//
// so each freshness band maps to one exact expected score.
final _freshnessToScore = <double, double>{
  1.00: 0.775,
  0.90: 0.75,
  0.75: 0.7125,
  0.60: 0.675,
  0.40: 0.625,
  0.20: 0.575,
  0.05: 0.5375,
};

double _scoreFor(double freshness) => _freshnessToScore[freshness]!;

HazardReport _report(DateTime capturedAt) {
  return HazardReport(
    id: 'clock-test',
    hazardType: 'FLOODED ROAD',
    severity: 'HIGH',
    description: 'fixed clock fixture',
    capturedAt: capturedAt,
    createdAt: capturedAt,
    latitude: 13.402,
    longitude: 80.138,
  );
}

void main() {
  const engine = RiskEngine();
  final now = DateTime.utc(2026, 10, 3, 12);

  group('same report, different reference times', () {
    final capturedAt = DateTime.utc(2026, 10, 3, 8);
    final report = _report(capturedAt);

    test('risk falls as the supplied reference time moves later', () {
      final fresh = engine.calculateRisk(
        report,
        now: capturedAt.add(const Duration(minutes: 30)),
      );
      final aged = engine.calculateRisk(
        report,
        now: capturedAt.add(const Duration(hours: 10)),
      );
      final stale = engine.calculateRisk(
        report,
        now: capturedAt.add(const Duration(hours: 100)),
      );

      expect(fresh, closeTo(_scoreFor(1.00), 1e-9));
      expect(aged, closeTo(_scoreFor(0.75), 1e-9));
      expect(stale, closeTo(_scoreFor(0.05), 1e-9));
      expect(fresh, greaterThan(aged));
      expect(aged, greaterThan(stale));
    });

    test('the same reference time always gives the same score', () {
      final reference = capturedAt.add(const Duration(hours: 20));

      final first = engine.calculateRisk(report, now: reference);
      final second = engine.calculateRisk(report, now: reference);

      expect(second, first);
      expect(first, closeTo(_scoreFor(0.60), 1e-9));
    });
  });

  group('freshness boundaries', () {
    // RiskEngine compares whole hours (Duration.inHours truncates), so each
    // band ends one hour boundary later than its label suggests: an age of
    // 1h59m59s still counts as 1 hour. These cases pin that existing
    // behaviour exactly rather than changing it.
    const almostHour = Duration(minutes: 59, seconds: 59);

    final cases = <(String, Duration, double)>[
      ('0 minutes', Duration.zero, 1.00),
      ('exactly 1 hour', const Duration(hours: 1), 1.00),
      ('1h59m59s (truncates to 1 hour)',
          const Duration(hours: 1) + almostHour, 1.00),
      ('2 hours', const Duration(hours: 2), 0.90),
      ('exactly 6 hours', const Duration(hours: 6), 0.90),
      ('6h59m59s (truncates to 6 hours)',
          const Duration(hours: 6) + almostHour, 0.90),
      ('7 hours', const Duration(hours: 7), 0.75),
      ('exactly 12 hours', const Duration(hours: 12), 0.75),
      ('12h59m59s (truncates to 12 hours)',
          const Duration(hours: 12) + almostHour, 0.75),
      ('13 hours', const Duration(hours: 13), 0.60),
      ('exactly 24 hours', const Duration(hours: 24), 0.60),
      ('24h59m59s (truncates to 24 hours)',
          const Duration(hours: 24) + almostHour, 0.60),
      ('25 hours', const Duration(hours: 25), 0.40),
      ('exactly 48 hours', const Duration(hours: 48), 0.40),
      ('48h59m59s (truncates to 48 hours)',
          const Duration(hours: 48) + almostHour, 0.40),
      ('49 hours', const Duration(hours: 49), 0.20),
      ('exactly 72 hours', const Duration(hours: 72), 0.20),
      ('72h59m59s (truncates to 72 hours)',
          const Duration(hours: 72) + almostHour, 0.20),
      ('73 hours', const Duration(hours: 73), 0.05),
      ('30 days', const Duration(days: 30), 0.05),
    ];

    for (final (label, age, freshness) in cases) {
      test('age $label gives freshness $freshness', () {
        final report = _report(now.subtract(age));

        expect(
          engine.calculateRisk(report, now: now),
          closeTo(_scoreFor(freshness), 1e-9),
        );
      });
    }
  });

  group('future capturedAt', () {
    test('still counts as maximum freshness (1.0)', () {
      for (final ahead in const [
        Duration(minutes: 1),
        Duration(hours: 5),
        Duration(days: 400),
      ]) {
        final report = _report(now.add(ahead));

        expect(
          engine.calculateRisk(report, now: now),
          closeTo(_scoreFor(1.00), 1e-9),
          reason: 'capturedAt $ahead in the future',
        );
      }
    });
  });

  group('backward compatibility', () {
    // Both cases are independent of the wall clock: a report from 2000 is
    // always older than 72 hours, and a report captured "now" is always
    // within the first freshness band.
    test('calculateRisk(report) without now still works', () {
      final ancient = _report(DateTime.utc(2000));
      final justNow = _report(DateTime.now());

      expect(engine.calculateRisk(ancient), closeTo(_scoreFor(0.05), 1e-9));
      expect(engine.calculateRisk(justNow), closeTo(_scoreFor(1.00), 1e-9));
    });

    test('passing now: null behaves like omitting it', () {
      final ancient = _report(DateTime.utc(2000));

      expect(
        engine.calculateRisk(ancient, now: null),
        engine.calculateRisk(ancient),
      );
    });

    test('RiskEngine is still constructible as a const', () {
      const first = RiskEngine();
      const second = RiskEngine();

      expect(identical(first, second), isTrue);
    });
  });

  group('mapHazardFromReport', () {
    // Captured in 2000 so that, if the supplied reference time were ignored,
    // the real clock would always make the report stale whatever day the
    // test runs.
    final capturedAt = DateTime.utc(2000);
    final report = _report(capturedAt);

    test('passes the supplied now through to RiskEngine', () {
      final fresh = mapHazardFromReport(
        report,
        engine,
        now: capturedAt.add(const Duration(minutes: 30)),
      );
      final stale = mapHazardFromReport(
        report,
        engine,
        now: capturedAt.add(const Duration(hours: 100)),
      );

      expect(fresh.riskScore, closeTo(_scoreFor(1.00), 1e-9));
      expect(fresh.riskLevel, RiskLevel.critical);
      expect(stale.riskScore, closeTo(_scoreFor(0.05), 1e-9));
      expect(stale.riskLevel, RiskLevel.high);
    });

    test('mapped score matches the engine at the same reference time', () {
      final reference = capturedAt.add(const Duration(hours: 10));

      final hazard = mapHazardFromReport(report, engine, now: reference);

      expect(
        hazard.riskScore,
        closeTo(engine.calculateRisk(report, now: reference), 1e-12),
      );
      expect(hazard.riskScore, closeTo(_scoreFor(0.75), 1e-9));
    });

    test('without now it behaves exactly as before', () {
      final hazard = mapHazardFromReport(report, engine);

      expect(hazard.riskScore, closeTo(engine.calculateRisk(report), 1e-12));
      expect(hazard.riskScore, closeTo(_scoreFor(0.05), 1e-9));
      expect(hazard.riskLevel, RiskLevel.high);
    });
  });
}
