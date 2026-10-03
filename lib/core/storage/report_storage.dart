import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hazard_report.dart';

class ReportStorage {
  static const String _storageKey = 'prism_reports';

  Future<List<HazardReport>> getReports() async {
    final prefs = await SharedPreferences.getInstance();

    final content = prefs.getString(_storageKey);

    if (content == null || content.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(content) as List;

      final reports = <HazardReport>[];
      for (final item in decoded) {
        if (item is! Map) continue;

        try {
          reports.add(
            HazardReport.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          // Skip this malformed entry without discarding valid reports.
        }
      }

      return reports;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveReport(HazardReport report) async {
    final prefs = await SharedPreferences.getInstance();

    final reports = await getReports();

    reports.removeWhere(
      (item) => item.id == report.id,
    );

    reports.add(report);

    await prefs.setString(
      _storageKey,
      jsonEncode(
        reports.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> deleteReport(String id) async {
    final prefs = await SharedPreferences.getInstance();

    final reports = await getReports();

    reports.removeWhere(
      (item) => item.id == id,
    );

    await prefs.setString(
      _storageKey,
      jsonEncode(
        reports.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);
  }
}
