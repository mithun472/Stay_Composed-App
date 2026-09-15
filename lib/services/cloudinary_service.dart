import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/utils/api_result.dart';
import 'other_services.dart' show ImageUploadService;

/// Unsigned direct upload straight to Cloudinary — no backend hop, matches
/// how the website already handles item images.
///
/// Only CLOUDINARY_CLOUD_NAME + CLOUDINARY_UPLOAD_PRESET are used, both
/// read from .env. CLOUDINARY_API_KEY / CLOUDINARY_API_SECRET must NEVER
/// be added here — signed operations (like delete) need those, and they
/// can only live in a backend that never ships to a device.
class CloudinaryUploadService extends ImageUploadService {
  String get _cloudName {
    final name = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    if (name == null || name.isEmpty) {
      throw StateError('CLOUDINARY_CLOUD_NAME missing from .env');
    }
    return name;
  }

  String get _uploadPreset {
    final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];
    if (preset == null || preset.isEmpty) {
      throw StateError('CLOUDINARY_UPLOAD_PRESET missing from .env');
    }
    return preset;
  }

  @override
  Future<ApiResult<String>> uploadImage(String localFilePath) async {
    final file = File(localFilePath);
    if (!await file.exists()) {
      return ApiResult.failure('Image file not found at $localFilePath.');
    }

    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', localFilePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final url = decoded['secure_url'] as String?;
        if (url == null) {
          return ApiResult.failure('Cloudinary response missing secure_url.');
        }
        return ApiResult.success(url);
      }

      String message = 'Upload failed (${response.statusCode}).';
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMap = decoded['error'] as Map<String, dynamic>?;
        if (errorMap?['message'] != null) message = errorMap!['message'].toString();
      } catch (_) {
        // Body wasn't JSON — keep the generic status-code message.
      }
      return ApiResult.failure(message);
    } catch (e) {
      return ApiResult.failure('Upload error: $e');
    }
  }

  @override
  Future<ApiResult<void>> deleteImage(String imageUrl) async {
    // Deleting from Cloudinary requires a SIGNED request (api_key +
    // api_secret). Neither can live in this app, so deletion is not
    // possible from the client. If images ever need to be removed, add a
    // small backend endpoint that signs the delete server-side and call
    // that endpoint here instead.
    return ApiResult.failure(
      'Delete is not supported from the app. Ask the backend to expose a '
      'signed delete endpoint if this is needed.',
    );
  }
}

final imageUploadServiceProvider = Provider<ImageUploadService>(
  (ref) => CloudinaryUploadService(),
);
