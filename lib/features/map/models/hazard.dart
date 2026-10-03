enum HazardType {
  openManhole,
  floodedRoad,
  fallenTree,
  electricHazard,
  damagedRoad,
  waterLogging,
  other,
}

enum HazardStatus {
  active,
  underReview,
  resolved,
  expired,
}

enum RiskLevel {
  low,
  moderate,
  high,
  critical,
}

class Hazard {
  final String id;
  final HazardType type;
  final HazardStatus status;
  final RiskLevel riskLevel;
  final double riskScore;
  final String? selectedSeverity;

  final double latitude;
  final double longitude;

  final String title;
  final String description;

  final DateTime reportedAt;
  final DateTime? verifiedAt;

  final int confirmationCount;

  // Community evidence
  final int totalResponses;
  final int yesConfirmations;
  final int noConfirmations;
  final DateTime? latestResponseAt;

  final String? imagePath;

  const Hazard({
    required this.id,
    required this.type,
    required this.status,
    required this.riskLevel,
    required this.riskScore,
    this.selectedSeverity,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.description,
    required this.reportedAt,
    this.verifiedAt,
    this.confirmationCount = 0,
    this.totalResponses = 0,
    this.yesConfirmations = 0,
    this.noConfirmations = 0,
    this.latestResponseAt,
    this.imagePath,
  });

  HazardStatus get lifecycleStatus => status;

  bool get isVisibleOnMap =>
      lifecycleStatus == HazardStatus.underReview ||
      lifecycleStatus == HazardStatus.active;

  String get lifecycleLabel {
    return switch (lifecycleStatus) {
      HazardStatus.underReview => 'UNDER REVIEW',
      HazardStatus.active => 'ACTIVE',
      HazardStatus.resolved => 'RESOLVED',
      HazardStatus.expired => 'EXPIRED',
    };
  }
}

