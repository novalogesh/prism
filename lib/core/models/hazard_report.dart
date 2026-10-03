// ignore_for_file: prefer_initializing_formals

import 'hazard_type.dart';

enum ReportSyncState { unsynced, synced, shared }

extension ReportSyncStatePresentation on ReportSyncState {
  String get storageValue => name.toUpperCase();

  String get displayLabel => storageValue;
}

enum HazardLifecycleStatus { underReview, active, resolved, expired }

extension HazardLifecycleStatusPresentation on HazardLifecycleStatus {
  String get storageValue {
    return switch (this) {
      HazardLifecycleStatus.underReview => 'UNDER_REVIEW',
      HazardLifecycleStatus.active => 'ACTIVE',
      HazardLifecycleStatus.resolved => 'RESOLVED',
      HazardLifecycleStatus.expired => 'EXPIRED',
    };
  }

  String get displayLabel {
    return switch (this) {
      HazardLifecycleStatus.underReview => 'UNDER REVIEW',
      HazardLifecycleStatus.active => 'ACTIVE',
      HazardLifecycleStatus.resolved => 'RESOLVED',
      HazardLifecycleStatus.expired => 'EXPIRED',
    };
  }
}

class HazardReport {
  final String id;
  final String hazardType;
  final String? severity;
  final String description;
  final String? photoPath;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? reporterAddress;
  // Legacy compatibility field. New logic should use syncState/lifecycleStatus.
  final String status;
  final bool sharedNearby;
  final DateTime createdAt;
  final ReportSyncState? _syncState;
  final HazardLifecycleStatus? _lifecycleStatus;

  const HazardReport({
    required this.id,
    required this.hazardType,
    this.severity,
    required this.description,
    this.photoPath,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.locationName,
    this.reporterAddress,
    this.status = 'UNSYNCED',
    this.sharedNearby = false,
    required this.createdAt,
    // Public parameter names feed private nullable fields for legacy fallback.
    ReportSyncState? syncState,
    HazardLifecycleStatus? lifecycleStatus,
  }) : _syncState = syncState,
       _lifecycleStatus = lifecycleStatus;

  ReportSyncState get syncState =>
      _syncState ?? _statesFromLegacyStatus(status).syncState;

  HazardLifecycleStatus get lifecycleStatus =>
      _lifecycleStatus ?? _statesFromLegacyStatus(status).lifecycleStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hazardType': canonicalHazardTypeName(hazardType),
      'severity': severity,
      'description': description,
      'photoPath': photoPath,
      'capturedAt': capturedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'reporterAddress': reporterAddress,
      'status': syncState.storageValue,
      'sharedNearby': sharedNearby,
      'createdAt': createdAt.toIso8601String(),
      'syncState': syncState.storageValue,
      'lifecycleStatus': lifecycleStatus.storageValue,
    };
  }

  factory HazardReport.fromJson(Map<String, dynamic> json) {
    final legacyStates = _statesFromLegacyStatus(json['status']);
    final syncState = json.containsKey('syncState')
        ? _syncStateFromJson(json['syncState']) ?? ReportSyncState.unsynced
        : legacyStates.syncState;
    final lifecycleStatus = json.containsKey('lifecycleStatus')
        ? _lifecycleStatusFromJson(json['lifecycleStatus']) ??
              HazardLifecycleStatus.underReview
        : legacyStates.lifecycleStatus;

    return HazardReport(
      id: json['id'] as String,
      hazardType: canonicalHazardTypeName(json['hazardType'] as String),
      severity: json['severity'] as String?,
      description: json['description'] as String,
      photoPath: json['photoPath'] as String?,
      capturedAt: DateTime.parse(
        json['capturedAt'] as String,
      ),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationName: json['locationName'] as String?,
      reporterAddress: json['reporterAddress'] as String?,
      status: json['status'] as String? ?? syncState.storageValue,
      sharedNearby: json['sharedNearby'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['createdAt'] as String,
      ),
      syncState: syncState,
      lifecycleStatus: lifecycleStatus,
    );
  }
}

({ReportSyncState syncState, HazardLifecycleStatus lifecycleStatus})
_statesFromLegacyStatus(Object? value) {
  final normalized = value is String
      ? value.trim().toUpperCase().replaceAll(' ', '_')
      : '';

  return switch (normalized) {
    'UNSYNCED' => (
      syncState: ReportSyncState.unsynced,
      lifecycleStatus: HazardLifecycleStatus.underReview,
    ),
    'SYNCED' => (
      syncState: ReportSyncState.synced,
      lifecycleStatus: HazardLifecycleStatus.underReview,
    ),
    'SHARED' => (
      syncState: ReportSyncState.shared,
      lifecycleStatus: HazardLifecycleStatus.underReview,
    ),
    'ACTIVE' || 'VERIFIED' => (
      syncState: ReportSyncState.unsynced,
      lifecycleStatus: HazardLifecycleStatus.active,
    ),
    'UNDER_REVIEW' => (
      syncState: ReportSyncState.unsynced,
      lifecycleStatus: HazardLifecycleStatus.underReview,
    ),
    'RESOLVED' || 'CLOSED' => (
      syncState: ReportSyncState.unsynced,
      lifecycleStatus: HazardLifecycleStatus.resolved,
    ),
    'EXPIRED' => (
      syncState: ReportSyncState.unsynced,
      lifecycleStatus: HazardLifecycleStatus.expired,
    ),
    _ => (
      syncState: ReportSyncState.unsynced,
      lifecycleStatus: HazardLifecycleStatus.underReview,
    ),
  };
}

ReportSyncState? _syncStateFromJson(Object? value) {
  if (value is! String) return null;

  return switch (value.trim().toUpperCase()) {
    'UNSYNCED' => ReportSyncState.unsynced,
    'SYNCED' => ReportSyncState.synced,
    'SHARED' => ReportSyncState.shared,
    _ => null,
  };
}

HazardLifecycleStatus? _lifecycleStatusFromJson(Object? value) {
  if (value is! String) return null;

  final normalized = value.trim().toUpperCase().replaceAll(' ', '_');
  return switch (normalized) {
    'UNDER_REVIEW' => HazardLifecycleStatus.underReview,
    'ACTIVE' => HazardLifecycleStatus.active,
    'RESOLVED' => HazardLifecycleStatus.resolved,
    'EXPIRED' => HazardLifecycleStatus.expired,
    _ => null,
  };
}



