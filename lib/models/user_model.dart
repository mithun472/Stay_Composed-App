import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String id;
  final String name;
  final String collegeEmail;
  final String? photoUrl;
  final String? department;
  final String? year;
  final bool isVerifiedCollegeAccount;

  const AppUser({
    required this.id,
    required this.name,
    required this.collegeEmail,
    this.photoUrl,
    this.department,
    this.year,
    this.isVerifiedCollegeAccount = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      collegeEmail: json['collegeEmail'] as String,
      photoUrl: json['photoUrl'] as String?,
      department: json['department'] as String?,
      year: json['year'] as String?,
      isVerifiedCollegeAccount: json['isVerifiedCollegeAccount'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'collegeEmail': collegeEmail,
        'photoUrl': photoUrl,
        'department': department,
        'year': year,
        'isVerifiedCollegeAccount': isVerifiedCollegeAccount,
      };

  AppUser copyWith({
    String? name,
    String? photoUrl,
    String? department,
    String? year,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      collegeEmail: collegeEmail,
      photoUrl: photoUrl ?? this.photoUrl,
      department: department ?? this.department,
      year: year ?? this.year,
      isVerifiedCollegeAccount: isVerifiedCollegeAccount,
    );
  }

  @override
  List<Object?> get props => [id, name, collegeEmail, photoUrl, department, year, isVerifiedCollegeAccount];
}
