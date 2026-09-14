import 'package:equatable/equatable.dart';
import 'enums.dart';

/// Tracks the two-sided verification process for one matched pair.
///
/// The claimant's [submittedSecretInfo] is compared by the finder (and,
/// eventually, backend logic) against the private info stored on the
/// [LostObject]/[FoundObject] — it is never auto-revealed to either side.
class VerificationRequest extends Equatable {
  final String id;
  final String matchId;
  final String lostObjectId;
  final String foundObjectId;

  final String ownerId;
  final String ownerName;
  final String finderId;
  final String finderName;
  final String objectName;

  final VerificationStatus status;
  final String? submittedSecretInfo;
  final int attemptsRemaining;
  final int maxAttempts;
  final DateTime createdAt;
  final DateTime expiresAt;

  const VerificationRequest({
    required this.id,
    required this.matchId,
    required this.lostObjectId,
    required this.foundObjectId,
    required this.ownerId,
    required this.ownerName,
    required this.finderId,
    required this.finderName,
    required this.objectName,
    this.status = VerificationStatus.matchFound,
    this.submittedSecretInfo,
    required this.attemptsRemaining,
    required this.maxAttempts,
    required this.createdAt,
    required this.expiresAt,
  });

  VerificationRequest copyWith({
    VerificationStatus? status,
    String? submittedSecretInfo,
    int? attemptsRemaining,
  }) {
    return VerificationRequest(
      id: id,
      matchId: matchId,
      lostObjectId: lostObjectId,
      foundObjectId: foundObjectId,
      ownerId: ownerId,
      ownerName: ownerName,
      finderId: finderId,
      finderName: finderName,
      objectName: objectName,
      status: status ?? this.status,
      submittedSecretInfo: submittedSecretInfo ?? this.submittedSecretInfo,
      attemptsRemaining: attemptsRemaining ?? this.attemptsRemaining,
      maxAttempts: maxAttempts,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  @override
  List<Object?> get props => [id, matchId, status, attemptsRemaining];
}

class Claim extends Equatable {
  final String id;
  final String verificationRequestId;
  final String objectName;
  final VerificationStatus status;
  final DateTime? approvedAt;
  final String? returnInstructions;

  const Claim({
    required this.id,
    required this.verificationRequestId,
    required this.objectName,
    required this.status,
    this.approvedAt,
    this.returnInstructions,
  });

  @override
  List<Object?> get props => [id, verificationRequestId, status];
}
