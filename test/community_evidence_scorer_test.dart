import 'package:flutter_test/flutter_test.dart';
import 'package:prism/features/map/models/community_response.dart';
import 'package:prism/features/map/services/community_evidence_scorer.dart';

void main() {
  final referenceTime = DateTime.utc(2026, 9, 29, 12);
  var responseNumber = 0;

  CommunityResponse response(
    String hazardId,
    CommunityResponseValue value, {
    Duration age = Duration.zero,
  }) {
    return CommunityResponse(
      hazardId: hazardId,
      deviceId: 'test-device-${responseNumber++}',
      response: value,
      distanceMeters: 42,
      respondedAt: referenceTime.subtract(age),
    );
  }

  CommunityEvidenceScore score(List<CommunityResponse> responses) {
    return calculateCommunityEvidenceScore(
      hazardId: 'hazard-1',
      responses: responses,
      referenceTime: referenceTime,
    );
  }

  test('no responses returns unavailable', () {
    final result = score([]);

    expect(result.value, isNull);
    expect(result.label, 'No community verification');
  });

  test('one recent YES has limited evidence score', () {
    final result = score([
      response('hazard-1', CommunityResponseValue.yes),
    ]);

    expect(result.value, closeTo(20, 1e-9));
    expect(result.label, 'Limited signal');
  });

  test('five recent YES responses reach full score', () {
    final result = score(
      List.generate(
        5,
        (_) => response('hazard-1', CommunityResponseValue.yes),
      ),
    );

    expect(result.value, closeTo(100, 1e-9));
    expect(result.label, 'Strong consistent signal');
  });

  test('all NO responses score the same as all YES responses', () {
    final result = score(
      List.generate(
        5,
        (_) => response('hazard-1', CommunityResponseValue.no),
      ),
    );

    expect(result.value, closeTo(100, 1e-9));
    expect(result.label, 'Strong consistent signal');
  });

  test('mixed responses reduce agreement', () {
    final result = score([
      response('hazard-1', CommunityResponseValue.yes),
      response('hazard-1', CommunityResponseValue.yes),
      response('hazard-1', CommunityResponseValue.yes),
      response('hazard-1', CommunityResponseValue.no),
      response('hazard-1', CommunityResponseValue.no),
    ]);

    expect(result.value, closeTo(20, 1e-9));
  });

  test('evenly split responses are labeled as disagreement', () {
    final result = score([
      response('hazard-1', CommunityResponseValue.yes),
      response('hazard-1', CommunityResponseValue.no),
    ]);

    expect(result.value, 0);
    expect(result.label, 'Responses disagree');
  });

  test('old responses contribute less than recent responses', () {
    final result = score(
      List.generate(
        8,
        (_) => response(
          'hazard-1',
          CommunityResponseValue.yes,
          age: const Duration(hours: 72),
        ),
      ),
    );

    expect(result.value, closeTo(20, 1e-9));
  });

  test('future responses do not increase score', () {
    final recentOnly = score([
      response('hazard-1', CommunityResponseValue.yes),
    ]);
    final withFuture = calculateCommunityEvidenceScore(
      hazardId: 'hazard-1',
      responses: [
        response('hazard-1', CommunityResponseValue.yes),
        CommunityResponse(
          hazardId: 'hazard-1',
          deviceId: 'future-device',
          response: CommunityResponseValue.no,
          distanceMeters: 42,
          respondedAt: referenceTime.add(const Duration(hours: 1)),
        ),
      ],
      referenceTime: referenceTime,
    );
    final futureOnly = calculateCommunityEvidenceScore(
      hazardId: 'hazard-1',
      responses: [
        CommunityResponse(
          hazardId: 'hazard-1',
          deviceId: 'future-device-only',
          response: CommunityResponseValue.yes,
          distanceMeters: 42,
          respondedAt: referenceTime.add(const Duration(hours: 1)),
        ),
      ],
      referenceTime: referenceTime,
    );

    expect(withFuture.value, recentOnly.value);
    expect(futureOnly.value, isNull);
  });

  test('responses from another hazard are ignored', () {
    final result = score([
      response('hazard-1', CommunityResponseValue.yes),
      response('hazard-2', CommunityResponseValue.no),
      response('hazard-2', CommunityResponseValue.no),
      response('hazard-2', CommunityResponseValue.no),
      response('hazard-2', CommunityResponseValue.no),
    ]);

    expect(result.value, closeTo(20, 1e-9));
  });
}