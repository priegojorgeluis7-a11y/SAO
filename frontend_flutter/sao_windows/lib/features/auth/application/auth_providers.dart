import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import '../../../core/network/api_client.dart';
import '../../../core/auth/token_storage.dart';
import '../data/auth_repository.dart';
import '../application/auth_controller.dart';
import '../data/models/user.dart';

/// Provider for AuthRepository
/// Uses ApiClient and TokenStorage from GetIt
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = GetIt.I<ApiClient>();
  final tokenStorage = GetIt.I<TokenStorage>();

  return AuthRepository(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
  );
});

/// Provider for AuthController (StateNotifier)
/// Manages authentication state throughout the app
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

/// Convenience provider - check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.isAuthenticated;
});

/// Convenience provider - get current user (or null if not authenticated)
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.user;
});

/// Convenience provider - check if auth is loading
final authLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.isLoading;
});

/// Convenience provider - get auth error message
final authErrorProvider = Provider<String?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.error;
});
