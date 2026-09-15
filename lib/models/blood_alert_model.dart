/// Model for the Blood Alert module. Field names match the Python backend
/// exactly (`POST /blood-alert` body, `GET /blood-alert/mine` response):
///   { "studentName": ..., "bloodType": ..., "phoneNumber": ..., "senderEmail": ... }
class BloodAlert {
  final String? id;
  final String studentName;
  final String bloodType;
  final String phoneNumber;
  final String senderEmail;
  final String? status;
  final DateTime? createdAt;

  const BloodAlert({
    this.id,
    required this.studentName,
    required this.bloodType,
    required this.phoneNumber,
    required this.senderEmail,
    this.status,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'studentName': studentName,
        'bloodType': bloodType,
        'phoneNumber': phoneNumber,
        'senderEmail': senderEmail,
      };

  factory BloodAlert.fromJson(Map<String, dynamic> json) {
    return BloodAlert(
      id: (json['id'] ?? json['_id'])?.toString(),
      studentName: json['studentName'] as String? ?? '',
      bloodType: json['bloodType'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      senderEmail: json['senderEmail'] as String? ?? '',
      status: json['status'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}