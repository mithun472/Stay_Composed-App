/// Result of `POST /claims` — the owner's answers scored against the
/// finder's challenge answers. More than half must match.
class ClaimResult {
  final bool verified;
  final int matchedFields;
  final int totalFields;
  final String message;
  final DateTime? cooldownUntil;

  const ClaimResult({
    required this.verified,
    required this.matchedFields,
    required this.totalFields,
    required this.message,
    this.cooldownUntil,
  });

  factory ClaimResult.fromJson(Map<String, dynamic> json) {
    return ClaimResult(
      verified: json['verified'] as bool? ?? false,
      matchedFields: (json['matchedFields'] as num?)?.round() ?? 0,
      totalFields: (json['totalFields'] as num?)?.round() ?? 0,
      message: json['message']?.toString() ?? '',
      cooldownUntil: json['cooldownUntil'] != null
          ? DateTime.tryParse(json['cooldownUntil'].toString())
          : null,
    );
  }

  bool get isOnCooldown => cooldownUntil != null && cooldownUntil!.isAfter(DateTime.now());
}
