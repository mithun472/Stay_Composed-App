import 'package:equatable/equatable.dart';
import 'enums.dart';

/// A found-object report.
///
/// Same privacy rule as [LostObject]: [secretVerificationInfo] is the
/// finder's own private notes about identifying details and must never be
/// shown to anyone other than the finder — it's what a claimant's answer
/// gets compared against.
///
/// [publicSummary] is the deliberately limited, safe-to-show-everyone
/// version described in spec section 10 (e.g. "Black chain found near the
/// library") — short, generic, and never containing the private details.
class FoundObject extends Equatable {
  final String id;
  final String finderId;
  final String finderName;

  final String objectName;
  final String category;
  final DateTime foundDate;
  final String? foundTime;
  final String foundLocation;
  final String publicSummary;
  final String? generalDescription;
  final String? imageUrl;

  // Private — never surface outside the finder's own screens.
  final String secretVerificationInfo;
  final String? additionalDetails;

  final FoundReportStatus status;
  final DateTime createdAt;

  const FoundObject({
    required this.id,
    required this.finderId,
    required this.finderName,
    required this.objectName,
    required this.category,
    required this.foundDate,
    this.foundTime,
    required this.foundLocation,
    required this.publicSummary,
    this.generalDescription,
    this.imageUrl,
    required this.secretVerificationInfo,
    this.additionalDetails,
    this.status = FoundReportStatus.awaitingClaim,
    required this.createdAt,
  });

  FoundObject copyWith({FoundReportStatus? status}) {
    return FoundObject(
      id: id,
      finderId: finderId,
      finderName: finderName,
      objectName: objectName,
      category: category,
      foundDate: foundDate,
      foundTime: foundTime,
      foundLocation: foundLocation,
      publicSummary: publicSummary,
      generalDescription: generalDescription,
      imageUrl: imageUrl,
      secretVerificationInfo: secretVerificationInfo,
      additionalDetails: additionalDetails,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, finderId, objectName, category, foundDate, foundLocation, status];
}
