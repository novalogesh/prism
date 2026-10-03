import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_response.dart';
import 'community_response_policy.dart';

class CommunityResponseStorage {
  static const String _storageKey = 'prism_community_responses';
  static const String _deviceIdKey = 'prism_community_device_id';

  Future<void> _writeQueue = Future<void>.value();

  Future<List<CommunityResponse>> getResponsesForHazard(
    String hazardId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getOrCreateDeviceId(prefs);
    final responses = await _readResponses(prefs, deviceId);
    return responses.where((response) => response.hazardId == hazardId).toList();
  }

  Future<List<CommunityResponse>> getActiveResponsesForHazard(
    String hazardId,
  ) async {
    final history = await getResponsesForHazard(hazardId);
    return latestCommunityResponsesForHazard(history, hazardId);
  }

  Future<Duration?> getCooldownRemainingForHazard({
    required String hazardId,
    required DateTime referenceTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getOrCreateDeviceId(prefs);
    final history = await _readResponses(prefs, deviceId);
    final active = latestCommunityResponsesForHazard(history, hazardId);

    for (final response in active) {
      if (response.deviceId == deviceId) {
        return communityResponseCooldownRemaining(
          lastRespondedAt: response.respondedAt,
          referenceTime: referenceTime,
        );
      }
    }

    return null;
  }

  Future<CommunityResponseSubmissionResult> submitResponse({
    required String hazardId,
    required CommunityResponseValue response,
    required double distanceMeters,
    required DateTime respondedAt,
  }) {
    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getOrCreateDeviceId(prefs);
      final history = await _readResponses(prefs, deviceId);
      final active = latestCommunityResponsesForHazard(history, hazardId);

      for (final previous in active) {
        if (previous.deviceId != deviceId) continue;

        final remaining = communityResponseCooldownRemaining(
          lastRespondedAt: previous.respondedAt,
          referenceTime: respondedAt,
        );
        if (remaining != null) {
          return CommunityResponseSubmissionResult(
            cooldownRemaining: remaining,
            activeResponses: active,
          );
        }
      }

      final newResponse = CommunityResponse(
        hazardId: hazardId,
        deviceId: deviceId,
        response: response,
        distanceMeters: distanceMeters,
        respondedAt: respondedAt,
      );
      history.add(newResponse);
      await _writeResponses(prefs, history);

      return CommunityResponseSubmissionResult(
        response: newResponse,
        activeResponses: latestCommunityResponsesForHazard(
          history,
          hazardId,
        ),
      );
    });
  }

  Future<String> _getOrCreateDeviceId(SharedPreferences prefs) async {
    final existingId = prefs.getString(_deviceIdKey);
    if (existingId != null && existingId.isNotEmpty) return existingId;

    final random = math.Random.secure();
    final deviceId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  Future<List<CommunityResponse>> _readResponses(
    SharedPreferences prefs,
    String legacyDeviceId,
  ) async {
    final content = prefs.getString(_storageKey);
    if (content == null || content.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(content) as List;
      final responses = <CommunityResponse>[];
      for (final item in decoded) {
        if (item is! Map) continue;

        try {
          responses.add(
            CommunityResponse.fromJson(
              Map<String, dynamic>.from(item),
              legacyDeviceId: legacyDeviceId,
            ),
          );
        } catch (_) {
          // Keep valid response history when one entry is malformed.
        }
      }

      return responses;
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeResponses(
    SharedPreferences prefs,
    List<CommunityResponse> responses,
  ) async {
    await prefs.setString(
      _storageKey,
      jsonEncode(responses.map((item) => item.toJson()).toList()),
    );
  }

  Future<T> _serialize<T>(Future<T> Function() operation) async {
    final previousWrite = _writeQueue;
    final completed = Completer<void>();
    _writeQueue = completed.future;
    await previousWrite;

    try {
      return await operation();
    } finally {
      completed.complete();
    }
  }
}