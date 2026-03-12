import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fog_frontier/cloud/models/landmark_models.dart';
import 'package:fog_frontier/core/constants/app_constants.dart';
import 'package:fog_frontier/core/utils/discovery_math.dart';
import 'package:fog_frontier/core/utils/journey_insights.dart';
import 'package:fog_frontier/data/models/player_profile.dart';
import 'package:fog_frontier/data/models/reveal_point.dart';

void main() {
  test('DiscoveryMath returns stable reveal data', () {
    const point = LatLng(42.6977, 23.3219);
    const radiusMeters = AppConstants.discoveryRadiusMeters;
    const cellDegrees = AppConstants.statsCellDegrees;

    final first = DiscoveryMath.cellsForRevealData(
      point: point,
      radiusMeters: radiusMeters,
      cellDegrees: cellDegrees,
    );
    final second = DiscoveryMath.cellsForRevealData(
      point: point,
      radiusMeters: radiusMeters,
      cellDegrees: cellDegrees,
    );

    expect(first, isNotEmpty);
    expect(first, equals(second));
  });

  test('DiscoveryMath always includes the containing cell', () {
    const point = LatLng(42.697743, 23.321965);
    const cellDegrees = AppConstants.statsCellDegrees;

    final cells = DiscoveryMath.cellsForRevealData(
      point: point,
      radiusMeters: AppConstants.discoveryRadiusMeters,
      cellDegrees: cellDegrees,
    );

    expect(
      cells.map((cell) => cell.cellId),
      contains(DiscoveryMath.cellIdFromLatLng(point, cellDegrees)),
    );
  });

  test('DiscoveryMath fills cells across a walked segment', () {
    const start = LatLng(42.6977, 23.3219);
    const end = LatLng(42.6977, 23.3224);
    const cellDegrees = AppConstants.statsCellDegrees;

    final cells = DiscoveryMath.cellsForPathSegmentData(
      start: start,
      end: end,
      radiusMeters: AppConstants.discoveryRadiusMeters,
      cellDegrees: cellDegrees,
    );

    expect(cells.length, greaterThan(2));
    expect(
      cells.map((cell) => cell.cellId),
      contains(DiscoveryMath.cellIdFromLatLng(start, cellDegrees)),
    );
    expect(
      cells.map((cell) => cell.cellId),
      contains(DiscoveryMath.cellIdFromLatLng(end, cellDegrees)),
    );
  });

  test('DiscoveryMath path segment does not widen into adjacent rows', () {
    const start = LatLng(42.6977, 23.3219);
    const end = LatLng(42.6977, 23.3228);
    const cellDegrees = AppConstants.statsCellDegrees;

    final cells = DiscoveryMath.cellsForPathSegmentData(
      start: start,
      end: end,
      radiusMeters: AppConstants.discoveryRadiusMeters,
      cellDegrees: cellDegrees,
    );

    final latIndexes =
        cells.map((cell) => int.parse(cell.cellId.split(':').first)).toSet();

    expect(latIndexes.length, 1);
  });

  test('Discovery cell id round-trip is consistent', () {
    const point = LatLng(42.6977, 23.3219);
    const cellDegrees = AppConstants.statsCellDegrees;

    final cellId = DiscoveryMath.cellIdFromLatLng(point, cellDegrees);
    final center = DiscoveryMath.cellCenterFromId(cellId, cellDegrees);
    final roundTrip = DiscoveryMath.cellIdFromLatLng(center, cellDegrees);

    expect(roundTrip, cellId);
  });

  test('Shared viewport cache key is stable within the same tile range', () {
    final first = DiscoveryMath.sharedViewportCacheKey(
      minLat: 42.6968,
      maxLat: 42.6988,
      minLon: 23.3205,
      maxLon: 23.3231,
      mapZoom: 17,
    );
    final second = DiscoveryMath.sharedViewportCacheKey(
      minLat: 42.6969,
      maxLat: 42.6987,
      minLon: 23.3206,
      maxLon: 23.3230,
      mapZoom: 17,
    );

    expect(second, first);
  });

  test('Landmark upload ticket parses uploadFieldsJson payload', () {
    final ticket = LandmarkUploadTicket.fromJson({
      'landmarkId': 'landmark-123',
      'uploadToken': 'token-123',
      'objectKey': 'user/landmark/original.jpg',
      'uploadUrl': 'https://example.com/upload',
      'uploadFieldsJson': '{"key":"value","x-amz-meta-user-id":"u1"}',
      'expiresAt': '2026-03-10T12:00:00Z',
      'maxBytes': 5242880,
    });

    expect(ticket.uploadFields['key'], 'value');
    expect(ticket.uploadFields['x-amz-meta-user-id'], 'u1');
    expect(ticket.maxBytes, 5242880);
  });

  test('Landmark upload ticket parses double-encoded uploadFieldsJson', () {
    final ticket = LandmarkUploadTicket.fromJson({
      'landmarkId': 'landmark-123',
      'uploadToken': 'token-123',
      'objectKey': 'user/landmark/original.jpg',
      'uploadUrl': 'https://example.com/upload',
      'uploadFieldsJson': '"{\\"key\\":\\"value\\",\\"policy\\":\\"abc\\"}"',
      'expiresAt': '2026-03-10T12:00:00Z',
      'maxBytes': 5242880,
    });

    expect(ticket.uploadFields['key'], 'value');
    expect(ticket.uploadFields['policy'], 'abc');
  });

  test('JourneyInsights groups reveal points into expeditions by time gap', () {
    final profile = PlayerProfile.createEmpty().copyWith(
      reveals: const [
        RevealPoint(
          latitude: 42.6977,
          longitude: 23.3219,
          discoveredAtIso: '2026-03-10T08:00:00Z',
        ),
        RevealPoint(
          latitude: 42.6978,
          longitude: 23.3221,
          discoveredAtIso: '2026-03-10T08:10:00Z',
        ),
        RevealPoint(
          latitude: 42.6982,
          longitude: 23.3230,
          discoveredAtIso: '2026-03-10T11:30:00Z',
        ),
      ],
    );

    final insights = JourneyInsights.fromProfile(profile);

    expect(insights.expeditions.length, 2);
    expect(insights.activeDays, 1);
    expect(insights.expeditions.first.revealCount, 1);
    expect(insights.expeditions.last.revealCount, 2);
  });

  test('JourneyInsights computes active days across multiple dates', () {
    final profile = PlayerProfile.createEmpty().copyWith(
      reveals: const [
        RevealPoint(
          latitude: 42.6977,
          longitude: 23.3219,
          discoveredAtIso: '2026-03-10T08:00:00Z',
        ),
        RevealPoint(
          latitude: 42.6978,
          longitude: 23.3221,
          discoveredAtIso: '2026-03-11T08:10:00Z',
        ),
      ],
    );

    final insights = JourneyInsights.fromProfile(profile);

    expect(insights.expeditions.length, 2);
    expect(insights.activeDays, 2);
    expect(insights.longestExpeditionMeters, 0);
  });
}
