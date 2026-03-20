import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/token_store.dart';
import '../data/admin_repositories.dart';

class SessionState {
  final bool loading;
  final String? error;
  final String? accessToken;
  final SessionUser? user;

  const SessionState({
    required this.loading,
    required this.error,
    required this.accessToken,
    required this.user,
  });

  const SessionState.initial()
      : loading = false,
        error = null,
        accessToken = null,
        user = null;

  bool get isAuthenticated => accessToken != null && user != null;

  SessionState copyWith({
    bool? loading,
    String? error,
    String? accessToken,
    SessionUser? user,
    bool clearError = false,
  }) {
    return SessionState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      accessToken: accessToken ?? this.accessToken,
      user: user ?? this.user,
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._authRepository) : super(const SessionState.initial());

  final AuthRepository _authRepository;

  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final tokens = await _authRepository.login(email, password);
      final me = await _authRepository.me(tokens.accessToken);
      await TokenStore.save(tokens.accessToken);
      state = SessionState(
        loading: false,
        error: null,
        accessToken: tokens.accessToken,
        user: me,
      );
    } catch (error) {
      state = SessionState(
        loading: false,
        error: 'No se pudo iniciar sesión: $error',
        accessToken: null,
        user: null,
      );
    }
  }

  Future<void> logout() async {
    final token = state.accessToken;
    state = const SessionState.initial();
    await TokenStore.clear();
    if (token == null) {
      return;
    }
    try {
      await _authRepository.logout(token);
    } catch (_) {
      // local-first logout
    }
  }
}

final adminBaseUrlProvider = Provider<String>((ref) {
  const fromDartDefine = String.fromEnvironment('SAO_BACKEND_URL', defaultValue: '');
  if (fromDartDefine.trim().isNotEmpty) {
    return fromDartDefine.trim();
  }
  return 'https://sao-api-fjzra25vya-uc.a.run.app';
});

final adminTransportProvider = Provider<AdminApiTransport>((ref) {
  final baseUrl = ref.watch(adminBaseUrlProvider);
  return HttpAdminApiTransport(baseUrl: baseUrl);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(adminTransportProvider));
});

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository(ref.watch(adminTransportProvider));
});

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(adminTransportProvider));
});

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return AuditRepository(ref.watch(adminTransportProvider));
});

final assignmentsAdminRepositoryProvider =
    Provider<AssignmentsAdminRepository>((ref) {
  return AssignmentsAdminRepository(ref.watch(adminTransportProvider));
});

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref.watch(authRepositoryProvider));
});
