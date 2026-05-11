class UserProfile {
  final String name;
  final int? age;
  final String? bloodGroup;
  final String? allergies;
  final String? medications;
  final String? conditions;
  final String? emergencyName;
  final String? emergencyPhone;
  final String? profilePicPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.name,
    this.age,
    this.bloodGroup,
    this.allergies,
    this.medications,
    this.conditions,
    this.emergencyName,
    this.emergencyPhone,
    this.profilePicPath,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isEmpty => name.trim().isEmpty;

  UserProfile copyWith({
    String? name,
    int? age,
    String? bloodGroup,
    String? allergies,
    String? medications,
    String? conditions,
    String? emergencyName,
    String? emergencyPhone,
    String? profilePicPath,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      conditions: conditions ?? this.conditions,
      emergencyName: emergencyName ?? this.emergencyName,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      profilePicPath: profilePicPath ?? this.profilePicPath,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'bloodGroup': bloodGroup,
        'allergies': allergies,
        'medications': medications,
        'conditions': conditions,
        'emergencyName': emergencyName,
        'emergencyPhone': emergencyPhone,
        'profilePicPath': profilePicPath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] ?? '',
        age: j['age'],
        bloodGroup: j['bloodGroup'],
        allergies: j['allergies'],
        medications: j['medications'],
        conditions: j['conditions'],
        emergencyName: j['emergencyName'],
        emergencyPhone: j['emergencyPhone'],
        profilePicPath: j['profilePicPath'],
        createdAt: DateTime.parse(j['createdAt']),
        updatedAt: DateTime.parse(j['updatedAt']),
      );

  factory UserProfile.empty() => UserProfile(
        name: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  /// Compact profile string used as system-prompt context for the AI.
  /// Sent with every chat/rescue message so Gemma knows the user.
  String toAIContext() {
    final parts = <String>[];
    if (name.isNotEmpty) parts.add('Name: $name');
    if (age != null) parts.add('Age: $age');
    if (bloodGroup != null && bloodGroup!.isNotEmpty) {
      parts.add('Blood group: $bloodGroup');
    }
    if (conditions != null && conditions!.trim().isNotEmpty) {
      parts.add('Medical conditions: $conditions');
    }
    if (allergies != null && allergies!.trim().isNotEmpty) {
      parts.add('Allergies: $allergies');
    }
    if (medications != null && medications!.trim().isNotEmpty) {
      parts.add('Medications: $medications');
    }
    if (emergencyName != null && emergencyName!.trim().isNotEmpty) {
      parts.add('Emergency contact: $emergencyName'
          '${emergencyPhone?.isNotEmpty == true ? " ($emergencyPhone)" : ""}');
    }
    if (parts.isEmpty) return '';
    return 'USER PROFILE: ${parts.join(" • ")}';
  }
}
