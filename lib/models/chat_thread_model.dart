import 'package:equatable/equatable.dart';

/// Where a thread sits in the owner/finder flow. Derived from the
/// backend's `status` + timestamps rather than stored separately, so the
/// server stays the single source of truth.
enum ChatPhase {
  /// Matched, talking, but the finder hasn't started verification yet.
  /// Canned prompts only — no free text (see [CannedPrompts]).
  preVerification,

  /// Finder pressed start-verification. Chat is locked; the owner's only
  /// move is answering the challenge questions via POST /claims.
  verifying,

  /// Ownership proved. Free text unlocks for handover coordination.
  verified,

  /// Handover done. Read-only, permanently.
  handedOver;

  String get label => switch (this) {
        ChatPhase.preVerification => 'Chatting',
        ChatPhase.verifying => 'Verification in progress',
        ChatPhase.verified => 'Verified',
        ChatPhase.handedOver => 'Handed over',
      };
}

class ChatThread extends Equatable {
  final String threadId;
  final String complaintId;
  final String foundItemId;
  final String claimantEmail;
  final String founderEmail;
  final int confidence;
  final String status;
  final DateTime? createdAt;
  final DateTime? verificationStartedAt;
  final DateTime? handedOverAt;

  const ChatThread({
    required this.threadId,
    required this.complaintId,
    required this.foundItemId,
    required this.claimantEmail,
    required this.founderEmail,
    this.confidence = 0,
    this.status = 'chat',
    this.createdAt,
    this.verificationStartedAt,
    this.handedOverAt,
  });

  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      threadId: (json['threadId'] ?? json['thread_id'] ?? json['id'] ?? '').toString(),
      complaintId: json['complaintId']?.toString() ?? '',
      foundItemId: json['foundItemId']?.toString() ?? '',
      claimantEmail: json['claimantEmail']?.toString() ?? '',
      founderEmail: json['founderEmail']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.round() ?? 0,
      status: json['status']?.toString() ?? 'chat',
      createdAt: _date(json['createdAt']),
      verificationStartedAt: _date(json['verificationStartedAt']),
      handedOverAt: _date(json['handedOverAt']),
    );
  }

  /// Timestamps win over [status] strings, because they're unambiguous —
  /// status wording may change server-side without breaking this.
  ChatPhase get phase {
    final s = status.toLowerCase();
    if (handedOverAt != null || s.contains('handed')) return ChatPhase.handedOver;
    if (s.contains('verified') || s.contains('claimed')) return ChatPhase.verified;
    if (verificationStartedAt != null || s.contains('verif')) return ChatPhase.verifying;
    return ChatPhase.preVerification;
  }

  bool get canSendFreeText => phase == ChatPhase.verified;
  bool get isClosed => phase == ChatPhase.handedOver;

  ChatThread copyWith({String? status, DateTime? verificationStartedAt, DateTime? handedOverAt}) {
    return ChatThread(
      threadId: threadId,
      complaintId: complaintId,
      foundItemId: foundItemId,
      claimantEmail: claimantEmail,
      founderEmail: founderEmail,
      confidence: confidence,
      status: status ?? this.status,
      createdAt: createdAt,
      verificationStartedAt: verificationStartedAt ?? this.verificationStartedAt,
      handedOverAt: handedOverAt ?? this.handedOverAt,
    );
  }

  @override
  List<Object?> get props => [threadId, status, verificationStartedAt, handedOverAt];
}

class ChatMessage extends Equatable {
  final String id;
  final String threadId;
  final String senderEmail;
  final String text;
  final DateTime? sentAt;

  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderEmail,
    required this.text,
    this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      threadId: json['threadId']?.toString() ?? '',
      senderEmail: json['senderEmail']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      sentAt: json['sentAt'] != null ? DateTime.tryParse(json['sentAt'].toString()) : null,
    );
  }

  bool isMine(String myEmail) => senderEmail.toLowerCase() == myEmail.toLowerCase();

  @override
  List<Object?> get props => [id, threadId, senderEmail, text, sentAt];
}
