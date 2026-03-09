import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../auth/cognito_auth_service.dart';
import 'appsync_service.dart';

class LandmarkUploadService {
  LandmarkUploadService({
    required this.authService,
    required this.appsyncService,
    ImagePicker? imagePicker,
  }) : _imagePicker = imagePicker ?? ImagePicker();

  final CognitoAuthService authService;
  final AppSyncService appsyncService;
  final ImagePicker _imagePicker;

  Future<XFile?> pickFromCamera() {
    return _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 2400,
      preferredCameraDevice: CameraDevice.rear,
    );
  }

  Future<void> uploadLandmark({
    required XFile file,
    required String title,
    required String description,
    required String category,
    required double lat,
    required double lon,
    required int mapZoom,
  }) async {
    if (!authService.isSignedIn) {
      throw Exception('Please sign in before uploading a landmark.');
    }

    final bytes = await file.readAsBytes();
    final mimeType = lookupMimeType(
          file.path,
          headerBytes: bytes.take(16).toList(),
        ) ??
        'image/jpeg';

    final ticket = await appsyncService.createLandmarkUploadTicket(
      title: title,
      description: description,
      category: category,
      lat: lat,
      lon: lon,
      filename: file.name,
      contentType: mimeType,
      byteLength: bytes.length,
      mapZoom: mapZoom,
    );

    final fields = Map<String, dynamic>.from(
      jsonDecode(ticket.uploadFieldsJson) as Map,
    );

    final request = http.MultipartRequest('POST', Uri.parse(ticket.uploadUrl));
    for (final entry in fields.entries) {
      request.fields[entry.key] = entry.value.toString();
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: file.name,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('S3 upload failed (${response.statusCode}): $responseBody');
    }

    await appsyncService.finalizeLandmarkUpload(
      landmarkId: ticket.landmarkId,
      uploadToken: ticket.uploadToken,
    );
  }
}