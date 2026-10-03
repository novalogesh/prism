import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism/features/map/models/community_response.dart';
import 'package:prism/features/map/services/community_evidence_scorer.dart';
import 'package:prism/features/map/services/community_response_policy.dart';
import 'package:prism/features/map/services/community_response_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final start = DateTime.utc(2026, 9, 29, 12);

  Future<CommunityResponseStorage> createStorage() async {
    SharedPreferences.setMockInitialValues({});
    return CommunityResponseStorage();
  }

  Future<CommunityResponseSubmissionResult> submit(
    CommunityResponseStorage storage, {
    required String hazardId,
    required CommunityResponseValue response,
    required DateTime at,
  }) {
    return storage.submitResponse(
      hazardId: hazardId,
      response: response,
      distanceMeters: 42,
      respondedAt: at,
    );
  }

  CommunityResponse record(
    String hazardId,
    String deviceId,
    CommunityResponseValue response,
    DateTime at,
  ) {
    return CommunityResponse(
      hazardId: hazardId,
      deviceId: deviceId,
      response: response,
      distanceMeters: 42,
      respondedAt: at,
    );
  }

  test('cooldown rejects a second vote and expires after one hour', () async {
    final storage = await createStorage();
    final initial = await submit(
      storage,
      hazardId: 'hazard-1',
      response: CommunityResponseValue.yes,
      at: start,
    );
    final blocked = await submit(
      storage,
      hazardId: 'hazard-1',
      response: CommunityResponseValue.no,
      at: start.add(const Duration(minutes: 30)),
    );

    expect(initial.response, isNotNull);
    expect(blocked.response, isNull);
    expect(blocked.cooldownRemaining, const Duration(minutes: 30));
    expect(blocked.activeResponses.single.response, CommunityResponseValue.yes);
    expect(await storage.getResponsesForHazard('hazard-1'), hasLength(1));

    final afterCooldown = await submit(
      storage,
      hazardId: 'hazard-1',
      response: CommunityResponseValue.no,
      at: start.add(const Duration(hours: 1)),
    );
    expect(afterCooldown.response?.response, CommunityResponseValue.no);
  });

  test('YES to NO replacement keeps one active vote and history', () async {
    final storage = await createStorage();
    final first = await submit(
      storage,
      hazardId: 'hazard-1',
      response: CommunityResponseValue.yes,
      at: start,
    );
    final replacement = await submit(
      storage,
      hazardId: 'hazard-1',
      response: CommunityResponseValue.no,
      at: start.add(const Duration(hours: 1)),
    );

    expect(replacement.response?.deviceId, first.response?.deviceId);
    expect(replacement.activeResponses, hasLength(1));
    expect(replacement.activeResponses.single.response, CommunityResponseValue.no);
    expect(await storage.getResponsesForHazard('hazard-1'), hasLength(2));
  });

  test('NO to YES replacement keeps one active vote and history', () async {
    final storage = await createStorage();
    await submit(
      storage,
      hazardId: 'hazard-1',
      response: CommunityResponseValue.no,
      at: start,
    );
    final replacement = await submit(
      storage,
      hazardId: 'hazard-1',
      response: CommunityResponseValue.yes,
      at: start.add(const Duration(hours: 1)),
    );

    expect(replacement.activeResponses, hasLength(1));
    expect(replacement.activeResponses.single.response, CommunityResponseValue.yes);
    expect(await storage.getResponsesForHazard('hazard-1'), hasLength(2));
  });

  test('same-choice re-verification refreshes rather than duplicates vote', () async {
    final storage = await createStorage();
    await submit(
      storage,
      hazardId: 'hazard-1',
      response: CommunityResponseValue.yes,
      at: start,
    );
    final replacement = await submit(
      storage,
      hazardId: 'hazard-1',
      response: CommunityResponseValue.yes,
      at: start.add(const Duration(hours: 1)),
    );

    expect(replacement.activeResponses, hasLength(1));
    expect(replacement.activeResponses.single.respondedAt,
        start.add(const Duration(hours: 1)));
    expect(await storage.getResponsesForHazard('hazard-1'), hasLength(2));
  });

  test('active totals include only the latest response for each device', () {
    final history = [
      record('hazard-1', 'device-a', CommunityResponseValue.yes, start),
      record(
        'hazard-1',
        'device-a',
        CommunityResponseValue.no,
        start.add(const Duration(hours: 1)),
      ),
      record('hazard-1', 'device-b', CommunityResponseValue.yes, start),
      record('hazard-2', 'device-c', CommunityResponseValue.no, start),
    ];

    final active = latestCommunityResponsesForHazard(history, 'hazard-1');

    expect(active, hasLength(2));
    expect(
      active.where((item) => item.response == CommunityResponseValue.yes),
      hasLength(1),
    );
    expect(
      active.where((item) => item.response == CommunityResponseValue.no),
      hasLength(1),
    );
  });

  test('score updates from active responses, not superseded history', () {
    final history = [
      record('hazard-1', 'device-a', CommunityResponseValue.yes, start),
      record(
        'hazard-1',
        'device-b',
        CommunityResponseValue.no,
        start.add(const Duration(hours: 1)),
      ),
      record(
        'hazard-1',
        'device-a',
        CommunityResponseValue.no,
        start.add(const Duration(hours: 2)),
      ),
    ];

    final score = calculateCommunityEvidenceScore(
      hazardId: 'hazard-1',
      responses: history,
      referenceTime: start.add(const Duration(hours: 2)),
    );

    expect(score.value, closeTo(39.430638823072115, 1e-9));
  });

  test('cooldown and active response are independent per hazard', () async {
    final storage = await createStorage();
    final firstHazard = await submit(
      storage,
      hazardId: 'hazard-1',
      response: CommunityResponseValue.yes,
      at: start,
    );
    final secondHazard = await submit(
      storage,
      hazardId: 'hazard-2',
      response: CommunityResponseValue.no,
      at: start,
    );

    expect(firstHazard.response, isNotNull);
    expect(secondHazard.response, isNotNull);
    expect(await storage.getActiveResponsesForHazard('hazard-1'), hasLength(1));
    expect(await storage.getActiveResponsesForHazard('hazard-2'), hasLength(1));
    expect(
      await storage.getCooldownRemainingForHazard(
        hazardId: 'hazard-1',
        referenceTime: start,
      ),
      communityResponseCooldown,
    );
    expect(
      await storage.getCooldownRemainingForHazard(
        hazardId: 'hazard-2',
        referenceTime: start,
      ),
      communityResponseCooldown,
    );
  });

  test('malformed history entry does not discard other responses on save', () async {
    SharedPreferences.setMockInitialValues({
      'prism_community_device_id': 'installation-1',
      'prism_community_responses': jsonEncode([
        {
          'hazardId': 'hazard-1',
          'deviceId': 'device-a',
          'response': 'YES',
          'distanceMeters': 42,
          'respondedAt': start.toIso8601String(),
        },
        {
          'hazardId': 'malformed',
          'deviceId': 'device-b',
          'response': 'MAYBE',
          'distanceMeters': 10,
          'respondedAt': start.toIso8601String(),
        },
        {
          'hazardId': 'hazard-2',
          'deviceId': 'device-c',
          'response': 'NO',
          'distanceMeters': 75,
          'respondedAt': start.toIso8601String(),
        },
      ]),
    });
    final storage = CommunityResponseStorage();

    expect(await storage.getResponsesForHazard('hazard-1'), hasLength(1));

    final saved = await storage.submitResponse(
      hazardId: 'hazard-3',
      response: CommunityResponseValue.yes,
      distanceMeters: 30,
      respondedAt: start,
    );
    final prefs = await SharedPreferences.getInstance();
    final storedRecords = jsonDecode(
      prefs.getString('prism_community_responses')!,
    ) as List;

    expect(saved.response, isNotNull);
    expect(storedRecords, hasLength(3));
    expect(await storage.getResponsesForHazard('hazard-1'), hasLength(1));
    expect(await storage.getResponsesForHazard('hazard-2'), hasLength(1));
    expect(await storage.getResponsesForHazard('hazard-3'), hasLength(1));
  });
}