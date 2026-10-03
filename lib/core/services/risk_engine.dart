import '../models/hazard_report.dart';
import '../models/hazard_type.dart';

/// Calculates PRISM hazard risk from information currently
/// available in a HazardReport.
///
/// The engine returns a normalized score from 0.0 to 1.0.
/// It is intentionally transparent so each factor can be
/// explained during product evaluation.
class RiskEngine {
  const RiskEngine();

  /// Returns the final normalized risk score.
  ///
  /// [now] is the reference time used to age the report for freshness. It
  /// defaults to [DateTime.now]; pass a fixed value to evaluate the same
  /// report deterministically (tests, or scoring many hazards in one pass).
  double calculateRisk(HazardReport report, {DateTime? now}) {
    final referenceTime = now ?? DateTime.now();

    final severity = _severityScore(report.hazardType, report.severity);
    final freshness = _freshnessScore(report.capturedAt, referenceTime);
    final uncertainty = _uncertaintyScore(report);

    // V1 weights use only information currently available
    // in the existing HazardReport model.
    //
    // Severity is dominant because hazard type is currently
    // the strongest available risk signal.
    const severityWeight = 0.60;
    const freshnessWeight = 0.25;
    const uncertaintyWeight = 0.15;

    final score =
        (severity * severityWeight) +
        (freshness * freshnessWeight) +
        (uncertainty * uncertaintyWeight);

    return score.clamp(0.0, 1.0);
  }

  /// Converts the numerical score into a user-facing category.
  String riskCategory(double score) {
    if (score >= 0.75) {
      return 'CRITICAL';
    }

    if (score >= 0.50) {
      return 'HIGH';
    }

    if (score >= 0.25) {
      return 'MODERATE';
    }

    return 'LOW';
  }

  double _severityScore(String hazardType, String? selectedSeverity) {
    switch (selectedSeverity?.trim().toUpperCase()) {
      case 'LOW':
        return 0.25;
      case 'MODERATE':
        return 0.50;
      case 'HIGH':
        return 0.75;
      case 'CRITICAL':
        return 1.00;
    }

    // Legacy reports and reports left at "ASSESS RISK" use the existing
    // hazard-type-derived severity rather than an invented stored value.
    switch (canonicalHazardTypeName(hazardType)) {
      case 'ELECTRIC HAZARD':
        return 1.00;

      case 'OPEN MANHOLE':
        return 0.95;

      case 'FLOODED ROAD':
        return 0.90;

      case 'DAMAGED ROAD':
        return 0.65;

      case 'FALLEN TREE':
        return 0.60;

      case 'WATER LOGGING':
      case 'WATERLOGGING':
        return 0.55;

      default:
        return 0.35;
    }
  }

  double _freshnessScore(DateTime capturedAt, DateTime referenceTime) {
    final age = referenceTime.difference(capturedAt).inHours;

    if (age <= 1) {
      return 1.00;
    }

    if (age <= 6) {
      return 0.90;
    }

    if (age <= 12) {
      return 0.75;
    }

    if (age <= 24) {
      return 0.60;
    }

    if (age <= 48) {
      return 0.40;
    }

    if (age <= 72) {
      return 0.20;
    }

    return 0.05;
  }

  double _uncertaintyScore(HazardReport report) {
    // A nearby-shared report has an additional signal.
    // Until real YES/NO community verification exists,
    // this remains deliberately simple.
    if (report.sharedNearby) {
      return 0.20;
    }

    if (report.lifecycleStatus == HazardLifecycleStatus.active) {
      return 0.10;
    }

    return 0.50;
  }
}
