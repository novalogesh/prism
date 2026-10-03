import 'dart:convert';

import '../../core/models/hazard_report.dart';
import '../../core/storage/report_storage.dart';

class NearbyReportService {
  final ReportStorage _storage;

  NearbyReportService({
    ReportStorage? storage,
  }) : _storage = storage ?? ReportStorage();

  String createSharePacket(HazardReport report) {
    return jsonEncode({
      'type': 'PRISM_HAZARD_REPORT',
      'version': 1,
      'report': report.toJson(),
    });
  }

  Future<HazardReport?> receiveSharePacket(
    String packet,
  ) async {
    try {
      final decoded =
          jsonDecode(packet) as Map<String, dynamic>;

      if (decoded['type'] != 'PRISM_HAZARD_REPORT') {
        return null;
      }

      if (decoded['version'] != 1) {
        return null;
      }

      final reportData =
          Map<String, dynamic>.from(
        decoded['report'] as Map,
      );

      final report = HazardReport.fromJson(reportData);

      await _storage.saveReport(report);

      return report;
    } catch (_) {
      return null;
    }
  }

  Future<void> markShared(
    HazardReport report,
  ) async {
    final updated = HazardReport(
      id: report.id,
      hazardType: report.hazardType,
      severity: report.severity,
      description: report.description,
      photoPath: report.photoPath,
      capturedAt: report.capturedAt,
      latitude: report.latitude,
      longitude: report.longitude,
      status: 'SHARED',
      sharedNearby: true,
      createdAt: report.createdAt,
      syncState: ReportSyncState.shared,
      lifecycleStatus: report.lifecycleStatus,
    );

    await _storage.saveReport(updated);
  }
}
