import 'dart:math' as math;

import '../models/community_response.dart';
import 'community_response_policy.dart';

class CommunityEvidenceScore {
  final double? value;
  final String label;

  const CommunityEvidenceScore({
    required this.value,
    required this.label,
  });
}

CommunityEvidenceScore calculateCommunityEvidenceScore({
  required String hazardId,
  required Iterable<CommunityResponse> responses,
  required DateTime referenceTime,
}) {
  var yesWeight = 0.0;
  var noWeight = 0.0;

  for (final response in
      latestCommunityResponsesForHazard(responses, hazardId)) {
    final age = referenceTime.difference(response.respondedAt);
    if (age.isNegative) continue;

    final ageInDays =
        age.inMicroseconds / const Duration(hours: 24).inMicroseconds;
    final weight = math.pow(2, -ageInDays).toDouble();

    switch (response.response) {
      case CommunityResponseValue.yes:
        yesWeight += weight;
      case CommunityResponseValue.no:
        noWeight += weight;
    }
  }

  final totalWeight = yesWeight + noWeight;
  if (totalWeight == 0) {
    return const CommunityEvidenceScore(
      value: null,
      label: 'No community verification',
    );
  }

  final volume = math.min(totalWeight / 5, 1.0);
  final agreement = (yesWeight - noWeight).abs() / totalWeight;
  final score = (100 * volume * agreement).clamp(0.0, 100.0);

  final label = switch (score) {
    0 => 'Responses disagree',
    < 25 => 'Limited signal',
    < 60 => 'Developing signal',
    < 85 => 'Consistent signal',
    _ => 'Strong consistent signal',
  };

  return CommunityEvidenceScore(value: score, label: label);
}