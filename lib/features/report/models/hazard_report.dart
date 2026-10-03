enum ReportHazardType {
  flood,
  openManhole,
  damagedRoad,
  fallenTree,
  electricHazard,
  waterLogging,
  other,
}

enum ReportRiskLevel {
  low,
  moderate,
  high,
  critical,
}

class HazardReport {
  final String id;
  final ReportHazardType type;
  final ReportRiskLevel riskLevel;

  final String description;

  final double? latitude;
  final double? longitude;

  final DateTime createdAt;

  final String? imagePath;

  const HazardReport({
    required this.id,
    required this.type,
    required this.riskLevel,
    required this.description,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.imagePath,
  });
}
