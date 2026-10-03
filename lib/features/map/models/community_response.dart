enum CommunityResponseValue { yes, no }

class CommunityResponse {
  final String hazardId;
  final String deviceId;
  final CommunityResponseValue response;
  final double distanceMeters;
  final DateTime respondedAt;

  const CommunityResponse({
    required this.hazardId,
    required this.deviceId,
    required this.response,
    required this.distanceMeters,
    required this.respondedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'hazardId': hazardId,
      'deviceId': deviceId,
      'response': response.name.toUpperCase(),
      'distanceMeters': distanceMeters,
      'respondedAt': respondedAt.toIso8601String(),
    };
  }

  factory CommunityResponse.fromJson(
    Map<String, dynamic> json, {
    String? legacyDeviceId,
  }) {
    final response = switch (json['response']) {
      'YES' => CommunityResponseValue.yes,
      'NO' => CommunityResponseValue.no,
      _ => throw const FormatException('Invalid community response.'),
    };

    return CommunityResponse(
      hazardId: json['hazardId'] as String,
        deviceId: json['deviceId'] as String? ??
          legacyDeviceId ??
          'legacy-device',
      response: response,
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      respondedAt: DateTime.parse(json['respondedAt'] as String),
    );
  }
}

class CommunityResponseSubmissionResult {
  final CommunityResponse? response;
  final Duration? cooldownRemaining;
  final List<CommunityResponse> activeResponses;

  const CommunityResponseSubmissionResult({
    this.response,
    this.cooldownRemaining,
    this.activeResponses = const [],
  });
}