import '../core/utils/api_result.dart';
import '../models/chat_model.dart';
import '../models/blood_request_model.dart';

/// TODO: Connect backend API here for every method below (likely a
/// websocket or polling endpoint for live messages).
abstract class ChatService {
  Future<ApiResult<Chat>> getChat(String chatId);
  Future<ApiResult<ChatMessage>> sendMessage(String chatId, String text);
  Future<ApiResult<void>> closeChat(String chatId);
  Future<ApiResult<void>> reportChat(String chatId, String reason);
  Future<ApiResult<void>> blockUser(String chatId, String userId);
}

/// TODO: Connect backend API here for every method below.
abstract class BloodDonationService {
  Future<ApiResult<BloodRequest>> createBloodRequest(BloodRequest request);
  Future<ApiResult<List<BloodRequest>>> getBloodRequests();
  Future<ApiResult<List<BloodRequest>>> getMyRequests(String userId);

  /// Backend forwards this to the appropriate college departments by
  /// email — the Flutter app never sends email directly.
  Future<ApiResult<void>> sendRequestToDepartments(String requestId);
}

/// TODO: Connect backend API here — real implementation should upload to
/// Cloudinary via a signed backend endpoint, never with Cloudinary
/// credentials embedded in the client.
abstract class ImageUploadService {
  Future<ApiResult<String>> uploadImage(String localFilePath);
  Future<ApiResult<void>> deleteImage(String imageUrl);
}

/// TODO: Connect backend API here — real implementation calls the CLIP-AI
/// matching endpoint. Kept as its own service (rather than folded into
/// TrueOwnerService) so the matching call is easy to swap, mock, or retry
/// independently of report CRUD.
abstract class AIService {
  Future<ApiResult<void>> requestMatchSearch(String lostObjectId);
}
