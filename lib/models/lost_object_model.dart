import 'package:equatable/equatable.dart';
import 'enums.dart';

/// A lost-object complaint.
///
/// IMPORTANT: [secretVerificationInfo] must never be rendered in any public
/// or shared-with-finder UI. It exists only to be compared, server-side,
/// against a claimant's submitted verification answer (see
/// [VerificationRequest]). Treat it the same way you'd treat a password —
/// display it back ONLY on screens owned exclusively by the reporting user
/// (e.g. "My Lost Reports" detail view, editable by them).
class LostObject extends Equatable {
  final String id;
  final String reporterId;
  final String reporterName;

  // Public fields — safe to show in match cards, dashboards, etc.
  final String objectName;
  final String category;
  final DateTime dateLost;
  final String? approximateTimeLost;
  final String locationLost;
  final String description;
  final String? color;
  final String? brand;
  final String? additionalInfo;
  final String? imageUrl;

  // Private field — NEVER surface this outside the owner's own screens.
  final String secretVerificationInfo;

  final LostReportStatus status;
  final DateTime createdAt;

  const LostObject({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.objectName,
    required this.category,
    required this.dateLost,
    this.approximateTimeLost,
    required this.locationLost,
    required this.description,
    this.color,
    this.brand,
    this.additionalInfo,
    this.imageUrl,
    required this.secretVerificationInfo,
    this.status = LostReportStatus.searching,
    required this.createdAt,
  });

  LostObject copyWith({LostReportStatus? status}) {
    return LostObject(
      id: id,
      reporterId: reporterId,
      reporterName: reporterName,
      objectName: objectName,
      category: category,
      dateLost: dateLost,
      approximateTimeLost: approximateTimeLost,
      locationLost: locationLost,
      description: description,
      color: color,
      brand: brand,
      additionalInfo: additionalInfo,
      imageUrl: imageUrl,
      secretVerificationInfo: secretVerificationInfo,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        reporterId,
        objectName,
        category,
        dateLost,
        locationLost,
        description,
        status,
      ];
}
