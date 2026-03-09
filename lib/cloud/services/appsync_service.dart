import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/cloud_discovery_cell.dart';
import '../auth/cognito_auth_service.dart';
import '../backend_config.dart';
import '../models/landmark_models.dart';
import '../models/shared_viewport_models.dart';

class AppSyncService {
  AppSyncService({
    required this.authService,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final CognitoAuthService authService;
  final http.Client _client;

  Future<void> syncDiscoveries({
    required List<CloudDiscoveryCell> cells,
    required double? currentLat,
    required double? currentLon,
    required int mapZoom,
    required String displayName,
  }) async {
    await _post(
      query: '''
mutation SyncDiscoveries(
  \$worldId: String
  \$cellsJson: AWSJSON!
  \$currentLat: Float
  \$currentLon: Float
  \$mapZoom: Int
  \$displayName: String
) {
  syncDiscoveries(
    worldId: \$worldId
    cellsJson: \$cellsJson
    currentLat: \$currentLat
    currentLon: \$currentLon
    mapZoom: \$mapZoom
    displayName: \$displayName
  ) {
    acceptedCellCount
  }
}
''',
      variables: {
        'worldId': BackendConfig.defaultWorldId,
        'cellsJson': jsonEncode(cells.map((e) => e.toJson()).toList()),
        'currentLat': currentLat,
        'currentLon': currentLon,
        'mapZoom': mapZoom,
        'displayName': displayName,
      },
    );
  }

  Future<SharedViewportResponse> getSharedViewport({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required int zoom,
  }) async {
    final data = await _post(
      query: '''
query GetSharedViewport(
  \$worldId: String
  \$minLat: Float!
  \$maxLat: Float!
  \$minLon: Float!
  \$maxLon: Float!
  \$zoom: Int!
) {
  getSharedViewport(
    worldId: \$worldId
    minLat: \$minLat
    maxLat: \$maxLat
    minLon: \$minLon
    maxLon: \$maxLon
    zoom: \$zoom
  ) {
    worldId
    generatedAt
    cells { cellId lat lon discovererCount tileId lastDiscoveredAt }
    players { userId displayName lat lon lastSeenAt }
    landmarks { landmarkId title description category lat lon status approvedObjectKey createdAt }
  }
}
''',
      variables: {
        'worldId': BackendConfig.defaultWorldId,
        'minLat': minLat,
        'maxLat': maxLat,
        'minLon': minLon,
        'maxLon': maxLon,
        'zoom': zoom,
      },
    );

    return SharedViewportResponse.fromJson(
      Map<String, dynamic>.from(data['getSharedViewport'] as Map),
    );
  }

  Future<LandmarkUploadTicket> createLandmarkUploadTicket({
    required String title,
    required String description,
    required String category,
    required double lat,
    required double lon,
    required String filename,
    required String contentType,
    required int byteLength,
    required int mapZoom,
  }) async {
    final data = await _post(
      query: '''
mutation CreateLandmarkUploadTicket(
  \$worldId: String
  \$title: String!
  \$description: String
  \$category: String!
  \$lat: Float!
  \$lon: Float!
  \$filename: String!
  \$contentType: String!
  \$byteLength: Int!
  \$mapZoom: Int
) {
  createLandmarkUploadTicket(
    worldId: \$worldId
    title: \$title
    description: \$description
    category: \$category
    lat: \$lat
    lon: \$lon
    filename: \$filename
    contentType: \$contentType
    byteLength: \$byteLength
    mapZoom: \$mapZoom
  ) {
    landmarkId
    uploadToken
    objectKey
    uploadUrl
    uploadFieldsJson
    expiresAt
    maxBytes
  }
}
''',
      variables: {
        'worldId': BackendConfig.defaultWorldId,
        'title': title,
        'description': description,
        'category': category,
        'lat': lat,
        'lon': lon,
        'filename': filename,
        'contentType': contentType,
        'byteLength': byteLength,
        'mapZoom': mapZoom,
      },
    );

    return LandmarkUploadTicket.fromJson(
      Map<String, dynamic>.from(data['createLandmarkUploadTicket'] as Map),
    );
  }

  Future<void> finalizeLandmarkUpload({
    required String landmarkId,
    required String uploadToken,
  }) async {
    await _post(
      query: '''
mutation FinalizeLandmarkUpload(\$landmarkId: String!, \$uploadToken: String!) {
  finalizeLandmarkUpload(landmarkId: \$landmarkId, uploadToken: \$uploadToken) {
    landmarkId
    status
  }
}
''',
      variables: {
        'landmarkId': landmarkId,
        'uploadToken': uploadToken,
      },
    );
  }

  Future<List<PendingLandmark>> listPendingLandmarks() async {
    final data = await _post(
      query: '''
query ListPendingLandmarks {
  listPendingLandmarks {
    landmarkId
    title
    description
    category
    lat
    lon
    status
    createdAt
    uploadedBy
  }
}
''',
      variables: const {},
    );

    return ((data['listPendingLandmarks'] as List?) ?? const [])
        .map((e) => PendingLandmark.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String> getPendingLandmarkReviewUrl(String landmarkId) async {
    final data = await _post(
      query: '''
query GetPendingLandmarkReviewUrl(\$landmarkId: String!) {
  getPendingLandmarkReviewUrl(landmarkId: \$landmarkId) {
    reviewUrl
  }
}
''',
      variables: {'landmarkId': landmarkId},
    );

    return (data['getPendingLandmarkReviewUrl'] as Map)['reviewUrl'] as String;
  }

  Future<void> moderateLandmark({
    required String landmarkId,
    required bool approve,
    String moderationNotes = '',
  }) async {
    await _post(
      query: '''
mutation ModerateLandmark(\$landmarkId: String!, \$approve: Boolean!, \$moderationNotes: String) {
  moderateLandmark(
    landmarkId: \$landmarkId
    approve: \$approve
    moderationNotes: \$moderationNotes
  ) {
    landmarkId
    status
  }
}
''',
      variables: {
        'landmarkId': landmarkId,
        'approve': approve,
        'moderationNotes': moderationNotes,
      },
    );
  }

  Future<String> getLandmarkViewUrl(String landmarkId) async {
    final data = await _post(
      query: '''
query GetLandmarkViewUrl(\$landmarkId: String!) {
  getLandmarkViewUrl(landmarkId: \$landmarkId) {
    viewUrl
  }
}
''',
      variables: {'landmarkId': landmarkId},
    );

    return (data['getLandmarkViewUrl'] as Map)['viewUrl'] as String;
  }

  Future<Map<String, dynamic>> _post({
    required String query,
    required Map<String, dynamic> variables,
  }) async {
    final idToken = await authService.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('You must be signed in.');
    }

    final response = await _client.post(
      Uri.parse(BackendConfig.appSyncGraphqlUrl),
      headers: {
        'content-type': 'application/json',
        'authorization': idToken,
      },
      body: jsonEncode({
        'query': query,
        'variables': variables,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'AppSync HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    final errors = decoded['errors'] as List?;
    if (errors != null && errors.isNotEmpty) {
      final messages = errors
          .map((e) => (e as Map<String, dynamic>)['message']?.toString() ?? 'Unknown AppSync error')
          .join(', ');
      throw Exception(messages);
    }

    return Map<String, dynamic>.from(decoded['data'] as Map);
  }
}