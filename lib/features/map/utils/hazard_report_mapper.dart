import '../../../core/models/hazard_report.dart';
import '../../../core/services/risk_engine.dart';
import '../models/hazard.dart';
import 'hazard_type_mapping.dart';

Hazard mapHazardFromReport(HazardReport report, RiskEngine riskEngine) {
  final riskScore = riskEngine.calculateRisk(report);

  return Hazard(
    id: report.id,
    type: hazardTypeForReport(report.hazardType),
    status: _hazardStatus(report.lifecycleStatus),
    riskLevel: _riskLevelFromScore(riskScore),
    riskScore: riskScore,
    selectedSeverity: report.severity,
    latitude: report.latitude!,
    longitude: report.longitude!,
    title: report.hazardType.trim().isEmpty
        ? 'Reported Hazard'
        : report.hazardType,
    description: report.description,
    reportedAt: report.capturedAt,
    confirmationCount: report.sharedNearby ? 1 : 0,
    imagePath: report.photoPath,
  );
}

HazardStatus _hazardStatus(HazardLifecycleStatus status) {
  return switch (status) {
    HazardLifecycleStatus.underReview => HazardStatus.underReview,
    HazardLifecycleStatus.active => HazardStatus.active,
    HazardLifecycleStatus.resolved => HazardStatus.resolved,
    HazardLifecycleStatus.expired => HazardStatus.expired,
  };
}

RiskLevel _riskLevelFromScore(double score) {
  if (score >= 0.75) return RiskLevel.critical;
  if (score >= 0.50) return RiskLevel.high;
  if (score >= 0.25) return RiskLevel.moderate;
  return RiskLevel.low;
}