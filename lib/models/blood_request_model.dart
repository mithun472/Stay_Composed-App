import 'package:equatable/equatable.dart';
import 'enums.dart';

class BloodRequest extends Equatable {
  final String id;
  final String patientName;
  final String bloodGroup;
  final int requiredUnits;
  final String hospitalName;
  final String hospitalLocation;
  final DateTime requiredDate;
  final BloodRequestUrgency urgency;
  final String? patientInfo;

  final String requesterId;
  final String requesterName;
  final String requesterDepartment;
  final String? contactInfo;
  final String? additionalMessage;

  final BloodRequestStatus status;
  final DateTime createdAt;

  const BloodRequest({
    required this.id,
    required this.patientName,
    required this.bloodGroup,
    required this.requiredUnits,
    required this.hospitalName,
    required this.hospitalLocation,
    required this.requiredDate,
    required this.urgency,
    this.patientInfo,
    required this.requesterId,
    required this.requesterName,
    required this.requesterDepartment,
    this.contactInfo,
    this.additionalMessage,
    this.status = BloodRequestStatus.pending,
    required this.createdAt,
  });

  BloodRequest copyWith({BloodRequestStatus? status}) {
    return BloodRequest(
      id: id,
      patientName: patientName,
      bloodGroup: bloodGroup,
      requiredUnits: requiredUnits,
      hospitalName: hospitalName,
      hospitalLocation: hospitalLocation,
      requiredDate: requiredDate,
      urgency: urgency,
      patientInfo: patientInfo,
      requesterId: requesterId,
      requesterName: requesterName,
      requesterDepartment: requesterDepartment,
      contactInfo: contactInfo,
      additionalMessage: additionalMessage,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, patientName, bloodGroup, status];
}
