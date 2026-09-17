/// Lifecycle status of a lost-object report.
enum LostReportStatus {
  searching,
  matchFound,
  verificationPending,
  claimed,
  returned,
  expired,
  closed;

  String get label => switch (this) {
        LostReportStatus.searching => 'Searching',
        LostReportStatus.matchFound => 'Match Found',
        LostReportStatus.verificationPending => 'Verification Pending',
        LostReportStatus.claimed => 'Claimed',
        LostReportStatus.returned => 'Returned',
        LostReportStatus.expired => 'Expired',
        LostReportStatus.closed => 'Closed',
      };
}

/// Lifecycle status of a found-object report.
enum FoundReportStatus {
  awaitingClaim,
  matchFound,
  verificationPending,
  claimed,
  returned,
  unclaimed,
  closed;

  String get label => switch (this) {
        FoundReportStatus.awaitingClaim => 'Awaiting Claim',
        FoundReportStatus.matchFound => 'Match Found',
        FoundReportStatus.verificationPending => 'Verification Pending',
        FoundReportStatus.claimed => 'Claimed',
        FoundReportStatus.returned => 'Returned',
        FoundReportStatus.unclaimed => 'Unclaimed',
        FoundReportStatus.closed => 'Closed',
      };
}

/// Two-sided verification status for a specific match between a lost and
/// found report. Mirrors section 15 of the product spec exactly.
enum VerificationStatus {
  matchFound,
  verificationPending,
  ownerVerificationSubmitted,
  finderVerificationPending,
  verificationSuccessful,
  claimApproved,
  claimRejected,
  dispute,
  expired;

  String get label => switch (this) {
        VerificationStatus.matchFound => 'Match Found',
        VerificationStatus.verificationPending => 'Verification Pending',
        VerificationStatus.ownerVerificationSubmitted => 'Owner Verification Submitted',
        VerificationStatus.finderVerificationPending => 'Finder Verification Pending',
        VerificationStatus.verificationSuccessful => 'Verification Successful',
        VerificationStatus.claimApproved => 'Claim Approved',
        VerificationStatus.claimRejected => 'Claim Rejected',
        VerificationStatus.dispute => 'Dispute',
        VerificationStatus.expired => 'Expired',
      };
}

enum ChatStatus {
  active,
  warning,
  restricted,
  expired,
  closed;

  String get label => switch (this) {
        ChatStatus.active => 'Active',
        ChatStatus.warning => 'Warning',
        ChatStatus.restricted => 'Restricted',
        ChatStatus.expired => 'Expired',
        ChatStatus.closed => 'Closed',
      };
}

enum BloodRequestUrgency {
  routine,
  urgent,
  critical;

  String get label => switch (this) {
        BloodRequestUrgency.routine => 'Routine',
        BloodRequestUrgency.urgent => 'Urgent',
        BloodRequestUrgency.critical => 'Critical',
      };
}

enum BloodRequestStatus {
  pending,
  sentToDepartments,
  fulfilled,
  expired,
  cancelled;

  String get label => switch (this) {
        BloodRequestStatus.pending => 'Pending',
        BloodRequestStatus.sentToDepartments => 'Sent to Departments',
        BloodRequestStatus.fulfilled => 'Fulfilled',
        BloodRequestStatus.expired => 'Expired',
        BloodRequestStatus.cancelled => 'Cancelled',
      };
}

/// Mirrors the canonical type list in the backend's
/// app/services/notification_service.py (KNOWN_TYPES) exactly. The backend
/// sends snake_case; notifications_provider.dart's _parseType() converts
/// snake_case -> camelCase to land here.
///
/// These previously did not overlap with the backend's strings at all
/// (`possibleMatch` / `verificationRequest` / `claimApproved` vs the
/// backend's `match_found` / `chat_opened` / `verification_completed`), so
/// every single notification fell through to the orElse fallback and
/// rendered as the wrong type. Adding a value on either side without
/// adding its twin here reintroduces that silent failure.
enum NotificationType {
  matchFound,
  chatOpened,
  chatMessage,
  verificationCompleted,
  verificationFailed,
  bloodRequestCreated,
  bloodRequestUpdated;

  String get label => switch (this) {
        NotificationType.matchFound => 'Possible Match',
        NotificationType.chatOpened => 'Chat Opened',
        NotificationType.chatMessage => 'New Message',
        NotificationType.verificationCompleted => 'Ownership Verified',
        NotificationType.verificationFailed => 'Verification Failed',
        NotificationType.bloodRequestCreated => 'Blood Alert Sent',
        NotificationType.bloodRequestUpdated => 'Blood Alert Updated',
      };

  /// True for events that belong to the TrueOwner module; false routes to
  /// the blood donation dashboard.
  bool get isTrueOwner => switch (this) {
        NotificationType.bloodRequestCreated ||
        NotificationType.bloodRequestUpdated =>
          false,
        _ => true,
      };
}