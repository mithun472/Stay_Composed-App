import 'package:equatable/equatable.dart';

/// One lost-or-found item, shaped exactly like the FastAPI `/items`
/// payloads. `type` is "lost" (a complaint) or "found" (a found report).
///
/// PRIVACY: [secretFeatures] only ever comes back populated on the
/// signed-in user's OWN items. On a candidate match it is null, and must
/// never be rendered anywhere a non-owner can see it.
class Item extends Equatable {
  final String id;
  final String type; // 'lost' | 'found'
  final String title;
  final String category;
  final String location;
  final String? locationDetail;
  final String date; // ISO date string, kept as-is for round-tripping
  final String description;
  final String? imageUrl;
  final List<String> secretFeatures;
  final List<String> challengeQuestions;

  /// Write-only. The finder's answers to [challengeQuestions], index-aligned,
  /// sent only on `POST /items` for a found report — the backend hashes
  /// them into `secretAnswerHashes`/`secretAnswerEmbeddings` and never
  /// returns them. Leave empty on anything read back from the server.
  final List<String> secretAnswers;

  final String? reportedBy; // already masked by the backend (e.g. "Campus Member A***")
  final String status;
  final DateTime? createdAt;

  const Item({
    required this.id,
    required this.type,
    required this.title,
    required this.category,
    required this.location,
    this.locationDetail,
    required this.date,
    required this.description,
    this.imageUrl,
    this.secretFeatures = const [],
    this.challengeQuestions = const [],
    this.secretAnswers = const [],
    this.reportedBy,
    this.status = 'open',
    this.createdAt,
  });

  bool get isLost => type == 'lost';

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return const [];
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: json['type']?.toString() ?? 'lost',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      locationDetail: json['locationDetail']?.toString(),
      date: json['date']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      secretFeatures: _stringList(json['secretFeatures']),
      challengeQuestions: _stringList(json['challengeQuestions']),
      reportedBy: json['reportedBy']?.toString(),
      status: json['status']?.toString() ?? 'open',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  /// Body for `POST /items`. Only the fields the backend accepts on
  /// create — id/status/createdAt are server-owned.
  ///
  /// Field rules the backend enforces (app/routers/items.py):
  ///  - `location` must be blank or one of [CampusLocations.all] for
  ///    "lost"; compulsory and from that same list for "found".
  ///  - `locationDetail` only matters when `location == "Others"`.
  ///  - "found" requires a non-empty `imageUrl`, plus equal-length
  ///    non-empty `challengeQuestions` and `secretAnswers`.
  ///  - "lost" requires at least one non-empty `secretFeatures` entry.
  Map<String, dynamic> toCreateJson({
    required String reporterEmail,
    required String reporterName,
  }) {
    return {
      'type': type,
      'title': title,
      'category': category,
      if (location.trim().isNotEmpty) 'location': location,
      if (locationDetail != null && locationDetail!.trim().isNotEmpty)
        'locationDetail': locationDetail!.trim(),
      'date': date,
      'description': description,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      if (isLost) 'secretFeatures': secretFeatures,
      if (!isLost) ...{
        'challengeQuestions': challengeQuestions,
        'secretAnswers': secretAnswers,
      },
      'reporterEmail': reporterEmail,
      'reporterName': reporterName,
    };
  }

  @override
  List<Object?> get props => [id, type, title, status];
}

/// An AI-suggested found item for one of the owner's complaints.
/// [confidence] is a 0–100 integer, straight from the backend.
class CandidateMatch extends Equatable {
  final Item candidate;
  final String forComplaintId;
  final int confidence;

  const CandidateMatch({
    required this.candidate,
    required this.forComplaintId,
    required this.confidence,
  });

  factory CandidateMatch.fromJson(Map<String, dynamic> json) {
    final raw = json['candidate'];
    return CandidateMatch(
      candidate: Item.fromJson(raw is Map<String, dynamic> ? raw : const {}),
      forComplaintId: json['forComplaintId']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.round() ?? 0,
    );
  }

  @override
  List<Object?> get props => [candidate.id, forComplaintId, confidence];
}

/// Whole `GET /items/mine` payload.
class MyItems {
  final List<Item> myComplaints;
  final List<Item> myFoundItems;
  final List<CandidateMatch> candidateMatches;

  /// Minimum confidence the backend requires before a chat thread can be
  /// opened. Read from the response if the backend sends it; otherwise
  /// null, and the UI stops gating locally and lets the API decide.
  final int? chatConfidenceThreshold;

  const MyItems({
    this.myComplaints = const [],
    this.myFoundItems = const [],
    this.candidateMatches = const [],
    this.chatConfidenceThreshold,
  });

  static List<Item> _items(dynamic value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().map(Item.fromJson).toList();
    }
    return const [];
  }

  factory MyItems.fromJson(Map<String, dynamic> json) {
    final matches = json['candidateMatches'];
    final rawThreshold =
        json['chatConfidenceThreshold'] ?? json['confidenceThreshold'] ?? json['threshold'];
    final threshold = rawThreshold is num ? rawThreshold : num.tryParse(rawThreshold?.toString() ?? '');
    return MyItems(
      myComplaints: _items(json['myComplaints']),
      myFoundItems: _items(json['myFoundItems']),
      candidateMatches: matches is List
          ? matches.whereType<Map<String, dynamic>>().map(CandidateMatch.fromJson).toList()
          : const [],
      chatConfidenceThreshold: threshold?.round(),
    );
  }

  /// Matches belonging to one complaint, best first.
  List<CandidateMatch> matchesFor(String complaintId) {
    final list = candidateMatches.where((m) => m.forComplaintId == complaintId).toList();
    list.sort((a, b) => b.confidence.compareTo(a.confidence));
    return list;
  }

  Item? complaintById(String id) {
    for (final c in myComplaints) {
      if (c.id == id) return c;
    }
    return null;
  }
}
