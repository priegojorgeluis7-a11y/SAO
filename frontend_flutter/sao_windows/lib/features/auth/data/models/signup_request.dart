class SignupRequest {
  final String displayName;
  final String email;
  final String password;
  final String role;
  final String inviteCode;

  const SignupRequest({
    required this.displayName,
    required this.email,
    required this.password,
    required this.role,
    required this.inviteCode,
  });

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'email': email,
        'password': password,
        'role': role,
        'invite_code': inviteCode,
      };
}