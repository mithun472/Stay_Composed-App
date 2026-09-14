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

enum NotificationType {
  possibleMatch,
  verificationRequest,
  claimApproved,
  claimRejected,
  chatExpiring,
  bloodRequestCreated,
  bloodRequestUpdated,
}
