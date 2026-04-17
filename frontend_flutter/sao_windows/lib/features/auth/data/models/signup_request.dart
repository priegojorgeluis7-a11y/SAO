class SignupRequest {
  final String displayName;
  final String email;
  final String password;
  final String role;
  final String inviteCode;
  final String? firstName;
  final String? lastName;
  final String? secondLastName;
  final String? birthDate;

  const SignupRequest({
    required this.displayName,
    required this.email,
    required this.password,
    required this.role,
    required this.inviteCode,
    this.firstName,
    this.lastName,
    this.secondLastName,
    this.birthDate,
  });

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        if (firstName != null && firstName!.trim().isNotEmpty)
          'first_name': firstName!.trim(),
        if (lastName != null && lastName!.trim().isNotEmpty)
          'last_name': lastName!.trim(),
        if (secondLastName != null && secondLastName!.trim().isNotEmpty)
          'second_last_name': secondLastName!.trim(),
        if (birthDate != null && birthDate!.trim().isNotEmpty)
          'birth_date': birthDate!.trim(),
        'email': email,
        'password': password,
        'role': role,
        'invite_code': inviteCode,
      };
}