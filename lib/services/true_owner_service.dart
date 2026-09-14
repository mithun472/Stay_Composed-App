import '../core/utils/api_result.dart';
import '../models/lost_object_model.dart';
import '../models/found_object_model.dart';
import '../models/match_result_model.dart';
import '../models/verification_model.dart';

/// TODO: Connect backend API here for every method below.
/// [MockTrueOwnerService] (added in Phase 2, alongside the report/match/
/// verification screens) implements this against an in-memory data set so
/// the app is fully navigable before the real API exists. Swapping in a
/// real implementation later means only writing a new class against this
/// same interface — no screen changes required.
abstract class TrueOwnerService {
  Future<ApiResult<LostObject>> createLostReport(LostObject report);

  Future<ApiResult<FoundObject>> createFoundReport(FoundObject report);

  Future<ApiResult<List<LostObject>>> getMyLostReports(String userId);

  Future<ApiResult<List<FoundObject>>> getMyFoundReports(String userId);

  /// Backed by CLIP AI on the server; frontend just renders whatever
  /// ranked [MatchResult]s come back.
  Future<ApiResult<List<MatchResult>>> getMatches(String lostObjectId);

  Future<ApiResult<VerificationRequest>> submitVerification({
    required String verificationRequestId,
    required String submittedSecretInfo,
  });

  Future<ApiResult<Claim>> claimObject(String verificationRequestId);
}
