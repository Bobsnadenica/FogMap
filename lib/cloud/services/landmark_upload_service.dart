import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

    final normalizedTitle = title.trim();
    final normalizedCategory = category.trim();
    final normalizedDescription = description.trim();
    if (normalizedTitle.length < 3 || normalizedTitle.length > 80) {
      throw Exception('Title must be between 3 and 80 characters.');
    }
    if (normalizedCategory.length < 2 || normalizedCategory.length > 40) {
      throw Exception('Category must be between 2 and 40 characters.');
    }

    final bytes = await file.readAsBytes();
    final mimeType = lookupMimeType(
          file.path,
          headerBytes: bytes.take(16).toList(),
        ) ??
        'image/jpeg';
    if (!{'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      throw Exception('Only JPEG, PNG, and WEBP images are supported.');
    }

    final ticket = await appsyncService.createLandmarkUploadTicket(
      title: normalizedTitle,
      description: normalizedDescription,
      category: normalizedCategory,
      lat: lat,
      lon: lon,
      filename: file.name,
      contentType: mimeType,
      byteLength: bytes.length,
      mapZoom: mapZoom,
    );

    final request = http.MultipartRequest('POST', Uri.parse(ticket.uploadUrl));

    for (final entry in ticket.uploadFields.entries) {
      request.fields[entry.key] = entry.value;
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'S3 upload failed (${response.statusCode}): $responseBody',
      );
    }

    await appsyncService.finalizeLandmarkUpload(
      landmarkId: ticket.landmarkId,
      uploadToken: ticket.uploadToken,
    );
  }
}
