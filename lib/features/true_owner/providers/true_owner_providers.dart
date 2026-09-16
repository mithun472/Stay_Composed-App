import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/api_result.dart';
import '../../../models/item_model.dart';
import '../../../models/chat_thread_model.dart';
import '../../../services/true_owner_service.dart';
import '../../authentication/providers/auth_provider.dart';

/// Email of the signed-in college account. Every true-owner route is
/// keyed on it, so screens read it from here instead of digging into
/// auth state themselves.
final currentEmailProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).user?.collegeEmail;
});

final currentNameProvider = Provider<String>((ref) {
  return ref.watch(authControllerProvider).user?.name ?? 'Student';
});

class NotSignedInException implements Exception {
  @override
  String toString() => 'Sign in with your college email first.';
}

class BackendUrlMissingException implements Exception {
  @override
  String toString() =>
      'Backend URL not set. Add your ngrok URL in Settings first.';
}

/// Unwraps [ApiResult] into AsyncValue so screens can use .when() once
/// rather than nesting a second switch inside every builder.
T _unwrap<T>(ApiResult<T> result) {
  return result.when(
    success: (data) => data,
    failure: (message) {
      if (message == 'Backend URL not set. Add your ngrok URL in Settings first.') {
        throw BackendUrlMissingException();
      }

      throw Exception(message);
    },
  );
}

/// `GET /items/mine` — complaints, found reports and AI candidates in one
/// call. Invalidate this after any write to refresh the dashboard.
final myItemsProvider = FutureProvider.autoDispose<MyItems>((ref) async {
  final email = ref.watch(currentEmailProvider);
  if (email == null) throw NotSignedInException();
  return _unwrap(await ref.watch(trueOwnerServiceProvider).getMine(email));
});

/// `GET /chat/my-threads`
final myThreadsProvider = FutureProvider.autoDispose<List<ChatThread>>((ref) async {
  final email = ref.watch(currentEmailProvider);
  if (email == null) throw NotSignedInException();
  return _unwrap(await ref.watch(trueOwnerServiceProvider).getMyThreads(email));
});

/// One thread, refetched from the list so phase changes made by the
/// finder (start-verification) show up without a full-screen reload.
final threadByIdProvider =
    FutureProvider.autoDispose.family<ChatThread?, String>((ref, threadId) async {
  final threads = await ref.watch(myThreadsProvider.future);
  for (final t in threads) {
    if (t.threadId == threadId) return t;
  }
  return null;
});

/// Refresh everything the true-owner screens read. Called after creating
/// an item, opening a thread, claiming, or completing a handover.
void invalidateTrueOwner(WidgetRef ref) {
  ref.invalidate(myItemsProvider);
  ref.invalidate(myThreadsProvider);
}

extension TrueOwnerRefresh on WidgetRef {
  void refreshTrueOwner() {
    invalidate(myItemsProvider);
    invalidate(myThreadsProvider);
  }
}
