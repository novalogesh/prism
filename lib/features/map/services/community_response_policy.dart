import '../models/community_response.dart';

const communityResponseCooldown = Duration(hours: 1);

List<CommunityResponse> latestCommunityResponsesForHazard(
  Iterable<CommunityResponse> responses,
  String hazardId,
) {
  final latestByDevice = <String, CommunityResponse>{};

  for (final response in responses) {
    if (response.hazardId != hazardId) continue;

    final current = latestByDevice[response.deviceId];
    if (current == null || !response.respondedAt.isBefore(current.respondedAt)) {
      latestByDevice[response.deviceId] = response;
    }
  }

  return latestByDevice.values.toList();
}

Duration? communityResponseCooldownRemaining({
  required DateTime lastRespondedAt,
  required DateTime referenceTime,
}) {
  final remaining = lastRespondedAt
      .add(communityResponseCooldown)
      .difference(referenceTime);

  return remaining > Duration.zero ? remaining : null;
}