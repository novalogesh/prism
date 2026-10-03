import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hazard_report.dart';

class ReportStorage {
  static const String _storageKey = 'prism_reports';

  // ReportStorage is instantiated in several places (report, reports and map
  // pages, NearbyReportService), so write ordering and change notification
  // are static: they must be shared by every instance.
  static Future<void> _writeQueue = Future<void>.value();
  static final ValueNotifier<int> _changes = ValueNotifier<int>(0);

  /// Increments after every successful write (save, delete, clear).
  ///
  /// Listeners should reload via [getReports]; the value itself carries no
  /// meaning beyond "something changed". Failed writes never notify.
  static ValueListenable<int> get changes => _changes;

  /// Runs [operation] after every previously queued write has finished.
  ///
  /// An error from [operation] is returned to its caller, and does not stop
  /// later queued writes from running.
  static Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

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

  Future<void> saveReport(HazardReport report) {
    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();

      final reports = await getReports();

      reports.removeWhere(
        (item) => item.id == report.id,
      );

      reports.add(report);

      final written = await prefs.setString(
        _storageKey,
        jsonEncode(
          reports.map((item) => item.toJson()).toList(),
        ),
      );

      if (written) _changes.value++;
    });
  }

  Future<void> deleteReport(String id) {
    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();

      final reports = await getReports();

      reports.removeWhere(
        (item) => item.id == id,
      );

      final written = await prefs.setString(
        _storageKey,
        jsonEncode(
          reports.map((item) => item.toJson()).toList(),
        ),
      );

      if (written) _changes.value++;
    });
  }

  Future<void> clearAll() {
    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();

      final removed = await prefs.remove(_storageKey);

      if (removed) _changes.value++;
    });
  }
}
