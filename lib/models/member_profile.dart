class MemberProfile {
  final String memberId;
  final String brethrenId;
  final String displayName;
  final String role;
  final String membershipStatus;

  final String? lodgeName;
  final int? lodgeNumber;
  final String? city;
  final String? province;

  final String? profilePhotoUrl;
  final DateTime? birthday;
  final String? bloodType;

  final DateTime? enteredApprentice;
  final DateTime? fellowcraft;
  final DateTime? masterMason;

  final String? occupation;
  final String? company;
  final String? workAddress;
  final String? workPhone;

  final String? mobile;
  final String? emergencyContactName;
  final String? emergencyContactNumber;

  final bool birthdayPending;
  final bool bloodTypePending;

  final bool enteredApprenticePending;
  final bool fellowcraftPending;
  final bool masterMasonPending;

  final String? birthdayRequested;
  final String? bloodTypeRequested;

  final String? enteredApprenticeRequested;
  final String? fellowcraftRequested;
  final String? masterMasonRequested;

  MemberProfile({
    required this.memberId,
    required this.brethrenId,
    required this.displayName,
    required this.role,
    required this.membershipStatus,
    this.lodgeName,
    this.lodgeNumber,
    this.city,
    this.province,
    this.profilePhotoUrl,
    this.birthday,
    this.bloodType,
    this.enteredApprentice,
    this.fellowcraft,
    this.masterMason,
    this.occupation,
    this.company,
    this.workAddress,
    this.workPhone,
    this.mobile,
    this.emergencyContactName,
    this.emergencyContactNumber,
    required this.birthdayPending,
    required this.bloodTypePending,
    required this.enteredApprenticePending,
    required this.fellowcraftPending,
    required this.masterMasonPending,
    this.birthdayRequested,
    this.bloodTypeRequested,
    this.enteredApprenticeRequested,
    this.fellowcraftRequested,
    this.masterMasonRequested,
  });

  factory MemberProfile.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return MemberProfile(
      memberId: (json['member_id'] ?? '').toString(),
      brethrenId: (json['brethren_id'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      membershipStatus: (json['membership_status'] ?? '').toString(),
      lodgeName: json['lodge_name']?.toString(),
      lodgeNumber: json['lodge_number'],
      city: json['city']?.toString(),
      province: json['province']?.toString(),
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      birthday: parseDate(json['birthday']),
      bloodType: json['blood_type']?.toString(),
      enteredApprentice: parseDate(json['date_entered_apprentice']),
      fellowcraft: parseDate(json['date_fellowcraft']),
      masterMason: parseDate(json['date_master_mason']),
      occupation: json['occupation']?.toString(),
      company: json['company_name']?.toString(),
      workAddress: json['work_address']?.toString(),
      workPhone: json['work_phone']?.toString(),
      mobile: json['primary_contact_number']?.toString(),
      emergencyContactName: json['emergency_contact_name']?.toString(),
      emergencyContactNumber: json['emergency_contact_number']?.toString(),
      birthdayPending: json['birthday_pending'] == true,
      bloodTypePending: json['blood_type_pending'] == true,
      enteredApprenticePending: json['entered_apprentice_pending'] == true,
      fellowcraftPending: json['fellowcraft_pending'] == true,
      masterMasonPending: json['master_mason_pending'] == true,
      birthdayRequested: json['birthday_requested']?.toString(),
      bloodTypeRequested: json['blood_type_requested']?.toString(),
      enteredApprenticeRequested:
          json['entered_apprentice_requested']?.toString(),
      fellowcraftRequested: json['fellowcraft_requested']?.toString(),
      masterMasonRequested: json['master_mason_requested']?.toString(),
    );
  }
}
