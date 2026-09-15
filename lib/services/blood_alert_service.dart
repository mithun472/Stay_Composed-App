import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/utils/api_result.dart';
import '../models/blood_alert_model.dart';

/// Talks to the two Python backend routes for the Blood Alert module:
///   POST /blood-alert
///   GET  /blood-alert/mine?email={email}
abstract class BloodAlertService {
  Future<ApiResult<BloodAlert>> sendAlert(BloodAlert alert);
  Future<ApiResult<List<BloodAlert>>> getMine(String email);
}

class BloodAlertServiceImpl extends BloodAlertService {
  final ApiClient _client;
  BloodAlertServiceImpl(this._client);

  @override
  Future<ApiResult<BloodAlert>> sendAlert(BloodAlert alert) async {
    final result = await _client.post('/blood-alert', alert.toJson());
    return result.when(
      success: (data) {
        // Backend may echo the created alert back, or just return
        // {"status": "sent"} — handle either without crashing.
        if (data.containsKey('name') || data.containsKey('bloodGroup')) {
          return ApiResult.success(BloodAlert.fromJson(data));
        }
        return ApiResult.success(alert);
      },
      failure: (message) => ApiResult.failure(message),
    );
  }

  @override
  Future<ApiResult<List<BloodAlert>>> getMine(String email) async {
    final result = await _client.get('/blood-alert/mine', query: {'email': email});
    return result.when(
      success: (data) {
        final items = (data['items'] as List?) ?? const [];
        final alerts = items
            .whereType<Map<String, dynamic>>()
            .map(BloodAlert.fromJson)
            .toList();
        return ApiResult.success(alerts);
      },
      failure: (message) => ApiResult.failure(message),
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => const ApiClient());

final bloodAlertServiceProvider = Provider<BloodAlertService>(
  (ref) => BloodAlertServiceImpl(ref.watch(apiClientProvider)),
);
