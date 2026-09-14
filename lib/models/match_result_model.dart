import 'package:equatable/equatable.dart';

/// A CLIP-AI-suggested match between a lost report and a found report.
///
/// This is presentational only — a suggestion, never proof of ownership.
/// Every screen that renders a [MatchResult] must make that explicit to
/// the user (see TrueOwnerDisclaimerBanner in core/widgets).
class MatchResult extends Equatable {
  final String id;
  final String lostObjectId;
  final String foundObjectId;

  final String objectName;
  final String category;
  final double matchConfidence; // 0.0–1.0
  final String? foundImageUrl;
  final String foundLocation;
  final DateTime foundDate;
  final String generalDescription;

  const MatchResult({
    required this.id,
    required this.lostObjectId,
    required this.foundObjectId,
    required this.objectName,
    required this.category,
    required this.matchConfidence,
    this.foundImageUrl,
    required this.foundLocation,
    required this.foundDate,
    required this.generalDescription,
  });

  int get confidencePercent => (matchConfidence * 100).round();

  @override
  List<Object?> get props => [id, lostObjectId, foundObjectId, matchConfidence];
}
