class SignupResponse {
  final String userId;
  final String email;
  final String role;

  const SignupResponse({
    required this.userId,
    required this.email,
    required this.role,
  });

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    return SignupResponse(
      userId: (json['user_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
    );
  }
}