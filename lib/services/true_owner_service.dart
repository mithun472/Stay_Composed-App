import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/utils/api_result.dart';
import '../models/item_model.dart';
import '../models/chat_thread_model.dart';
import '../models/claim_model.dart';
import 'blood_alert_service.dart' show apiClientProvider;

/// Every REST route in the true-owner flow. One method per backend route,
/// same names as the docs, so the mapping stays obvious:
///
///   POST /items
///   GET  /items/mine?email=
///   POST /chat/thread
///   GET  /chat/my-threads?email=
///   GET  /chat/{thread_id}/messages?email=
///   POST /claims
///   POST /chat/{thread_id}/complete-handover?email=
///
/// The WebSocket lives in [ChatSocketService] instead — different
/// transport, different lifecycle.
abstract class TrueOwnerService {
  Future<ApiResult<Item>> createItem(
    Item item, {
    required String reporterEmail,
    required String reporterName,
  });

  Future<ApiResult<MyItems>> getMine(String email);

  Future<ApiResult<ChatThread>> openThread({
    required String complaintId,
    required String foundItemId,
    required String requesterEmail,
  });

  Future<ApiResult<List<ChatThread>>> getMyThreads(String email);

  Future<ApiResult<List<ChatMessage>>> getMessages(String threadId, String email);

  Future<ApiResult<ClaimResult>> submitClaim({
    required String complaintId,
    required String foundItemId,
    required List<String> answers,
    required String claimantEmail,
  });

  Future<ApiResult<void>> completeHandover(String threadId, String email);
}

class TrueOwnerServiceImpl extends TrueOwnerService {
  final ApiClient _client;
  TrueOwnerServiceImpl(this._client);

  /// Thread ids are `complaintId:foundItemId`, so the colon has to survive
  /// into the path unencoded while anything odd still gets escaped.
  String _segment(String value) => Uri.encodeComponent(value).replaceAll('%3A', ':');

  @override
  Future<ApiResult<Item>> createItem(
    Item item, {
    required String reporterEmail,
    required String reporterName,
  }) async {
    final body = item.toCreateJson(reporterEmail: reporterEmail, reporterName: reporterName);
    final result = await _client.post('/items', body);
    return result.when(
      success: (data) {
        try {
          // Backend may echo the created item, wrap it, or return a bare ack.
          final raw = data['item'] is Map<String, dynamic> ? data['item'] as Map<String, dynamic> : data;
          if (raw['id'] != null || raw['_id'] != null) {
            return ApiResult.success(Item.fromJson(raw));
          }
          return ApiResult.success(item);
        } catch (e) {
          return ApiResult.failure('Could not read the server response: $e');
        }
      },
      failure: (message) => ApiResult.failure(message),
    );
  }

  @override
  Future<ApiResult<MyItems>> getMine(String email) async {
    final result = await _client.get('/items/mine', query: {'email': email});
    return result.when(
      success: (data) {
        try {
          return ApiResult.success(MyItems.fromJson(data));
        } catch (e) {
          return ApiResult.failure('Could not read your reports: $e');
        }
      },
      failure: (message) => ApiResult.failure(message),
    );
  }

  @override
  Future<ApiResult<ChatThread>> openThread({
    required String complaintId,
    required String foundItemId,
    required String requesterEmail,
  }) async {
    final result = await _client.post('/chat/thread', {
      'complaintId': complaintId,
      'foundItemId': foundItemId,
      'requesterEmail': requesterEmail,
    });
    return result.when(
      success: (data) {
        try {
          final raw = data['thread'] is Map<String, dynamic> ? data['thread'] as Map<String, dynamic> : data;
          final thread = ChatThread.fromJson(raw);
          if (thread.threadId.isEmpty) {
            // Fall back to the documented id format rather than failing the
            // whole action over a missing echo field.
            return ApiResult.success(ChatThread(
              threadId: '$complaintId:$foundItemId',
              complaintId: complaintId,
              foundItemId: foundItemId,
              claimantEmail: requesterEmail,
              founderEmail: '',
            ));
          }
          return ApiResult.success(thread);
        } catch (e) {
          return ApiResult.failure('Could not open this chat: $e');
        }
      },
      failure: (message) => ApiResult.failure(message),
    );
  }

  @override
  Future<ApiResult<List<ChatThread>>> getMyThreads(String email) async {
    final result = await _client.get('/chat/my-threads', query: {'email': email});
    return result.when(
      success: (data) {
        try {
          // ApiClient wraps top-level JSON arrays under 'items'.
          final rawItems = data['items'];
          final items = rawItems is List ? rawItems : const [];
          return ApiResult.success(
            items.whereType<Map<String, dynamic>>().map(ChatThread.fromJson).toList(),
          );
        } catch (e) {
          return ApiResult.failure('Could not load your chats: $e');
        }
      },
      failure: (message) => ApiResult.failure(message),
    );
  }

  @override
  Future<ApiResult<List<ChatMessage>>> getMessages(String threadId, String email) async {
    final result = await _client.get('/chat/${_segment(threadId)}/messages', query: {'email': email});
    return result.when(
      success: (data) {
        try {
          final rawItems = data['items'];
          final items = rawItems is List ? rawItems : const [];
          final messages =
              items.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
          messages.sort((a, b) {
            final at = a.sentAt, bt = b.sentAt;
            if (at == null || bt == null) return 0;
            return at.compareTo(bt);
          });
          return ApiResult.success(messages);
        } catch (e) {
          return ApiResult.failure('Could not load messages for this chat: $e');
        }
      },
      failure: (message) => ApiResult.failure(message),
    );
  }

  @override
  Future<ApiResult<ClaimResult>> submitClaim({
    required String complaintId,
    required String foundItemId,
    required List<String> answers,
    required String claimantEmail,
  }) async {
    final result = await _client.post('/claims', {
      'complaintId': complaintId,
      'foundItemId': foundItemId,
      'answers': answers,
      'claimantEmail': claimantEmail,
    });
    return result.when(
      success: (data) {
        try {
          return ApiResult.success(ClaimResult.fromJson(data));
        } catch (e) {
          return ApiResult.failure('Could not read the verification result: $e');
        }
      },
      failure: (message) => ApiResult.failure(message),
    );
  }

  @override
  Future<ApiResult<void>> completeHandover(String threadId, String email) async {
    // Query string goes in the path — ApiClient.post takes no query map,
    // and Uri.parse keeps it intact.
    final path = '/chat/${_segment(threadId)}/complete-handover'
        '?email=${Uri.encodeQueryComponent(email)}';
    final result = await _client.post(path, const {});
    return result.when(
      success: (_) => ApiResult.success(null),
      failure: (message) => ApiResult.failure(message),
    );
  }
}

final trueOwnerServiceProvider = Provider<TrueOwnerService>(
  (ref) => TrueOwnerServiceImpl(ref.watch(apiClientProvider)),
);