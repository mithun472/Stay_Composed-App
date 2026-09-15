import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';
import '../utils/api_result.dart';

/// Thrown when a network call is attempted before a backend URL has been
/// set on the Settings screen.
class BackendNotConfiguredException implements Exception {
  const BackendNotConfiguredException();
}

/// Minimal REST client every real service implementation can share.
/// Base URL comes from [BackendConfig] (set via Settings -> ngrok URL),
/// never hardcoded, so switching tunnels doesn't need a rebuild.
class ApiClient {
  const ApiClient();

  Future<String> _requireBaseUrl() async {
    final url = await BackendConfig.getBaseUrl();
    if (url == null || url.isEmpty) {
      throw const BackendNotConfiguredException();
    }
    return url;
  }

  Future<ApiResult<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final base = await _requireBaseUrl();
      final uri = Uri.parse('$base$path').replace(queryParameters: query);
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      return _decode(res);
    } on BackendNotConfiguredException {
      return ApiResult.failure(
        'Backend URL not set. Add your ngrok URL in Settings first.',
      );
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final base = await _requireBaseUrl();
      final uri = Uri.parse('$base$path');
      final res = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _decode(res);
    } on BackendNotConfiguredException {
      return ApiResult.failure(
        'Backend URL not set. Add your ngrok URL in Settings first.',
      );
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  ApiResult<Map<String, dynamic>> _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return ApiResult.success({});
      final decoded = jsonDecode(res.body);
      // GET /blood-alert/mine returns a JSON array — wrap it so callers
      // always get a Map back; the array lives under 'items'.
      if (decoded is List) {
        return ApiResult.success({'items': decoded});
      }
      return ApiResult.success(decoded as Map<String, dynamic>);
    }
    String message = 'Request failed (${res.statusCode}).';
    try {
      final decoded = jsonDecode(res.body);
      // FastAPI's HTTPException(detail=...) is what every router in this
      // backend actually raises (400/403/404/409), so 'detail' has to be
      // checked or those messages never reach the user.
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      } else if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      } else if (decoded is Map && decoded['error'] != null) {
        message = decoded['error'].toString();
      }
    } catch (_) {
      // Body wasn't JSON — keep the generic status-code message.
    }
    return ApiResult.failure(message);
  }
}
