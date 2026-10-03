import 'package:flutter_test/flutter_test.dart';
import 'package:prism/core/models/hazard_report.dart';
import 'package:prism/core/services/risk_engine.dart';
import 'package:prism/features/map/utils/hazard_report_mapper.dart';

final _capturedAt = DateTime.now();

Map<String, dynamic> _legacyJson(
  String? status, {
  bool includeStatus = true,
  bool sharedNearby = false,
}) {
  return {
    'id': 'lifecycle-report',
    'hazardType': 'OPEN MANHOLE',
    'description': 'Test report',
    'capturedAt': _capturedAt.toIso8601String(),
    'createdAt': _capturedAt.toIso8601String(),
    'latitude': 13.0827,
    'longitude': 80.2707,
    'sharedNearby': sharedNearby,
    if (includeStatus) 'status': status,
  };
}

HazardReport _legacyReport(
  String? status, {
  bool includeStatus = true,
  bool sharedNearby = false,
}) {
  return HazardReport.fromJson(
    _legacyJson(
      status,
      includeStatus: includeStatus,
      sharedNearby: sharedNearby,
    ),
  );
}

void main() {
  test('new reports default to unsynced and under review', () {
    final report = HazardReport(
      id: 'new-report',
      hazardType: 'OPEN MANHOLE',
      description: '',
      capturedAt: _capturedAt,
      createdAt: _capturedAt,
    );

    expect(report.syncState, ReportSyncState.unsynced);
    expect(report.lifecycleStatus, HazardLifecycleStatus.underReview);
    expect(report.toJson()['syncState'], 'UNSYNCED');
    expect(report.toJson()['lifecycleStatus'], 'UNDER_REVIEW');
  });

  test('legacy synchronization statuses migrate independently', () {
    final cases = {
      'UNSYNCED': (ReportSyncState.unsynced, HazardLifecycleStatus.underReview),
      'SYNCED': (ReportSyncState.synced, HazardLifecycleStatus.underReview),
      'SHARED': (ReportSyncState.shared, HazardLifecycleStatus.underReview),
    };

    for (final entry in cases.entries) {
      final report = _legacyReport(entry.key);
      expect(report.syncState, entry.value.$1, reason: entry.key);
      expect(report.lifecycleStatus, entry.value.$2, reason: entry.key);
    }
  });

  test('legacy lifecycle statuses default sync state to unsynced', () {
    final cases = {
      'ACTIVE': HazardLifecycleStatus.active,
      'VERIFIED': HazardLifecycleStatus.active,
      'UNDER REVIEW': HazardLifecycleStatus.underReview,
      'UNDER_REVIEW': HazardLifecycleStatus.underReview,
      'RESOLVED': HazardLifecycleStatus.resolved,
      'CLOSED': HazardLifecycleStatus.resolved,
      'EXPIRED': HazardLifecycleStatus.expired,
    };

    for (final entry in cases.entries) {
      final report = _legacyReport(entry.key);
      expect(report.syncState, ReportSyncState.unsynced, reason: entry.key);
      expect(report.lifecycleStatus, entry.value, reason: entry.key);
    }
  });

  test('unknown and missing legacy status use approved defaults', () {
    final unknown = _legacyReport('SOMETHING_NEW');
    final missing = _legacyReport(null, includeStatus: false);

    for (final report in [unknown, missing]) {
      expect(report.syncState, ReportSyncState.unsynced);
      expect(report.lifecycleStatus, HazardLifecycleStatus.underReview);
    }
  });

  test('explicit independent fields take precedence over legacy status', () {
    final report = HazardReport.fromJson({
      ..._legacyJson('EXPIRED'),
      'syncState': 'SHARED',
      'lifecycleStatus': 'ACTIVE',
    });

    expect(report.syncState, ReportSyncState.shared);
    expect(report.lifecycleStatus, HazardLifecycleStatus.active);
    expect(report.toJson()['syncState'], 'SHARED');
    expect(report.toJson()['lifecycleStatus'], 'ACTIVE');
    expect(report.toJson()['status'], 'SHARED');
  });

  test('explicit lifecycle state overrides conflicting legacy risk status', () {
    final report = HazardReport.fromJson({
      ..._legacyJson('ACTIVE'),
      'syncState': 'UNSYNCED',
      'lifecycleStatus': 'UNDER_REVIEW',
    });
    final legacyConstructorReport = HazardReport(
      id: 'legacy-constructor',
      hazardType: 'OPEN MANHOLE',
      description: '',
      capturedAt: _capturedAt,
      createdAt: _capturedAt,
      status: 'ACTIVE',
    );
    final engine = const RiskEngine();

    expect(report.lifecycleStatus, HazardLifecycleStatus.underReview);
    expect(engine.calculateRisk(report), closeTo(0.895, 1e-9));
    expect(
      legacyConstructorReport.lifecycleStatus,
      HazardLifecycleStatus.active,
    );
    expect(engine.calculateRisk(legacyConstructorReport), closeTo(0.835, 1e-9));
  });

  test('each explicit field overrides only its own legacy-derived field', () {
    final explicitSync = HazardReport.fromJson({
      ..._legacyJson('CLOSED'),
      'syncState': 'SYNCED',
    });
    final explicitLifecycle = HazardReport.fromJson({
      ..._legacyJson('SHARED'),
      'lifecycleStatus': 'EXPIRED',
    });

    expect(explicitSync.syncState, ReportSyncState.synced);
    expect(explicitSync.lifecycleStatus, HazardLifecycleStatus.resolved);
    expect(explicitLifecycle.syncState, ReportSyncState.shared);
    expect(explicitLifecycle.lifecycleStatus, HazardLifecycleStatus.expired);
  });

  test('sharedNearby remains persisted and retains existing risk effect', () {
    final report = _legacyReport('SHARED', sharedNearby: true);
    final restored = HazardReport.fromJson(report.toJson());
    final engine = const RiskEngine();
    final notNearbyShared = HazardReport.fromJson(_legacyJson('UNSYNCED'));

    expect(restored.sharedNearby, isTrue);
    expect(restored.syncState, ReportSyncState.shared);
    expect(
      engine.calculateRisk(restored),
      closeTo(0.85, 1e-9),
    );
    expect(
      engine.calculateRisk(notNearbyShared),
      closeTo(0.895, 1e-9),
    );
  });

  test('map visibility depends on lifecycle and not synchronization state', () {
    const syncStates = ['UNSYNCED', 'SYNCED', 'SHARED'];
    const lifecycleStates = {
      'UNDER_REVIEW': ('UNDER REVIEW', true),
      'ACTIVE': ('ACTIVE', true),
      'RESOLVED': ('RESOLVED', false),
      'EXPIRED': ('EXPIRED', false),
    };
    final mapperRiskEngine = const RiskEngine();

    for (final syncState in syncStates) {
      for (final entry in lifecycleStates.entries) {
        final report = HazardReport.fromJson({
          ..._legacyJson('UNSYNCED'),
          'syncState': syncState,
          'lifecycleStatus': entry.key,
        });
        final hazard = mapHazardFromReport(report, mapperRiskEngine);

        expect(hazard.lifecycleLabel, entry.value.$1);
        expect(
          hazard.isVisibleOnMap,
          entry.value.$2,
          reason: '$syncState / ${entry.key}',
        );
      }
    }
  });

  test('lifecycle migration preserves representative existing risk outputs', () {
    final engine = const RiskEngine();
    final underReview = _legacyReport('UNSYNCED');
    final activeLegacy = _legacyReport('ACTIVE');
    final verifiedLegacy = _legacyReport('VERIFIED');
    final explicitActive = HazardReport.fromJson({
      ..._legacyJson('UNSYNCED'),
      'lifecycleStatus': 'ACTIVE',
    });
    final syncedUnderReview = _legacyReport('SYNCED');
    final sharedUnderReview = _legacyReport('SHARED');

    expect(engine.calculateRisk(underReview), closeTo(0.895, 1e-9));
    expect(engine.calculateRisk(activeLegacy), closeTo(0.835, 1e-9));
    expect(engine.calculateRisk(verifiedLegacy), closeTo(0.835, 1e-9));
    expect(engine.calculateRisk(explicitActive), closeTo(0.835, 1e-9));
    expect(
      engine.calculateRisk(syncedUnderReview),
      closeTo(engine.calculateRisk(underReview), 1e-9),
    );
    expect(
      engine.calculateRisk(sharedUnderReview),
      closeTo(engine.calculateRisk(underReview), 1e-9),
    );
  });
}